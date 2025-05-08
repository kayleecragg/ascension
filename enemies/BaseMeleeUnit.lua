-- BaseMeleeUnit.lua
local Slash = require("effects.Slash")

local BaseMeleeUnit = {}
BaseMeleeUnit.__index = BaseMeleeUnit
BaseMeleeUnit.slashes = {}  -- Shared slashes container

function BaseMeleeUnit:new(x, y, width, height, health, maxHealth, speed, maxSpeed, attackDamage, attackRange, attackCD, attackTimer)
    local enemy = {}
    setmetatable(enemy, BaseMeleeUnit)

    enemy.x = x
    enemy.y = y
    enemy.width = width
    enemy.height = height
    enemy.health = health
    enemy.maxHealth = maxHealth
    enemy.speed = speed
    enemy.maxSpeed = maxSpeed
    enemy.attackDamage = attackDamage
    enemy.attackCD = attackCD
    enemy.attackRange = attackRange
    enemy.attackTimer = attackTimer
    enemy.alive = true

    return enemy
end

function BaseMeleeUnit:attack(target)
    -- Reset attack timer
    self.attackTimer = self.attackCD
    
    -- Create a slash effect
    local slash = Slash:new(
        self.x + self.width/2, 
        self.y + self.height/2, 
        target.x + target.width/2, 
        target.y + target.height/2, 
        self.attackDamage, 
        0.4,  -- Duration
        self.attackRange
    )
    
    -- Set if this is an enemy slash
    slash.isEnemy = true
    
    -- Add to slashes table
    table.insert(BaseMeleeUnit.slashes, slash)
    
    return slash
end

function BaseMeleeUnit:take_damage(amount)
    -- Reduce health by damage amount
    self.health = self.health - amount
    
    -- Check if unit is dead
    if self.health <= 0 then
        self.health = 0
        self.alive = false
    end
    
    return self.health
end

function BaseMeleeUnit:getDistanceTo(target)
    -- Calculate distance between centers
    local dx = (target.x + target.width/2) - (self.x + self.width/2)
    local dy = (target.y + target.height/2) - (self.y + self.height/2)
    return math.sqrt(dx * dx + dy * dy)
end

-- Update method to be compatible with your combat loop
function BaseMeleeUnit:update(dt, target)
    -- Update attack timer
    self.attackTimer = math.max(0, self.attackTimer - dt)
    
    -- Basic AI: move towards target if not in attack range
    if target and self.alive then
        local dx = target.x - self.x
        local dy = target.y - self.y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist > self.attackRange then
            -- Move toward player
            self.x = self.x + (dx/dist)*self.speed*dt
            self.y = self.y + (dy/dist)*self.speed*dt
        elseif self.attackTimer <= 0 then
            -- Attack when in range and cooldown is ready
            self:attack(target)
        end
    end
end

return BaseMeleeUnit