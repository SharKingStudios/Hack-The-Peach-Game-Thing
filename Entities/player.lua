-- Entities/Player.lua --------------------------------------------------------
local HC        = require "Libraries.HC"
local Particles = require "Systems.particles"          -- for poof FX
local Spells = require "Systems.spells"


local Player = {
    x = 128, y = 128, vx = 0, vy = 0,
    speed = 120, accel = 600,
    health = 5, critterCount = 0, nextCardReward = 5,
    hand = {},                                -- animated card instances
    spellCD = 0,                              -- seconds remaining
    shape = nil,
    dir = "front",                         -- front/back/left/right
    sprites = {},                          -- loaded in .load()
    w = 32,  h = 48,                       -- adjust to your PNG size

}

-- --------------------------------------------------------------------------- constants
local MAX_HEALTH      = 5
local HAND_LIMIT      = 5
local SPELL_COOLDOWN  = 1.0                   -- seconds
local SCALE           = 0.15                  -- card draw scale
local IMG_W, IMG_H    = 731, 1024             -- raw card PNG size
local CARD_W, CARD_H  = IMG_W*SCALE, IMG_H*SCALE
SPELL_COOLDOWN_OFFSET = 70        -- pixels the card “sinks” while locked

-- cached deck --------------------------------------------------------------- lazy images
local CARD_DB = {
    -- ITEM CARDS -------------------------------------------------------------
    apple  = { file="Assets/Sprites/apple_item.png",  type="item",
               onPlay=function(p) p.health = math.min(p.health+1 , MAX_HEALTH) end },
 
    banana = { file="Assets/Sprites/banana_item.png", type="item",
               onPlay=function(p) p.health = math.min(p.health+2 , MAX_HEALTH) end },
 
    peach  = { file="Assets/Sprites/peach_item.png",  type="item",
               onPlay=function(p) p.health = math.min(p.health+3 , MAX_HEALTH) end },
 
    -- SPELL CARDS ------------------------------------------------------------
    -- fireball  = { file="Assets/Sprites/fireball_card.png",  type="spell", charges=3,
            --   onPlay=function(p,c) Spells.cast(p,"fireball") c.charges=c.charges-1 end },

    lightning = { file="Assets/Sprites/lightning_card.png", type="spell", charges=1,
                onPlay=function(p,c) Spells.cast(p,"lightning") c.charges=c.charges-1 end },
 
    tornado   = { file="Assets/Sprites/tornado_card.png",   type="spell", charges=1,
                  onPlay=function(p,c) Spells.cast(p,"tornado") c.charges=c.charges-1 end },
 
    -- whirlpool = { file="Assets/Sprites/whirlpool_card.png", type="spell", charges=1,
                --   onPlay=function(p,c) Spells.cast(p,"whirlpool") c.charges=c.charges-1 end },
}
Player.CARD_DB = CARD_DB
 
local function getCardDef(id)
    local d = CARD_DB[id]
    if not d.img then d.img = love.graphics.newImage(d.file) end -- lazy load
    return d
