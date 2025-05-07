-- main.lua
local dialogue    = require "dialogue"
local currentLine = 1
local gameState   = "dialogue"  -- states: "dialogue", "fighting", "victory"

-- Wave system
local waves = {1, 2, 3, 4, 5, 5}  -- counts per wave
local currentWave = 0
local totalGodsDefeated = 0
local enemies = {}

-- Clamp helper
local function clamp(val, minv, maxv)
    return math.max(minv, math.min(maxv, val))
end

function love.load()
    love.window.setTitle("Hua Cheng vs Heavenly Officials")
    love.window.setMode(800, 600, {resizable = true})

    -- fonts
    fonts = {
        name = love.graphics.newFont(18),
        text = love.graphics.newFont(14),
        hint = love.graphics.newFont(12),
    }

    -- load assets
    assets = {
        bg        = love.graphics.newImage(dialogue.bg),
        portraits = {}
    }
    for _, entry in ipairs(dialogue.lines) do
        assets.portraits[entry.portrait] = love.graphics.newImage(entry.portrait)
    end

    -- Initialize player
    player = {
        x = 100, y = 300,
        width = 50, height = 50,
        speed = 200,
        health = 5,
        alive = true,
        attackDamage = 1,
        attackRange  = 60,
        attackCD     = 1,
        attackTimer  = 0,
    }

    -- Projectiles
    projectiles = {}
    projSpeed   = 500
    projCount   = 5
    projSpread  = math.rad(15)
end

function spawnWave()
    currentWave = currentWave + 1
    enemies = {}
    local numEnemies = waves[currentWave]
    for i = 1, numEnemies do
        table.insert(enemies, {
            x = math.random(100, 700),
            y = math.random(100, 500),
            width = 50,
            height = 50,
            speed = 80 + (currentWave * 20),
            health = 2 + (currentWave * 2),
            alive = true,
            attackDamage = 1,
            attackRange = 50,
            attackCD = 1.5,
            attackTimer = 0,
        })
    end
end

