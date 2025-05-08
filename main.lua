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
             .. scriptPath .. "?.lua;"           -- current dir
             .. scriptPath .. "enemies/?.lua;"   -- enemies
             .. scriptPath .. "effects/?.lua;"   -- effects

-- state tracking
local currentState  = "intro"
local previousState

function love.load()
    love.graphics.setFont(assets.dialogueFont)
    settings.apply()
    dialogue.start(dialogue.introLines)
end

function love.update(dt)
    -- update fade
    Fade.update(dt)
    -- if mid-fade, skip state updates
    if Fade.state ~= "none" then return end

    -- handle state-specific updates
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
    end
end

function love.draw()
    -- draw based on current state
    if currentState == "intro" or currentState == "mid" then
        dialogue.draw()
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

    -- draw fade overlay on top
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

    -- ignore other input while fading
    if Fade.state ~= "none" then return end

    -- settings input
    if currentState == "settings" then
        settings.keypressed(key)
        return
    end

    -- dialogue input
    if currentState == "intro" or currentState == "mid" then
        if key == "space" then
            local done = dialogue.nextLine()
            if done then
                if currentState == "intro" then
                    Fade.start("combat", function()
                        currentState = "combat"
                        combat.start()
                    end)
                else
                    Fade.start("debate", function()
                        currentState = "debate"
                        debate.start()
                    end)
                end
            end
        end

    -- combat input
    elseif currentState == "combat" then
        combat.keypressed(key)

    -- debate placeholder
    elseif currentState == "debate" then
        if key == "space" then
            Fade.start("victory", function()
                currentState = "victory"
            end)
        end

    -- death or victory reset
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
    -- only pass through when in combat and not fading
    if currentState == "combat" and Fade.state == "none" then
        combat.mousepressed(x, y, button)
    end
end
