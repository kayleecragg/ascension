-- combat.lua
local assets        = require("assets")
local util          = require("util")
local Player        = require("entities.Player")
local Enemy         = require("entities.Enemy")
local TakeDamage    = require("effects.takeDamage")
local BaseMeleeUnit = require("entities.BaseMeleeUnit")
local RangedUnit    = require("entities.RangedUnit")
local Orb           = require("effects.Orb")

local Combat = {}

-- constants
local PADDING          = 40
local MESSAGE_DURATION = 2

-- message state
local message      = ""
local messageTimer = 0

-- combat state
Combat.player        = nil
Combat.enemies       = {}
Combat.projectiles   = {}
Combat.currentWave   = 0
Combat.playerDead    = false
Combat.combatDone    = false

-- helper to play sounds
local function playSound(src)
    if src then src:stop(); src:play() end
end

function Combat.start()
    Combat.player           = Player.new()
    Combat.enemies          = {}
    Combat.projectiles      = {}
    Combat.orbs             = {}
    BaseMeleeUnit.slashes   = {}
    RangedUnit.beams        = {}
    Combat.currentWave      = 0
    Combat.playerDead       = false
    Combat.combatDone       = false
    message                 = ""
    messageTimer            = 0

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
        local opts1 = {"base","ranged","charge"}
        local opts2 = {"charge","ranged"}
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

function Combat.killPlayer()
    if Combat.player and Combat.player.alive then
        Combat.player.alive  = false
        Combat.playerDead    = true
        message              = "You died!"
        messageTimer         = MESSAGE_DURATION
        assets.music.combatTheme:stop()
        if assets.music.deathTheme then assets.music.deathTheme:play() end
    end
end

function Combat.update(dt)
    if Combat.playerDead or Combat.combatDone then return end
    local w,h = love.graphics.getDimensions()
    TakeDamage.update(dt)

    -- update player
    Combat.player:update(dt)

    -- enemy AI
    for _, e in ipairs(Combat.enemies) do
        if e.alive and Combat.player.alive then
            e:update(dt, Combat.player)
        end
    end

    -- melee slashes
    for i = #BaseMeleeUnit.slashes, 1, -1 do
        local s = BaseMeleeUnit.slashes[i]
        s:update(dt)
        if (s.timer / s.duration) >= s.damageTime then
            if s.isEnemy and Combat.player.alive then
                local px,py = Combat.player.x + Combat.player.width/2, Combat.player.y + Combat.player.height/2
                local dist = math.sqrt((s.x-px)^2 + (s.y-py)^2)
                if dist < s.width/2 + Combat.player.width/2 then
                    Combat.player.health = Combat.player.health - s.damage
                    TakeDamage.start()
                    playSound(assets.sfx.playerHit)
                    if Combat.player.health <= 0 then
                        Combat.killPlayer()
                    end
                end
            elseif not s.isEnemy then
                for _, e2 in ipairs(Combat.enemies) do
                    if e2.alive then
                        local ex,ey = e2.x + e2.width/2, e2.y + e2.height/2
                        local dist = math.sqrt((s.x-ex)^2 + (s.y-ey)^2)
                        if dist < s.width/2 + e2.width/2 then
                            e2:take_damage(s.damage)
                            playSound(assets.sfx.enemyHit)

                            -- DROP HEALTH ORB CHANCE
                            if not e2.alive then
                                playSound(assets.sfx.enemyDeath)
                                local dropChance = Enemy.getDropChance(e2)
                                if math.random() < dropChance then
                                    table.insert(Combat.orbs, Orb.new(e2.x + e2.width / 2, e2.y + e2.height / 2))
                                end
                            end
                        end
                    end
                end
            end
        end
        if not s.active then table.remove(BaseMeleeUnit.slashes, i) end
    end

    -- ranged beams (enemy)
    for i = #RangedUnit.beams, 1, -1 do
        local beam = RangedUnit.beams[i]
        beam.timer = beam.timer + dt

        -- move beam
        beam.x = beam.x + beam.dirX * beam.speed * dt
        beam.y = beam.y + beam.dirY * beam.speed * dt

        -- collision with player
        if Combat.player.alive then
            local px,py = Combat.player.x + Combat.player.width/2, Combat.player.y + Combat.player.height/2
            local ex,ey = beam.x - beam.dirX*beam.length, beam.y - beam.dirY*beam.length
            local vx,vy = px - beam.x, py - beam.y
            local wx,wy = ex - beam.x, ey - beam.y
            local dot   = vx*wx + vy*wy
            local lenSq = wx*wx + wy*wy
            local t     = (lenSq == 0) and -1 or (dot / lenSq)
            local cx,cy
            if t < 0    then cx,cy = beam.x, beam.y
            elseif t > 1 then cx,cy = ex, ey
            else             cx,cy = beam.x + t*wx, beam.y + t*wy end
            local dx,dy = px - cx, py - cy
            if math.sqrt(dx*dx + dy*dy) < (Combat.player.width/2 + beam.width/2) then
                Combat.player.health = Combat.player.health - beam.damage
                TakeDamage.start()
                playSound(assets.sfx.playerHit)
                if Combat.player.health <= 0 then
                    Combat.killPlayer()
                end
            end
        end

        -- beam lifetime / off-screen
        if beam.timer >= beam.lifetime then
            table.remove(RangedUnit.beams, i)
        end
    end

    -- projectiles (player)
    for i = #Combat.projectiles, 1, -1 do
        local p = Combat.projectiles[i]
        p.x = p.x + p.dx * p.speed * dt
        p.y = p.y + p.dy * p.speed * dt
        local hit = false
        for _, e in ipairs(Combat.enemies) do
            if e.alive
            and p.x > e.x and p.x < e.x+e.width
            and p.y > e.y and p.y < e.y+e.height
            then
                e:take_damage(p.damage)
                playSound(assets.sfx.enemyHit)
                if not e.alive then playSound(assets.sfx.enemyDeath) end
                hit = true
                break
            end
        end
        if hit or p.x < 0 or p.x > w or p.y < 0 or p.y > h then
            table.remove(Combat.projectiles, i)
        end
    end

    -- wave completion
    local allDead = true
    for _, e in ipairs(Combat.enemies) do
        if e.alive then allDead = false; break end
    end
    if allDead then
        if Combat.currentWave < #Enemy.spawnRates.waves then
            Combat.spawnWave()
        else
            message           = "Victory!"
            Combat.combatDone = true
            messageTimer      = MESSAGE_DURATION
            assets.music.combatTheme:stop()
        end
    end

    -- message timer
    if messageTimer > 0 then
        messageTimer = messageTimer - dt
        if messageTimer <= 0 then message = "" end
    end

    for _, orb in ipairs(Combat.orbs) do
        orb:update(dt)
        orb:checkCollected(Combat.player)
    end
