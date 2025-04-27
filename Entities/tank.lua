-- Entities/tank.lua ----------------------------------------------------------
local HC        = require "Libraries.HC"
local Particles = require "Systems.particles"
local Spells    = require "Systems.spells"
local Projectiles = require "Systems.projectiles"

local Tank        = {}; Tank.__index = Tank

local MOVE_SPEED, FIRE_RANGE, FIRE_CD = 40, 250, 1.4
local SEPARATION_FACTOR               = 200
local STEP_HZ_AT_TOP_SPEED            = 4      -- walk-cycle toggles per sec
local LOW_SPEED_THRESHOLD   = 8          -- px / s: below this the bot counts as idle
local ANGLE_MARGIN_DEG      = 20         -- must be ≥ 20° into next quadrant to switch
local DIR_SWITCH_COOLDOWN   = 0.20       -- s: minimum delay between direction flips

-- --------------------------------------------------------------------------- sprite setup
local DIRS = {"front","back","left","right"}
local function loadSprites()
    local s = {}
    for _,d in ipairs(DIRS) do
        s[d] = {
            standing = love.graphics.newImage("Assets/Sprites/tank/tank_"..d.."_standing.png"),
            walking  = love.graphics.newImage("Assets/Sprites/tank/tank_"..d.."_walking.png")
        }
    end
    return s
end
local SPRITES = loadSprites()

-- --------------------------------------------------------------------------- helpers
local function separation(self, robots)
    local sx, sy = 0, 0
    for _, r in ipairs(robots) do
        if r ~= self then
            local dx, dy = self.x - r.x, self.y - r.y
            local d2     = dx*dx + dy*dy
            if d2 > 0 and d2 < 4096 then sx, sy = sx + dx/d2, sy + dy/d2 end
        end
    end
    return sx*SEPARATION_FACTOR, sy*SEPARATION_FACTOR
end

local function lineBlocked(self, player, robots)
    for _, r in ipairs(robots) do
        if r ~= self and r.shape:intersectsRay(self.x, self.y, player.x, player.y) then
            return true
        end
    end
    return false
end

local function dirFromVector(dx, dy)           -- 4-way
    if math.abs(dx) > math.abs(dy) then
        return (dx > 0) and "right" or "left"
    else
        return (dy > 0) and "front" or "back"  -- +y is down on screen
    end
end

local function axisDirFromVector(dx, dy, curDir)
    -- convert to degrees where 0 = right, 90 = down
    local angle = math.deg(math.atan2(dy, dx))

    -- keep current dir unless we’ve moved ≥ ANGLE_MARGIN_DEG into the next sector
    if     angle >  65 and angle <= 115 then return "front"
    elseif angle < -65 and angle >= -115 then return "back"
    elseif angle >= -65 and angle <=  65 then return "right"
    else                                   return "left"  -- |angle| > 115
    end
end


-- --------------------------------------------------------------------------- constructor
function Tank.new(x, y, collider)
    local self = setmetatable({
        x=x, y=y, w=64, h=64, hp=3, fire=0,
        walkTimer=0, stepFrame=false, dir="front"
    }, Tank)
    self.shape = collider:circle(x, y, 32)
    self.shape.type   = "enemy"
    self.shape.object = self
    return self
end

function Tank:takeDamage(amount)
    self.hp = self.hp - amount
    print(("Tank took %d damage! HP now %d"):format(amount, self.hp))
end

