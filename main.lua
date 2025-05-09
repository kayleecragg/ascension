-- main.lua

local assets   = require("assets")
local dialogue = require("dialogue")
local combat   = require("combat")
local debate   = require("debate")
local util     = require("util")
local settings = require("settings")
local Fade     = require("effects.fade")

-- debug-based script path setup
local scriptPath = debug.getinfo(1).source:match("@?(.*/)") or "./"
package.path = package.path .. ";"
             .. scriptPath .. "?.lua;"
             .. scriptPath .. "entities/?.lua;"
             .. scriptPath .. "effects/?.lua;"

-- state tracking
local currentState  = "intro"
local previousState

function love.load()
    love.graphics.setFont(assets.dialogueFont)
    settings.apply()
    dialogue.start(dialogue.introLines)
end

function love.update(dt)
    Fade.update(dt)
    if Fade.state ~= "none" then return end

    if currentState == "combat" then
        combat.update(dt)
        if combat.isDead() then
            Fade.start("death", function()
                currentState = "death"
            end)
        elseif combat.isDone() then
            Fade.start("mid", function()
                currentState = "mid"
                dialogue.start(dialogue.midLines)
            end)
        end

    elseif currentState == "debate" then
        debate.update(dt)

    elseif currentState == "intro" or currentState == "mid" then
        dialogue.update(dt)

    elseif currentState == "instructions" then
        -- no update logic for static screen
    end
end

function love.draw()
    if currentState == "intro" or currentState == "mid" then
        dialogue.draw()

    elseif currentState == "instructions" then
        love.graphics.setFont(assets.dialogueFont)
        local w, h = love.graphics.getDimensions()
        love.graphics.printf("INSTRUCTIONS:\n\n- Move: W A S D\n- Dodge: Left Shift\n- Melee Attack: Left Click\n- Ranged Attack: Right Click\n- Teleport: Space (then click)\n\nPress SPACE to begin combat.",
            0, h * 0.2, w, "center")

    elseif currentState == "combat" then
        combat.draw()

    elseif currentState == "debate" then
        debate.draw()

    elseif currentState == "death" then
        love.graphics.setFont(assets.bigFont)
        love.graphics.printf("YOU DIED",
            0, love.graphics.getHeight()/2,
            love.graphics.getWidth(), "center")

    elseif currentState == "victory" then
        love.graphics.setFont(assets.bigFont)
        love.graphics.printf("VICTORY!",
            0, love.graphics.getHeight()/2,
            love.graphics.getWidth(), "center")

    elseif currentState == "settings" then
        settings.draw()
    end

    -- fade overlay always on top
    local w,h = love.graphics.getDimensions()
    Fade.draw(w, h)
end

function love.keypressed(key)
    -- toggle settings
    if key == "escape" then
        if currentState == "settings" then
            Fade.start(previousState or "intro", function()
                currentState = previousState or "intro"
            end)
        else
            previousState = currentState
            Fade.start("settings", function()
                currentState = "settings"
            end)
        end
        return
    end

    if Fade.state ~= "none" then return end

    if currentState == "settings" then
        settings.keypressed(key)
        return
    end

    -- Dialogue input
    if currentState == "intro" or currentState == "mid" then
        if key == "space" then
            local done = dialogue.nextLine()
            if done then
                if currentState == "intro" then
                    Fade.start("instructions", function()
                        currentState = "instructions"
                    end)
                else
                    Fade.start("debate", function()
                        currentState = "debate"
                        debate.start()
                    end)
                end
            end
        end

    -- Instructions input
    elseif currentState == "instructions" then
        if key == "space" then
            Fade.start("combat", function()
                currentState = "combat"
                combat.start()
            end)
        end

    -- Combat input
    elseif currentState == "combat" then
        combat.keypressed(key)

    -- Debate input
    elseif currentState == "debate" then
        if key == "space" then
            Fade.start("victory", function()
                currentState = "victory"
            end)
        end

    -- Death or Victory reset
    elseif currentState == "death" or currentState == "victory" then
        if key == "space" then
            Fade.start("intro", function()
                combat.reset()
                dialogue.start(dialogue.introLines)
                currentState = "intro"
            end)
        end
    end
end

function love.mousepressed(x, y, button)
    if currentState == "combat" and Fade.state == "none" then
        combat.mousepressed(x, y, button)
    end
end
