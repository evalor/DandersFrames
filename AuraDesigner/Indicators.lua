local addonName, DF = ...

-- ============================================================
-- AURA DESIGNER - INDICATORS
-- Visual rendering for all 8 indicator types. Creates, shows,
-- hides, and updates indicator elements on unit frames.
--
-- Uses a Begin/Apply/End pattern per frame update:
--   BeginFrame(frame)  — reset per-frame state
--   Apply(frame, ...)  — called per active indicator
--   EndFrame(frame)    — revert anything not applied
-- ============================================================

local pairs, ipairs, type = pairs, ipairs, type
local GetTime = GetTime
local max, min = math.max, math.min

DF.AuraDesigner = DF.AuraDesigner or {}

local Indicators = {}
DF.AuraDesigner.Indicators = Indicators

-- ============================================================
-- PER-FRAME STATE
-- Tracks which frame-level indicators were applied this frame
-- so EndFrame can revert unclaimed ones.
-- ============================================================

-- frame.dfAD = { border = false, healthbar = false, ... }
-- Set to true when an indicator claims it during Apply

local function EnsureFrameState(frame)
    if not frame.dfAD then
        frame.dfAD = {
            -- Frame-level claim flags (reset each BeginFrame)
            border = false,
            healthbar = false,
            nametext = false,
            healthtext = false,
            framealpha = false,
            -- Placed indicator counters
            iconCount = 0,
            squareCount = 0,
            barCount = 0,
            -- Saved defaults for reverting
            savedBorderColor = nil,
            savedNameColor = nil,
            savedHealthTextColor = nil,
            savedAlpha = nil,
        }
    end
    return frame.dfAD
end

-- ============================================================
-- BEGIN FRAME
-- Reset per-frame state before Apply calls
-- ============================================================

function Indicators:BeginFrame(frame)
    local state = EnsureFrameState(frame)
    state.border = false
    state.healthbar = false
    state.nametext = false
    state.healthtext = false
    state.framealpha = false
    state.iconCount = 0
    state.squareCount = 0
    state.barCount = 0
end

-- ============================================================
-- APPLY — DISPATCH TO TYPE HANDLERS
-- ============================================================

function Indicators:Apply(frame, typeKey, config, auraData, defaults, auraName, priority)
    if typeKey == "border" then
        self:ApplyBorder(frame, config, auraData)
    elseif typeKey == "healthbar" then
        self:ApplyHealthBar(frame, config, auraData)
    elseif typeKey == "nametext" then
        self:ApplyNameText(frame, config, auraData)
    elseif typeKey == "healthtext" then
        self:ApplyHealthText(frame, config, auraData)
    elseif typeKey == "framealpha" then
        self:ApplyFrameAlpha(frame, config, auraData)
    elseif typeKey == "icon" then
        self:ApplyIcon(frame, config, auraData, defaults, auraName)
    elseif typeKey == "square" then
        self:ApplySquare(frame, config, auraData, defaults, auraName)
    elseif typeKey == "bar" then
        self:ApplyBar(frame, config, auraData, defaults, auraName)
    end
end

-- ============================================================
-- END FRAME
-- Revert anything not claimed during this frame's Apply calls
-- ============================================================

function Indicators:EndFrame(frame)
    local state = frame.dfAD
    if not state then return end

    -- Revert border
    if not state.border then
        self:RevertBorder(frame)
    end

    -- Revert health bar color
    if not state.healthbar then
        self:RevertHealthBar(frame)
    end

    -- Revert name text color
    if not state.nametext then
        self:RevertNameText(frame)
    end

    -- Revert health text color
    if not state.healthtext then
        self:RevertHealthText(frame)
    end

    -- Revert frame alpha
    if not state.framealpha then
        self:RevertFrameAlpha(frame)
    end

    -- Hide unused placed indicators
    self:HideUnusedIcons(frame, state.iconCount)
    self:HideUnusedSquares(frame, state.squareCount)
    self:HideUnusedBars(frame, state.barCount)
end

