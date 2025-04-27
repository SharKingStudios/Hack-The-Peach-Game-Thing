-- Entities/tank.lua
local Projectiles = require "Systems.projectiles"
local Tank        = {}; Tank.__index = Tank

local MOVE_SPEED, FIRE_RANGE, FIRE_CD = 40, 250, 1.4
local SEPARATION_FACTOR = 200

function Tank.new(x, y, collider)
    local self = setmetatable({x=x, y=y, w=64, h=64, hp=5, fire=0}, Tank)
    self.shape = collider:circle(x, y, 32)
    self.shape.type   = "enemy"
    self.shape.object = self
    return self
end


local function separation(self, robots)
    local sx, sy = 0, 0
    for _, r in ipairs(robots) do
        if r ~= self then
            local dx, dy = self.x - r.x, self.y - r.y
            local d2     = dx*dx + dy*dy
            if d2 > 0 and d2 < 4096 then
                sx, sy = sx + dx/d2, sy + dy/d2
            end
        end
    end
    return sx*SEPARATION_FACTOR, sy*SEPARATION_FACTOR
end

local function lineBlocked(self, player, robots)
    for _, r in ipairs(robots) do
        if r ~= self and r.shape:intersectsRay(self.x, self.y,
                                               player.x, player.y) then
            return true
        end
    end
    return false
end

function Tank:update(dt, player, robots, game, slide)
    -- if not game.isVisible(self.x, self.y, 96) then return end

    self.fire = self.fire - dt
    local dx, dy = player.x - self.x, player.y - self.y
    local dist   = math.sqrt(dx*dx + dy*dy)

    local moveX, moveY = 0, 0
    if dist >= FIRE_RANGE then
        local sx, sy = separation(self, robots)
        local vx, vy = dx/dist + sx, dy/dist + sy
        local len    = math.sqrt(vx*vx + vy*vy)
        moveX, moveY = (vx/len)*MOVE_SPEED*dt, (vy/len)*MOVE_SPEED*dt
    else
        local blocked = lineBlocked(self, player, robots)
        if blocked then
            -- sidestep left then right
            local lx, ly = -dy/dist,  dx/dist
            local rx, ry =  dy/dist, -dx/dist
            local step   = MOVE_SPEED * dt
            -- try left
            local xTry, yTry = slide(self.shape, lx*step, ly*step)
            if lineBlocked({x=xTry,y=yTry,shape=self.shape}, player, robots) then
                -- still blocked, move right instead
                xTry, yTry = slide(self.shape, rx*step, ry*step)
            end
            self.x, self.y = xTry, yTry
        elseif self.fire <= 0 then
            self.fire = FIRE_CD
            Projectiles.spawn(self.x, self.y, dx/dist, dy/dist, "enemy", 320, 2)
        end
    end

    -- if we didn't move in blocked branch
    if moveX ~= 0 or moveY ~= 0 then
        self.x, self.y = slide(self.shape, moveX, moveY)
    end
end

function Tank:draw()
    love.graphics.setColor(0.3, 0.3, 0.8)
    love.graphics.rectangle("fill", self.x-32, self.y-32, 64, 64)
    love.graphics.setColor(1, 1, 1)
end

return Tank
