-- Entities/critter.lua
local Critter = {}
Critter.__index = Critter

local hopSpeed = 120

-- load the 16×16 critter sprite once
local critterImg = love.graphics.newImage("Assets/Sprites/critter.png")

function Critter.new(x, y)
    return setmetatable({
        x = x, y = y,
        w = 16, h = 16,
    }, Critter)
end

function Critter:update(dt, player, Particles)
    local dx, dy = player.x - self.x, player.y - self.y
    local dist   = math.sqrt(dx*dx + dy*dy)
    if dist > 1 then
        local nx, ny = dx/dist, dy/dist
        self.x = self.x + nx * hopSpeed * dt
        self.y = self.y + ny * hopSpeed * dt
    end

    -- pickup
    if dist < 14 then
        player.critterCount = (player.critterCount or 0) + 1
        Particles.burst{ x=self.x, y=self.y, count=50, sizeStart=3 }
        self.dead = true
    end
end

function Critter:draw()
    -- center the 16×16 sprite on (x,y)
    local w, h = critterImg:getWidth(), critterImg:getHeight()
    love.graphics.draw(critterImg, self.x - w/2, self.y - h/2)
end

return Critter
