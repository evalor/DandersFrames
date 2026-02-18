local addonName, DF = ...

-- ============================================================
-- CLASS POWER PIPS
-- Displays class-specific resources (Holy Power, Chi, etc.)
-- on the player frame as individual colored pips.
-- Only active for the player unit.
-- Compatible with test mode (testShowClassPower) and health fade.
-- ============================================================

local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitClass = UnitClass
local UnitIsUnit = UnitIsUnit
local IsInRaid = IsInRaid

-- ============================================================
-- CLASS POWER MAPPING
-- ============================================================

local CLASS_POWER_TYPES = {
    PALADIN     = 9,   -- Holy Power
    MONK        = 12,  -- Chi (Windwalker)
    ROGUE       = 4,   -- Combo Points
    DRUID       = 4,   -- Combo Points (Feral / cat form)
    WARLOCK     = 7,   -- Soul Shards
    MAGE        = 16,  -- Arcane Charges (Arcane spec)
    EVOKER      = 19,  -- Essence
}

local POWER_COLORS = {
    [4]  = { r = 1.00, g = 0.96, b = 0.41 },  -- Combo Points
    [7]  = { r = 0.58, g = 0.51, b = 0.79 },  -- Soul Shards
    [9]  = { r = 0.95, g = 0.90, b = 0.60 },  -- Holy Power
    [12] = { r = 0.71, g = 1.00, b = 0.92 },  -- Chi
    [16] = { r = 0.44, g = 0.44, b = 1.00 },  -- Arcane Charges
    [19] = { r = 0.00, g = 0.69, b = 0.58 },  -- Essence
}

local POWER_TYPE_TOKENS = {
    [4]  = "COMBO_POINTS",
    [7]  = "SOUL_SHARDS",
    [9]  = "HOLY_POWER",
    [12] = "CHI",
    [16] = "ARCANE_CHARGES",
    [19] = "ESSENCE",
}

local INACTIVE_ALPHA = 0.2
local MAX_PIPS = 10

local activePowerType = nil
local activePowerToken = nil
local pipContainer = nil
local pips = {}
local currentTargetFrame = nil  -- frame we're attached to (party or raid player frame)
local currentUseRaidDb = false

-- ============================================================
-- GET THE FRAME THAT DISPLAYS THE PLAYER (party or raid)
-- When in raid, the party container is hidden; the player is shown on a raid frame.
-- ============================================================
local function GetPlayerFrameForClassPower()
    if IsInRaid() and DF.raidContainer and DF.raidContainer:IsShown() and DF.IterateRaidFrames then
        local found = nil
        DF:IterateRaidFrames(function(f)
            if not f then return end
            local u = f.unit or (f.GetAttribute and f:GetAttribute("unit"))
            if u and UnitIsUnit(u, "player") and f:IsShown() then
                found = f
                return true
            end
        end)
        if found then
            return found, true
        end
    end
    return DF.playerFrame, false
end

-- ============================================================
-- DETECT CLASS POWER
-- ============================================================

local function DetectClassPower()
    local _, playerClass = UnitClass("player")
    if not playerClass then return nil end
    local candidateType = CLASS_POWER_TYPES[playerClass]
    if not candidateType then return nil end

    local maxPower = UnitPowerMax("player", candidateType)
    if maxPower and maxPower > 0 then
        return candidateType, POWER_TYPE_TOKENS[candidateType], maxPower
    end

    return nil
end

-- ============================================================
-- LAYOUT PIPS
-- ============================================================

local function LayoutPips(frame, count, db)
    if not pipContainer or not frame then return end

    local height = db.classPowerHeight or 4
    local gap = db.classPowerGap or 1
    local yOffset = db.classPowerY or -1
    local xOffset = db.classPowerX or 0

    local parentWidth = frame.healthBar and frame.healthBar:GetWidth() or frame:GetWidth()
    pipContainer:SetSize(parentWidth, height)

    pipContainer:ClearAllPoints()
    local anchor = db.classPowerAnchor or "INSIDE_BOTTOM"
    local bar = frame.healthBar or frame
    if anchor == "INSIDE_BOTTOM" then
        pipContainer:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", xOffset, yOffset)
        pipContainer:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", xOffset, yOffset)
    elseif anchor == "INSIDE_TOP" then
        pipContainer:SetPoint("TOPLEFT", bar, "TOPLEFT", xOffset, yOffset)
        pipContainer:SetPoint("TOPRIGHT", bar, "TOPRIGHT", xOffset, yOffset)
    elseif anchor == "TOP" then
        pipContainer:SetPoint("BOTTOM", bar, "TOP", xOffset, yOffset)
    else
        pipContainer:SetPoint("TOP", bar, "BOTTOM", xOffset, yOffset)
    end

    local pipWidth = (parentWidth - (count - 1) * gap) / count

    for i = 1, MAX_PIPS do
        if not pips[i] then
            local bg = pipContainer:CreateTexture(nil, "BACKGROUND")
            bg:SetTexture("Interface\\Buttons\\WHITE8x8")
            local fg = pipContainer:CreateTexture(nil, "ARTWORK")
            fg:SetTexture("Interface\\Buttons\\WHITE8x8")
            pips[i] = { bg = bg, fg = fg }
        end

        local pip = pips[i]

        if i <= count then
            local xPos = (i - 1) * (pipWidth + gap)

            pip.bg:ClearAllPoints()
            pip.bg:SetPoint("LEFT", pipContainer, "LEFT", xPos, 0)
            pip.bg:SetSize(pipWidth, height)
            pip.bg:SetVertexColor(0.15, 0.15, 0.15, INACTIVE_ALPHA)
            pip.bg:Show()

            pip.fg:ClearAllPoints()
            pip.fg:SetPoint("LEFT", pipContainer, "LEFT", xPos, 0)
            pip.fg:SetSize(pipWidth, height)
            pip.fg:Hide()
        else
            pip.bg:Hide()
            pip.fg:Hide()
        end
    end
