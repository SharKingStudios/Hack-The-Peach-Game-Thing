-- Scenes/game.lua
local sti        = require "Libraries.sti"
local Camera     = require "Libraries.hump.camera"
local HC         = require "Libraries.HC"
local suit       = require "Libraries.suit"

local Player     = require "Entities.player"
local Walker     = require "Entities.walker"
local Tank       = require "Entities.tank"
local Critter    = require "Entities.critter"

local Projectiles= require "Systems.projectiles"
local Particles  = require "Systems.particles"

local game = {}
local map, cam, collider
local walkers, tanks, critters = {}, {}, {}
local CAMERA_SMOOTH, ZOOM = 8, 2
game.gameoverFade = 0

local DEBUG_DRAW_COLLIDERS = false

-- shop & level state
local Levels = {
  "introLevel.lua",
  "introLevel.lua",
  "level1.lua",
  "level2.lua",
  "level3.lua",
  "level4.lua",
  "level5_floor1.lua",
  "level5_floor2.lua",
  "level6.lua",
}
game.currentLevel = 1
game.state        = "playing"   -- "playing" | "shop" | "fading"
game.shop         = { cards = {}, timer = 0, fade = 0 }

function love.keypressed(k)
    if k == "f1" then DEBUG_DRAW_COLLIDERS = not DEBUG_DRAW_COLLIDERS end
    if k == "y" then Player.playCard(1)
    elseif k == "u" then Player.playCard(2)
    elseif k == "i" then Player.playCard(3)
    elseif k == "o" then Player.playCard(4)
    elseif k == "p" then Player.playCard(5)
    end
    if k=="h" then require("Systems.spells").melee(Player) end
end

-- -------------------------------------------------- HUD constants
local HUD = {
    SCALE           = 3, -- scale all except cards
    HEART_MARGIN_X  = 12,
    HEART_MARGIN_Y  = 12,
    CRITTER_MARGIN  = 16,
}

local heartImg   = love.graphics.newImage("Assets/Sprites/heart.png")    -- or nil
local critterImg = love.graphics.newImage("Assets/Sprites/critter.png")  -- or nil

-- sizes after scaling -------------------------------------------------------
HUD.HEART_W = (heartImg:typeOf("Image") and heartImg:getWidth() or 24) * HUD.SCALE
HUD.HEART_H = (heartImg:typeOf("Image") and heartImg:getHeight() or 24) * HUD.SCALE
HUD.HEART_SP = HUD.HEART_W + 4                                           -- gap

HUD.CRITTER_W = (critterImg:typeOf("Image") and critterImg:getWidth() or 16)*HUD.SCALE
HUD.CRITTER_H = (critterImg:typeOf("Image") and critterImg:getHeight() or 16)*HUD.SCALE

-- bigger VCR font
local hudFont = love.graphics.newFont("Assets/Fonts/VCR_OSD_MONO.ttf", 36)

-- screen-shake state
game.shT, game.shDur, game.shInt, game.shX, game.shY = 0, 0, 0, 0, 0
function game.shake(int, dur) game.shInt, game.shDur, game.shT = int, dur, dur end

function game.isVisible(x, y, pad)
    local w, h = love.graphics.getWidth()/2, love.graphics.getHeight()/2
    return math.abs(x - cam.x) <= w + pad and math.abs(y - cam.y) <= h + pad
end

-- helper that moves a shape and resolves overlaps
local function slide(shape, dx, dy)
    shape:move(dx, dy)
    for other, sep in pairs(collider:collisions(shape)) do
        if other.type == "wall" then
            shape:move(sep.x, sep.y)
        end
    end
    return shape:center()
end

