-- Systems/particles.lua
local Particles = {
    poofs = {},
    rings = {}
}

local img = love.graphics.newImage("Assets/Sprites/white1x1.png") -- 1x1 white pixel

-- Create a small "poof" effect (e.g., critter pickup)
function Particles.poof(x, y)
    local ps = love.graphics.newParticleSystem(img, 32)
    ps:setParticleLifetime(0.2, 0.4)
    ps:setSpeed(30, 70)
    ps:setSpread(math.pi * 2)
    ps:setSizes(1, 0)
    ps:setColors(1, 1, 1, 1, 1, 1, 1, 0)
    table.insert(Particles.poofs, { ps = ps, x = x, y = y, t = 0.4 })
end

-- Create a "red ring" effect (e.g., walker stomp damage zone)
function Particles.ring(x, y, ttl, radius)
    table.insert(Particles.rings, { x = x, y = y, t = ttl, max = ttl, r = radius })
end

function Particles.update(dt)
    -- Update poofs
    for i = #Particles.poofs, 1, -1 do
        local p = Particles.poofs[i]
        p.ps:update(dt)
        p.t = p.t - dt
        if p.t <= 0 then
            table.remove(Particles.poofs, i)
        end
    end

    -- Update rings
    for i = #Particles.rings, 1, -1 do
        local r = Particles.rings[i]
        r.t = r.t - dt
        if r.t <= 0 then
            table.remove(Particles.rings, i)
        end
    end
end

function Particles.draw()
    -- Draw poofs
    for _, p in ipairs(Particles.poofs) do
        love.graphics.draw(p.ps, p.x, p.y)
    end

    -- Draw rings
    love.graphics.setColor(1, 0, 0, 0.4)
    for _, r in ipairs(Particles.rings) do
        local a = r.t / r.max
        love.graphics.circle("line", r.x, r.y, r.r * (1 - a) * 1.2)
    end
    love.graphics.setColor(1, 1, 1)
end

return Particles
