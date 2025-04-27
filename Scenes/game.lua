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

local DEBUG_DRAW_COLLIDERS = false

function love.keypressed(k)
    if k == "f1" then DEBUG_DRAW_COLLIDERS = not DEBUG_DRAW_COLLIDERS end
    if k == "u" then Player.playCard(1)
    elseif k == "i" then Player.playCard(2)
    elseif k == "o" then Player.playCard(3)
    elseif k == "j" then Player.playCard(4)
    elseif k == "k" then Player.playCard(5)
    end
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

local function spawnRobots()
    table.insert(walkers, Walker.new(200, 150, collider))
    table.insert(walkers, Walker.new(500, 300, collider))
    table.insert(tanks,   Tank.new  (400, 400, collider))
    table.insert(tanks,   Tank.new  (500, 400, collider))
end

function game.load()
    map      = sti("Assets/Maps/introLevel.lua")
    collider = HC.new()
    cam      = Camera(0, 0); cam.scale = ZOOM
    game.collider = collider

    Player.load(collider)
    Projectiles.init(collider)
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
-- -------------------------------------------------- update
function game.update(dt)
    Player.update(dt, collider)

    -- build one list that contains *all* active robots
    local robots = {}
    for _, w in ipairs(walkers) do robots[#robots+1] = w end
    for _, t in ipairs(tanks)   do robots[#robots+1] = t end
    

    for i = #walkers, 1, -1 do
        walkers[i]:update(dt, Player, robots,  game, slide)
        if walkers[i].hp <= 0 then
            table.insert(critters, Critter.new(walkers[i].x, walkers[i].y))
            collider:remove(walkers[i].shape)
            table.remove(walkers, i)
        end
    end

    for i = #tanks, 1, -1 do
        -- in game.lua, inside the tank loop
        tanks[i]:update(dt, Player, robots, game, slide, collider)
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

    -- card reward for rescued critters
    if Player.critterCount >= Player.nextCardReward then
        Player.addCards(3)
        Player.nextCardReward = Player.nextCardReward + 5
    end

    Projectiles.update(dt)
    resolveProjectiles()
    Particles.update(dt)

    if #Player.hand < 5 then
        Player.addCards(1) -- add cards constantly for testing REMOVETHIS
    end


    -- push player out of walls
    local cols = collider:collisions(Player.shape)
    for other, sep in pairs(cols) do
        if other.type == "wall" then
            Player.shape:move(sep.x, sep.y)
        end
    end
    Player.x, Player.y = Player.shape:center()

    -- camera smoothing + shake
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
        -- TODO: push shop/state-change here
    end    
end
-- -------------------------------------------------- draw
function game.draw()
    cam:attach(); love.graphics.translate(game.shX, game.shY)
        map:drawTileLayer("Ground"); map:drawTileLayer("Walls"); map:drawTileLayer("Props")

        -- depth sort
        local render = {}
        for _,w in ipairs(walkers)  do table.insert(render, w) end
        for _,t in ipairs(tanks)    do table.insert(render, t) end
        table.insert(render, Player)
        for _,c in ipairs(critters) do table.insert(render, c) end
        table.sort(render, function(a,b) return a.y < b.y end)
        for _,e in ipairs(render) do e:draw() end

        Projectiles.draw(); Particles.draw()
        map:drawTileLayer("Above")

        -- DEBUG collider outlines (F1 toggle)
        if DEBUG_DRAW_COLLIDERS then
            love.graphics.setColor(1, 0, 0, 0.5)
            -- HC keeps its shapes in collider.shapes  (table indexed by shape)
            for s in pairs(collider.shapes) do
                if s:typeOf("Circle") then
                    local cx, cy = s:center()
                    love.graphics.circle("line", cx, cy, s:radius())
                elseif s:typeOf("Polygon") then
                    love.graphics.polygon("line", s:unpack())
                end
            end
            love.graphics.setColor(1, 1, 1)
        end

    cam:detach()

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

    -- hand of cards (bottom-right) ----------------------------------------------
    local imgW, imgH = 731, 1024
    local scale      = 0.15
    local cardW, cardH = imgW*scale, imgH*scale

    local n = #Player.hand
    if n > 0 then
        --------------------------------------------------------------------------
        -- FAN TUNABLES
        local FAN_ANGLE_TOTAL  = math.rad(-60)   -- total left-to-right sweep
        local FAN_X_TOTAL      = 300             -- x spread of the fan
        local FAN_Y_TOTAL      = 0               -- y spread (positive = up)
        --------------------------------------------------------------------------

        -- distribute over the *gaps* between cards
        local stepAng = (n > 1) and FAN_ANGLE_TOTAL/(n-1) or 0
        local stepX   = (n > 1) and FAN_X_TOTAL /(n-1) or 0
        local stepY   = (n > 1) and FAN_Y_TOTAL /(n-1) or 0

        -- anchor = centre of the *front* (top) card
        local baseX = love.graphics.getWidth()  - 20 - cardW/2
        local baseY = love.graphics.getHeight() - 20 - cardH/2

        for i, card in ipairs(Player.hand) do
            -- draw order: back first, front last
            local back = n - i        -- 0 for front card, (n-1) for back
            local ang  = -FAN_ANGLE_TOTAL/2 + back*stepAng
            local x    = baseX - back*stepX
            local y    = baseY - back*stepY

            local img = card.img
            if img and img:typeOf("Image") then
                love.graphics.draw(img, x, y, ang, scale, scale,
                                imgW/2, imgH/2)
            else
                love.graphics.setColor(0.2,0.2,0.2)
                love.graphics.rectangle("fill",
                    x-cardW/2, y-cardH/2, cardW, cardH, 6, 6)
                love.graphics.setColor(1,1,1)
            end
        end
    end


    suit.layout:reset(10,10)
    suit.Label("HP: "..Player.health,     suit.layout:row(120,20))
    suit.Label("Critters: "..(Player.critterCount or 0), suit.layout:row())
    if suit.Button("Quit", suit.layout:row(80,30)).hit then love.event.quit() end
end

return game