end

-- ============================================================
-- UPDATE PIPS
-- ============================================================

local function UpdatePips()
    if not activePowerType or not pipContainer then return end
    if not pipContainer:IsShown() then return end

    local current = UnitPower("player", activePowerType) or 0
    local maxPower = UnitPowerMax("player", activePowerType) or 0

    if maxPower == 0 then
        pipContainer:Hide()
        return
    end

    pipContainer:SetAlpha(1.0)

    local color = POWER_COLORS[activePowerType] or { r = 1, g = 1, b = 1 }

    for i = 1, maxPower do
        local pip = pips[i]
        if pip then
            if i <= current then
                pip.fg:SetVertexColor(color.r, color.g, color.b, 1.0)
                pip.fg:Show()
            else
                pip.fg:Hide()
            end
        end
    end

    for i = maxPower + 1, MAX_PIPS do
        if pips[i] then
            pips[i].bg:Hide()
            pips[i].fg:Hide()
        end
    end
end

-- ============================================================
-- REFRESH
-- ============================================================

local eventFrame = CreateFrame("Frame")

local function Refresh()
    local frame, useRaidDb = GetPlayerFrameForClassPower()
    local db = DF.GetDB and (useRaidDb and DF:GetRaidDB() or DF:GetDB()) or nil

    -- In raid, raid frame units may not be assigned yet; if we fell back to party frame but it's hidden, retry
    if IsInRaid() and DF.raidContainer and DF.raidContainer:IsShown() and not useRaidDb and frame == DF.playerFrame and (not frame or not frame:IsShown()) then
        if C_Timer and C_Timer.After then
            C_Timer.After(0.5, Refresh)
        end
        return
    end

    currentTargetFrame = frame
    currentUseRaidDb = useRaidDb

    if not frame or not frame:IsShown() then
        if pipContainer then pipContainer:Hide() end
        activePowerType = nil
        activePowerToken = nil
        if db and db.classPowerEnabled then
            eventFrame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
            eventFrame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
        end
        return
    end

    if not db or not db.classPowerEnabled then
        if pipContainer then pipContainer:Hide() end
        activePowerType = nil
        activePowerToken = nil
        eventFrame:UnregisterEvent("UNIT_POWER_FREQUENT")
        eventFrame:UnregisterEvent("UNIT_MAXPOWER")
        return
    end

    -- Test mode: respect testShowClassPower (hide pips in test mode if disabled)
    if DF.testMode or DF.raidTestMode then
        if not db.testShowClassPower then
            if pipContainer then pipContainer:Hide() end
            activePowerType = nil
            activePowerToken = nil
            return
        end
    end

    local powerType, powerToken, maxPower = DetectClassPower()

    if not powerType or not maxPower or maxPower == 0 then
        activePowerType = nil
        activePowerToken = nil
        if pipContainer then pipContainer:Hide() end
        eventFrame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
        eventFrame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
        return
    end

    activePowerType = powerType
    activePowerToken = powerToken

    local containerParent = (db.classPowerIgnoreFade and frame:GetParent()) or frame
    if not pipContainer then
        pipContainer = CreateFrame("Frame", nil, containerParent)
    end
    pipContainer:SetParent(containerParent)
    local baseLevel = frame.healthBar and frame.healthBar:GetFrameLevel() or frame:GetFrameLevel()
    pipContainer:SetFrameLevel(containerParent == frame and (baseLevel + 5) or (frame:GetFrameLevel() + 10))

    eventFrame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
    eventFrame:RegisterUnitEvent("UNIT_MAXPOWER", "player")

    LayoutPips(frame, maxPower, db)
    pipContainer:Show()
    UpdatePips()
end

-- ============================================================
-- EVENT HANDLER
-- ============================================================

eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "GROUP_ROSTER_UPDATE" then
        -- Switch party/raid layout: re-resolve player frame and refresh
        Refresh()
        return
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "UPDATE_SHAPESHIFT_FORM" then
        if C_Timer and C_Timer.After then
            C_Timer.After(0.5, Refresh)
            if event == "PLAYER_ENTERING_WORLD" then
                C_Timer.After(2, Refresh)
            end
        else
            Refresh()
        end
    elseif event == "UNIT_POWER_FREQUENT" and arg1 == "player" then
        if activePowerToken then
            if arg2 == activePowerToken then
                UpdatePips()
            end
        else
            local pType, pToken, maxP = DetectClassPower()
            if pType and maxP and maxP > 0 then
                Refresh()
            end
        end
    elseif event == "UNIT_MAXPOWER" and arg1 == "player" then
        if activePowerToken then
            Refresh()
        else
            local pType, pToken, maxP = DetectClassPower()
            if pType and maxP and maxP > 0 then
                Refresh()
            end
        end
    end
end)

-- Export for options and ElementAppearance (health fade)
DF.RefreshClassPower = Refresh
DF.UpdateClassPowerAlpha = function()
    if not pipContainer or not pipContainer:IsShown() then return end
    local frame, useRaidDb = GetPlayerFrameForClassPower()
    if not frame then return end
    local db = DF.GetDB and (useRaidDb and DF:GetRaidDB() or DF:GetDB()) or nil
    if not db then return end
    local containerParent = (db.classPowerIgnoreFade and frame:GetParent()) or frame
    if pipContainer:GetParent() ~= containerParent then
        pipContainer:SetParent(containerParent)
    end
    pipContainer:SetAlpha(1.0)
end
