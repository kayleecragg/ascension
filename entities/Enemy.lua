-- Enemy.lua
-- Core definition for all enemy types with base stats and factory function

local Enemy = {}

-- Base enemy stats used by all enemy types
Enemy.baseStats = {
    -- Dimensions
    width = 50,
    height = 50,
    
    -- Health
    baseHealth = 5,
    healthPerWave = 4,
    
    -- Movement
    baseSpeed = 60,
    speedPerWave = 15,
    baseMaxSpeed = 100,
    maxSpeedPerWave = 15,
    
    -- Combat
    baseAttackDamage = 1,
    baseAttackRange = 50,
    baseAttackCD = 1.5,
}

-- Type-specific multipliers
Enemy.typeMultipliers = {
    base = {
        health = 1.0,
        speed = 1.0,
        attackDamage = 1.0,
        attackRange = 1.0,
        attackCD = 1.0,
        width = 1.0,
        height = 1.0,
    },
    charge = {
        health = 0.6,     -- Weaker but faster
        speed = 1.25,
        attackDamage = 1.0,
        attackRange = 1.0,
        attackCD = 1.33,  -- Slower attack (2 seconds vs 1.5)
        width = 1.1,      -- Slightly bigger
        height = 1.1,
    },
    ranged = {
        health = 0.4,     -- Fragile but dangerous
        speed = 0.75,     -- Slower
        attackDamage = 1.0,
        attackRange = 1.2, -- Longer range
        attackCD = 1.33,   -- Matches beamCD of 2 seconds
        width = 0.9,       -- Slightly smaller
        height = 0.9,
    }
}

-- Spawn rate configuration - moved from combat.lua
Enemy.spawnRates = {
    -- Wave configuration - number of enemies per wave
    waves = {2, 4, 6, 8, 10, 11},
    
    -- Enemy type probability distribution (out of 10):
    -- Values represent the upper bound of the range for each type
    typeChances = {
        base = 6,    -- 1-6 (60% chance)
        charge = 8,  -- 7-8 (20% chance)
        ranged = 10  -- 9-10 (20% chance)
    }
}

-- Helper function to get an enemy type based on probability
function Enemy.getRandomType()
    local roll = math.random(1, 10)
    if roll <= Enemy.spawnRates.typeChances.base then
        return "base"
    elseif roll <= Enemy.spawnRates.typeChances.charge then
        return "charge"
    else
        return "ranged"
    end
end

-- Utility function to get enemy type color - moved up before it's needed
function Enemy.getTypeColor(enemyType)
    if enemyType == "base" then
        return {1, 1, 0}      -- Yellow
    elseif enemyType == "charge" then
        return {1, 0, 0}      -- Red
    elseif enemyType == "ranged" then
        return {0.2, 0.4, 0.8} -- Blue
    else
        return {1, 1, 1}      -- White fallback
    end
end

-- Calculate stats based on type and wave
function Enemy.calculateStats(enemyType, wave)
    local stats = {}
    local mult = Enemy.typeMultipliers[enemyType]
    local w = wave or 1
    
    -- Apply base dimensions with type multipliers
    stats.width = Enemy.baseStats.width * mult.width
    stats.height = Enemy.baseStats.height * mult.height
    
    -- Apply health scaling
    stats.health = (Enemy.baseStats.baseHealth + w * Enemy.baseStats.healthPerWave) * mult.health
    stats.maxHealth = stats.health
    
    -- Apply speed scaling
    stats.speed = (Enemy.baseStats.baseSpeed + w * Enemy.baseStats.speedPerWave) * mult.speed
    stats.maxSpeed = (Enemy.baseStats.baseMaxSpeed + w * Enemy.baseStats.maxSpeedPerWave) * mult.speed
    
    -- Apply combat stats
    stats.attackDamage = Enemy.baseStats.baseAttackDamage * mult.attackDamage
    stats.attackRange = Enemy.baseStats.baseAttackRange * mult.attackRange
    stats.attackCD = Enemy.baseStats.baseAttackCD * mult.attackCD
    stats.attackTimer = 0
    stats.alive = true
    
    -- Set color here directly
    stats.color = Enemy.getTypeColor(enemyType)
    
    return stats
end

-- Factory function to create enemies
function Enemy.new(enemyType, wave)
    local x = math.random(100, 700)
    local y = math.random(100, 500)
    
    -- Calculate stats first
    local stats = Enemy.calculateStats(enemyType, wave)
    stats.x = x
    stats.y = y
    
    -- Import unit types at function call time to avoid circular dependency
    if enemyType == "base" then
        local BaseMeleeUnit = require("entities.BaseMeleeUnit")
        return BaseMeleeUnit.new(stats)
    elseif enemyType == "charge" then
        local ChargeMeleeUnit = require("entities.ChargeMeleeUnit")
        return ChargeMeleeUnit.new(stats)
    elseif enemyType == "ranged" then
        local RangedUnit = require("entities.RangedUnit")
        return RangedUnit.new(stats)
    end
end

return Enemy