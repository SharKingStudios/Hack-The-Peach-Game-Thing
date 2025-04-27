-- Entities/critter.lua
local Critter = {}
Critter.__index = Critter

local hopSpeed = 90

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
        self.x = self.x + (dx/dist) * hopSpeed * dt
        self.y = self.y + (dy/dist) * hopSpeed * dt
    end

    -- pickup
    if dist < 12 then
        player.critterCount = (player.critterCount or 0) + 1
        Particles.poof(self.x, self.y)
        self.dead = true
    end
end

function Critter:draw()
    love.graphics.setColor(1, 1, 0)
    love.graphics.rectangle("fill", self.x - 8, self.y - 8, 16, 16)
    love.graphics.setColor(1,1,1)
end

return Critter
