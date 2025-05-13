-- entities/Player.lua
local assets        = require("assets")
local util          = require("util")
local BaseMeleeUnit = require("entities.BaseMeleeUnit")
local Slash         = require("effects.Slash")

local Player = {}
Player.__index = Player

-- Constants
local PADDING        = 40
local TELEPORT_RANGE = 370
local DODGE_DURATION = 0.4
local DODGE_PHASES   = {4, 3, 2, 1}

-- Helper: draw icon + cooldown box
local function drawAbilityBox(x, y, size, timer, maxCD, label)
    love.graphics.setColor(0.2,0.2,0.2)
    love.graphics.rectangle("fill", x, y, size, size)
    if timer > 0 then
        local pct = timer / maxCD
        love.graphics.setColor(0,0,0,0.6)
        love.graphics.rectangle("fill", x, y + size*(1-pct), size, size*pct)
    end
    love.graphics.setColor(1,1,1)
    love.graphics.rectangle("line", x, y, size, size)
    local textW = assets.dialogueFont:getWidth(label)
    love.graphics.print(label, x + size/2 - textW/2, y + size + 2)
    if timer > 0 then
        love.graphics.printf(string.format("%.1f", timer), x, y + size/2 - 6, size, "center")
    end
end

function Player.new()
    return setmetatable({
        -- position & size
        x = 100, y = 300,
        width = 50, height = 50,
        -- movement
        speed = 200,
        -- health
        health = 100,
        maxHealth = 100,
        alive = true,
        -- melee
        attackDamage = 5,
        attackRange  = 120,
        attackCD     = 1,
        attackTimer  = 0,
        -- ranged
        rangedDamage = 2,
        rangedCD     = 2,
        rangedTimer  = 0,
        projCount    = 5,
        projSpeed    = 700,
        projSpread   = math.rad(15),
        -- teleport
        teleportCD     = 12,
        teleportTimer  = 0,
        teleportAiming = false,
        -- dodge
        dodgeCD    = 4,
        dodgeTimer = 0,
        dodging    = false,
        dodgeTime  = 0,
        dodgeDir   = {x=0,y=0},
    }, Player)
end

-- Melee attack: spawns a Slash into BaseMeleeUnit.slashes
function Player:meleeAttack(tx, ty)
    if self.attackTimer > 0 or not self.alive then return false end
    local px,py = self.x + self.width/2, self.y + self.height/2
    local slash = Slash:new(px,py, tx,ty, self.attackDamage, 0.4, self.attackRange)
    slash.isEnemy = false
    table.insert(BaseMeleeUnit.slashes, slash)
    self.attackTimer = self.attackCD
    return true
end

-- Ranged attack: returns a list of projectiles for combat.lua to insert
function Player:rangedAttack(tx, ty)
    if self.rangedTimer > 0 or not self.alive then return nil end
    local px,py = self.x + self.width/2, self.y + self.height/2
    local bullets = {}
    local baseAng = math.atan2(ty-py, tx-px)
    for i=1,self.projCount do
        local spread = baseAng + (i-(self.projCount+1)/2)*self.projSpread
        table.insert(bullets, {
            x = px, y = py,
            dx = math.cos(spread), dy = math.sin(spread),
            speed = self.projSpeed,
            damage = self.rangedDamage,
        })
    end
    self.rangedTimer = self.rangedCD
    return bullets
end

-- Start dodge: sets state, direction, cooldown
function Player:startDodge()
    if self.dodgeTimer > 0 or not self.alive then return false end
    local dx,dy = 0,0
    if love.keyboard.isDown("d") then dx=dx+1 end
    if love.keyboard.isDown("a") then dx=dx-1 end
    if love.keyboard.isDown("s") then dy=dy+1 end
    if love.keyboard.isDown("w") then dy=dy-1 end
    local len = math.sqrt(dx*dx+dy*dy)
    if len == 0 then dx,dy = 1,0 else dx,dy = dx/len,dy/len end

    self.dodgeDir    = {x=dx,y=dy}
    self.dodging     = true
    self.dodgeTime   = 0
    self.dodgeTimer  = self.dodgeCD
    return true
end

