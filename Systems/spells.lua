-- Systems/spells.lua ---------------------------------------------------------
local Projectiles = require "Systems.projectiles"
local Particles   = require "Systems.particles"

local Spells = { list = {} }                 -- active spell instances

-- utilities ------------------------------------------------------------------
local function vlen(dx,dy) return math.sqrt(dx*dx + dy*dy) end
-- radialDamage : deal <dmg> to every enemy shape whose centre is within
-- <radius> pixels of (x,y).  Returns true if at least one enemy was hit.
local function radialDamage(x, y, radius, dmg)
    local hit = false
    local col = Projectiles.collider
    if col and col.shapes then
        for sh in pairs(col.shapes) do
            if sh.type == "enemy" and sh.object and sh.object.hp > 0 then
                local ox, oy = sh.object.x, sh.object.y
                if vlen(ox - x, oy - y) <= radius then
                    -- delegate to entity's takeDamage, if defined
                    if sh.object.takeDamage then
                        sh.object:takeDamage(dmg)
                    else
                        sh.object.hp = sh.object.hp - dmg
                    end
                    hit = true
                end
            end
        end
    end
    return hit
end

-------------------------------------------------------------------------------

-- FIREBALL -------------------------------------------------------------------
local fireAnim = {}
for i=1,8 do
    fireAnim[i] = love.graphics.newImage(
        ("Assets/Sprites/skill_fx/fire/fireball%d.png"):format(i))
end

