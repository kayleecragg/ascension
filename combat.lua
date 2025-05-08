-- combat.lua

local assets     = require("assets")
local util       = require("util")
local Player     = require("entities.player")
local TakeDamage = require("effects.takeDamage")
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
    for i=1,count do
        table.insert(Combat.enemies, {
            x = math.random(100,700), y = math.random(100,500),
            width = 50, height = 50,
            speed = 80 + Combat.currentWave*20,
            health = 2 + Combat.currentWave*2,
            maxHealth = 2 + Combat.currentWave*2,
            alive = true,
            attackDamage = 1,
            attackRange  = 50,
            attackCD     = 1.5,
            attackTimer  = 0,
        })
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

    -- Enemy AI & Attacks
    for _, e in ipairs(Combat.enemies) do
        if e.alive and Combat.player.alive then
            local dx,dy = Combat.player.x - e.x, Combat.player.y - e.y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist > e.attackRange then
                e.x = e.x + (dx/dist)*e.speed*dt
                e.y = e.y + (dy/dist)*e.speed*dt
            elseif e.attackTimer <= 0 then
                e.attackTimer = e.attackCD
                Combat.player.health = Combat.player.health - e.attackDamage
                TakeDamage.start()  -- flash on damage
                playSound(assets.sfx.enemyAttack)
                playSound(assets.sfx.playerHit)
                if Combat.player.health <= 0 then
                    Combat.playerDead = true
                    message = "You died!"
                    messageTimer = MESSAGE_DURATION
                    assets.music.combatTheme:stop()
                end
            end
            e.attackTimer = math.max(0, e.attackTimer - dt)
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
               and p.x>e.x and p.x<e.x+e.width
               and p.y>e.y and p.y<e.y+e.height then
                e.health = e.health - p.damage
                playSound(assets.sfx.enemyHit)
                if e.health <= 0 then e.alive=false; playSound(assets.sfx.enemyDeath) end
                hit=true; break
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
    -- Projectiles
    for _, p in ipairs(Combat.projectiles) do love.graphics.setColor(0.75,0.75,0.75); love.graphics.circle("fill",p.x,p.y,5) end

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

function Combat.mousepressed(x,y,button)
    local px,py=Combat.player.x+Combat.player.width/2,Combat.player.y+Combat.player.height/2
    if button==1 and Combat.player.attackTimer<=0 then
        for _,e in ipairs(Combat.enemies) do
            if e.alive then local dx,dy=e.x+e.width/2-px,e.y+e.height/2-py
                if math.sqrt(dx*dx+dy*dy)<=Combat.player.attackRange then e.health=e.health-Combat.player.attackDamage; playSound(assets.sfx.enemyHit); if e.health<=0 then e.alive=false; playSound(assets.sfx.enemyDeath) end end
            end
        end
        Combat.player.attackTimer=Combat.player.attackCD; playSound(assets.sfx.playerMelee); message="Melee Attack!"; messageTimer=MESSAGE_DURATION
    elseif button==2 then
        if Combat.player.rangedTimer>0 then playSound(assets.sfx.abilityCooldown); message="Ability on cooldown!"; messageTimer=MESSAGE_DURATION; return end
        local ang=math.atan2(y-py,x-px)
        for i=1,Combat.projCount do local sp=ang+(i-(Combat.projCount+1)/2)*Combat.projSpread; table.insert(Combat.projectiles,{x=px,y=py,dx=math.cos(sp),dy=math.sin(sp),speed=Combat.projSpeed,damage=Combat.player.rangedDamage}) end
        Combat.player.rangedTimer=Combat.player.rangedCD; if assets.sfx.playerRanged then assets.sfx.playerRanged:clone():play() end; message="Ranged Attack!"; messageTimer=MESSAGE_DURATION
    end
end

function Combat.isDone() return Combat.combatDone end
function Combat.isDead() return Combat.playerDead end
function Combat.reset() Combat.start() end

return Combat