-- --------------------------------------------------------------------------- update / draw
function Tank:update(dt, player, robots, game, slide)
    -- 1) Spell hits (ignore robotFX)
    for _, s in ipairs(Spells.list) do
        if s.kind ~= "robotFX" and s.x and s.y then
            local dx, dy = s.x - self.x, s.y - self.y
            if dx*dx + dy*dy < (32+16)^2 then  -- radius 32 vs sprite ~16
                self:takeDamage(1)
                if self.hp <= 0 then return end
            end
        end
    end

    -- 2) Projectile hits
    for _, p in ipairs(Projectiles.list) do
        if p.side == "player"
        and p.shape:collidesWith(self.shape) then
            self:takeDamage(1)
            p.dead = true
            if self.hp <= 0 then return end
        end
    end


    local prevX, prevY = self.x, self.y

    self.fire = self.fire - dt
    local toPlayerX, toPlayerY = player.x - self.x, player.y - self.y
    local distToPlayer         = math.sqrt(toPlayerX*toPlayerX + toPlayerY*toPlayerY)

    ------------------------------------- steering
    local moveX, moveY = 0, 0
    if distToPlayer >= FIRE_RANGE then
        local sx, sy = separation(self, robots)
        local vx, vy = toPlayerX/distToPlayer + sx, toPlayerY/distToPlayer + sy
        local len    = math.sqrt(vx*vx + vy*vy)
        moveX, moveY = (vx/len)*MOVE_SPEED*dt, (vy/len)*MOVE_SPEED*dt
    else
        local blocked = lineBlocked(self, player, robots)
        if blocked then
            local lx, ly = -toPlayerY/distToPlayer,  toPlayerX/distToPlayer
            local rx, ry =  toPlayerY/distToPlayer, -toPlayerX/distToPlayer
            local step   = MOVE_SPEED * dt
            local xTry, yTry = slide(self.shape, lx*step, ly*step)
            if lineBlocked({x=xTry,y=yTry,shape=self.shape}, player, robots) then
                xTry, yTry = slide(self.shape, rx*step, ry*step)
            end
            self.x, self.y = xTry, yTry
        elseif self.fire <= 0 then
            self.fire = FIRE_CD
            Projectiles.spawn(self.x, self.y, toPlayerX/distToPlayer, toPlayerY/distToPlayer,
                              "enemy", 320, 2)
        end
    end
    if moveX ~= 0 or moveY ~= 0 then
        self.x, self.y = slide(self.shape, moveX, moveY)
    end

    ------------------------------------- animation state
    local dxMove, dyMove = self.x - prevX, self.y - prevY
    local speedNow       = math.sqrt(dxMove*dxMove + dyMove*dyMove) / dt

    self.dirCooldown = math.max(0, (self.dirCooldown or 0) - dt)

    local moving      = speedNow >= LOW_SPEED_THRESHOLD
    local proposedDir = moving
        and axisDirFromVector(dxMove, dyMove, self.dir)
        or  axisDirFromVector(toPlayerX, toPlayerY, self.dir)

    if proposedDir ~= self.dir and self.dirCooldown <= 0 then
        self.dir = proposedDir
        self.dirCooldown = DIR_SWITCH_COOLDOWN
    end

    -- walk-cycle frame toggle
    if moving then
        self.walkTimer = (self.walkTimer or 0)
                        + dt * (speedNow / MOVE_SPEED) * STEP_HZ_AT_TOP_SPEED
        if self.walkTimer >= 1 then
            self.walkTimer = self.walkTimer - 1
            self.stepFrame = not self.stepFrame
        end
    else
        self.stepFrame = false
    end

    -- for _, p in ipairs(require("Systems.projectiles").list) do -- Instant kill
    --     if p.side == "player"
    --     and p.shape:collidesWith(self.shape) then
    --         self.hp = 0
    --         print("Tank was hit by a projectile and died!")
    --         return
    --     end
    -- end

    -- HP effects ---------------------------------------------------------------
    if self.hp==2 then                -- low sparks
        self._fxT = (self._fxT or 0) - dt
        if self._fxT<=0 then
            self._fxT = 0.4
            Particles.spark(self.x,self.y-20,10)
        end
    elseif self.hp==1 then            -- sparks + smoke
        self._fxT = (self._fxT or 0) - dt
        if self._fxT<=0 then
            self._fxT = 0.25
            Particles.spark(self.x,self.y-20,18)
            Particles.smoke(self.x,self.y-10,12)
        end
    end

    if self.hp<=0 and not self._blew then
        self._blew=true
        -- lots of metal bits
        Particles.debris(self.x, self.y, 30)
        -- black smoke
        Particles.smoke(self.x, self.y, 25)
        -- extra yellow sparks
        Particles.spark(self.x, self.y, 20)
    end
end

function Tank:draw()
    local frame = self.stepFrame and "walking" or "standing"
    local img   = SPRITES[self.dir][frame]
    love.graphics.draw(img, self.x - self.w/2, self.y - self.h/2)
end

return Tank
