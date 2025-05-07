local assets = require("assets")
local Debate = {}

function Debate.start() end
function Debate.update(dt) end
function Debate.draw()
  love.graphics.setFont(assets.bigFont)
  love.graphics.printf("[Debate section coming soon]",
    0, love.graphics.getHeight()/2, love.graphics.getWidth(), "center")
end

return Debate
