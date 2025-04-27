-- Systems/projectiles.lua
local HC          = require "Libraries.HC"
local Projectiles = { list = {}, collider = nil }

function Projectiles.init(collider)
    Projectiles.collider = collider
end

-- side : "enemy" or "player"
function Projectiles.spawn(x, y, dx, dy, side, speed, life)
    local w,h     = 12, 4
    local angle   = math.atan2(dy, dx)
    local shape   = Projectiles.collider:rectangle(x - w/2, y - h/2, w, h)
    shape:setRotation(angle, x, y)

    table.insert(Projectiles.list, {
        x = x, y = y, dx = dx, dy = dy,
        speed = speed or 320,
        life  = life  or 2,
        side  = side  or "enemy",
        angle = angle,
        shape = shape
    })
end

function Projectiles.update(dt)
    for i = #Projectiles.list, 1, -1 do
        local p = Projectiles.list[i]
        p.x = p.x + p.dx * p.speed * dt
        p.y = p.y + p.dy * p.speed * dt
        p.shape:moveTo(p.x, p.y)
        p.life = p.life - dt
        if p.life <= 0 then
            Projectiles.collider:remove(p.shape)
            table.remove(Projectiles.list, i)
        end
    end
end

function Projectiles.draw()
    love.graphics.setColor(1, 0, 0)
    for _, p in ipairs(Projectiles.list) do
        love.graphics.push()
        love.graphics.translate(p.x, p.y)
        love.graphics.rotate(p.angle)
        love.graphics.rectangle("fill", -6, -2, 12, 4)
        love.graphics.pop()
    end
    love.graphics.setColor(1, 1, 1)
end

return Projectiles
