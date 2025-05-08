-- enemies/RangedUnit.lua
local BaseMeleeUnit = require("enemies.BaseMeleeUnit")
local Slash = require("effects.Slash")

local RangedUnit = {}
RangedUnit.__index = RangedUnit
setmetatable(RangedUnit, {__index = BaseMeleeUnit})  -- Set up inheritance

-- Store all active beam projectiles
RangedUnit.beams = {}

function RangedUnit:new(x, y, width, height, health, maxHealth, speed, maxSpeed, attackDamage, attackRange, attackCD, attackTimer)
    -- Call the parent constructor
    local unit = BaseMeleeUnit:new(x, y, width, height, health, maxHealth, speed, maxSpeed, attackDamage, attackRange, attackCD, attackTimer)
    
    -- Change the metatable to RangedUnit
    setmetatable(unit, RangedUnit)
    
    -- Add RangedUnit specific properties
    unit.beamCD = 5        -- Cooldown for beam ability (longer than charge)
    unit.beamTimer = 0     -- Current cooldown timer
    unit.beamDamage = unit.attackDamage * 3  -- Damage done by beam
    unit.beamSpeed = 600   -- Speed of the beam projectile
    unit.beamWidth = 30    -- Width of the beam
    unit.beamLength = 80   -- Length of the beam
    unit.castingBeam = false  -- Whether currently casting a beam
    unit.castTime = 1.0    -- Time to cast beam
    unit.castTimer = 0     -- Current cast timer
    unit.beamDirection = {x = 0, y = 0}  -- Direction of the beam
    unit.color = {0.2, 0.4, 0.8}  -- Blue color for this unit type
    unit.particleTimer = 0  -- Timer for particle effects
    unit.particles = {}    -- Initialize the particles table here
    
    return unit
end

function RangedUnit:ability(target)
    if self.beamTimer <= 0 and not self.castingBeam and self.alive then
        -- Start casting
        self.castingBeam = true
        self.castTimer = 0
        
        -- Calculate direction to player
        local targetX = target.x + target.width/2
        local targetY = target.y + target.height/2
        local startX = self.x + self.width/2
        local startY = self.y + self.height/2
        
        -- Calculate normalized direction vector
        local dx = targetX - startX
        local dy = targetY - startY
        local length = math.sqrt(dx * dx + dy * dy)
        
        if length > 0 then
            self.beamDirection.x = dx / length
            self.beamDirection.y = dy / length
        else
            self.beamDirection.x = 1
            self.beamDirection.y = 0
        end
        
        return true
    end
    
    return false
end

function RangedUnit:fireBeam()
    -- Create a new beam projectile
    local beam = {
        x = self.x + self.width/2,
        y = self.y + self.height/2,
        dirX = self.beamDirection.x,
        dirY = self.beamDirection.y,
        width = self.beamWidth,
        length = self.beamLength,
        speed = self.beamSpeed,
        damage = self.beamDamage,
        active = true,
        particles = {},  -- Initialize particles array for the beam
        lifetime = 5,  -- Maximum lifetime in seconds
        timer = 0,
        owner = self,
    }
    
    table.insert(RangedUnit.beams, beam)
    return beam
end

