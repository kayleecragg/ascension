-- combat.lua

local assets     = require("assets")
local util       = require("util")
local Player     = require("entities.player")
local TakeDamage = require("effects.takeDamage")
local Slash  = require("effects.Slash")
local BaseMeleeUnit = require("enemies.BaseMeleeUnit")

local Combat     = {}

local PADDING          = 20
local MESSAGE_DURATION = 2

-- On-screen message state
local message      = ""
local messageTimer = 0

-- Combat state
Combat.player      = {}
Combat.enemies     = {}
Combat.projectiles = {}
Combat.waves       = {1,2,3,4,5,5}
Combat.currentWave = 0
Combat.playerDead  = false
Combat.combatDone  = false

-- Projectile settings
Combat.projSpeed  = 500
Combat.projCount  = 5
Combat.projSpread = math.rad(15)

-- Helper: play short sound
local function playSound(src)
    if src then src:stop(); src:play() end
end

-- Draws cooldown icon
local function drawAbilityBox(x, y, size, timer, maxCD, label)
    love.graphics.setColor(0.2,0.2,0.2)
    love.graphics.rectangle("fill", x, y, size, size)
    if timer>0 then
        local pct = timer/maxCD
        love.graphics.setColor(0,0,0,0.6)
        love.graphics.rectangle("fill", x, y + size*(1-pct), size, size*pct)
    end
    love.graphics.setColor(1,1,1)
    love.graphics.rectangle("line", x, y, size, size)
    love.graphics.printf(label, x, y+size+2, size, "center")
    if timer>0 then
        love.graphics.printf(string.format("%.1f",timer), x, y+size/2-6, size, "center")
    end
end

function Combat.start()
    -- Initialize player
    Combat.player = Player.new()

    -- Reset combat state
    Combat.enemies     = {}
    Combat.projectiles = {}
    BaseMeleeUnit.slashes = {} -- Reset slashes
    Combat.currentWave = 0
    Combat.playerDead  = false
    Combat.combatDone  = false
    message            = ""
    messageTimer       = 0

    -- Spawn first wave
    Combat.spawnWave()

    -- Play combat music at lower volume
    assets.music.combatTheme:setVolume(0.3)
    if not assets.music.combatTheme:isPlaying() then
        assets.music.combatTheme:play()
    end
end

function Combat.spawnWave()
    Combat.currentWave = Combat.currentWave + 1
    local count = Combat.waves[Combat.currentWave] or 0
    for i = 1, count do
        -- Create enemies as BaseMeleeUnit instances
        local enemy = BaseMeleeUnit:new(
            math.random(100,700),  -- x
            math.random(100,500),  -- y
            50,                    -- width
            50,                    -- height
            2 + Combat.currentWave*2, -- health
            2 + Combat.currentWave*2, -- maxHealth
            80 + Combat.currentWave*20, -- speed
            120 + Combat.currentWave*20, -- maxSpeed
            1,                     -- attackDamage
            50,                    -- attackRange
            1.5,                   -- attackCD
            0                      -- attackTimer
        )
        table.insert(Combat.enemies, enemy)
    end
end

