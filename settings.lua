local assets = require("assets")

local Settings = {
    masterVolume = 1.0,
    musicVolume  = 1.0,
    options      = {"Master Volume", "Music Volume"},
    selected     = 1,
    step         = 0.1,
}

-- Apply volumes
function Settings.apply()
    love.audio.setVolume(Settings.masterVolume)
    if assets.music then
        for _, track in pairs(assets.music) do
            track:setVolume(Settings.masterVolume * Settings.musicVolume)
        end
    end
end

-- Handle key input in settings menu
function Settings.keypressed(key)
    if key == "up" then
        Settings.selected = ((Settings.selected - 2) % #Settings.options) + 1
    elseif key == "down" then
        Settings.selected = (Settings.selected % #Settings.options) + 1
    elseif key == "left" or key == "right" then
        local delta = (key == "left") and -Settings.step or Settings.step
        if Settings.options[Settings.selected] == "Master Volume" then
            Settings.masterVolume = math.max(0, math.min(1, Settings.masterVolume + delta))
        else
            Settings.musicVolume = math.max(0, math.min(1, Settings.musicVolume + delta))
        end
        Settings.apply()
    end
end

-- Draw settings menu
function Settings.draw()
    local w,h = love.graphics.getDimensions()
    love.graphics.setFont(assets.bigFont)
    love.graphics.printf("Settings", 0, h*0.2, w, "center")
    love.graphics.setFont(assets.dialogueFont)
    for i, opt in ipairs(Settings.options) do
        local y = h*0.4 + (i-1)*40
        local value = (opt == "Master Volume") and Settings.masterVolume or Settings.musicVolume
        local text = string.format("%s: %d%%", opt, math.floor(value * 100))
        love.graphics.setColor(i == Settings.selected and {1,0.85,0.6} or {1,1,1})
        love.graphics.printf(text, 0, y, w, "center")
    end
    love.graphics.setColor(1,1,1,0.6)
    love.graphics.printf("Use ↑/↓ to select, ←/→ to adjust, Esc to return", 0, h*0.8, w, "center")
end

return Settings