function RangedUnit:update(dt, target)
    -- Update beam cooldown
    self.beamTimer = math.max(0, self.beamTimer - dt)
    
    -- Update particle timer
    self.particleTimer = self.particleTimer + dt
    
    if self.castingBeam then
        -- Update cast timer
        self.castTimer = self.castTimer + dt
        
        -- Generate casting particles
        if self.particleTimer >= 0.05 then  -- Every 0.05 seconds
            self.particleTimer = 0
            
            -- Create particles that orbit the unit during casting
            local angle = math.random() * math.pi * 2
            local distance = self.width * 0.8
            local particleX = self.x + self.width/2 + math.cos(angle) * distance
            local particleY = self.y + self.height/2 + math.sin(angle) * distance
            
            local particle = {
                x = particleX,
                y = particleY,
                targetX = self.x + self.width/2,
                targetY = self.y + self.height/2,
                size = 4 + math.random() * 4,
                speed = 120 + math.random() * 60,
                lifetime = 0.5,
                timer = 0,
                color = {0.3, 0.6, 1, 0.8}
            }
            
            table.insert(self.particles, particle)
        end
        
        -- If cast time is complete, fire the beam
        if self.castTimer >= self.castTime then
            self:fireBeam()
            self.castingBeam = false
            self.beamTimer = self.beamCD  -- Start cooldown
        end
    else
        -- Not casting, use normal AI or attempt to use ability
        if math.random() < 0.005 and target then  -- Small chance to use beam ability
            self:ability(target)
        else
            -- Call the parent's update method for normal behavior
            BaseMeleeUnit.update(self, dt, target)
        end
    end
    
    -- Update particles
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.timer = p.timer + dt
        
        -- Move particles toward the center during casting
        if self.castingBeam then
            local dx = p.targetX - p.x
            local dy = p.targetY - p.y
            local dist = math.sqrt(dx * dx + dy * dy)
            
            if dist > 0 then
                p.x = p.x + (dx / dist) * p.speed * dt
                p.y = p.y + (dy / dist) * p.speed * dt
            end
        end
        
        -- Fade out
        p.color[4] = 0.8 * (1 - (p.timer / p.lifetime))
        
        -- Remove expired particles
        if p.timer >= p.lifetime then
            table.remove(self.particles, i)
        end
    end
    
    -- Update beams
    for i = #RangedUnit.beams, 1, -1 do
        local beam = RangedUnit.beams[i]
        beam.timer = beam.timer + dt
        
        -- Move beam
        beam.x = beam.x + beam.dirX * beam.speed * dt
        beam.y = beam.y + beam.dirY * beam.speed * dt
        
        -- Generate trail particles
        if math.random() < 0.3 then
            local trailParticle = {
                x = beam.x - beam.dirX * (math.random() * beam.length),
                y = beam.y - beam.dirY * (math.random() * beam.length),
                size = 3 + math.random() * 5,
                lifetime = 0.3,
                timer = 0,
                color = {0.2, 0.5, 1, 0.7}
            }
            table.insert(beam.particles, trailParticle)
        end
        
        -- Update beam particles
        for j = #beam.particles, 1, -1 do
            local p = beam.particles[j]
            p.timer = p.timer + dt
            p.color[4] = 0.7 * (1 - (p.timer / p.lifetime))
            
            if p.timer >= p.lifetime then
                table.remove(beam.particles, j)
            end
        end
        
        -- Check if beam has expired or left the screen
        local w, h = love.graphics.getDimensions()
        if beam.timer >= beam.lifetime or 
           beam.x < -beam.length or beam.x > w + beam.length or
           beam.y < -beam.length or beam.y > h + beam.length then
            table.remove(RangedUnit.beams, i)
        end
    end
end

function RangedUnit:draw()
    -- Draw particles
    for _, p in ipairs(self.particles) do
        love.graphics.setColor(p.color)
        love.graphics.circle("fill", p.x, p.y, p.size * (1 - (p.timer / p.lifetime)))
    end
    
    -- Draw the unit with appropriate color
    if self.alive then
        if self.castingBeam then
            -- Glowing effect during casting
            love.graphics.setColor(0.4, 0.7, 1, 0.4)
            love.graphics.circle("fill", 
                self.x + self.width/2, 
                self.y + self.height/2, 
                self.width * (0.7 + math.sin(self.castTimer * 10) * 0.2)
            )
            
            -- Brighter color during casting
            love.graphics.setColor(0.4, 0.7, 1)
        else
            love.graphics.setColor(self.color)
        end
        
        love.graphics.rectangle("fill", 
            self.x, self.y, 
            self.width, self.height
        )
        
        -- Draw ability cooldown indicator
        if self.beamTimer > 0 then
            local cdPercent = self.beamTimer / self.beamCD
            love.graphics.setColor(0.1, 0.3, 0.7, 0.7)
            love.graphics.arc("fill", 
                self.x + self.width/2, 
                self.y + self.height/2, 
                self.width * 0.6, 
                -math.pi/2, 
                -math.pi/2 + (1 - cdPercent) * math.pi * 2
            )
        end
        
        -- Draw aiming direction during casting
        if self.castingBeam then
            love.graphics.setColor(0.4, 0.7, 1, 0.5)
            love.graphics.line(
                self.x + self.width/2,
                self.y + self.height/2,
                self.x + self.width/2 + self.beamDirection.x * 200,
                self.y + self.height/2 + self.beamDirection.y * 200
            )
        end
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1)
    
    -- Draw all beams
    for _, beam in ipairs(RangedUnit.beams) do
        -- Draw beam particles
        for _, p in ipairs(beam.particles) do
            love.graphics.setColor(p.color)
            love.graphics.circle("fill", p.x, p.y, p.size)
        end
        
        -- Calculate beam endpoints
        local endX = beam.x - beam.dirX * beam.length
        local endY = beam.y - beam.dirY * beam.length
        
        -- Draw main beam
        love.graphics.setColor(0.4, 0.8, 1, 0.8)
        love.graphics.setLineWidth(beam.width)
        love.graphics.line(beam.x, beam.y, endX, endY)
        
        -- Draw beam core
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.setLineWidth(beam.width * 0.4)
        love.graphics.line(beam.x, beam.y, endX, endY)
        
        -- Reset line width
        love.graphics.setLineWidth(1)
    end
end

return RangedUnit