-- ============================================================
-- HIDE ALL — Clear everything (used when AD disabled or no unit)
-- ============================================================

function Indicators:HideAll(frame)
    self:RevertBorder(frame)
    self:RevertHealthBar(frame)
    self:RevertNameText(frame)
    self:RevertHealthText(frame)
    self:RevertFrameAlpha(frame)
    self:HideUnusedIcons(frame, 0)
    self:HideUnusedSquares(frame, 0)
    self:HideUnusedBars(frame, 0)
end

-- ============================================================
-- FRAME-LEVEL INDICATORS
-- These modify existing frame elements. Only the highest
-- priority aura claiming a type wins (first Apply call claims).
-- ============================================================

-- ============================================================
-- BORDER
-- ============================================================

function Indicators:ApplyBorder(frame, config, auraData)
    local state = EnsureFrameState(frame)
    if state.border then return end  -- Already claimed by higher priority
    state.border = true

    local border = frame.border
    if not border then return end

    -- Save original border color on first use
    if not state.savedBorderColor and border.top then
        local r, g, b, a = border.top:GetVertexColor()
        state.savedBorderColor = { r = r, g = g, b = b, a = a }
    end

    local color = config.color
    if color then
        local r, g, b = color[1] or color.r or 1, color[2] or color.g or 1, color[3] or color.b or 1
        if border.top then border.top:SetVertexColor(r, g, b, 1) end
        if border.bottom then border.bottom:SetVertexColor(r, g, b, 1) end
        if border.left then border.left:SetVertexColor(r, g, b, 1) end
        if border.right then border.right:SetVertexColor(r, g, b, 1) end
    end

    -- Border thickness
    local thickness = config.thickness or 1
    if border.top then
        border.top:SetHeight(thickness)
        border.bottom:SetHeight(thickness)
        border.left:SetWidth(thickness)
        border.right:SetWidth(thickness)
    end

    -- Show border
    if border.top then
        border.top:Show()
        border.bottom:Show()
        border.left:Show()
        border.right:Show()
    end
end

function Indicators:RevertBorder(frame)
    local state = frame and frame.dfAD
    if not state or not state.savedBorderColor then return end

    local border = frame.border
    if not border or not border.top then return end

    local c = state.savedBorderColor
    border.top:SetVertexColor(c.r, c.g, c.b, c.a)
    border.bottom:SetVertexColor(c.r, c.g, c.b, c.a)
    border.left:SetVertexColor(c.r, c.g, c.b, c.a)
    border.right:SetVertexColor(c.r, c.g, c.b, c.a)

    -- Restore thickness from settings
    local db = DF:GetFrameDB(frame)
    if db then
        local t = db.borderThickness or 1
        border.top:SetHeight(t)
        border.bottom:SetHeight(t)
        border.left:SetWidth(t)
        border.right:SetWidth(t)
    end
end

-- ============================================================
-- HEALTH BAR COLOR
-- ============================================================

function Indicators:ApplyHealthBar(frame, config, auraData)
    local state = EnsureFrameState(frame)
    if state.healthbar then return end
    state.healthbar = true

    local healthBar = frame.healthBar
    if not healthBar then return end

    local color = config.color
    if not color then return end

    local r, g, b = color[1] or color.r or 1, color[2] or color.g or 1, color[3] or color.b or 1
    local mode = config.mode or "replace"

    if mode == "replace" then
        healthBar:SetStatusBarColor(r, g, b, 1)
    elseif mode == "tint" then
        -- Blend with current color
        local blend = (config.blend or 50) / 100
        local cr, cg, cb = healthBar:GetStatusBarColor()
        local nr = cr + (r - cr) * blend
        local ng = cg + (g - cg) * blend
        local nb = cb + (b - cb) * blend
        healthBar:SetStatusBarColor(nr, ng, nb, 1)
    end
end

function Indicators:RevertHealthBar(frame)
    -- The normal frame update cycle will restore health bar color
    -- on the next UpdateUnitFrame call, so we don't need to do
    -- anything special here. The color will be recalculated from
    -- the unit's actual health/class color settings.