function love.update(dt)
    if gameState == "fighting" then
        local w, h = love.graphics.getDimensions()
        -- Player movement
        if player.alive then
            if love.keyboard.isDown("a") then player.x = player.x - player.speed * dt end
            if love.keyboard.isDown("d") then player.x = player.x + player.speed * dt end
            if love.keyboard.isDown("w") then player.y = player.y - player.speed * dt end
            if love.keyboard.isDown("s") then player.y = player.y + player.speed * dt end
            player.x = clamp(player.x, 0, w - player.width)
            player.y = clamp(player.y, 0, h - player.height)
        end
        -- Cooldowns
        player.attackTimer = math.max(0, player.attackTimer - dt)
        -- Enemy AI
        for _, e in ipairs(enemies) do
            if e.alive and player.alive then
                local dx, dy = player.x - e.x, player.y - e.y
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist > e.attackRange then
                    e.x = e.x + (dx/dist) * e.speed * dt
                    e.y = e.y + (dy/dist) * e.speed * dt
                elseif e.attackTimer <= 0 then
                    e.attackTimer = e.attackCD
                    player.health = player.health - e.attackDamage
                    if player.health <= 0 then player.alive = false end
                end
                e.attackTimer = math.max(0, e.attackTimer - dt)
            end
        end
        -- Projectiles
        local w, h = love.graphics.getDimensions()
        for i = #projectiles, 1, -1 do
            local p = projectiles[i]
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            local hit = false
            for _, e in ipairs(enemies) do
                if e.alive and p.x >= e.x and p.x <= e.x + e.width
                   and p.y >= e.y and p.y <= e.y + e.height then
                    e.health = e.health - player.attackDamage
                    if e.health <= 0 then
                        e.alive = false
                        totalGodsDefeated = totalGodsDefeated + 1
                    end
                    hit = true
                    break
                end
            end
            if hit or p.x < 0 or p.x > w or p.y < 0 or p.y > h then
                table.remove(projectiles, i)
            end
        end
        -- Wave complete?
        local allDead = true
        for _, e in ipairs(enemies) do
            if e.alive then allDead = false break end
        end
        if allDead then
            if currentWave < #waves then spawnWave() else gameState = "victory" end
        end
    end
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    if gameState == "dialogue" then
        -- Draw background
        local bw, bh = assets.bg:getDimensions()
        local scale = math.max(w/bw, h/bh)
        love.graphics.setColor(1,1,1)
        love.graphics.draw(assets.bg, (w-bw*scale)/2, (h-bh*scale)/2, 0, scale, scale)
        -- Dim overlay
        love.graphics.setColor(unpack(dialogue.overlayColor))
        love.graphics.rectangle("fill", 0, 0, w, h)
        -- Draw portrait
        local entry = dialogue.lines[currentLine]
        local img = assets.portraits[entry.portrait]
        local iw, ih = img:getDimensions()
        local scaleP = (h/ih) * 1.3
        love.graphics.setColor(1,1,1)
        love.graphics.draw(img, (w - iw*scaleP)/2, h/9, 0, scaleP, scaleP)
        -- Draw panel centered
        local p = dialogue.panel
        local panelX = (w - p.width) / 2
        local panelY = h - p.height - p.yOffset
        love.graphics.setColor(unpack(p.fillColor))
        love.graphics.rectangle("fill", panelX, panelY, p.width, p.height)
        love.graphics.setColor(unpack(p.borderColor))
        love.graphics.setLineWidth(p.borderWidth)
        love.graphics.rectangle("line", panelX, panelY, p.width, p.height)
        -- Render text
        love.graphics.setFont(fonts.name)
        love.graphics.setColor(1,0.85,0.6)
        love.graphics.printf(entry.name, panelX+20, panelY+10, p.width-40)
        love.graphics.setFont(fonts.text)
        love.graphics.setColor(1,1,1)
        love.graphics.printf(entry.text, panelX+20, panelY+40, p.width-40)
        -- Hint
        love.graphics.setFont(fonts.hint)
        love.graphics.setColor(1,1,1,0.6)
        love.graphics.printf("Press SPACE to continue", panelX + p.width - 160, panelY + p.height - 25, 150, "right")

    elseif gameState == "fighting" then
        -- Draw player
        love.graphics.setColor(player.alive and {0,1,0} or {0.4,0.4,0.4})
        love.graphics.rectangle("fill", player.x, player.y, player.width, player.height)
        love.graphics.setColor(1,1,1)
        love.graphics.print("HP: "..player.health, 10, 10)
        -- Draw enemies
        for _, e in ipairs(enemies) do
            if e.alive then
                love.graphics.setColor(1,0,0)
                love.graphics.rectangle("fill", e.x, e.y, e.width, e.height)
                love.graphics.setColor(1,1,1)
                love.graphics.print("HP: "..e.health, e.x, e.y-20)
            end
        end
        -- Draw projectiles
        love.graphics.setColor(1,1,0)
        for _, p in ipairs(projectiles) do love.graphics.circle("fill", p.x, p.y, 5) end
        -- UI
        love.graphics.setColor(1,1,1)
        love.graphics.print("Wave: "..currentWave.."/"..#waves, 10, 30)
        love.graphics.print("Defeated: "..totalGodsDefeated, 10, 50)

    elseif gameState == "victory" then
        love.graphics.setColor(1,1,1)
        love.graphics.printf("VICTORY! Defeated all "..totalGodsDefeated.." gods!", 0, h/2-20, w, "center")
    end
end

function love.keypressed(key)
    if gameState == "dialogue" and key == "space" then
        currentLine = currentLine + 1
        if currentLine > #dialogue.lines then
            gameState = "fighting"
            spawnWave()
        end
    elseif gameState == "fighting" and key == "space" and player.alive then
        local mx, my = love.mouse.getPosition()
        local w, h = love.graphics.getDimensions()
        player.x = clamp(mx - player.width/2, 0, w - player.width)
        player.y = clamp(my - player.height/2, 0, h - player.height)
    end
end

function love.mousepressed(x, y, button)
    if gameState == "fighting" then
        if button == 1 and player.attackTimer <= 0 then
            player.attackTimer = player.attackCD
            for _, e in ipairs(enemies) do
                if e.alive and math.abs(e.x - player.x) < player.attackRange
                   and math.abs(e.y - player.y) < player.attackRange then
                    e.health = e.health - player.attackDamage
                end
            end
        elseif button == 2 then
            local px, py = player.x + player.width/2, player.y + player.height/2
            for i = 1, projCount do
                local angle = math.atan2(y-py, x-px) + (math.random()-0.5)*projSpread
                table.insert(projectiles, { x=px, y=py,
                    vx=math.cos(angle)*projSpeed,
                    vy=math.sin(angle)*projSpeed })
            end
        end
    end
end