end

function Combat.draw()
    local w,h = love.graphics.getDimensions()

    -- draw player
    Combat.player:draw()

    -- draw enemies & health bars
    for _, e in ipairs(Combat.enemies) do
        if e.alive then
            e:draw()
            local pct = util.clamp(e.health / e.maxHealth, 0, 1)
            love.graphics.setColor(0,0,0)
            love.graphics.rectangle("fill", e.x, e.y-8, e.width, 5)
            love.graphics.setColor(0,1,0)
            love.graphics.rectangle("fill", e.x, e.y-8, e.width * pct, 5)
        end
    end

    -- draw slashes
    for _, s in ipairs(BaseMeleeUnit.slashes) do s:draw() end

    -- draw projectiles
    for _, p in ipairs(Combat.projectiles) do
        love.graphics.setColor(0.75,0.75,0.75)
        love.graphics.circle("fill", p.x, p.y, 5)
    end

    -- draw enemy beams
    for _, beam in ipairs(RangedUnit.beams) do
        -- beam particles
        for _, p in ipairs(beam.particles) do
            love.graphics.setColor(p.color)
            love.graphics.circle("fill", p.x, p.y, p.size)
        end
        -- main beam
        local endX = beam.x - beam.dirX * beam.length
        local endY = beam.y - beam.dirY * beam.length
        love.graphics.setColor(0.4,0.8,1,0.8)
        love.graphics.setLineWidth(beam.width)
        love.graphics.line(beam.x, beam.y, endX, endY)
        love.graphics.setColor(1,1,1,0.9)
        love.graphics.setLineWidth(beam.width * 0.4)
        love.graphics.line(beam.x, beam.y, endX, endY)
        love.graphics.setLineWidth(1)
    end

    -- draw orbs
    for _, orb in ipairs(Combat.orbs) do
        if not orb.collected then
            orb:draw()
        end
    end

    -- HUD: HP and Wave
    love.graphics.setColor(1,1,1)
    love.graphics.print("HP: " .. math.floor(Combat.player.health) .. "/" .. Combat.player.maxHealth, PADDING, 10)
    love.graphics.print("Wave: " .. Combat.currentWave .. "/" .. #Enemy.spawnRates.waves, PADDING, 30)

    -- draw damage flash
    if Combat.player and Combat.player.alive and not Combat.playerDead then
        TakeDamage.draw(w, h)
    end

    -- draw messages
    if message ~= "" then
        love.graphics.printf(message, 0, h-30, w, "center")
    end
end

function Combat.keypressed(key)
    -- dodge
    if key == "lshift" then
        if Combat.player:startDodge() then
            playSound(assets.sfx.teleport)
            message = "Dodged!"
        else
            playSound(assets.sfx.abilityCooldown)
            message = "Dodge on cooldown!"
        end
        messageTimer = MESSAGE_DURATION

    -- teleport
    elseif key == "space" then
        if Combat.player.teleportAiming then return end
        if Combat.player:startTeleport() then
            message = "Click to teleport"
        else
            message = "Ability on cooldown!"
        end
        playSound(assets.sfx.abilityCooldown)
        messageTimer = MESSAGE_DURATION
    end
end

function Combat.mousepressed(x, y, button)
    -- complete teleport
    if Combat.player.teleportAiming and button == 1 then
        if Combat.player:completeTeleport(x, y) then
            playSound(assets.sfx.teleport)
            message = "Teleported!"
        end
        messageTimer = MESSAGE_DURATION
        return
    end

    -- melee / ranged
    if button == 1 then
        if Combat.player:meleeAttack(x, y) then
            playSound(assets.sfx.playerMelee)
            message = "Melee Attack!"
        else
            playSound(assets.sfx.abilityCooldown)
            message = "Ability on cooldown!"
        end
        messageTimer = MESSAGE_DURATION

    elseif button == 2 then
        local bullets = Combat.player:rangedAttack(x, y)
        if bullets then
            for _, b in ipairs(bullets) do
                table.insert(Combat.projectiles, b)
            end
            if assets.sfx.playerRanged then assets.sfx.playerRanged:clone():play() end
            message = "Ranged Attack!"
        else
            playSound(assets.sfx.abilityCooldown)
            message = "Ability on cooldown!"
        end
        messageTimer = MESSAGE_DURATION
    end
end

function Combat.isDone() return Combat.combatDone end
function Combat.isDead() return Combat.playerDead end
function Combat.reset()
    Combat.player        = nil
    Combat.enemies       = {}
    Combat.projectiles   = {}
    Combat.orbs          = {}
    Combat.currentWave   = 0
    Combat.playerDead    = false
    Combat.combatDone    = false
end

return Combat
