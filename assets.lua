-- assets.lua

local assets = {}

-- -- Fonts
-- assets.nameFont     = love.graphics.newFont(18)
-- assets.dialogueFont = love.graphics.newFont(14)
-- assets.hintFont     = love.graphics.newFont(12)
-- assets.bigFont      = love.graphics.newFont(32)


-- Fonts (supports Chinese)
local chineseFontPath = "resources/fonts/NotoSansSC-Regular.otf"

assets.nameFont     = love.graphics.newFont(chineseFontPath, 18)
assets.dialogueFont = love.graphics.newFont(chineseFontPath, 16)
assets.hintFont     = love.graphics.newFont(chineseFontPath, 12)
assets.bigFont      = love.graphics.newFont(chineseFontPath, 32)

-- Images
assets.bg                = love.graphics.newImage("resources/images/bg.png")
assets.bg2               = love.graphics.newImage("resources/images/bg2.jpeg")
assets.huaChengPortrait  = love.graphics.newImage("resources/images/huacheng.png")
assets.lingWenPortrait   = love.graphics.newImage("resources/images/lingwen.png")
assets.xieLianPortrait   = love.graphics.newImage("resources/images/xielian.png")
assets.nothing           = love.graphics.newImage("resources/images/nothing.png")
assets.mysteryman        = love.graphics.newImage("resources/images/mysteryman.png")
assets.mysterywoman        = love.graphics.newImage("resources/images/mysterywoman.png")


return assets