end

-- ============================================================
-- NAME TEXT COLOR
-- ============================================================

function Indicators:ApplyNameText(frame, config, auraData)
    local state = EnsureFrameState(frame)
    if state.nametext then return end
    state.nametext = true

    local nameText = frame.nameText
    if not nameText then return end

    -- Save original color on first use
    if not state.savedNameColor then
        local r, g, b, a = nameText:GetTextColor()
        state.savedNameColor = { r = r, g = g, b = b, a = a }
    end

    local color = config.color
    if color then
        local r, g, b = color[1] or color.r or 1, color[2] or color.g or 1, color[3] or color.b or 1
        nameText:SetTextColor(r, g, b, 1)
    end
end

function Indicators:RevertNameText(frame)
    local state = frame and frame.dfAD
    if not state or not state.savedNameColor then return end

    local nameText = frame.nameText
    if not nameText then return end

    local c = state.savedNameColor
    nameText:SetTextColor(c.r, c.g, c.b, c.a)
    state.savedNameColor = nil  -- Re-capture next time
end

-- ============================================================
-- HEALTH TEXT COLOR
-- ============================================================

function Indicators:ApplyHealthText(frame, config, auraData)
    local state = EnsureFrameState(frame)
    if state.healthtext then return end
    state.healthtext = true

    local healthText = frame.healthText
    if not healthText then return end

    -- Save original color on first use
    if not state.savedHealthTextColor then
        local r, g, b, a = healthText:GetTextColor()
        state.savedHealthTextColor = { r = r, g = g, b = b, a = a }
    end

    local color = config.color
    if color then
        local r, g, b = color[1] or color.r or 1, color[2] or color.g or 1, color[3] or color.b or 1
        healthText:SetTextColor(r, g, b, 1)
    end
end

function Indicators:RevertHealthText(frame)
    local state = frame and frame.dfAD
    if not state or not state.savedHealthTextColor then return end

    local healthText = frame.healthText
    if not healthText then return end

    local c = state.savedHealthTextColor
    healthText:SetTextColor(c.r, c.g, c.b, c.a)
    state.savedHealthTextColor = nil
end

-- ============================================================
-- FRAME ALPHA
-- ============================================================

function Indicators:ApplyFrameAlpha(frame, config, auraData)
    local state = EnsureFrameState(frame)
    if state.framealpha then return end
    state.framealpha = true

    -- Save original alpha on first use
    if not state.savedAlpha then
        state.savedAlpha = frame:GetAlpha()
    end

    local alpha = config.alpha
    if alpha then
        frame:SetAlpha(alpha)
    end
end

function Indicators:RevertFrameAlpha(frame)
    local state = frame and frame.dfAD
    if not state or not state.savedAlpha then return end

    frame:SetAlpha(state.savedAlpha)
    state.savedAlpha = nil
end

-- ============================================================
-- PLACED INDICATORS — ICON
-- Creates icon frames lazily and positions at configured anchor
-- ============================================================

-- Get or create the icon pool for a frame
local function GetIconPool(frame)
    if not frame.dfAD_icons then
        frame.dfAD_icons = {}
    end
    return frame.dfAD_icons
end

local function CreateIndicatorIcon(frame, index)
    local icon = CreateFrame("Frame", nil, frame.contentOverlay or frame)
    icon:SetSize(24, 24)
    icon:SetFrameLevel((frame.contentOverlay or frame):GetFrameLevel() + 10)

    -- Border background
    icon.border = icon:CreateTexture(nil, "BACKGROUND")
    icon.border:SetAllPoints()
    icon.border:SetColorTexture(0, 0, 0, 1)

    -- Spell texture
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetPoint("TOPLEFT", 1, -1)
    icon.texture:SetPoint("BOTTOMRIGHT", -1, 1)
    icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Cooldown swipe
    icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cooldown:SetAllPoints(icon.texture)
    icon.cooldown:SetDrawEdge(false)
    icon.cooldown:SetDrawSwipe(true)
    icon.cooldown:SetReverse(true)
    icon.cooldown:SetHideCountdownNumbers(true)

    -- Stack count
    icon.count = icon:CreateFontString(nil, "OVERLAY")
    icon.count:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    icon.count:SetPoint("BOTTOMRIGHT", -1, 1)
    icon.count:SetTextColor(1, 1, 1)

    -- Duration text
    icon.duration = icon:CreateFontString(nil, "OVERLAY")
    icon.duration:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    icon.duration:SetPoint("TOP", icon, "BOTTOM", 0, -1)
    icon.duration:SetTextColor(1, 1, 1)

    icon:Hide()
    return icon
