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

-- Type-specific default multipliers
Enemy.typeMultipliers = {
    base = {
        health = 1, speed = 1.0, attackDamage = 1.0,
        attackRange = 1.0, attackCD = 1.0,
        width = 1.0, height = 1.0,
    },
    charge = {
        health = 0.9, speed = 1.5, attackDamage = 1.0,
        attackRange = 1.0, attackCD = 1.33,
        width = 1.1, height = 1.1,
    },
    ranged = {
        health = 0.6, speed = 0.75, attackDamage = 1.0,
        attackRange = 1.2, attackCD = 1.33,
        width = 0.9, height = 0.9,
    }
}

-- Spawn rate configuration
Enemy.spawnRates = {
    waves = {2, 5, 7, 8, 9, 10},
    typeChances = {
        base = 5,     -- 1-5
        charge = 8,   -- 6-8
        ranged = 10,  -- 9-10
    }
}

-- per-wave, per-unit multipliers
Enemy.customMultipliers = {
    [1] = {
        base =   { health = 1.0, speed = 1.0, attackDamage = 1.0 },
        charge = { health = 1.0, speed = 1.0, attackDamage = 1.0 },
        ranged = { health = 1.0, speed = 1.0, attackDamage = 1.0 },
    },
    [2] = {
        base =   { health = 1.2, speed = 1.1, attackDamage = 1.1 },
        charge = { health = 1.2, speed = 1.1, attackDamage = 1.1 },
        ranged = { health = 1.2, speed = 1.1, attackDamage = 1.1 },
    },
    [3] = {
        base =   { health = 1.4, speed = 1.2, attackDamage = 1.2 },
        charge = { health = 1.5, speed = 1.5, attackDamage = 1.5 },
        ranged = { health = 1.3, speed = 1.2, attackDamage = 1.3 },
    },
    [4] = {
        base =   { health = 1.6, speed = 1.3, attackDamage = 1.3 },
        charge = { health = 1.7, speed = 1.6, attackDamage = 1.6 },
        ranged = { health = 1.5, speed = 1.4, attackDamage = 1.5 },
    },
    [5] = {
        base =   { health = 1.8, speed = 1.4, attackDamage = 1.4 },
        charge = { health = 2.0, speed = 2.0, attackDamage = 2.0 },
        ranged = { health = 1.7, speed = 1.5, attackDamage = 1.6 },
    },
    [6] = {
        base =   { health = 2.0, speed = 1.5, attackDamage = 1.5 },
        charge = { health = 2.5, speed = 2.2, attackDamage = 2.2 },
        ranged = { health = 2.0, speed = 1.7, attackDamage = 2.0 },
    },
}


-- Helper to get an enemy type based on probability
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

-- Helper to get color for an enemy type
function Enemy.getTypeColor(enemyType)
    if enemyType == "base" then
        return {1, 1, 0}
    elseif enemyType == "charge" then
        return {1, 0, 0}
    elseif enemyType == "ranged" then
        return {0.2, 0.4, 0.8}
    else
        return {1, 1, 1}
    end
end

-- Get custom multiplier for a specific unit if defined
function Enemy.getCustomMultiplier(wave, enemyType, indexInWave)
    local waveData = Enemy.customMultipliers[wave]
    if waveData and waveData[enemyType] then
        return waveData[enemyType][indexInWave]
    end
    return nil
end

-- Calculate stats from base and multipliers
-- just type multiplier, purposely commented out, but left in in case we wanna revert back to this

-- function Enemy.calculateStats(enemyType, wave, customMult)
--     local stats = {}
--     local base = Enemy.baseStats
--     local mult = customMult or Enemy.typeMultipliers[enemyType]
--     local w = wave or 1

--     stats.width     = base.width * mult.width
--     stats.height    = base.height * mult.height
--     stats.health    = (base.baseHealth + w * base.healthPerWave) * mult.health
--     stats.maxHealth = stats.health
--     stats.speed     = (base.baseSpeed + w * base.speedPerWave) * mult.speed
--     stats.maxSpeed  = (base.baseMaxSpeed + w * base.maxSpeedPerWave) * mult.speed
--     stats.attackDamage = base.baseAttackDamage * mult.attackDamage
--     stats.attackRange  = base.baseAttackRange * mult.attackRange
--     stats.attackCD     = base.baseAttackCD * mult.attackCD
--     stats.attackTimer  = 0
--     stats.alive        = true
--     stats.color        = Enemy.getTypeColor(enemyType)

--     return stats
-- end

-- Calculate stats from base and multipliers
-- Combined version, base type multiplier * wave multiplier

function Enemy.calculateStats(enemyType, wave, customMult)
    local stats = {}
    local base = Enemy.baseStats
    local typeMult = Enemy.typeMultipliers[enemyType]
    local waveMult = customMult or {}

    -- Combine: default * wave override (if present)
    local function getStat(key)
        return typeMult[key] * (waveMult[key] or 1)
    end

    local w = wave or 1
    stats.width     = base.width     * getStat("width")
    stats.height    = base.height    * getStat("height")
    stats.health    = (base.baseHealth + w * base.healthPerWave) * getStat("health")
    stats.maxHealth = stats.health
    stats.speed     = (base.baseSpeed + w * base.speedPerWave) * getStat("speed")
    stats.maxSpeed  = (base.baseMaxSpeed + w * base.maxSpeedPerWave) * getStat("speed")
    stats.attackDamage = base.baseAttackDamage * getStat("attackDamage")
    stats.attackRange  = base.baseAttackRange  * getStat("attackRange")
    stats.attackCD     = base.baseAttackCD     * getStat("attackCD")
    stats.attackTimer  = 0
    stats.alive        = true
    stats.color        = Enemy.getTypeColor(enemyType)
    stats.enemyType     = enemyType


    return stats
end


-- Factory function to create enemy instance
function Enemy.new(enemyType, wave, indexInWave)
    local x = math.random(100, 700)
    local y = math.random(100, 500)

    local customMult = Enemy.getCustomMultiplier(wave, enemyType, indexInWave)
    local stats = Enemy.calculateStats(enemyType, wave, customMult)
    stats.x = x
    stats.y = y

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

--- Returns the drop chance for an enemy instance
function Enemy.getDropChance(enemy)
    if not enemy or not enemy.enemyType then
        return 0.1
    end

    if enemy.enemyType == "charge" then
        return 0.30
    else
        return 0.1
    end
end


return Enemy
