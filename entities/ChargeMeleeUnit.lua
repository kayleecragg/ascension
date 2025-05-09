-- ChargeMeleeUnit.lua
-- A specialized melee unit that can charge at the player for high damage.

local BaseMeleeUnit = require("entities.BaseMeleeUnit")
local Slash = require("effects.Slash")
local TakeDamage = require("effects.takeDamage")
local util = require("util")
local Combat = require("combat")

local ChargeMeleeUnit = {}
ChargeMeleeUnit.__index = ChargeMeleeUnit
setmetatable(ChargeMeleeUnit, {__index = BaseMeleeUnit})  -- Inherit behavior, not stats

-- Constructor accepts pre-calculated stats
function ChargeMeleeUnit.new(stats)
    -- Note: color is now set in Enemy.calculateStats
    
    setmetatable(stats, ChargeMeleeUnit)

    -- Charge-specific properties
    stats.chargeCD = 5       -- Cooldown for charge ability
    stats.chargeTimer = 0    -- Current cooldown timer
    stats.chargeSpeed = stats.maxSpeed * 5  -- Speed while charging (5x normal max speed)
    stats.chargeDamage = stats.attackDamage * 1.2  -- Damage done by charge
    stats.isCharging = false -- Whether currently in charging state
    stats.chargeDuration = 0.8 -- How long the charge lasts
    stats.chargeTime = 0 -- Current charge timer
    stats.chargeTargetX = 0 -- X coordinate target for charge
    stats.chargeTargetY = 0 -- Y coordinate target for charge
    stats.chargeDirectionX = 0 -- X direction of charge
    stats.chargeDirectionY = 0 -- Y direction of charge
    stats.chargeTrail = {} -- To create a trail effect during charging
    stats.trailLifetime = 0.4 -- How long trail particles last (increased from 0.2)

    return stats
end

function ChargeMeleeUnit:ability(target)
    if self.chargeTimer <= 0 and not self.isCharging and self.alive then
        -- Reset charge state
        self.isCharging = true
        self.chargeTime = 0
        
        -- Calculate direction to player
        local targetX = target.x + target.width/2
        local targetY = target.y + target.height/2
        local startX = self.x + self.width/2
        local startY = self.y + self.height/2
        
        -- Store the target position at the start of charge
        self.chargeTargetX = targetX
        self.chargeTargetY = targetY
        
        -- Calculate direction
        local dx = targetX - startX
        local dy = targetY - startY
        local length = math.sqrt(dx * dx + dy * dy)
        
        if length > 0 then
            self.chargeDirectionX = dx / length
            self.chargeDirectionY = dy / length
        else
            self.chargeDirectionX = 1  -- Default to right if somehow on top of target
            self.chargeDirectionY = 0
        end
        
        -- Clear existing trail
        self.chargeTrail = {}
        
        return true
    end
    
    return false
end