function Combat.update(dt)
    if Combat.playerDead or Combat.combatDone then return end
    local w,h = love.graphics.getDimensions()

    -- Update damage flash
    TakeDamage.update(dt)

    -- Player movement
    if Combat.player.alive then
        if love.keyboard.isDown("a") then Combat.player.x = Combat.player.x - Combat.player.speed*dt end
        if love.keyboard.isDown("d") then Combat.player.x = Combat.player.x + Combat.player.speed*dt end
        if love.keyboard.isDown("w") then Combat.player.y = Combat.player.y - Combat.player.speed*dt end
        if love.keyboard.isDown("s") then Combat.player.y = Combat.player.y + Combat.player.speed*dt end
        Combat.player.x = util.clamp(Combat.player.x, PADDING, w-Combat.player.width-PADDING)
        Combat.player.y = util.clamp(Combat.player.y, PADDING, h-Combat.player.height-PADDING)
    end

    -- Cooldowns
    Combat.player.attackTimer   = math.max(0, Combat.player.attackTimer - dt)
    Combat.player.rangedTimer   = math.max(0, Combat.player.rangedTimer - dt)
    Combat.player.teleportTimer = math.max(0, Combat.player.teleportTimer - dt)

    -- Enemy AI & Attacks using BaseMeleeUnit class
    for _, e in ipairs(Combat.enemies) do
        if e.alive and Combat.player.alive then
            e:update(dt, Combat.player)
        end
    end

    -- Update slashes and check for collisions
    for i = #BaseMeleeUnit.slashes, 1, -1 do
        local s = BaseMeleeUnit.slashes[i]
        s:update(dt)
        
        -- Apply damage at the right moment if slash hasn't hit yet
        if not s.hasHit and (s.timer / s.duration) >= s.damageTime then
            if s.isEnemy then
                -- Enemy slash hitting player
                if Combat.player.alive then
                    -- Calculate distance to player center
                    local px = Combat.player.x + Combat.player.width/2
                    local py = Combat.player.y + Combat.player.height/2
                    local dist = math.sqrt((s.x - px)^2 + (s.y - py)^2)
                    
                    -- Check if close enough to hit
                    if dist < s.width/2 + Combat.player.width/2 then
                        Combat.player.health = Combat.player.health - s.damage
                        playSound(assets.sfx.playerHit)
                        s.hasHit = true
                        
                        if Combat.player.health <= 0 then
                            Combat.playerDead = true
                            message = "You died!"
                            messageTimer = MESSAGE_DURATION
                            assets.music.combatTheme:stop()
                        end
                    end
                end
            else
                -- Player slash hitting enemies
                for _, e in ipairs(Combat.enemies) do
                    if e.alive then
                        -- Calculate distance to enemy center
                        local ex = e.x + e.width/2
                        local ey = e.y + e.height/2
                        local dist = math.sqrt((s.x - ex)^2 + (s.y - ey)^2)
                        
                        if dist < s.width/2 + e.width/2 then
                            e:take_damage(s.damage)
                            playSound(assets.sfx.enemyHit)
                            s.hasHit = true
                            
                            if not e.alive then
                                playSound(assets.sfx.enemyDeath)
                            end
                            break
                        end
                    end
                end
            end
        end
        
        -- Remove inactive slashes
        if not s.active then
            table.remove(BaseMeleeUnit.slashes, i)
        end
    end

    -- Projectiles
    for i = #Combat.projectiles,1,-1 do
        local p = Combat.projectiles[i]
        p.x = p.x + p.dx * p.speed * dt
        p.y = p.y + p.dy * p.speed * dt
        local hit = false
        for _, e in ipairs(Combat.enemies) do
            if e.alive 
              and p.x > e.x and p.x < e.x + e.width 
              and p.y > e.y and p.y < e.y + e.height then
                e:take_damage(p.damage)
                playSound(assets.sfx.enemyHit)
                if not e.alive then
                    playSound(assets.sfx.enemyDeath)
                end
                hit = true
                break
            end
        end
        if hit or p.x<0 or p.x>w or p.y<0 or p.y>h then table.remove(Combat.projectiles,i) end
    end

    -- Wave completion
    local allDead = true
    for _, e in ipairs(Combat.enemies) do if e.alive then allDead=false; break end end
    if allDead then
        if Combat.currentWave<#Combat.waves then Combat.spawnWave()
        else message="Victory!"; messageTimer=MESSAGE_DURATION; Combat.combatDone=true; assets.music.combatTheme:stop() end
    end

    -- Message timer
    if messageTimer>0 then messageTimer=messageTimer-dt; if messageTimer<=0 then message="" end end
end

