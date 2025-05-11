-- main.lua

local assets   = require("assets")
local dialogue = require("dialogue")
local combat   = require("combat")
local debate   = require("debate")
local util     = require("util")
local settings = require("settings")
local Fade     = require("effects.Fade")
local States   = require("states")

-- debug-based script path setup
local scriptPath = debug.getinfo(1).source:match("@?(.*/)") or "./"
package.path = package.path .. ";"
             .. scriptPath .. "?.lua;"
             .. scriptPath .. "entities/?.lua;"
             .. scriptPath .. "effects/?.lua;"

-- state tracking
local currentState  = States.INTRO
local previousState

local function playMusicForState(state)
    for _, music in pairs(assets.music) do
        music:stop()
    end
    if state == States.INTRO then
        assets.music.introTheme:play()
    elseif state == States.MID then
        assets.music.midTheme:play()
    elseif state == States.COMBAT then
        assets.music.combatTheme:setVolume(0.3)
        assets.music.combatTheme:play()
    elseif state == States.DEBATE then
        assets.music.debateTheme:play()
    elseif state == States.VICTORY then
        assets.music.victoryTheme:play()
    elseif state == States.DEATH then
        assets.music.deathTheme:play()
    end
end


function love.load()
    love.graphics.setFont(assets.dialogueFont)
    settings.apply()
    dialogue.start(dialogue.introLines)
    playMusicForState(currentState)

end

function love.update(dt)
    Fade.update(dt)
    if Fade.state ~= "none" then return end

    if currentState == States.COMBAT then
        combat.update(dt)
        if combat.isDead() then
            Fade.start("death", function()
                currentState = States.DEATH
            end)
        elseif combat.isDone() then
            Fade.start("mid", function()
                currentState = States.MID
                dialogue.start(dialogue.midLines)
                playMusicForState(currentState)
            end)
        end

    elseif currentState == States.DEBATE then
        debate.update(dt)

    elseif currentState == States.INTRO or currentState == States.MID then
        dialogue.update(dt)

    elseif currentState == States.INSTRUCTIONS then
        -- no update logic for static screen
    end
end

function love.draw()
    if currentState == States.INTRO or currentState == States.MID then
        dialogue.draw()

    elseif currentState == States.INSTRUCTIONS then
        love.graphics.setFont(assets.dialogueFont)
        local w, h = love.graphics.getDimensions()
        love.graphics.printf("INSTRUCTIONS:\n\n- Move: W A S D\n- Dodge: Left Shift\n- Melee Attack: Left Click\n- Ranged Attack: Right Click\n- Teleport: Space (then click)\n\nPress SPACE to begin combat.",
            0, h * 0.2, w, "center")

    elseif currentState == States.COMBAT then
        combat.draw()

    elseif currentState == States.DEBATE then
        debate.draw()

    elseif currentState == States.DEATH then
        love.graphics.setFont(assets.bigFont)
        love.graphics.printf("YOU DIED",
            0, love.graphics.getHeight()/2,
            love.graphics.getWidth(), "center")

    elseif currentState == States.VICTORY then
        love.graphics.setFont(assets.bigFont)
        love.graphics.printf("VICTORY!",
            0, love.graphics.getHeight()/2,
            love.graphics.getWidth(), "center")

    elseif currentState == States.SETTINGS then
        settings.draw()
    end

    -- fade overlay always on top
    local w,h = love.graphics.getDimensions()
    Fade.draw(w, h)
end

function love.keypressed(key)
    -- toggle settings
    if key == "escape" then
        if currentState == States.SETTINGS then
            Fade.start(previousState or States.INTRO, function()
                currentState = previousState or States.INTRO
                -- Resume music if it was paused
                if assets.music.combatTheme and currentState == States.COMBAT then
                    assets.music.combatTheme:play()
                end
            end)
        else
            -- Pause music if we're in combat
            if currentState == States.COMBAT and assets.music.combatTheme:isPlaying() then
                assets.music.combatTheme:pause()
            end
            previousState = currentState
            Fade.start(States.SETTINGS, function()
                currentState = States.SETTINGS
            end)
        end
        return
    end


    if Fade.state ~= "none" then return end

    if currentState == States.SETTINGS then
        settings.keypressed(key)
        return
    end

    -- Dialogue input
    if currentState == States.INTRO or currentState == States.MID then
        if key == "space" then
            local done = dialogue.nextLine()
            if done then
                if currentState == States.INTRO then
                    Fade.start(States.INSTRUCTIONS, function()
                        currentState = States.INSTRUCTIONS
                    end)
                else
                    Fade.start(States.DEBATE, function()
                        currentState = States.DEBATE
                        debate.start()
                        playMusicForState(currentState)
                    end)
                end
            end
        end

    -- Instructions input
    elseif currentState == States.INSTRUCTIONS then
        if key == "space" then
            Fade.start(States.COMBAT, function()
                currentState = States.COMBAT
                combat.start()
                playMusicForState(currentState)
            end)
        end

    -- Combat input
    elseif currentState == States.COMBAT then
        combat.keypressed(key)

    -- Debate input
    elseif currentState == States.DEBATE then
        if key == "space" then
            Fade.start(States.VICTORY, function()
                currentState = States.VICTORY
                playMusicForState(currentState)
            end)
        end

    -- Death or Victory reset
    elseif currentState == States.DEATH or currentState == States.VICTORY then
        if key == "space" then
            Fade.start(States.INTRO, function()
                -- stop all music
                for _, m in pairs(assets.music) do
                    if m:isPlaying() then m:stop() end
                end
                combat.reset()
                dialogue.start(dialogue.introLines)
                currentState = States.INTRO
                playMusicForState(currentState)
            end)
        end
    end
end

function love.mousepressed(x, y, button)
    if currentState == States.COMBAT and Fade.state == "none" then
        combat.mousepressed(x, y, button)
    end
end