end

function Indicators:ApplyIcon(frame, config, auraData, defaults, auraName)
    local state = EnsureFrameState(frame)
    state.iconCount = state.iconCount + 1
    local index = state.iconCount

    local pool = GetIconPool(frame)
    local icon = pool[index]
    if not icon then
        icon = CreateIndicatorIcon(frame, index)
        pool[index] = icon
    end

    -- Size
    local size = config.size or (defaults and defaults.iconSize) or 24
    local scale = config.scale or (defaults and defaults.iconScale) or 1.0
    icon:SetSize(size, size)
    icon:SetScale(scale)

    -- Alpha
    icon:SetAlpha(config.alpha or 1.0)

    -- Position
    local anchor = config.anchor or "TOPLEFT"
    local offsetX = config.offsetX or 0
    local offsetY = config.offsetY or 0
    icon:ClearAllPoints()

    -- Growth direction for multiple icons at same anchor
    local growth = config.growth or "RIGHT"
    local spacing = config.spacing or 2
    local growOffset = (index - 1) * (size * scale + spacing)
    local gx, gy = 0, 0
    if growth == "RIGHT" then gx = growOffset
    elseif growth == "LEFT" then gx = -growOffset
    elseif growth == "UP" then gy = growOffset
    elseif growth == "DOWN" then gy = -growOffset
    end

    icon:SetPoint(anchor, frame, anchor, offsetX + gx, offsetY + gy)

    -- Texture
    if auraData.icon then
        icon.texture:SetTexture(auraData.icon)
    elseif auraData.spellId and C_Spell and C_Spell.GetSpellTexture then
        icon.texture:SetTexture(C_Spell.GetSpellTexture(auraData.spellId))
    end

    -- Cooldown swipe
    local hideSwipe = config.hideSwipe
    if not hideSwipe and auraData.duration and auraData.duration > 0 and auraData.expirationTime and auraData.expirationTime > 0 then
        icon.cooldown:SetCooldown(auraData.expirationTime - auraData.duration, auraData.duration)
        icon.cooldown:Show()
    else
        icon.cooldown:Hide()
    end

    -- Stack count
    local showStacks = config.showStacks
    if showStacks == nil and defaults then showStacks = defaults.showStacks end
    local stackMin = config.stackMinimum or (defaults and defaults.stackMinimum) or 2
    if showStacks and auraData.stacks and auraData.stacks >= stackMin then
        icon.count:SetText(auraData.stacks)
        local stackScale = config.stackScale or (defaults and defaults.stackScale) or 1.0
        local stackFont = config.stackFont or (defaults and defaults.stackFont) or "Fonts\\FRIZQT__.TTF"
        icon.count:SetFont(stackFont, 10 * stackScale, "OUTLINE")
        icon.count:Show()
    else
        icon.count:Hide()
    end

    -- Duration text
    local showDuration = config.showDuration
    if showDuration == nil and defaults then showDuration = defaults.showDuration end
    if showDuration and auraData.duration and auraData.duration > 0 then
        local remaining = auraData.expirationTime - GetTime()
        if remaining > 0 then
            if remaining >= 60 then
                icon.duration:SetText(string.format("%dm", remaining / 60))
            else
                icon.duration:SetText(string.format("%.0f", remaining))
            end
            icon.duration:Show()
        else
            icon.duration:Hide()
        end
    else
        icon.duration:Hide()
    end

    -- Border
    local showBorder = config.showBorder
    if showBorder == nil and defaults then showBorder = defaults.iconBorderEnabled end
    if showBorder then
        icon.border:Show()
    else
        icon.border:Hide()
    end

    icon:Show()