function Combat.draw()
    local w,h = love.graphics.getDimensions()

    -- Draw player
    love.graphics.setColor(Combat.player.alive and {1,0,0} or {0.4,0.4,0.4})
    love.graphics.rectangle("fill", Combat.player.x, Combat.player.y, Combat.player.width, Combat.player.height)
    -- Health bar
    local ratio = util.clamp(Combat.player.health/Combat.player.maxHealth,0,1)
    love.graphics.setColor(0,0,0); love.graphics.rectangle("fill", Combat.player.x, Combat.player.y-8, Combat.player.width,5)
    love.graphics.setColor(0,1,0); love.graphics.rectangle("fill", Combat.player.x, Combat.player.y-8, Combat.player.width*ratio,5)
    love.graphics.setColor(1,1,1)
    love.graphics.print("HP:"..Combat.player.health.."/"..Combat.player.maxHealth, PADDING,10)
    love.graphics.print("Wave:"..Combat.currentWave.."/"..#Combat.waves, PADDING,30)

    -- Draw enemies & their bars
    for _, e in ipairs(Combat.enemies) do
        if e.alive then
            love.graphics.setColor(1,1,0); love.graphics.rectangle("fill", e.x,e.y,e.width,e.height)
            local eRatio=util.clamp(e.health/e.maxHealth,0,1)
            love.graphics.setColor(0,0,0); love.graphics.rectangle("fill", e.x,e.y-8,e.width,5)
            love.graphics.setColor(0,1,0); love.graphics.rectangle("fill", e.x,e.y-8,e.width*eRatio,5)
        end
    end
    
    -- Draw slashes
    for _, s in ipairs(BaseMeleeUnit.slashes) do
        s:draw()
    end

    -- Draw projectiles
    for _, p in ipairs(Combat.projectiles) do
        love.graphics.setColor(0.75,0.75,0.75)
        love.graphics.circle("fill", p.x, p.y, 5)
    end

    -- Ability HUD
    local bs,by=48,h-48-PADDING
drawAbilityBox(PADDING,      by,bs,Combat.player.teleportTimer,Combat.player.teleportCD,"SPACE")
drawAbilityBox(PADDING+bs+PADDING,by,bs,Combat.player.rangedTimer,Combat.player.rangedCD,"RMB")

    -- Damage flash overlay
    TakeDamage.draw(w,h)

    -- Event message
    if message~="" then love.graphics.setColor(1,1,1); love.graphics.printf(message,0,h-30,w,"center") end
end

function Combat.keypressed(key)
    if key=="space" and Combat.player.alive then
        if Combat.player.teleportTimer>0 then playSound(assets.sfx.abilityCooldown); message="Ability on cooldown!"; messageTimer=MESSAGE_DURATION; return end
        local mx,my=love.mouse.getPosition(); local w,h=love.graphics.getDimensions()
        Combat.player.x=util.clamp(mx-Combat.player.width/2,PADDING,w-Combat.player.width-PADDING)
        Combat.player.y=util.clamp(my-Combat.player.height/2,PADDING,h-Combat.player.height-PADDING)
        Combat.player.teleportTimer=Combat.player.teleportCD
        playSound(assets.sfx.teleport); message="Teleported!"; messageTimer=MESSAGE_DURATION
    end
end

function Combat.mousepressed(x, y, button)
    local px = Combat.player.x + Combat.player.width/2
    local py = Combat.player.y + Combat.player.height/2

    if button == 1 and Combat.player.attackTimer <= 0 and Combat.player.alive then
        -- Create player slash toward mouse position
        local slash = Slash:new(
            px, py, x, y, 
            Combat.player.attackDamage, 
            0.4, 
            Combat.player.attackRange
        )
        slash.isEnemy = false  -- This is a player slash
        table.insert(BaseMeleeUnit.slashes, slash)
        
        Combat.player.attackTimer = Combat.player.attackCD
        playSound(assets.sfx.playerMelee)
        message = "Melee Attack!"
        messageTimer = MESSAGE_DURATION

    elseif button == 2 and Combat.player.alive then
        -- Ranged
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