-- Entities/player.lua --------------------------------------------------------
local HC = require "Libraries.HC"
local Player = {
    x = 128, y = 128, vx = 0, vy = 0,
    speed = 120, accel = 600,
    w = 32, h = 48,
    img = nil, frames={}, frame=1,timer=0,interval=0.2,
    health = 5,                       -- will be reset below
    critterCount = 0,
    nextCardReward = 5,
    hand  = {},                       -- start with no cards
    shape = nil
}

local MAX_HEALTH = 5
Player.health = MAX_HEALTH           -- centralised setter

-- --------------------------------------------------------------------------- CARD DATABASE
local CARD_DB = {
    --  items ----------------------------------------
    apple     = {file="Assets/Sprites/apple_item.png",     type="item",
                 onPlay=function() Player.health = math.min(Player.health+1, MAX_HEALTH) end},
    banana    = {file="Assets/Sprites/banana_item.png",    type="item",
                 onPlay=function() Player.health = math.min(Player.health+2, MAX_HEALTH) end},
    peach     = {file="Assets/Sprites/peach_item.png",     type="item",
                 onPlay=function() Player.health = math.min(Player.health+3, MAX_HEALTH) end},
    --  spells (effect stubs for now) -----------------
    fireball  = {file="Assets/Sprites/fireball_card.png",  type="spell", onPlay=function() end},
    lightning = {file="Assets/Sprites/lightning_card.png", type="spell", onPlay=function() end},
    tornado   = {file="Assets/Sprites/tornado_card.png",   type="spell", onPlay=function() end},
    whirlpool = {file="Assets/Sprites/whirlpool_card.png", type="spell", onPlay=function() end},
}

-- lazy-load helper: guarantees .img is a love Image --------------------------
local function getCard(id)
    local c = CARD_DB[id]
    if not c.img then                -- first access?  load the sprite now
        c.img = love.graphics.newImage(c.file)
    end
    return c
end

-- build a deck list (just the ids) ------------------------------------------
Player.deck = {}
for id in pairs(CARD_DB) do Player.deck[#Player.deck+1] = id end

-- --------------------------------------------------------------------------- INPUT HELPERS
local function anyDown(keys)
    for _,k in ipairs(keys) do if love.keyboard.isDown(k) then return true end end
end

-- --------------------------------------------------------------------------- CARD HANDLING
function Player.addCards(n)
    for _ = 1, n do
        if #Player.hand >= 5 then break end          -- hand limit
        local id = Player.deck[love.math.random(#Player.deck)]
        Player.hand[#Player.hand+1] = getCard(id)
    end
    -- keep items first, spells later (Dont sort its confusing lol)
    -- table.sort(Player.hand, function(a,b)
    --     return (a.type=="item" and b.type=="spell")
    -- end)
end

function Player.playCard(slot)                      -- slot = 1..5 (UI hotkeys)
    local card = Player.hand[slot]; if not card then return end
    if card.onPlay then card.onPlay() end
    table.remove(Player.hand, slot)
end

-- --------------------------------------------------------------------------- CORE METHODS
function Player.load(collider)
    Player.img = love.graphics.newImage("Assets/Sprites/player.png")
    local sw   = Player.img:getWidth()
    for i = 0, math.floor(sw / Player.w) - 1 do
        Player.frames[#Player.frames+1] =
            love.graphics.newQuad(i*Player.w, 0, Player.w, Player.h, sw, Player.img:getHeight())
    end
    Player.shape = collider:rectangle(Player.x-Player.w/2, Player.y-Player.h/2,
                                      Player.w, Player.h)
    Player.shape.object = Player
end

function Player.damage(dmg, game)
    Player.health = math.max(Player.health - dmg, 0)
    game.shake(12,0.35)
end

function Player.update(dt, collider)
    -- movement ---------------------------------------------------------------
    local dx,dy = 0,0
    if anyDown{"w","up"}   then dy = dy-1 end
    if anyDown{"s","down"} then dy = dy+1 end
    if anyDown{"a","left"} then dx = dx-1 end
    if anyDown{"d","right"}then dx = dx+1 end

    local len = math.sqrt(dx*dx + dy*dy)
    if len > 0 then
        Player.vx = Player.vx + (dx/len)*Player.accel*dt
        Player.vy = Player.vy + (dy/len)*Player.accel*dt
        local sp  = math.sqrt(Player.vx^2 + Player.vy^2)
        if sp > Player.speed then
            Player.vx, Player.vy = Player.vx/sp*Player.speed, Player.vy/sp*Player.speed
        end
    else
        Player.vx, Player.vy = 0, 0
    end

    Player.x = Player.x + Player.vx*dt
    Player.y = Player.y + Player.vy*dt
    Player.shape:moveTo(Player.x, Player.y)

    -- animation --------------------------------------------------------------
    if #Player.frames > 1 then
        Player.timer = Player.timer + dt
        if Player.timer >= Player.interval then
            Player.timer = Player.timer - Player.interval
            Player.frame = Player.frame % #Player.frames + 1
        end
    end
end

function Player.draw()
    love.graphics.draw(Player.img, Player.frames[Player.frame],
                       Player.x - Player.w/2, Player.y - Player.h/2)
end

return Player