end

function Indicators:HideUnusedIcons(frame, usedCount)
    local pool = frame and frame.dfAD_icons
    if not pool then return end
    for i = usedCount + 1, #pool do
        pool[i]:Hide()
    end
end

-- ============================================================
-- PLACED INDICATORS — SQUARE
-- Small colored square indicators
-- ============================================================

local function GetSquarePool(frame)
    if not frame.dfAD_squares then
        frame.dfAD_squares = {}
    end
    return frame.dfAD_squares
end

local function CreateIndicatorSquare(frame)
    local sq = CreateFrame("Frame", nil, frame.contentOverlay or frame)
    sq:SetSize(8, 8)
    sq:SetFrameLevel((frame.contentOverlay or frame):GetFrameLevel() + 10)

    sq.border = sq:CreateTexture(nil, "BACKGROUND")
    sq.border:SetAllPoints()
    sq.border:SetColorTexture(0, 0, 0, 1)

    sq.texture = sq:CreateTexture(nil, "ARTWORK")
    sq.texture:SetPoint("TOPLEFT", 1, -1)
    sq.texture:SetPoint("BOTTOMRIGHT", -1, 1)

    -- Stack count (small)
    sq.count = sq:CreateFontString(nil, "OVERLAY")
    sq.count:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    sq.count:SetPoint("CENTER", 0, 0)
    sq.count:SetTextColor(1, 1, 1)

    sq:Hide()
    return sq
end

function Indicators:ApplySquare(frame, config, auraData, defaults, auraName)
    local state = EnsureFrameState(frame)
    state.squareCount = state.squareCount + 1
    local index = state.squareCount

    local pool = GetSquarePool(frame)
    local sq = pool[index]
    if not sq then
        sq = CreateIndicatorSquare(frame)
        pool[index] = sq
    end

    -- Size
    local size = config.size or 8
    sq:SetSize(size, size)

    -- Alpha
    sq:SetAlpha(config.alpha or 1.0)

    -- Color
    local color = config.color
    if color then
        sq.texture:SetColorTexture(color[1] or color.r or 1, color[2] or color.g or 1, color[3] or color.b or 1, 1)
    else
        sq.texture:SetColorTexture(1, 1, 1, 1)
    end

    -- Position
    local anchor = config.anchor or "BOTTOMLEFT"
    local offsetX = config.offsetX or 0
    local offsetY = config.offsetY or 0
    sq:ClearAllPoints()

    local growth = config.growth or "RIGHT"
    local spacing = config.spacing or 1
    local growOffset = (index - 1) * (size + spacing)
    local gx, gy = 0, 0
    if growth == "RIGHT" then gx = growOffset
    elseif growth == "LEFT" then gx = -growOffset
    elseif growth == "UP" then gy = growOffset
    elseif growth == "DOWN" then gy = -growOffset
    end

    sq:SetPoint(anchor, frame, anchor, offsetX + gx, offsetY + gy)

    -- Border
    local showBorder = config.showBorder
    if showBorder == nil then showBorder = true end
    if showBorder then
        sq.border:Show()
    else
        sq.border:Hide()
    end

    -- Stack count
    local showStacks = config.showStacks
    local stackMin = config.stackMinimum or 2
    if showStacks and auraData.stacks and auraData.stacks >= stackMin then
        sq.count:SetText(auraData.stacks)
        sq.count:Show()
    else
        sq.count:Hide()
    end

    sq:Show()
end

function Indicators:HideUnusedSquares(frame, usedCount)
    local pool = frame and frame.dfAD_squares
    if not pool then return end
    for i = usedCount + 1, #pool do
        pool[i]:Hide()
    end
end

-- ============================================================
-- PLACED INDICATORS — BAR
-- Progress bars showing remaining aura duration
-- ============================================================

