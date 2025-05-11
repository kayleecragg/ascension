-- effects/Orb.lua
local Orb = {}
Orb.__index = Orb

function Orb.new(x, y)
    local self = setmetatable({}, Orb)
    self.x = x
    self.y = y
    self.radius = 12
    self.healPercent = 0.3 -- HOW MUCH HEALTH THE ORB RESTORES
    self.collected = false
    return self
end

function Orb:update(dt)
    -- Add animation logic here if desired
end

function Orb:draw()
    if not self.collected then
        love.graphics.setColor(0, 1, 0, 0.9) -- Green
        love.graphics.circle("fill", self.x, self.y, self.radius)
        love.graphics.setColor(1, 1, 1)
    end
end

function Orb:checkCollected(player)
    if self.collected or not player.alive then return end
    local px = player.x + player.width / 2
    local py = player.y + player.height / 2
    local dx = px - self.x
    local dy = py - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < self.radius + player.width / 2 then
        self.collected = true
        player.health = math.min(player.maxHealth, player.health + player.maxHealth * self.healPercent)
    end
end

return Orb
