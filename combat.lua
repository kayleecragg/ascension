-- combat.lua

local assets        = require("assets")
local util          = require("util")
local Player        = require("entities.Player")
local Enemy         = require("entities.Enemy")
local TakeDamage    = require("effects.takeDamage")
local Slash         = require("effects.Slash")
local BaseMeleeUnit = require("entities.BaseMeleeUnit")
local RangedUnit    = require("entities.RangedUnit")

local Combat        = {}

local PADDING          = 20
local MESSAGE_DURATION = 2
local TELEPORT_RANGE   = 370

-- On-screen message state
local message      = ""
local messageTimer = 0

-- Combat state
Combat.player          = {}
Combat.enemies         = {}
Combat.projectiles     = {}
Combat.currentWave     = 0
Combat.playerDead      = false
Combat.combatDone      = false

-- Projectile settings
Combat.projSpeed  = 700
Combat.projCount  = 5
Combat.projSpread = math.rad(15)

-- Teleport-aim flag
Combat.teleportAiming = false

-- Helper to play short sounds
local function playSound(src)
    if src then src:stop(); src:play() end
end

-- Draws an ability icon + cooldown overlay
local function drawAbilityBox(x, y, size, timer, maxCD, label)
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", x, y, size, size)
    if timer > 0 then
        local pct = timer / maxCD
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", x, y + size * (1 - pct), size, size * pct)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", x, y, size, size)
    love.graphics.printf(label, x, y + size + 2, size, "center")
    if timer > 0 then
        love.graphics.printf(string.format("%.1f", timer), x, y + size/2 - 6, size, "center")
    end
end

function Combat.start()
    Combat.player        = Player.new()
    Combat.enemies       = {}
    Combat.projectiles   = {}
    BaseMeleeUnit.slashes= {}
    Combat.currentWave   = 0
    Combat.playerDead    = false
    Combat.combatDone    = false
    Combat.teleportAiming= false
    message              = ""
    messageTimer         = 0

    Combat.spawnWave()
    assets.music.combatTheme:setVolume(0.3)
    if not assets.music.combatTheme:isPlaying() then
        assets.music.combatTheme:play()
    end
end

