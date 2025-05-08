local assets   = require("assets")
local dialogue = require("dialogue")
local combat   = require("combat")
local debate   = require("debate")
local util     = require("util")

local currentState = "intro"

local scriptPath = debug.getinfo(1).source:match("@?(.*/)") or "./"

package.path = package.path .. ";" 
             .. scriptPath .. "?.lua" .. ";"          -- Current directory
             .. scriptPath .. "enemies/?.lua" .. ";"  -- enemies directory
             .. scriptPath .. "effects/?.lua" .. ";"    -- effects directory 


function love.load()
    love.graphics.setFont(assets.dialogueFont)
    dialogue.start(dialogue.introLines)
end

function love.update(dt)
    if currentState == "combat" then
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
end

function love.keypressed(key)
    if currentState == "intro" or currentState == "mid" then
        if key == "space" then
            local done = dialogue.nextLine()
            if done then
                if currentState == "intro" then
                    currentState = "combat"
                    combat.start()
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
