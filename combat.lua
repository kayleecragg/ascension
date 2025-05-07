local assets = require("assets")
local util   = require("util")
local Combat = {}

Combat.player     = {}
Combat.enemies    = {}
Combat.projectiles= {}
Combat.waves      = {1,2,3,4,5,5}
Combat.currentWave = 0
Combat.playerDead = false
Combat.combatDone = false

Combat.projSpeed  = 500
Combat.projCount  = 5
Combat.projSpread = math.rad(15)

function Combat.start()
    Combat.player = {
        x            = 100, y = 300,
        width        = 50, height = 50,
        speed        = 200,
        health       = 5,
        alive        = true,
        attackDamage = 1,
        attackRange  = 60,
        attackCD     = 1,
        attackTimer  = 0,
        rangedCD     = 2,
        rangedTimer  = 0,
        rangedDamage = 2,
    }
    Combat.enemies     = {}
    Combat.projectiles = {}
    Combat.currentWave = 0
    Combat.playerDead  = false
    Combat.combatDone  = false
    Combat.spawnWave()
end

function Combat.spawnWave()
    Combat.currentWave = Combat.currentWave + 1
    local count = Combat.waves[Combat.currentWave] or 0
    for i = 1, count do
        table.insert(Combat.enemies, {
            x           = math.random(100,700),
            y           = math.random(100,500),
            width       = 50, height = 50,
            speed       = 80 + Combat.currentWave*20,
            health      = 2 + Combat.currentWave*2,
            alive       = true,
            attackDamage= 1,
            attackRange = 50,
            attackCD    = 1.5,
            attackTimer = 0,
            maxHealth   = 2 + Combat.currentWave*2,
        })
    end
end

function Combat.update(dt)
    if Combat.playerDead or Combat.combatDone then return end

    local w,h = love.graphics.getDimensions()

    -- Player movement
    if Combat.player.alive then
        if love.keyboard.isDown("a") then Combat.player.x = Combat.player.x - Combat.player.speed*dt end
        if love.keyboard.isDown("d") then Combat.player.x = Combat.player.x + Combat.player.speed*dt end
        if love.keyboard.isDown("w") then Combat.player.y = Combat.player.y - Combat.player.speed*dt end
        if love.keyboard.isDown("s") then Combat.player.y = Combat.player.y + Combat.player.speed*dt end
        Combat.player.x = util.clamp(Combat.player.x, 0, w - Combat.player.width)
        Combat.player.y = util.clamp(Combat.player.y, 0, h - Combat.player.height)
    end

    -- Cooldowns
    Combat.player.attackTimer = math.max(0, Combat.player.attackTimer - dt)
    Combat.player.rangedTimer = math.max(0, Combat.player.rangedTimer - dt)
    -- Combat.player.rangedTimer = 0

    -- Enemy AI
    for _, e in ipairs(Combat.enemies) do
        if e.alive and Combat.player.alive then
            local dx,dy = Combat.player.x - e.x, Combat.player.y - e.y
            local dist   = math.sqrt(dx*dx + dy*dy)
            if dist > e.attackRange then
                e.x = e.x + (dx/dist)*e.speed*dt
                e.y = e.y + (dy/dist)*e.speed*dt
            elseif e.attackTimer <= 0 then
                e.attackTimer = e.attackCD
                Combat.player.health = Combat.player.health - e.attackDamage
                if Combat.player.health <= 0 then
                    Combat.playerDead = true
                end
            end
            e.attackTimer = math.max(0, e.attackTimer - dt)
        end
    end

    -- Projectiles
    for i = #Combat.projectiles, 1, -1 do
        local p = Combat.projectiles[i]
        p.x = p.x + p.dx * p.speed * dt
        p.y = p.y + p.dy * p.speed * dt

        local hit = false
        for _, e in ipairs(Combat.enemies) do
            if e.alive and
               p.x > e.x and p.x < e.x + e.width and
               p.y > e.y and p.y < e.y + e.height then
                e.health = e.health - p.damage
                if e.health <= 0 then e.alive = false end
                hit = true
                break
            end
        end

        if hit or p.x < 0 or p.x > w or p.y < 0 or p.y > h then
            table.remove(Combat.projectiles, i)
        end
    end

    -- Check wave completion
    if not Combat.playerDead then
        local allDead = true
        for _, e in ipairs(Combat.enemies) do
            if e.alive then allDead = false break end
        end
        if allDead then
            if Combat.currentWave < #Combat.waves then
                Combat.spawnWave()
            else
                Combat.combatDone = true
            end
        end
    end
