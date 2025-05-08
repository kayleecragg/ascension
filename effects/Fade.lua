-- effects/fade.lua
-- Smooth fade module with cubic ease-in-out
local Fade = {}

Fade.state    = "none"   -- "none", "out", or "in"
Fade.timer    = 0
Fade.duration = 0.5      -- default half-fade duration (seconds)
Fade.callback = nil

-- Cubic ease-in-out function
local function easeInOutCubic(t)
    if t < 0.5 then
        return 4 * t * t * t
    else
        local f = (2 * t - 2)
        return 0.5 * f * f * f + 1
    end
end

--- Start a fade-out → callback → fade-in.
-- You can call:
--    Fade.start(callback)
--    Fade.start("anyString", callback)
--    Fade.start(duration, callback)
--    Fade.start(numberDuration, callback)
function Fade.start(a, b)
    -- figure out which argument is which
    if type(a) == "number" then
        -- custom duration passed
        Fade.duration = a
        Fade.callback = b
    elseif type(a) == "function" then
        -- only callback passed
        Fade.callback = a
    else
        -- first arg was a string (state name) or nil
        Fade.callback = b
    end

    -- reset timer & begin fade-out
    Fade.timer = 0
    Fade.state = "out"
end

function Fade.update(dt)
    if Fade.state == "none" then return end

    Fade.timer = Fade.timer + dt
    if Fade.timer >= Fade.duration then
        if Fade.state == "out" then
            -- fade-out done → perform callback & start fade-in
            Fade.timer = 0
            Fade.state = "in"
            if Fade.callback then
                Fade.callback()
                Fade.callback = nil
            end
        else
            -- fade-in done → stop
            Fade.state = "none"
        end
    end
end

--- Draw the black overlay with eased alpha
function Fade.draw(w, h)
    if Fade.state == "none" then return end

    local t = Fade.timer / Fade.duration
    if t > 1 then t = 1 end

    local alpha
    if Fade.state == "out" then
        alpha = easeInOutCubic(t)
    else
        alpha = easeInOutCubic(1 - t)
    end

    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 1, 1, 1)
end

return Fade