function ChargeMeleeUnit:update(dt, target)
    -- Update charge cooldown
    self.chargeTimer = math.max(0, self.chargeTimer - dt)
    
    -- Update trail particles - moved outside of charging check to ensure
    -- particles continue to update even after charge ends
    for i = #self.chargeTrail, 1, -1 do
        local p = self.chargeTrail[i]
        p.timer = p.timer + dt
        
        -- Move particles that have momentum
        if p.dx and p.dy then
            p.x = p.x + p.dx * dt
            p.y = p.y + p.dy * dt
            
            -- Slow down particles
            p.dx = p.dx * 0.92  -- Slightly slower decay for better visual
            p.dy = p.dy * 0.92
        end
        
        -- Remove expired particles
        if p.timer >= p.lifetime then
            table.remove(self.chargeTrail, i)
        end
    end
    
    if self.isCharging then
        -- Update charge timer
        self.chargeTime = self.chargeTime + dt
        
        -- Move in charging direction
        local moveX = self.chargeDirectionX * self.chargeSpeed * dt
        local moveY = self.chargeDirectionY * self.chargeSpeed * dt

        self.x = self.x + moveX
        self.y = self.y + moveY

        -- Clamp within screen bounds
        local w, h = love.graphics.getDimensions()
        self.x = util.clamp(self.x, 20, w - self.width - 20)
        self.y = util.clamp(self.y, 20, h - self.height - 20)
        
        -- Add trail particles
        if math.random() < 0.3 then  -- Only add some particles for performance
            table.insert(self.chargeTrail, {
                x = self.x + self.width/2 - self.chargeDirectionX * self.width/2,
                y = self.y + self.height/2 - self.chargeDirectionY * self.height/2,
                lifetime = self.trailLifetime,
                timer = 0,
                size = self.width * 0.4,
                color = {self.color[1], self.color[2], self.color[3], 0.7}
            })
        end
        
        -- Check for collision with player during charge
        if target and target.alive then
            local myCenter = {x = self.x + self.width/2, y = self.y + self.height/2}
            local targetCenter = {x = target.x + target.width/2, y = target.y + target.height/2}
            
            local dx = myCenter.x - targetCenter.x
            local dy = myCenter.y - targetCenter.y
            local dist = math.sqrt(dx * dx + dy * dy)
            
            if dist < (self.width + target.width) / 2 then
                -- Hit the player!
                target.health = target.health - self.chargeDamage
                TakeDamage.start()

                if target.health <= 0 then
                    Combat.killPlayer()
                end

                -- Create an impact effect
                for i = 1, 8 do
                    local angle = math.random() * math.pi * 2
                    local speed = math.random(50, 200)
                    table.insert(self.chargeTrail, {
                        x = myCenter.x,
                        y = myCenter.y,
                        dx = math.cos(angle) * speed,
                        dy = math.sin(angle) * speed,
                        lifetime = self.trailLifetime * 1.5,
                        timer = 0,
                        size = self.width * 0.3,
                        color = {1, 0.2, 0.1, 0.9}
                    })
                end
            end

        end
        
        -- End charge after duration expires
        if self.chargeTime >= self.chargeDuration then
            self.isCharging = false
            self.chargeTimer = self.chargeCD  -- Start cooldown
        end
    else
        -- Not charging, use normal AI
        if math.random() < 0.01 and target then  -- Small chance to use charge ability
            self:ability(target)
        else
            -- Call the parent's update method for normal behavior
            BaseMeleeUnit.update(self, dt, target)
        end
    end
end

function ChargeMeleeUnit:draw()
    -- Draw charge trail
    for _, p in ipairs(self.chargeTrail) do
        -- Calculate alpha based on remaining lifetime
        local alpha = p.color[4] * (1 - (p.timer / p.lifetime))
        
        -- Apply the fading alpha value
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        
        -- Draw the particle with a size that might diminish slightly over time
        local sizeMultiplier = 1 - (p.timer / p.lifetime) * 0.3
        love.graphics.circle("fill", p.x, p.y, p.size * sizeMultiplier)
    end
    
    -- Draw the unit with appropriate color
    if self.alive then
        if self.isCharging then
            -- Brighter color during charge
            love.graphics.setColor(1, 0.3, 0.3)
        else
            love.graphics.setColor(self.color)
        end
        
        love.graphics.rectangle("fill", 
            self.x, self.y, 
            self.width, self.height
        )
        
        -- Draw health bar
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("fill", 
            self.x, self.y - 8, 
            self.width, 5
        )
        
        love.graphics.setColor(0, 1, 0)
        love.graphics.rectangle("fill", 
            self.x, self.y - 8, 
            self.width * (self.health / self.maxHealth), 5
        )
        
        -- Draw ability cooldown indicator
        if self.chargeTimer > 0 then
            local cdPercent = self.chargeTimer / self.chargeCD
            love.graphics.setColor(0.2, 0.2, 0.8, 0.7)
            love.graphics.arc("fill", 
                self.x + self.width/2, 
                self.y + self.height/2, 
                self.width * 0.6, 
                -math.pi/2, 
                -math.pi/2 + (1 - cdPercent) * math.pi * 2
            )
        end
        
        -- Reset color
        love.graphics.setColor(1, 1, 1)
    end
end

return ChargeMeleeUnit