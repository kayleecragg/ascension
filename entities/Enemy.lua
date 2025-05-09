-- Enemy.lua
-- Factory for enemy creation, routing to different enemy types.

local BaseMeleeUnit   = require("entities.BaseMeleeUnit")
local ChargeMeleeUnit = require("entities.ChargeMeleeUnit")
local RangedUnit      = require("entities.RangedUnit")

local Enemy = {}

function Enemy.new(enemyType, wave)
    local x = math.random(100, 700)
    local y = math.random(100, 500)
    local w = wave or 1

    if enemyType == "base" then
        -- Base melee unit: slightly tanky
        return BaseMeleeUnit.new({
            x = x, y = y,
            width = 50, height = 50,
            health = 5 + w * 4,
            maxHealth = 5 + w * 4,
            speed = 60 + w * 15,
            maxSpeed = 100 + w * 15,
            attackDamage = 1,
            attackRange = 50,
            attackCD = 1.5,
            attackTimer = 0,
            alive = true,
        })

    elseif enemyType == "charge" then
        -- Faster, weaker unit that can charge
        return ChargeMeleeUnit.new({
            x = x, y = y,
            width = 55, height = 55,
            health = 3 + w * 2,
            maxHealth = 3 + w * 2,
            speed = 75 + w * 20,
            maxSpeed = 110 + w * 20,
            attackDamage = 1,
            attackRange = 50,
            attackCD = 2,
            attackTimer = 0,
            alive = true,
        })

    elseif enemyType == "ranged" then
        -- Fragile ranged unit with beam attack
        return RangedUnit.new({
            x = x, y = y,
            width = 45, height = 45,
            health = 2 + w * 2,
            maxHealth = 2 + w * 2,
            speed = 45 + w * 20,
            maxSpeed = 130 + w * 20,
            attackDamage = 1,
            attackRange = 60,
            attackCD = 2,  -- handled by beamCD
            attackTimer = 0,
            alive = true,
        })
    end
end

return Enemy
