local assets   = require("assets")
local dialogue = require("dialogue")
local combat   = require("combat")
local debate   = require("debate")
local util     = require("util")

local currentState = "intro"

local dissolveShader = love.graphics.newShader("resources/shaders/dissolve.fs")
local dissolveTimer = 0
local isDissolving = false
local dissolveCanvas

function love.load()
    love.graphics.setFont(assets.dialogueFont)
    dialogue.start(dialogue.introLines)

    local w, h = love.graphics.getDimensions()
    dissolveCanvas = love.graphics.newCanvas(w, h)
end

function love.resize(w, h)
    dissolveCanvas = love.graphics.newCanvas(w, h)
end

function love.update(dt)
    if isDissolving then
        dissolveTimer = dissolveTimer + dt
        if dissolveTimer >= 1 then
            currentState = "combat"
            combat.start()
            isDissolving = false
        end
    elseif currentState == "combat" then
        combat.update(dt)
        if combat.isDead() then
            currentState = "death"
        elseif combat.isDone() then
            currentState = "mid"
            dialogue.start(dialogue.midLines)
        end
    elseif currentState == "debate" then
        debate.update(dt)
    end

    if currentState == "intro" or currentState == "mid" then
        dialogue.update(dt)
    end
end

function love.draw()
    -- Step 1: draw scene to canvas
    love.graphics.setCanvas(dissolveCanvas)
    love.graphics.clear(0, 0, 0, 1)

    if currentState == "intro" or currentState == "mid" then
        dialogue.draw()
    elseif currentState == "combat" then
        combat.draw()
    elseif currentState == "debate" then
        debate.draw()
    elseif currentState == "death" then
        love.graphics.setFont(assets.bigFont)
        love.graphics.printf("YOU DIED", 0, love.graphics.getHeight()/2, love.graphics.getWidth(), "center")
    elseif currentState == "victory" then
        love.graphics.setFont(assets.bigFont)
        love.graphics.printf("VICTORY!", 0, love.graphics.getHeight()/2, love.graphics.getWidth(), "center")
    end

    love.graphics.setCanvas()

    -- Step 2: apply dissolve shader if needed
    if isDissolving then
        local w, h = love.graphics.getDimensions()
        dissolveShader:send("dissolve", dissolveTimer)
        dissolveShader:send("time", love.timer.getTime())
        dissolveShader:send("shadow", false)
        dissolveShader:send("burn_colour_1", {1, 0.3, 0.3, 1})
        dissolveShader:send("burn_colour_2", {1, 1, 0.4, 1})
        dissolveShader:send("hovering", 0)
        dissolveShader:send("mouse_screen_pos", {0, 0})

        love.graphics.setShader(dissolveShader)
    end

    -- Step 3: draw the canvas to the screen (shader will apply here)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(dissolveCanvas, 0, 0)

    if isDissolving then
        love.graphics.setShader()
    end
end

function love.keypressed(key)
    if currentState == "intro" or currentState == "mid" then
        if key == "space" then
            local done = dialogue.nextLine()
            if done then
                if currentState == "intro" then
                    isDissolving = true
                    dissolveTimer = 0
                else
                    currentState = "debate"
                    debate.start()
                end
            end
        end
    elseif currentState == "combat" then
        combat.keypressed(key)
    elseif currentState == "debate" then
        if key == "space" then
            currentState = "victory"
        end
    elseif currentState == "death" or currentState == "victory" then
        if key == "space" then
            combat.reset()
            dialogue.start(dialogue.introLines)
            currentState = "intro"
        end
    end
end

function love.mousepressed(x, y, button)
    if currentState == "combat" then
        combat.mousepressed(x, y, button)
    end
end
