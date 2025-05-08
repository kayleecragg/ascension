-- Slash.lua
local Slash = {}
Slash.__index = Slash

function Slash:new(startX, startY, targetX, targetY, damage, duration, attackRange)
    local slash = {}
    setmetatable(slash, Slash)
    
    -- Position and target
    slash.x = startX
    slash.y = startY
    slash.startX = startX
    slash.startY = startY
    slash.targetX = targetX
    slash.targetY = targetY
    
    -- Calculate direction vector
    local dx = targetX - startX
    local dy = targetY - startY
    local length = math.sqrt(dx*dx + dy*dy)
    slash.dirX = dx / length
    slash.dirY = dy / length
    
    -- Properties
    slash.width = attackRange * 0.8 or 30
    slash.height = attackRange * 0.4 or 15
    slash.damage = damage / 60 or 1
    slash.duration = duration or 0.4
    slash.timer = 0
    slash.active = true
    slash.isEnemy = false
    
    -- Animation properties
    slash.fadeInTime = slash.duration * 0.3
    slash.fadeOutTime = slash.duration * 0.7
    slash.alpha = 0  -- Start transparent
    slash.rotation = math.atan2(dy, dx)
    
    -- Calculate the distance to travel
    slash.distance = attackRange * 0.8 or 30
    
    -- When damage is actually applied (percentage of duration)
    slash.damageTime = 0.5  -- Damage occurs halfway through animation
    
    return slash
end

function Slash:update(dt)
    -- Update timer
    self.timer = self.timer + dt
    
    -- Check if slash has expired
    if self.timer >= self.duration then
        self.active = false
        return
    end
    
    -- Update position - move towards target
    local progress = self.timer / self.duration
    self.x = self.startX + self.dirX * (self.distance * progress)
    self.y = self.startY + self.dirY * (self.distance * progress)
    
    -- Update alpha (fade in/out)
    if self.timer < self.fadeInTime then
        -- Fade in
        self.alpha = self.timer / self.fadeInTime
    elseif self.timer > self.fadeOutTime then
        -- Fade out
        local fadeOutDuration = self.duration - self.fadeOutTime
        local fadeOutProgress = (self.timer - self.fadeOutTime) / fadeOutDuration
        self.alpha = 1 - fadeOutProgress
    else
        -- Full opacity in the middle
        self.alpha = 1
    end
end

function Slash:draw()
    -- Save current transform
    love.graphics.push()
    
    -- Translate to slash position
    love.graphics.translate(self.x, self.y)
    
    -- Rotate to face the direction of movement
    love.graphics.rotate(self.rotation)
    
    -- Draw the slash effect with different colors based on owner
    if self.isEnemy then
        love.graphics.setColor(1, 0.3, 0, self.alpha)  -- Orange-red for enemy slashes
    else
        love.graphics.setColor(0, 0.8, 1, self.alpha)  -- Blue for player slashes
    end
    
    -- Draw slash shape
    love.graphics.polygon("fill", 
        0, 0,                    -- point
        -self.width/2, self.height/2,  -- bottom left 
        self.width/2, self.height/2    -- bottom right
    )
    
    -- Draw a trail/glow effect
    if self.isEnemy then
        love.graphics.setColor(1, 0.2, 0, self.alpha * 0.5)  -- Red glow for enemy
    else
        love.graphics.setColor(0.3, 0.6, 1, self.alpha * 0.5)  -- Blue glow for player
    end
    love.graphics.polygon("fill", 
        -self.width/2, self.height/2,
        -self.width/4, self.height,
        self.width/4, self.height,
        self.width/2, self.height/2
    )
    
    -- Reset transform
    love.graphics.pop()
end

return Slash