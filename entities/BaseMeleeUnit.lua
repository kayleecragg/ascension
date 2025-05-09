-- BaseMeleeUnit.lua
-- A base melee enemy unit that attacks nearby players with a slash.

local Slash = require("effects.Slash")

local BaseMeleeUnit = {}
BaseMeleeUnit.__index = BaseMeleeUnit
BaseMeleeUnit.slashes = {}  -- Shared slashes container

-- Constructor that accepts pre-calculated stats
function BaseMeleeUnit.new(stats)
    -- Base melee units get a health bonus
    stats.health = stats.health * 2.0
    stats.maxHealth = stats.maxHealth * 2.0
    
    -- Apply additional melee-specific bonuses
    stats.speed = stats.speed * 1.05
    stats.attackDamage = stats.attackDamage * 1.2
    
    -- Note: color is now set in Enemy.calculateStats
    
    setmetatable(stats, BaseMeleeUnit)
    return stats
end

-- Perform an attack
function BaseMeleeUnit:attack(target)
    self.attackTimer = self.attackCD

    local slash = Slash:new(
        self.x + self.width / 2,
        self.y + self.height / 2,
        target.x + target.width / 2,
        target.y + target.height / 2,
        self.attackDamage,
        0.4,
        self.attackRange
    )

    slash.isEnemy = true
    table.insert(BaseMeleeUnit.slashes, slash)
end

-- Take damage and die if health reaches 0
function BaseMeleeUnit:take_damage(amount)
    self.health = self.health - amount
    if self.health <= 0 then
        self.health = 0
        self.alive = false
    end
end

-- Move toward target or attack
function BaseMeleeUnit:update(dt, target)
    self.attackTimer = math.max(0, self.attackTimer - dt)
    if not self.alive or not target then return end

    local dx = target.x - self.x
    local dy = target.y - self.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > self.attackRange then
        self.x = self.x + (dx / dist) * self.speed * dt
        self.y = self.y + (dy / dist) * self.speed * dt
    elseif self.attackTimer <= 0 then
        self:attack(target)
    end
end

-- Draw the unit
function BaseMeleeUnit:draw()
    if self.alive then
        love.graphics.setColor(self.color)
        love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    end
end

return BaseMeleeUnit