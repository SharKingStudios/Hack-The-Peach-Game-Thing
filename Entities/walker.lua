-- Entities/walker.lua
local HC        = require "Libraries.HC"
local Particles = require "Systems.particles"
local Walker = {}; Walker.__index = Walker

local SPEED, STOMP_RANGE, STOMP_CD, DMG = 70, 64, 2, 1

function Walker.new(x,y, collider) 
    local self = setmetatable({x=x,y=y,w=64,h=64, hp=3, stomp=0, shape=nil}, Walker)
    self.shape = collider:rectangle(x-32, y-32, 64, 64)
    self.shape.type  = "enemy"   -- add after shape creation
    self.shape.object= self
    return self
end

-- simple separation helper
local function separation(self, robots)
    local sx,sy=0,0
    for _,r in ipairs(robots) do
        if r~=self then
            local dx,dy = self.x-r.x, self.y-r.y
            local d2 = dx*dx+dy*dy
            if d2<4096 and d2>0 then
                sx = sx + dx/d2; sy = sy + dy/d2
            end
        end
    end
    return sx,sy
end

function Walker:update(dt, player, robots, game, slide)
    local dx, dy = player.x - self.x, player.y - self.y
    local dist   = math.sqrt(dx*dx + dy*dy)

    -- only think if on-screen (+96 px pad)
    if not game.isVisible(self.x, self.y, 96) then return end

    if dist > STOMP_RANGE then
        -- seek player + separation
        local sx, sy = separation(self, robots)
        dx, dy       = dx / dist + sx * 40,  dy / dist + sy * 40
        local len    = math.sqrt(dx*dx + dy*dy)
        local stepX, stepY = (dx / len) * SPEED * dt, (dy / len) * SPEED * dt

        -- move while resolving walls / other enemies
        self.x, self.y = slide(self.shape, stepX, stepY)

    else            -- stomp phase
        self.stomp = self.stomp - dt
        if self.stomp <= 0 then
            self.stomp = STOMP_CD
            Particles.ring(self.x, self.y, 0.3, STOMP_RANGE)
            if dist < STOMP_RANGE then player.damage(DMG, game) end
            game.shake(8, 0.25)
        end
    end
end


function Walker:draw()
    love.graphics.setColor(0.3,0.7,0.3); love.graphics.rectangle("fill", self.x-32, self.y-32,64,64); love.graphics.setColor(1,1,1)
end

return Walker
