local assets = require("assets")
local util   = require("util")
local Dialogue = {}

Dialogue.introLines = {
    { name = "Hua Cheng", text = "The higher they are, the harder they fall.", portrait = assets.huaChengPortrait},
    { name = "Hua Cheng", text = "...It's time, E'Ming.", portrait = assets.huaChengPortrait},
    { name = "Heavenly Official", text = "Who dare trespass into the Heavenly Palace!", portrait = assets.mysteryman},
    { name = "Hua Cheng", text = "I challenge you.", portrait = assets.huaChengPortrait },
    { name = "Heavenly Official", text = "HOW DARE YOU!?!!", portrait = assets.mysteryman },
    { name = "Hua Cheng", text = "If you win, I will give you my ashes to scatter.", portrait = assets.huaChengPortrait },
    { name = "Hua Cheng", text = "But if I win...", portrait = assets.huaChengPortrait },
    { name = "Hua Cheng", text = "Step down from your posts in Heaven.", portrait = assets.huaChengPortrait },
    { name = "Heavenly Official", text = "Hah! Alright then little shrimp. You won't last a second.", portrait = assets.mysteryman },
}

Dialogue.midLines = {
    { name = " ", text = "The Martial Gods had been utterly defeated. It was now the Literature Gods' turn.", portrait = nil },
    { name = " ", text = "If they couldn't beat him in a fight, then they should at least be able beat him in debating, right?", portrait = nil },
    { name = "Hua Cheng", text = "Well fought… Prepare for the debate.", portrait = assets.huaChengPortrait },
    { name = "", text = "The Literature Gods await!", portrait = nil },
}

Dialogue.overlayColor = { 0, 0, 0, 0.7 }
Dialogue.panel = {
    width = 700,
    height = 150,
    yOffset = 30,
    fillColor = {0,0,0,0.7},
    borderColor = {1,1,1,1},
    borderWidth = 4
}

Dialogue.currentLines = nil
Dialogue.currentIndex = 0
Dialogue.currentBg = assets.bg
Dialogue.lastSpeaker = nil
Dialogue.speakerTimer = 0
Dialogue.speakerTransitionTime = 0.3

function Dialogue.start(lines)
    Dialogue.currentLines = lines
    Dialogue.currentIndex = 1
    Dialogue.currentBg = (lines == Dialogue.midLines) and assets.bg2 or assets.bg

    local firstLine = lines[1]
    Dialogue.lastSpeaker = firstLine and firstLine.name or nil
    Dialogue.speakerTimer = 0
end

function Dialogue.nextLine()
    if not Dialogue.currentLines then return false end
    Dialogue.currentIndex = Dialogue.currentIndex + 1
    if Dialogue.currentIndex > #Dialogue.currentLines then
        Dialogue.currentLines = nil
        return true
    end

    local current = Dialogue.currentLines[Dialogue.currentIndex]
    if current.name ~= Dialogue.lastSpeaker then
        Dialogue.lastSpeaker = current.name
        Dialogue.speakerTimer = Dialogue.speakerTransitionTime
    end
    return false
end

function Dialogue.update(dt)
    Dialogue.speakerTimer = math.max(0, Dialogue.speakerTimer - dt)
end

function Dialogue.draw()
    if not Dialogue.currentLines or not Dialogue.currentLines[Dialogue.currentIndex] then return end

    local w, h = love.graphics.getDimensions()

    -- Draw background scaled
    local bg = Dialogue.currentBg
    local bw, bh = bg:getDimensions()
    local scale = math.max(w/bw, h/bh)
    love.graphics.setColor(1,1,1)
    love.graphics.draw(bg, (w - bw*scale)/2, (h - bh*scale)/2, 0, scale, scale)

    -- Dim overlay
    love.graphics.setColor(Dialogue.overlayColor)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local line = Dialogue.currentLines[Dialogue.currentIndex]
    if line.portrait then
        local img = line.portrait
        local iw, ih = img:getDimensions()
        local pscale = (h/ih) * 1.3

        -- Slide and fade if speaker just changed
        local t = 1 - (Dialogue.speakerTimer / Dialogue.speakerTransitionTime)
        local alpha = util.clamp(t, 0, 1)
        local yOffset = util.clamp(50 * (1 - t), 0, 50)

        love.graphics.setColor(1,1,1, alpha)
        love.graphics.draw(img, (w - iw*pscale)/2, h/9 + yOffset, 0, pscale, pscale)
    end

    local p = Dialogue.panel
    local px = (w - p.width)/2
    local py = h - p.height - p.yOffset
    love.graphics.setColor(p.fillColor)
    love.graphics.rectangle("fill", px, py, p.width, p.height)
    love.graphics.setColor(p.borderColor)
    love.graphics.setLineWidth(p.borderWidth)
    love.graphics.rectangle("line", px, py, p.width, p.height)

    love.graphics.setFont(assets.nameFont)
    love.graphics.setColor(1,0.85,0.6)
    love.graphics.printf(line.name, px+20, py+10, p.width-40)
    love.graphics.setFont(assets.dialogueFont)
    love.graphics.setColor(1,1,1)
    love.graphics.printf(line.text, px+20, py+40, p.width-40)

    love.graphics.setFont(assets.hintFont)
    love.graphics.setColor(1,1,1,0.6)
    love.graphics.printf("Press SPACE to continue", px + p.width - 160, py + p.height - 25, 150, "right")
end

return Dialogue