-- Update dodge movement each frame
function Player:updateDodge(dt)
    if not self.dodging then return end
    self.dodgeTime = self.dodgeTime + dt
    local frac  = self.dodgeTime / DODGE_DURATION
    local phase = math.min(#DODGE_PHASES, math.floor(frac * #DODGE_PHASES) + 1)
    local speedMul = DODGE_PHASES[phase]
    self.x = self.x + self.dodgeDir.x * self.speed * speedMul * dt
    self.y = self.y + self.dodgeDir.y * self.speed * speedMul * dt
    -- clamp
    local w,h = love.graphics.getDimensions()
    self.x = util.clamp(self.x, PADDING, w - self.width - PADDING)
    self.y = util.clamp(self.y, PADDING, h - self.height - PADDING)
    if self.dodgeTime >= DODGE_DURATION then
        self.dodging   = false
        self.dodgeTime = 0
    end
end

-- Begin teleport aiming
function Player:startTeleport()
    if self.teleportTimer > 0 or not self.alive then return false end
    self.teleportAiming = true
    return true
end

-- Complete teleport on click
function Player:completeTeleport(tx, ty)
    if not self.teleportAiming then return false end
    local px,py = self.x + self.width/2, self.y + self.height/2
    local dx,dy = tx-px, ty-py
    local dist = math.sqrt(dx*dx+dy*dy)
    if dist > TELEPORT_RANGE then
        dx,dy = dx/dist*TELEPORT_RANGE, dy/dist*TELEPORT_RANGE
    end
    local w,h = love.graphics.getDimensions()
    self.x = util.clamp(px+dx - self.width/2, PADDING, w - self.width - PADDING)
    self.y = util.clamp(py+dy - self.height/2, PADDING, h - self.height - PADDING)
    self.teleportTimer = self.teleportCD
    self.teleportAiming = false
    return true
end

-- Called each frame
function Player:update(dt)
    -- cooldowns
    self.attackTimer   = math.max(0, self.attackTimer   - dt)
    self.rangedTimer   = math.max(0, self.rangedTimer   - dt)
    self.teleportTimer = math.max(0, self.teleportTimer - dt)
    self.dodgeTimer    = math.max(0, self.dodgeTimer    - dt)

    -- dodge movement
    self:updateDodge(dt)

    -- normal movement if not dodging
    if self.alive and not self.dodging then
        if love.keyboard.isDown("a") then self.x = self.x - self.speed * dt end
        if love.keyboard.isDown("d") then self.x = self.x + self.speed * dt end
        if love.keyboard.isDown("w") then self.y = self.y - self.speed * dt end
        if love.keyboard.isDown("s") then self.y = self.y + self.speed * dt end
        local w,h = love.graphics.getDimensions()
        self.x = util.clamp(self.x, PADDING, w - self.width - PADDING)
        self.y = util.clamp(self.y, PADDING, h - self.height - PADDING)
    end
end

-- Draw player, health bar, and ability UI
function Player:draw()
    local w,h = love.graphics.getDimensions()
    -- body
    love.graphics.setColor(self.alive and {0,1,0} or {0.4,0.4,0.4})
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    -- HP bar
    local pct = util.clamp(self.health/self.maxHealth,0,1)
    love.graphics.setColor(0,0,0)
    love.graphics.rectangle("fill", self.x, self.y-8, self.width, 5)
    love.graphics.setColor(0,1,0)
    love.graphics.rectangle("fill", self.x, self.y-8, self.width*pct, 5)
    -- ability boxes
    local bs = 48
    local gap = 20
    local totalWidth = 3 * bs + 2 * gap
    local startX = (w - totalWidth) / 2
    local by = 10  -- distance from top

    drawAbilityBox(startX,                 by, bs, self.teleportTimer, self.teleportCD, "SPACE")
    drawAbilityBox(startX + bs + gap,     by, bs, self.rangedTimer,   self.rangedCD,   "RMB")
    drawAbilityBox(startX + 2*(bs + gap), by, bs, self.dodgeTimer,    self.dodgeCD,    "LSHIFT")
    -- teleport range
    if self.teleportAiming then
        local cx,cy = self.x+self.width/2, self.y+self.height/2
        love.graphics.setColor(1,1,1,0.2)
        love.graphics.circle("fill", cx,cy, TELEPORT_RANGE)
        love.graphics.setColor(1,1,1,0.6)
        love.graphics.circle("line", cx,cy, TELEPORT_RANGE)
    end
    love.graphics.setColor(1,1,1)
end

return Player