local function GetBarPool(frame)
    if not frame.dfAD_bars then
        frame.dfAD_bars = {}
    end
    return frame.dfAD_bars
end

local function CreateIndicatorBar(frame)
    local bar = CreateFrame("StatusBar", nil, frame.contentOverlay or frame)
    bar:SetSize(60, 6)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:SetFrameLevel((frame.contentOverlay or frame):GetFrameLevel() + 10)

    bar.border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    bar.border:SetPoint("TOPLEFT", -1, 1)
    bar.border:SetPoint("BOTTOMRIGHT", 1, -1)
    if bar.border.SetBackdrop then
        bar.border:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        bar.border:SetBackdropBorderColor(0, 0, 0, 1)
    end

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar.bg:SetVertexColor(0.15, 0.15, 0.15, 0.8)

    bar:Hide()
    return bar
end

function Indicators:ApplyBar(frame, config, auraData, defaults, auraName)
    local state = EnsureFrameState(frame)
    state.barCount = state.barCount + 1
    local index = state.barCount

    local pool = GetBarPool(frame)
    local bar = pool[index]
    if not bar then
        bar = CreateIndicatorBar(frame)
        pool[index] = bar
    end

    -- Size
    local width = config.width or 60
    local height = config.height or 6
    if config.matchFrameWidth then width = frame:GetWidth() end
    if config.matchFrameHeight then height = frame:GetHeight() end
    bar:SetSize(width, height)

    -- Alpha
    bar:SetAlpha(config.alpha or 1.0)

    -- Orientation
    local orientation = config.orientation or "HORIZONTAL"
    bar:SetOrientation(orientation)

    -- Colors
    local fillColor = config.fillColor
    if fillColor then
        bar:SetStatusBarColor(fillColor[1] or fillColor.r or 0.3, fillColor[2] or fillColor.g or 0.7, fillColor[3] or fillColor.b or 0.3, 1)
    else
        bar:SetStatusBarColor(0.3, 0.7, 0.3, 1)
    end

    local bgColor = config.bgColor
    if bgColor and bar.bg then
        bar.bg:SetVertexColor(bgColor[1] or bgColor.r or 0.15, bgColor[2] or bgColor.g or 0.15, bgColor[3] or bgColor.b or 0.15, 0.8)
    end

    -- Border
    local showBorder = config.showBorder
    if showBorder == nil then showBorder = true end
    if bar.border then
        if showBorder then
            bar.border:Show()
            local borderColor = config.borderColor
            if borderColor and bar.border.SetBackdropBorderColor then
                bar.border:SetBackdropBorderColor(borderColor[1] or borderColor.r or 0, borderColor[2] or borderColor.g or 0, borderColor[3] or borderColor.b or 0, 1)
            end
        else
            bar.border:Hide()
        end
    end

    -- Position
    local anchor = config.anchor or "BOTTOM"
    local offsetX = config.offsetX or 0
    local offsetY = config.offsetY or 0
    bar:ClearAllPoints()

    local growth = config.growth or "DOWN"
    local spacing = config.spacing or 2
    local growOffset = (index - 1) * (height + spacing)
    local gx, gy = 0, 0
    if growth == "RIGHT" then gx = growOffset
    elseif growth == "LEFT" then gx = -growOffset
    elseif growth == "UP" then gy = growOffset
    elseif growth == "DOWN" then gy = -growOffset
    end

    bar:SetPoint(anchor, frame, anchor, offsetX + gx, offsetY + gy)

    -- Fill based on remaining duration
    if auraData.duration and auraData.duration > 0 and auraData.expirationTime then
        local remaining = auraData.expirationTime - GetTime()
        local pct = max(0, min(1, remaining / auraData.duration))
        bar:SetValue(pct)
    else
        bar:SetValue(1)  -- Permanent aura = full bar
    end

    bar:Show()
end

function Indicators:HideUnusedBars(frame, usedCount)
    local pool = frame and frame.dfAD_bars
    if not pool then return end
    for i = usedCount + 1, #pool do
        pool[i]:Hide()
    end
end
