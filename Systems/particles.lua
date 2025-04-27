-- Systems/particles.lua ------------------------------------------------------
local Particles = { world = {}, gui = {}, rings = {} }
local img = love.graphics.newImage("Assets/Sprites/white1x1.png")   -- 1×1 pixel

local botImgs = {
    love.graphics.newImage("Assets/Sprites/botParticles/gear_sprite1.png"),
    love.graphics.newImage("Assets/Sprites/botParticles/gear_sprite2.png"),
    love.graphics.newImage("Assets/Sprites/botParticles/metal_shard_sprite1.png"),
    love.graphics.newImage("Assets/Sprites/botParticles/metal_shard_sprite2.png"),
    love.graphics.newImage("Assets/Sprites/botParticles/screw_sprite.png")
}

function Particles.debris(x,y,count)
    for i=1,count do
        local obj = {
            img   = botImgs[love.math.random(#botImgs)],
            x     = x, y = y,
            dx    = love.math.random()*140-70,
            dy    = love.math.random()*140-70,
            ang   = love.math.random()*math.pi*2,
            spin  = love.math.random()*6-3,
            life  = 1.2
        }
        Particles.world[#Particles.world+1] = obj
    end
end

-- generic burst --------------------------------------------------------------
function Particles.burst(args)
    -- args: x,y, gui?, count, lifeMin/Max, speedMin/Max,
    --       sizeStart/End, startCol{r,g,b}, endCol{r,g,b}, spread
    local ps = love.graphics.newParticleSystem(img, args.count or 60)
    ps:setParticleLifetime(args.lifeMin or 0.25, args.lifeMax or 0.6)
    ps:setSpeed(args.speedMin or 60, args.speedMax or 180)
    ps:setSizes(args.sizeStart or 2, args.sizeEnd or 0)
    ps:setSpin(0, 8); ps:setSpinVariation(1)
    ps:setSpread(args.spread or math.pi*2)
    local sc = args.startCol or {1,1,1}; local ec = args.endCol or {1,1,1}
    ps:setColors(sc[1],sc[2],sc[3],1,  ec[1],ec[2],ec[3],0)
    ps:emit(ps:getBufferSize())
    local list = args.gui and Particles.gui or Particles.world
    -- keep the system alive for its *longest* particle lifetime
    local maxLife = select(2, ps:getParticleLifetime())
    table.insert(list,{ps=ps, x=args.x, y=args.y, t=maxLife})
end

-- convenience wrappers -------------------------------------------------------
function Particles.poof(x,y,gui)  Particles.burst{ x=x,y=y, gui=gui, count=36 } end
function Particles.ring(x,y,ttl,radius)      -- unchanged
    table.insert(Particles.rings,{x=x,y=y,t=ttl,max=ttl,r=radius})
end

function Particles.spark(x,y,qty)
    Particles.burst{
        x=x,y=y,count=qty or 15,
        sizeStart=2,startCol={1,1,0.2},endCol={1,1,0.2},
        speedMin=40,speedMax=120
    }
end
function Particles.smoke(x,y,qty)
    Particles.burst{
        x=x,y=y,count=qty or 20,sizeStart=4,
        startCol={0,0,0},endCol={0.1,0.1,0.1},
        speedMin=20,speedMax=60
    }
end


-- update    ------------------------------------------------------------------
function Particles.update(dt)
    local function step(tbl)
        for i=#tbl,1,-1 do
            local s=tbl[i]; s.ps:update(dt); s.t=s.t-dt
            if s.t<=0 then table.remove(tbl,i) end
        end
    end
    step(Particles.world); step(Particles.gui)

    for i=#Particles.rings,1,-1 do
        local r=Particles.rings[i]; r.t=r.t-dt
        if r.t<=0 then table.remove(Particles.rings,i) end
    end

    for i=#Particles.world,1,-1 do
        local o = Particles.world[i]
        if o.img then                           -- debris object
            o.life = o.life - dt
            o.x = o.x + o.dx*dt
            o.y = o.y + o.dy*dt
            o.ang = o.ang + o.spin*dt
            if o.life <= 0 then table.remove(Particles.world,i) end
        end
    end
end

-- draw (world space, called inside camera) -----------------------------------
function Particles.draw()
    for _,s in ipairs(Particles.world) do love.graphics.draw(s.ps,s.x,s.y) end
    love.graphics.setColor(1,0,0,0.4)
    for _,r in ipairs(Particles.rings) do
        local a=r.t/r.max; love.graphics.circle("line",r.x,r.y,r.r*(1-a)*1.2)
    end
    for _,o in ipairs(Particles.world) do
        if o.img then
            love.graphics.draw(o.img, o.x, o.y, o.ang, 1,1,
                               o.img:getWidth()/2, o.img:getHeight()/2)
        end
    end    
    love.graphics.setColor(1,1,1)
end

-- draw on GUI AFTER camera detach -------------------------------------------
function Particles.drawGUI()
    for _,s in ipairs(Particles.gui) do love.graphics.draw(s.ps,s.x,s.y) end
end

return Particles