function Combat.spawnWave()
    Combat.currentWave = Combat.currentWave + 1
    local count = Enemy.spawnRates.waves[Combat.currentWave] or 0

    if Combat.currentWave == 1 then
        local opts1 = {"base", "ranged", "charge"}
        local opts2 = {"charge", "ranged"}
        local e1 = Enemy.new(opts1[math.random(#opts1)], Combat.currentWave)
        if e1.chargeTimer then e1.chargeTimer = e1.chargeCD end
        table.insert(Combat.enemies, e1)
        local e2 = Enemy.new(opts2[math.random(#opts2)], Combat.currentWave)
        if e2.chargeTimer then e2.chargeTimer = e2.chargeCD end
        table.insert(Combat.enemies, e2)
    else
        for i = 1, count do
            local et = Enemy.getRandomType()
            local e  = Enemy.new(et, Combat.currentWave)
            if e.chargeTimer then e.chargeTimer = e.chargeCD end
            table.insert(Combat.enemies, e)
        end
    end
end

function Combat.update(dt)
    if Combat.playerDead or Combat.combatDone then return end
    local w, h = love.graphics.getDimensions()
    TakeDamage.update(dt)

    -- only allow movement when not aiming teleport
    if Combat.player.alive and not Combat.teleportAiming then
        if love.keyboard.isDown("a") then Combat.player.x = Combat.player.x - Combat.player.speed * dt end
        if love.keyboard.isDown("d") then Combat.player.x = Combat.player.x + Combat.player.speed * dt end
        if love.keyboard.isDown("w") then Combat.player.y = Combat.player.y - Combat.player.speed * dt end
        if love.keyboard.isDown("s") then Combat.player.y = Combat.player.y + Combat.player.speed * dt end
        Combat.player.x = util.clamp(Combat.player.x, PADDING, w - Combat.player.width - PADDING)
        Combat.player.y = util.clamp(Combat.player.y, PADDING, h - Combat.player.height - PADDING)
    end

    Combat.player.attackTimer   = math.max(0, Combat.player.attackTimer   - dt)
    Combat.player.rangedTimer   = math.max(0, Combat.player.rangedTimer   - dt)
    Combat.player.teleportTimer = math.max(0, Combat.player.teleportTimer - dt)

    -- enemy updates
    for _, e in ipairs(Combat.enemies) do
        if e.alive and Combat.player.alive then
            e:update(dt, Combat.player)
        end
    end

    -- slashes
    for i = #BaseMeleeUnit.slashes, 1, -1 do
        local s = BaseMeleeUnit.slashes[i]
        s:update(dt)
        if (s.timer / s.duration) >= s.damageTime then
            if s.isEnemy and Combat.player.alive then
                local px, py = Combat.player.x + Combat.player.width/2, Combat.player.y + Combat.player.height/2
                local dist = math.sqrt((s.x - px)^2 + (s.y - py)^2)
                if dist < s.width/2 + Combat.player.width/2 then
                    Combat.player.health = Combat.player.health - s.damage
                    TakeDamage.start()
                    playSound(assets.sfx.playerHit)
                    if Combat.player.health <= 0 then
                        Combat.player.health = 0
                        Combat.player.alive = false
                        Combat.playerDead = true
                        message = "You died!"
                        messageTimer = MESSAGE_DURATION
                        assets.music.combatTheme:stop()
                    end
                end
            elseif not s.isEnemy then
                for _, e in ipairs(Combat.enemies) do
                    if e.alive then
                        local ex, ey = e.x + e.width/2, e.y + e.height/2
                        local dist = math.sqrt((s.x - ex)^2 + (s.y - ey)^2)
                        if dist < s.width/2 + e.width/2 then
                            e:take_damage(s.damage)
                            playSound(assets.sfx.enemyHit)
                            if not e.alive then playSound(assets.sfx.enemyDeath) end
                        end
                    end
                end
            end
        end
        if not s.active then table.remove(BaseMeleeUnit.slashes, i) end
    end

    -- ranged beams
    for i = #RangedUnit.beams, 1, -1 do
        local beam = RangedUnit.beams[i]
        if Combat.player.alive then
            local px, py = Combat.player.x + Combat.player.width/2, Combat.player.y + Combat.player.height/2
            local ex, ey = beam.x - beam.dirX * beam.length, beam.y - beam.dirY * beam.length
            local vx, vy = px - beam.x, py - beam.y
            local wx, wy = ex - beam.x, ey - beam.y
            local dot = vx*wx + vy*wy
            local len_sq = wx*wx + wy*wy
            local t = (len_sq == 0) and -1 or (dot/len_sq)
            local cx, cy
            if t < 0    then cx,cy = beam.x, beam.y
            elseif t > 1 then cx,cy = ex, ey
            else             cx,cy = beam.x + t*wx, beam.y + t*wy end
            local dx, dy = px - cx, py - cy
            if math.sqrt(dx*dx + dy*dy) < (Combat.player.width/2 + beam.width/2) then
                Combat.player.health = Combat.player.health - beam.damage
                playSound(assets.sfx.playerHit)
                TakeDamage.start()
                if Combat.player.health <= 0 then
                    Combat.player.health = 0
                    Combat.player.alive = false
                    Combat.playerDead = true
                    message = "You died!"
                    messageTimer = MESSAGE_DURATION
                    assets.music.combatTheme:stop()
                end
            end
        end
    end

    -- projectiles
    for i = #Combat.projectiles, 1, -1 do
        local p = Combat.projectiles[i]
        p.x = p.x + p.dx * p.speed * dt
        p.y = p.y + p.dy * p.speed * dt
        local hit = false
        for _, e in ipairs(Combat.enemies) do
            if e.alive
            and p.x > e.x and p.x < e.x + e.width
            and p.y > e.y and p.y < e.y + e.height
            then
                e:take_damage(p.damage)
                playSound(assets.sfx.enemyHit)
                if not e.alive then playSound(assets.sfx.enemyDeath) end
                hit = true
                break
            end
        end
        if hit or p.x<0 or p.x>w or p.y<0 or p.y>h then
            table.remove(Combat.projectiles, i)
        end
    end

    -- check wave end
    local allDead = true
    for _, e in ipairs(Combat.enemies) do
        if e.alive then allDead = false; break end
    end
    if allDead then
        if Combat.currentWave < #Enemy.spawnRates.waves then
            Combat.spawnWave()
        else
            message = "Victory!"
            messageTimer = MESSAGE_DURATION
            Combat.combatDone = true
            assets.music.combatTheme:stop()
        end
    end

    if messageTimer > 0 then
        messageTimer = messageTimer - dt
        if messageTimer <= 0 then message = "" end
    end
end

function Combat.draw()
    local w,h = love.graphics.getDimensions()

    -- player
    love.graphics.setColor(Combat.player.alive and {0,1,0} or {0.4,0.4,0.4})
    love.graphics.rectangle("fill",
        Combat.player.x,
        Combat.player.y,
        Combat.player.width,
        Combat.player.height
    )
    local hpPct = util.clamp(Combat.player.health/Combat.player.maxHealth,0,1)
    love.graphics.setColor(0,0,0)
    love.graphics.rectangle("fill",
        Combat.player.x,
        Combat.player.y-8,
        Combat.player.width, 5
    )
    love.graphics.setColor(0,1,0)
    love.graphics.rectangle("fill",
        Combat.player.x,
        Combat.player.y-8,
        Combat.player.width * hpPct, 5
    )
    love.graphics.setColor(1,1,1)
    love.graphics.print("HP:"..math.floor(Combat.player.health).."/"..Combat.player.maxHealth, PADDING,10)
    love.graphics.print("Wave:"..Combat.currentWave.."/"..#Enemy.spawnRates.waves, PADDING,30)

    -- enemies
    for _, e in ipairs(Combat.enemies) do
        if e.alive then
            e:draw()
            local ePct = util.clamp(e.health/e.maxHealth,0,1)
            love.graphics.setColor(0,0,0)
            love.graphics.rectangle("fill", e.x, e.y-8, e.width,5)
            love.graphics.setColor(0,1,0)
            love.graphics.rectangle("fill", e.x, e.y-8, e.width * ePct,5)
        end
    end

    -- slashes
    for _, s in ipairs(BaseMeleeUnit.slashes) do s:draw() end

    -- projectiles
    for _, p in ipairs(Combat.projectiles) do
        love.graphics.setColor(0.75,0.75,0.75)
        love.graphics.circle("fill", p.x, p.y, 5)
    end

    -- ability icons
    local bs, by = 48, h - 48 - PADDING
    drawAbilityBox(PADDING,      by, bs, Combat.player.teleportTimer, Combat.player.teleportCD, "SPACE")
    drawAbilityBox(PADDING+bs+PADDING, by, bs, Combat.player.rangedTimer, Combat.player.rangedCD, "RMB")

    -- teleport‐aim circle
    if Combat.teleportAiming then
        local cx = Combat.player.x + Combat.player.width/2
        local cy = Combat.player.y + Combat.player.height/2
        love.graphics.setColor(1,1,1,0.2)
        love.graphics.circle("fill", cx, cy, TELEPORT_RANGE)
        love.graphics.setColor(1,1,1,0.6)
        love.graphics.circle("line", cx, cy, TELEPORT_RANGE)
        love.graphics.setColor(1,1,1)
    end

    TakeDamage.draw(w,h)

    if message ~= "" then
        love.graphics.setColor(1,1,1)
        love.graphics.printf(message, 0, h-30, w, "center")
    end

    love.graphics.setColor(1,1,1)
end

function Combat.keypressed(key)
    if key == "space" and Combat.player.alive then
        if Combat.player.teleportTimer > 0 then
            playSound(assets.sfx.abilityCooldown)
            message = "Ability on cooldown!"
            messageTimer = MESSAGE_DURATION
            return
        end
        -- enter aim mode
        Combat.teleportAiming = true
        message = "Click to teleport"
        messageTimer = MESSAGE_DURATION
        return
    end
    -- other keypresses (handled elsewhere)
end

function Combat.mousepressed(x, y, button)
    -- handle teleport click
    if Combat.teleportAiming and button == 1 then
        local px = Combat.player.x + Combat.player.width/2
        local py = Combat.player.y + Combat.player.height/2
        local dx = x - px
        local dy = y - py
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist > TELEPORT_RANGE then
            dx = dx/dist * TELEPORT_RANGE
            dy = dy/dist * TELEPORT_RANGE
        end
        local w, h = love.graphics.getDimensions()
        Combat.player.x = util.clamp(px + dx - Combat.player.width/2, PADDING, w-Combat.player.width-PADDING)
        Combat.player.y = util.clamp(py + dy - Combat.player.height/2, PADDING, h-Combat.player.height-PADDING)
        Combat.player.teleportTimer = Combat.player.teleportCD
        playSound(assets.sfx.teleport)
        message = "Teleported!"
        messageTimer = MESSAGE_DURATION
        Combat.teleportAiming = false
        return
    end

    -- melee / ranged
    local px = Combat.player.x + Combat.player.width/2
    local py = Combat.player.y + Combat.player.height/2

    if button == 1 and Combat.player.attackTimer <= 0 and Combat.player.alive then
        local slash = Slash:new(px, py, x, y,
            Combat.player.attackDamage, 0.4, Combat.player.attackRange
        )
        slash.isEnemy = false
        table.insert(BaseMeleeUnit.slashes, slash)
        Combat.player.attackTimer = Combat.player.attackCD
        playSound(assets.sfx.playerMelee)
        message = "Melee Attack!"
        messageTimer = MESSAGE_DURATION

    elseif button == 2 and Combat.player.alive then
        if Combat.player.rangedTimer > 0 then
            playSound(assets.sfx.abilityCooldown)
            message = "Ability on cooldown!"
            messageTimer = MESSAGE_DURATION
            return
        end
        local angle = math.atan2(y - py, x - px)
        for i = 1, Combat.projCount do
            local spread = angle + (i - (Combat.projCount+1)/2) * Combat.projSpread
            table.insert(Combat.projectiles, {
                x = px, y = py,
                dx = math.cos(spread),
                dy = math.sin(spread),
                speed = Combat.projSpeed,
                damage = Combat.player.rangedDamage,
            })
        end
        Combat.player.rangedTimer = Combat.player.rangedCD
        if assets.sfx.playerRanged then
            local s = assets.sfx.playerRanged:clone()
            s:play()
        end
        message = "Ranged Attack!"
        messageTimer = MESSAGE_DURATION
    end
end

function Combat.isDone() return Combat.combatDone end
function Combat.isDead() return Combat.playerDead end
function Combat.reset() Combat.start() end

return Combat