end
local DECK_IDS = {}; for id in pairs(CARD_DB) do DECK_IDS[#DECK_IDS+1] = id end

-- --------------------------------------------------------------------------- helpers
local function anyDown(keys)
    for _,k in ipairs(keys) do if love.keyboard.isDown(k) then return true end end
end

local function makeInstance(id)               -- build animated instance
    local def = getCardDef(id)
    local xOff = love.graphics.getWidth() + CARD_W     -- spawn off-screen
    local yOff = love.graphics.getHeight() + CARD_H
    local inst = {x=xOff, y=yOff, angle=0, targetX=0, targetY=0, targetAngle=0, uses=def.uses or 1}
    setmetatable(inst, {__index=def})         -- inherit .img, .type, .onPlay
    return inst
end

local function layoutHand()
    local n = #Player.hand; if n==0 then return end
    local FAN_ANG  = math.rad(-60);             -- whole sweep
    local FAN_X    = 300;  local FAN_Y = 0
    local stepAng  = (n>1) and FAN_ANG/(n-1) or 0
    local stepX    = (n>1) and FAN_X /(n-1)  or 0
    local stepY    = (n>1) and FAN_Y /(n-1)  or 0

    local baseX = love.graphics.getWidth()  - 20 - CARD_W/2
    local baseY = love.graphics.getHeight() - 20 - CARD_H/2

    for i, card in ipairs(Player.hand) do
        local back = n - i
        card.targetX      = baseX - back*stepX
        card.targetY      = baseY - back*stepY
        card.targetAngle  = -FAN_ANG/2 + back*stepAng
    end
end

-- --------------------------------------------------------------------------- public API
function Player.addCards(n)
    for _ = 1, n do
        if #Player.hand >= HAND_LIMIT then break end
        local id = DECK_IDS[love.math.random(#DECK_IDS)]
        Player.hand[#Player.hand+1] = makeInstance(id)
    end
    -- items first, spells after (dont sort its confusing)
    -- table.sort(Player.hand, function(a,b) return (a.type=="item" and b.type=="spell") end)
    layoutHand()
end

function Player.addCard(id)
    if #Player.hand >= HAND_LIMIT then return end
    -- makeInstance is already in scope above
    Player.hand[#Player.hand+1] = makeInstance(id)
    layoutHand()
end

function Player.playCard(slot)
    local card = Player.hand[slot]; if not card then return end
    if card.type=="spell" and Player.spellCD>0 then return end

    card.onPlay(Player, card) -- **pass card, too**

    if card.type=="spell" then
        if not card.charges or card.charges<=0 then
            table.remove(Player.hand,slot) -- only when out of charges
        end
        Player.spellCD = SPELL_COOLDOWN
    else
        table.remove(Player.hand,slot) -- items still disappear
    end
    layoutHand()
end


-- --------------------------------------------------------------------------- core callbacks
function Player.load(collider)
    Player.health = MAX_HEALTH

    local base = "Assets/Sprites/Player/heidi_"
    Player.sprites.front = love.graphics.newImage(base.."front_sprite.png")
    Player.sprites.back  = love.graphics.newImage(base.."back_sprite.png")
    Player.sprites.left  = love.graphics.newImage(base.."left_sprite.png")
    Player.sprites.right = love.graphics.newImage(base.."right_sprite.png")

    Player.shape = collider:rectangle(Player.x-Player.w/2, Player.y-Player.h/2,
                                      Player.w, Player.h)
    Player.shape.object = Player
end


function Player.damage(dmg, game)
    Player.health = math.max(Player.health - dmg, 0)
    game.shake(12,0.35)
end

function Player.update(dt, collider)
    ---------------------------------------------------------------- movement
    local dx,dy = 0,0
    if anyDown{"w","up"}   then dy = dy-1 end
    if anyDown{"s","down"} then dy = dy+1 end
    if anyDown{"a","left"} then dx = dx-1 end
    if anyDown{"d","right"}then dx = dx+1 end
    local len = math.sqrt(dx*dx+dy*dy)
    if len>0 then
        Player.vx = Player.vx + (dx/len)*Player.accel*dt
        Player.vy = Player.vy + (dy/len)*Player.accel*dt
        local sp  = math.sqrt(Player.vx^2 + Player.vy^2)
        if sp > Player.speed then
            Player.vx,Player.vy = Player.vx/sp*Player.speed, Player.vy/sp*Player.speed
        end
    else Player.vx,Player.vy = 0,0 end
    Player.x = Player.x + Player.vx*dt
    Player.y = Player.y + Player.vy*dt
    Player.shape:moveTo(Player.x, Player.y)

    -- -------------------------------------------------------------- animation
    -- if #Player.frames>1 then
    --     Player.timer = Player.timer + dt
    --     if Player.timer >= Player.interval then
    --         Player.timer = Player.timer - Player.interval
    --         Player.frame = Player.frame % #Player.frames + 1
    --     end
    -- end

    -- update facing ---------------------------------------------------------
    if math.abs(Player.vx) + math.abs(Player.vy) > 4 then
        if math.abs(Player.vx) > math.abs(Player.vy) then
            Player.dir = (Player.vx > 0) and "right" or "left"
        else
            Player.dir = (Player.vy > 0) and "front" or "back"
        end
    end

    -------------------------------------------------------------- cooldown
    local prevCD = Player.spellCD -- cooldown tick & relayout when it crosses 0
    if Player.spellCD > 0 then
        Player.spellCD = math.max(0, Player.spellCD - dt)
    end
    if (prevCD == 0 and Player.spellCD > 0) or (prevCD > 0 and Player.spellCD == 0) then
        layoutHand()     -- targets change → cards glide automatically
    end

    if Player.spellCD > 0 then Player.spellCD = math.max(0, Player.spellCD - dt) end

    -------------------------------------------------------------- card motion
    for _,c in ipairs(Player.hand) do
        local s = 12*dt                       -- lerp speed
        c.x     = c.x     + (c.targetX    - c.x)    * s
        local dip = (c.type == "spell" and Player.spellCD > 0) and SPELL_COOLDOWN_OFFSET or 0
        c.y = c.y + ((c.targetY + dip) - c.y) * s
        c.angle = c.angle + (c.targetAngle- c.angle)* s
    end
end

function Player.draw()
    local img = Player.sprites[Player.dir] or Player.sprites.front
    love.graphics.draw(img, Player.x-Player.w/2, Player.y-Player.h/2)
end

return Player