-- per‐level spawn config: { playerStart={x,y}, robotSpawns={{"walker",x,y}, ...} }
local LevelConfigs = {
  [1] = {
    playerStart = {128,128},
    robotSpawns = {
      {"walker", 400,150},
      {"walker", 500,300},
      {"tank",   400,400},
      {"tank",   500,400},
      {"walker", 300,250},
    }
  },
  [2] = {
    playerStart = {700,500},
    robotSpawns = {
      {"walker", 250,200},
      {"walker", 450,350},
      {"tank",   350,450},
      {"tank",   550,300},
      {"walker", 300,300},
    }
  },
  [3] = {
    playerStart = {128,128},
    robotSpawns = {
      {"walker", 180,180},
      {"walker", 520,320},
      {"tank",   420,420},
      {"tank",   480,360},
      {"walker", 360,240},
    }
  },
  [4] = {
    playerStart = {128,128},
    robotSpawns = {
      {"walker", 180,180},
      {"walker", 520,320},
      {"tank",   420,420},
      {"tank",   480,360},
      {"walker", 360,240},
    }
  },
  [5] = {
    playerStart = {128,128},
    robotSpawns = {
      {"walker", 180,180},
      {"walker", 520,320},
      {"tank",   420,420},
      {"tank",   480,360},
      {"walker", 360,240},
    }
  },
  [6] = {
    playerStart = {128,128},
    robotSpawns = {
      {"walker", 180,180},
      {"walker", 520,320},
      {"tank",   420,420},
      {"tank",   480,360},
      {"walker", 360,240},
    }
  },
  [7] = {
    playerStart = {128,128},
    robotSpawns = {
      {"walker", 180,180},
      {"walker", 520,320},
      {"tank",   420,420},
      {"tank",   480,360},
      {"walker", 360,240},
    }
  },
}

local function spawnRobots()
    local cfg = LevelConfigs[game.currentLevel] or LevelConfigs[1]
    for _, r in ipairs(cfg.robotSpawns) do
        local kind, x, y = r[1], r[2], r[3]
        if kind == "walker" then
            table.insert(walkers, Walker.new(x, y, collider))
        else
            table.insert(tanks,   Tank.new  (x, y, collider))
        end
    end
end

function game.load()
    map      = sti("Assets/Maps/"..Levels[game.currentLevel])
    collider = HC.new()
    cam      = Camera(0, 0); cam.scale = ZOOM
    game.collider = collider
    
    -- (re)load player shape but keep health/critterCount/hand
    local start   = LevelConfigs[game.currentLevel].playerStart
    local prevHP  = Player.health
    Player.load(collider)
    Projectiles.init(collider)
    Player.health      = prevHP
    Player.x, Player.y = start[1], start[2]
    Player.shape:moveTo(Player.x, Player.y)
    -- spawn this level’s robots
    spawnRobots()

    -- static walls from “Collide” object layer
    for _, obj in ipairs(map.layers["Collide"].objects or {}) do
        local s = collider:rectangle(obj.x, obj.y, obj.width, obj.height)
        s.type = "wall"
    end
end

local function levelCleared()
    return #walkers == 0 and #tanks == 0 and #critters == 0
end

-- -------------------------------------------------- projectile vs everything
local function resolveProjectiles()
    for i = #Projectiles.list, 1, -1 do
        local p = Projectiles.list[i]
        if p.side == "enemy" then
            if p.shape:collidesWith(Player.shape) then
                Player.damage(1, game)
                collider:remove(p.shape)
                table.remove(Projectiles.list, i)
            end
        end
    end
end

local function cardTint(c)
    local f = (c.y - c.targetY) / SPELL_COOLDOWN_OFFSET
    if c.type=="spell" and f>0 then
        local g = 1 - 0.6*f
        love.graphics.setColor(g,g,g)
    else
        love.graphics.setColor(1,1,1)
    end
end