end

function Combat.draw()
    -- Draw player
    love.graphics.setColor(Combat.player.alive and {1,0,0} or {0.4,0.4,0.4})
    love.graphics.rectangle("fill", Combat.player.x, Combat.player.y,
                            Combat.player.width, Combat.player.height)

    -- Player health bar
    love.graphics.setColor(0,0,0)
    love.graphics.rectangle("fill", Combat.player.x, Combat.player.y - 8, Combat.player.width, 5)
    love.graphics.setColor(0,1,0)
    love.graphics.rectangle("fill", Combat.player.x, Combat.player.y - 8,
        Combat.player.width * (Combat.player.health / 5), 5)

    love.graphics.setColor(1,1,1)
    love.graphics.print("HP: "..Combat.player.health, 10, 10)

    -- Draw enemies
    for _, e in ipairs(Combat.enemies) do
        if e.alive then
            love.graphics.setColor(1,1,0) -- yellow
            love.graphics.rectangle("fill", e.x, e.y, e.width, e.height)

            -- Health bar
            love.graphics.setColor(0,0,0)
            love.graphics.rectangle("fill", e.x, e.y - 8, e.width, 5)
            love.graphics.setColor(0,1,0)
            love.graphics.rectangle("fill", e.x, e.y - 8,
                e.width * (e.health / e.maxHealth), 5)
        end
    end

    -- Draw projectiles
    for _, p in ipairs(Combat.projectiles) do
        love.graphics.setColor(0.75, 0.75, 0.75) -- silver
        love.graphics.circle("fill", p.x, p.y, 5)
    end

    love.graphics.setColor(1,1,1)
    love.graphics.print("Wave: "..Combat.currentWave.."/"..#Combat.waves, 10, 30)
end

function Combat.keypressed(key)
    if key == "space" and Combat.player.alive then
        local mx, my = love.mouse.getPosition()
        local w, h = love.graphics.getDimensions()
        Combat.player.x = util.clamp(mx - Combat.player.width / 2, 0, w - Combat.player.width)
        Combat.player.y = util.clamp(my - Combat.player.height / 2, 0, h - Combat.player.height)
    end
end

function Combat.mousepressed(x, y, button)
    local px = Combat.player.x + Combat.player.width / 2
    local py = Combat.player.y + Combat.player.height / 2

    if button == 1 and Combat.player.attackTimer <= 0 then
        -- Melee attack
        for _, e in ipairs(Combat.enemies) do
            if e.alive then
                local dx = e.x + e.width/2 - px
                local dy = e.y + e.height/2 - py
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist <= Combat.player.attackRange then
                    e.health = e.health - Combat.player.attackDamage
                    if e.health <= 0 then e.alive = false end
                end
            end
        end
        Combat.player.attackTimer = Combat.player.attackCD

    elseif button == 2 and Combat.player.rangedTimer <= 0 then
        -- Ranged projectile burst
        local angle = math.atan2(y - py, x - px)
        for i = 1, Combat.projCount do
            local spread = angle + (i - (Combat.projCount+1)/2) * Combat.projSpread
            local dx = math.cos(spread)
            local dy = math.sin(spread)
            table.insert(Combat.projectiles, {
                x = px, y = py,
                dx = dx, dy = dy,
                speed = Combat.projSpeed,
                damage = Combat.player.rangedDamage,
            })
        end
        Combat.player.rangedTimer = Combat.player.rangedCD
    end
end

function Combat.isDone()  return Combat.combatDone end
function Combat.isDead()  return Combat.playerDead end
function Combat.reset()   Combat.start()           end

return Combat
