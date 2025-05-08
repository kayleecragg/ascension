local TakeDamage = {}

local FLASH_DURATION = 0.3
local flashTimer = 0

function TakeDamage.start()
    flashTimer = FLASH_DURATION
end

function TakeDamage.update(dt)
    if flashTimer > 0 then
        flashTimer = flashTimer - dt
        if flashTimer < 0 then flashTimer = 0 end
    end
end

function TakeDamage.draw(w, h)
    if flashTimer > 0 then
        local alpha = (flashTimer / FLASH_DURATION) * 0.5
        love.graphics.setColor(1, 0, 0, alpha)
        love.graphics.rectangle("fill", 0, 0, w, h)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return TakeDamage