local function spawnFireball(px,py, ex,ey)
    local dx,dy = ex-px, ey-py
    local l     = vlen(dx,dy);  dx,dy = dx/l, dy/l

    local fb = { kind="fire", x=px, y=py, dx=dx, dy=dy,
                 speed=280, life=2, frame=1, ft=0 }
    fb.update = function(self,dt)
        -- move & animate sprite
        self.x, self.y = self.x + self.dx*self.speed*dt,
                         self.y + self.dy*self.speed*dt
        self.life = self.life - dt
        self.ft   = self.ft + dt*20
        if self.ft >= 1 then self.ft = self.ft-1; self.frame = self.frame%8+1 end

        -- damage on proximity (20-px blast)
        if radialDamage(self.x, self.y, 20, 1) or self.life<=0 then
            self.dead = true
            Particles.poof(self.x, self.y)
        end

        -- trailing blue particles
        Particles.burst{
            x=self.x, y=self.y, count=3,
            startCol={0.4,0.6,1}, endCol={0.2,0.3,1},
            sizeStart=2, sizeEnd=0, speedMin=15, speedMax=40
        }
    end
    fb.draw   = function(self)
        love.graphics.draw(fireAnim[self.frame], self.x-8, self.y-8)
    end
    Spells.list[#Spells.list+1] = fb
end

-- LIGHTNING ------------------------------------------------------------------
local boltImgs = {}
for i=1,5 do
    boltImgs[i] = love.graphics.newImage(
        ("Assets/Sprites/skill_fx/lightning/lightning%d.png"):format(i))
end
local function castLightning(player)
    local RADIUS, STRIKES, GAP = 100, 5, 0.08
    for n=0,STRIKES-1 do
        Spells.list[#Spells.list+1] = {
            kind="bolt", delay=n*GAP, player=player,
            update=function(self,dt)
                self.delay = self.delay-dt
                if self.delay>0 then return end
                if not self.spawned then
                    self.spawned = true
                    local a = love.math.random()*math.pi*2
                    self.x = self.player.x + math.cos(a)*RADIUS
                    self.y = self.player.y + math.sin(a)*RADIUS
                    radialDamage(self.x,self.y,64,2)
                    Particles.burst{ x=self.x,y=self.y, count=30,
                        startCol={1,1,0.3}, endCol={1,0.6,0}, sizeStart=4 }
                    self.life = 0.12
                else
                    self.life = self.life - dt
                    if self.life<=0 then self.dead=true end
                end
            end,
            draw=function(self)
                if self.spawned then
                    love.graphics.draw(boltImgs[love.math.random(5)],
                                       self.x-48,self.y-96)
                end
            end
        }
    end
end

-- MELEE ----------------------------------------------------------------------
local meleeImgs = {
    love.graphics.newImage("Assets/Sprites/skill_fx/melee/melee1.png"),
    love.graphics.newImage("Assets/Sprites/skill_fx/melee/melee2.png"),
    love.graphics.newImage("Assets/Sprites/skill_fx/melee/melee3.png"),
}
local function meleeSwing(player)
    local dx,dy = 0,0
    if player.dir=="front" then dy=1
    elseif player.dir=="back" then dy=-1
    elseif player.dir=="left" then dx=-1 else dx=1 end

    local bx,by = player.x+dx*40, player.y+dy*40
    player.x,player.y = player.x+dx*20, player.y+dy*20
    radialDamage(bx,by,48,1)

    -- 3-frame slash sprite
    local slash = {kind="slash",frame=1,timer=0,x=bx,y=by}
    slash.update=function(s,dt)
        s.timer=s.timer+dt
        if s.timer>=0.04 then s.timer=s.timer-0.04;
            s.frame=s.frame+1; if s.frame>3 then s.dead=true end end
    end
    slash.draw=function(s) love.graphics.draw(meleeImgs[s.frame],s.x-24,s.y-24) end
    Spells.list[#Spells.list+1] = slash
    Particles.burst{ x=bx,y=by, count=15, sizeStart=3 }
end

-- ROBOT FX (walker stomp) ----------------------------------------------------
local robotFx = {}
for i=1,3 do
    robotFx[i] = love.graphics.newImage(
        ("Assets/Sprites/skill_fx/robot/robot_fx%d.png"):format(i))
end
function Spells.robotFX(x,y)
    Spells.list[#Spells.list+1] = {
        kind="robotFX",frame=1,ft=0,life=0.36,x=x,y=y,
        update=function(s,dt)
            s.life,s.ft = s.life-dt, s.ft+dt*12
            if s.ft>=1 then s.ft=s.ft-1; s.frame=s.frame%3+1 end
            if s.life<=0 then s.dead=true end
        end,
        draw=function(s) love.graphics.draw(robotFx[s.frame], s.x-64,s.y-64) end
    }
end

-- TORNADO --------------------------------------------------------------------
local tornadoImgs = {
    love.graphics.newImage("Assets/Sprites/skill_fx/tornado/tornado_sprite1.png"),
    love.graphics.newImage("Assets/Sprites/skill_fx/tornado/tornado_sprite2.png")
}
local function spawnTornado(px,py,dir)
    local ang = (dir=="front" and math.pi/2) or (dir=="back" and -math.pi/2) or
                (dir=="left"  and math.pi  ) or 0
    local sx,sy = math.cos(ang), math.sin(ang)
    local t = {kind="tornado",x=px,y=py,frame=1,ft=0,time=0}
    t.update=function(self,dt)
        self.time = self.time + dt
        self.x    = self.x + sx*120*dt
        self.y    = self.y + sy*120*dt + math.sin(self.time*6)*40*dt
        self.ft   = self.ft + dt*8
        if self.ft>=1 then self.ft=self.ft-1; self.frame=self.frame%2+1 end
        radialDamage(self.x,self.y,40,2)
        if self.time>2 then self.dead=true end
    end
    t.draw=function(self) love.graphics.draw(tornadoImgs[self.frame],self.x-32,self.y-32) end
    Spells.list[#Spells.list+1] = t
end

-- WHIRLPOOL ------------------------------------------------------------------
local wpImgs={
 love.graphics.newImage("Assets/Sprites/skill_fx/whirlpool/whirlpool_sprite1.png"),
 love.graphics.newImage("Assets/Sprites/skill_fx/whirlpool/whirlpool_sprite2.png")}
local function castWhirlpool(player,ex,ey)
    local dx,dy = ex-player.x, ey-player.y
    local a      = math.atan2(dy,dx)
    local bx,by  = player.x+math.cos(a)*70, player.y+math.sin(a)*70
    local beam = {kind="whirl",x=bx,y=by,ang=a,frame=1,ft=0,life=1}
    beam.update=function(self,dt)
        self.life=self.life-dt; if self.life<=0 then self.dead=true end
        self.ft=self.ft+dt*10; if self.ft>=1 then self.ft=self.ft-1;
            self.frame=self.frame%2+1 end
        radialDamage(self.x,self.y,260,3)
        Particles.burst{ x=self.x+math.cos(a)*200, y=self.y+math.sin(a)*200,
            startCol={0.3,0.5,1}, endCol={0.2,0.4,1}, count=8,
            speedMin=60,speedMax=120 }
    end
    beam.draw=function(self)
        love.graphics.draw(wpImgs[self.frame], self.x, self.y, self.ang,1,1,0,32)
    end
    Spells.list[#Spells.list+1] = beam
end

-- PUBLIC API -----------------------------------------------------------------
function Spells.cast(player,id)
    -- nearest enemy for directional spells
    local best,ex,ey,bd
    local col = Projectiles.collider
    if col and col.shapes then
        bd = 1/0
        for sh in pairs(col.shapes) do
            if sh.type == "enemy" and sh.object.hp > 0 then
                local cx, cy = sh.object.x, sh.object.y
                local d = vlen(cx - player.x, cy - player.y)
                if d < bd then best, ex, ey, bd = sh, cx, cy, d end
            end
        end
    end

    if id=="fireball" and best     then spawnFireball(player.x,player.y,ex,ey)
    elseif id=="lightning"         then castLightning(player)
    elseif id=="tornado"           then spawnTornado(player.x,player.y,player.dir)
    elseif id=="whirlpool" and best then castWhirlpool(player,ex,ey) end
end
Spells.melee   = meleeSwing           -- exported for “H” key
Spells.robotFX = Spells.robotFX       -- walker calls this

-- engine loop ---------------------------------------------------------------
function Spells.update(dt)
    for i=#Spells.list,1,-1 do
        local s = Spells.list[i]
        if s.update then s:update(dt) end
        if s.dead   then table.remove(Spells.list,i) end
    end
end
function Spells.draw()
    for _,s in ipairs(Spells.list) do if s.draw then s:draw() end end
end

return Spells