-- -------------------------------------------------- shop / level helpers
function game:startShop()
    -- switch into shop once
    game.state       = "shop"
    game.shop.timer  = 0
    game.shop.fade   = 0
    -- grab current screen dims
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    -- build a pool of all card IDs from Player.CARD_DB
    local pool = {}
    for id,_ in pairs(Player.CARD_DB) do
        pool[#pool+1] = id
    end
    game.shop.cards = {}
    for i=1,3 do
        local id      = pool[love.math.random(#pool)]
        local data    = Player.CARD_DB[id]
        local cost    = love.math.random(1,5)
        local spacing = 220
        -- use the already-loaded image in Player.CARD_DB
        -- ensure the card image is loaded
        local img     = data.img or love.graphics.newImage(data.file)
        data.img      = img
        table.insert(game.shop.cards, {
            id   = id,
            img  = img,
            cost = cost,
            x    = W/2 + (i-2)*spacing,
            y0   = H + 150,
            y1   = H/2,
            y    = H + 150,
            w    = 180, h = 260,
        })
    end
end

function game:exitShop()
    game.state = "fading"
    game.shop.fade = 0
end

function game:loadLevel(idx)
    if not Levels[idx] then return end
    game.currentLevel = idx
    game.state        = "playing"
    -- clear existing robots & critters
    walkers, tanks, critters = {}, {}, {}

    -- load the new map and collider
    map      = sti("Assets/Maps/"..Levels[idx])
    collider = HC.new()
    cam      = Camera(0,0); cam.scale = ZOOM
    game.collider = collider

    -- reposition player (preserve health, hand, critterCount)
    local cfg    = LevelConfigs[idx]
    local startX, startY = cfg.playerStart[1], cfg.playerStart[2]
    local prevHP = Player.health
    Player.load(collider)
    Projectiles.init(collider)
    Player.health      = prevHP
    Player.x, Player.y = startX, startY
    Player.shape:moveTo(Player.x, Player.y)

    -- spawn robots from the level config
    spawnRobots()

    -- rebuild static walls
    for _, obj in ipairs(map.layers["Collide"].objects or {}) do
        local s = collider:rectangle(obj.x, obj.y, obj.width, obj.height)
        s.type = "wall"
    end
end

-- -------------------------------------------------- update
function game.update(dt)
    if game.state == "playing" then
        Player.update(dt, collider)

        if game.state == "playing" and Player.health <= 0 then
            game.state        = "gameover"
            game.gameoverFade = 0
            return
        end

        local robots = {}
        for _, w in ipairs(walkers) do robots[#robots+1] = w end
        for _, t in ipairs(tanks)   do robots[#robots+1] = t end

        require("Systems.spells").update(dt)

        for i = #walkers, 1, -1 do
            walkers[i]:update(dt, Player, robots,  game, slide)
            if walkers[i].hp <= 0 then
                table.insert(critters, Critter.new(walkers[i].x, walkers[i].y))
                collider:remove(walkers[i].shape)
                table.remove(walkers, i)
            end
        end

        for i = #tanks, 1, -1 do
            tanks[i]:update(dt, Player, robots, game, slide)
            if tanks[i].hp <= 0 then
                table.insert(critters, Critter.new(tanks[i].x, tanks[i].y))
                collider:remove(tanks[i].shape)
                table.remove(tanks, i)
            end
        end

        for i = #critters, 1, -1 do
            critters[i]:update(dt, Player, Particles)
            if critters[i].dead then table.remove(critters, i) end
        end

        if Player.critterCount >= Player.nextCardReward then
            Player.addCards(3)
            Player.nextCardReward = Player.nextCardReward + 5
        end

        Projectiles.update(dt)
        resolveProjectiles()
        Particles.update(dt)

        if #Player.hand < 5 then
            Player.addCards(1) -- testing
        end

        -- walls collision, camera, map update...
        local cols = collider:collisions(Player.shape)
        for other, sep in pairs(cols) do
            if other.type == "wall" then
                Player.shape:move(sep.x, sep.y)
            end
        end
        Player.x, Player.y = Player.shape:center()

        local nx = cam.x + (Player.x - cam.x) * math.min(dt*CAMERA_SMOOTH,1)
        local ny = cam.y + (Player.y - cam.y) * math.min(dt*CAMERA_SMOOTH,1)
        cam:lookAt(nx, ny)
        if game.shT > 0 then
            game.shT = game.shT - dt
            local m = game.shInt * (game.shT / game.shDur)
            game.shX = (love.math.random()*2-1)*m
            game.shY = (love.math.random()*2-1)*m
        else game.shX, game.shY = 0, 0 end

        map:update(dt)

        if levelCleared() then
            game:startShop()
        end

    elseif game.state == "shop" then
        -- animate cards in
        game.shop.timer = math.min(game.shop.timer + dt, 1)
        for _, card in ipairs(game.shop.cards) do
            card.y = card.y0 + (card.y1 - card.y0) * game.shop.timer
        end

    elseif game.state == "fading" then
        game.shop.fade = math.min(game.shop.fade + dt, 1)
        if game.shop.fade >= 1 then
            game:loadLevel(game.currentLevel + 1)
        end
    elseif game.state == "gameover" then
        -- fade to black over ~2 seconds
        game.gameoverFade = math.min(game.gameoverFade + dt * 0.5, 1)
        return
    end
end

-- -------------------------------------------------- draw
function game.draw()
    if game.state == "gameover" then
        local W, H = love.graphics.getWidth(), love.graphics.getHeight()
        -- black fullscreen with fade
        love.graphics.setColor(0, 0, 0, game.gameoverFade)
        love.graphics.rectangle("fill", 0, 0, W, H)
        -- draw Game Over text
        love.graphics.setFont(hudFont)
        love.graphics.setColor(1, 1, 1, game.gameoverFade)
        local title = "GAME OVER"
        local sub   = "Those poor critters..."
        local w1 = hudFont:getWidth(title)
        local w2 = hudFont:getWidth(sub)
        love.graphics.print(title, W/2 - w1/2, H/2 - 20)
        love.graphics.print(sub,   W/2 - w2/2, H/2 + 20)
        return
    end

    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    cam:attach(); love.graphics.translate(game.shX, game.shY)
        map:drawTileLayer("Ground"); map:drawTileLayer("Walls"); map:drawTileLayer("Props")

        local render = {}
        for _,w in ipairs(walkers)  do table.insert(render, w) end
        for _,t in ipairs(tanks)    do table.insert(render, t) end
        table.insert(render, Player)
        for _,c in ipairs(critters) do table.insert(render, c) end
        table.sort(render, function(a,b) return a.y < b.y end)
        for _,e in ipairs(render) do e:draw() end

        Projectiles.draw(); Particles.draw()
        require("Systems.spells").draw()
        map:drawTileLayer("Above")

        -- Robots remaining
        love.graphics.setColor(1,1,1)
        love.graphics.print("Robots Remaining: "..(#walkers + #tanks), 10, H - 30)

        if DEBUG_DRAW_COLLIDERS then
            love.graphics.setColor(1, 0, 0, 0.5)
            for s in pairs(collider.shapes) do
                if s:typeOf("Circle") then
                    local cx, cy = s:center()
                    love.graphics.circle("line", cx, cy, s:radius())
                elseif s:typeOf("Polygon") then
                    love.graphics.polygon("line", s:unpack())
                end
            end
            love.graphics.setColor(1,1,1)
        end
    cam:detach()

    love.graphics.setFont(hudFont)

    if game.state == "shop" then
        -- darken screen
        love.graphics.setColor(0,0,0,0.6)
        love.graphics.rectangle("fill", 0,0, W,H)
        -- critter currency
        love.graphics.setColor(1,1,1)
        love.graphics.print("Critters: "..Player.critterCount, W/2 - 60, 50)
        -- draw cards
        for _, card in ipairs(game.shop.cards) do
            local affordable = Player.critterCount >= card.cost
            love.graphics.setColor(affordable and 1 or 0.3, affordable and 1 or 0.3, affordable and 1 or 0.3)
            love.graphics.draw(card.img, card.x, card.y, 0, card.w/card.img:getWidth(), card.h/card.img:getHeight(), card.img:getWidth()/2, card.img:getHeight()/2)
            love.graphics.setColor(1,1,1)
            love.graphics.print("Cost: "..card.cost, card.x - 30, card.y + card.h/2 + 10)
        end
        return
    end

    -- -------------------------------------------------- HUD  (hearts / critters / hand)
    love.graphics.setFont(hudFont)

    -- hearts -------------------------------------------------
    for i = 1, 5 do
        local x = HUD.HEART_MARGIN_X + (i-1)*HUD.HEART_SP
        local y = HUD.HEART_MARGIN_Y
        if heartImg:typeOf("Image") then
            if i <= Player.health then
                love.graphics.draw(heartImg, x, y, 0,
                                HUD.SCALE, HUD.SCALE)
            else
                love.graphics.setColor(0.3,0.3,0.3)
                love.graphics.draw(heartImg, x, y, 0, HUD.SCALE, HUD.SCALE)
                love.graphics.setColor(1,1,1)
            end
        else
            love.graphics.setColor(i<=Player.health and {1,0,0} or {0.3,0.3,0.3})
            love.graphics.rectangle("fill", x, y, HUD.HEART_W, HUD.HEART_H)
            love.graphics.setColor(1,1,1)
        end
    end

    -- critter counter (top-right) ----------------------------
    local cw, ch = HUD.CRITTER_W, HUD.CRITTER_H
    local cx = love.graphics.getWidth() - cw - HUD.CRITTER_MARGIN
    local cy = HUD.HEART_MARGIN_Y
    if critterImg:typeOf("Image") then
        love.graphics.draw(critterImg, cx, cy, 0, HUD.SCALE, HUD.SCALE)
    else
        love.graphics.setColor(1,1,0); love.graphics.rectangle("fill", cx, cy, cw, ch); love.graphics.setColor(1,1,1)
    end
    local countStr = tostring(Player.critterCount)
    love.graphics.print(countStr,
        cx - 12 - hudFont:getWidth(countStr),               -- 12-px gap
        cy + (ch - hudFont:getHeight())/2)

    -- hand of cards (bottom-right) -------------------------------------------
    -- cards already know their animated x, y, angle (set in Player.update)
    local IMG_W, IMG_H = 731, 1024          -- raw sprite size (for pivot)
    local SCALE        = 0.15               -- same scale you used before

    for i = 1, #Player.hand do -- back to front
        local c = Player.hand[i]
        if c.img then
            cardTint(c)
            love.graphics.draw(c.img, c.x, c.y, c.angle, SCALE, SCALE, IMG_W/2, IMG_H/2)
            love.graphics.setColor(1,1,1)
        end

        if c.charges and c.charges>1 then
            love.graphics.setFont(hudFont)
            love.graphics.print("x"..c.charges, c.x, c.y-130, 0, 0.5,0.5)
        end
    end


    suit.layout:reset(10,10)
    suit.Label("HP: "..Player.health,     suit.layout:row(120,20))
    suit.Label("Critters: "..(Player.critterCount or 0), suit.layout:row())
    if suit.Button("Quit", suit.layout:row(80,30)).hit then love.event.quit() end

    Particles.drawGUI()

    if game.state == "fading" then
        love.graphics.setColor(0,0,0, game.shop.fade)
        love.graphics.rectangle("fill", 0,0, W,H)
    end
end

-- mouse click handling for shop
function love.mousepressed(x,y,b)
    if game.state=="shop" and b==1 then
        if #Player.hand >= 5 then
            game:exitShop()
            return
        end
        for _, card in ipairs(game.shop.cards) do
            if math.abs(x-card.x) < card.w/2 and math.abs(y-card.y) < card.h/2 then
                if Player.critterCount >= card.cost then
                    Player.critterCount = Player.critterCount - card.cost
                    Player:addCard(card.id)
                    game:exitShop()
                end
                return
            end
        end
    end
end

return game
