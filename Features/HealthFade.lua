local addonName, DF = ...

-- ============================================================
-- HEALTH THRESHOLD FADE SYSTEM
-- Fades frames/elements when a unit's health is above a configurable
-- threshold. UnitHealthPercent has SecretReturns=true (Blizzard API doc):
-- we use a hidden StatusBar in Core.lua whose OnValueChanged receives
-- a resolved value; dfComputedAboveThreshold is set there.
-- Cancel-on-dispel supported.
-- ============================================================

-- Upvalue all frequently used globals for performance
local UnitExists = UnitExists
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local issecretvalue = issecretvalue or function() return false end

-- Invalidate curve cache when options change (called from Options.lua)
function DF:InvalidateHealthFadeCurve()
    -- Reserved for future curve-based implementation
end

-- ============================================================
-- APPLY CANCEL OVERRIDES (dispel only)
-- frame.dfComputedAboveThreshold is set by Core's hidden bar OnValueChanged (resolved value).
-- ============================================================
local function ApplyCancelOverrides(frame, isAboveThreshold)
    if not isAboveThreshold or not frame or not frame.unit then return isAboveThreshold end
    local db = frame.isRaidFrame and DF:GetRaidDB() or DF:GetDB()
    if not db then return isAboveThreshold end

    if db.hfCancelOnDispel then
        if frame.dfDispelOverlay and frame.dfDispelOverlay:IsShown() then
            return false
        end
    end

    return isAboveThreshold
end

-- ============================================================
-- UPDATE HEALTH FADE STATE FOR A FRAME
-- Base "above threshold" from frame.dfComputedAboveThreshold (set by hidden bar
-- OnValueChanged with resolved value; UnitHealthPercent has SecretReturns=true).
-- ============================================================

function DF:UpdateHealthFade(frame)
    if not frame or not frame.unit then return end

    if frame.isPetFrame then
        DF:UpdatePetHealthFade(frame)
        return
    end

    if DF.PerfTest and not DF.PerfTest.enableHealthFade then return end
    if DF.testMode or DF.raidTestMode then return end

    local db = frame.isRaidFrame and DF:GetRaidDB() or DF:GetDB()
    if not db or not db.healthFadeEnabled then
        if frame.dfIsHealthFaded then
            frame.dfIsHealthFaded = false
            if DF.UpdateAllElementAppearances then
                DF:UpdateAllElementAppearances(frame)
            end
        end
        return
    end

    -- Use resolved value from hidden bar callback (safe to use); nil = not yet set = don't fade
    local isAboveThreshold = (frame.dfComputedAboveThreshold == true)
    isAboveThreshold = ApplyCancelOverrides(frame, isAboveThreshold)

    if frame.dfIsHealthFaded ~= isAboveThreshold then
        frame.dfIsHealthFaded = isAboveThreshold
        if DF.UpdateAllElementAppearances then
            DF:UpdateAllElementAppearances(frame)
        end
    end
end

-- ============================================================
-- UPDATE HEALTH FADE FOR PET FRAMES
-- (Pet frames still use percent check; no curve needed for simplicity)
-- ============================================================

local function GetPetHealthPercent(unit)
    if not unit or not UnitExists(unit) then return 0 end
    local cur = UnitHealth(unit, true)
    local max = UnitHealthMax(unit, true)
    if not cur or not max then return 0 end
    if issecretvalue(cur) or issecretvalue(max) then return 0 end
    if max == 0 then return 0 end
    return (cur / max) * 100
end

function DF:UpdatePetHealthFade(frame)
    if not frame or not frame.unit then return end
    if not UnitExists(frame.unit) then return end

    local db = frame.isRaidFrame and DF:GetRaidDB() or DF:GetDB()
    if not db or not db.healthFadeEnabled then
        frame.dfIsHealthFaded = false
        return
    end

    local pct = GetPetHealthPercent(frame.unit)
    local threshold = db.healthFadeThreshold or 100
    local isAboveThreshold = (pct >= threshold - 0.5)

    if frame.dfIsHealthFaded ~= isAboveThreshold then
        frame.dfIsHealthFaded = isAboveThreshold
        local healthFadeAlpha = db.healthFadeAlpha or 0.5
        if frame.SetAlpha then
            frame:SetAlpha(isAboveThreshold and healthFadeAlpha or 1.0)
        end
        if frame.healthBar then
            frame.healthBar:SetAlpha(isAboveThreshold and healthFadeAlpha or 1.0)
        end
    end
end

-- ============================================================
-- HELPER: Check if a frame should be faded (above health threshold)
-- Used by ElementAppearance.lua. Now derived from curve when possible.
-- ============================================================

function DF:IsHealthFaded(frame)
    if not frame then return false end
    local db = frame.isRaidFrame and DF:GetRaidDB() or DF:GetDB()
    if not db or not db.healthFadeEnabled then
        return false
    end
    return frame.dfIsHealthFaded == true
end

-- ============================================================
-- HELPER: Get health fade alpha for an element
-- Used by ElementAppearance.lua. For frame-level fade, can use curve alpha.
-- ============================================================

local HEALTH_FADE_ALPHA_MAP = {
    healthBar = "hfHealthBarAlpha",
    background = "hfBackgroundAlpha",
    nameText = "hfNameTextAlpha",
    healthText = "hfHealthTextAlpha",
    auras = "hfAurasAlpha",
    icons = "hfIconsAlpha",
    dispelOverlay = "hfDispelOverlayAlpha",
    powerBar = "hfPowerBarAlpha",
    missingBuff = "hfMissingBuffAlpha",
    defensiveIcon = "hfDefensiveIconAlpha",
    targetedSpell = "hfTargetedSpellAlpha",
    myBuffIndicator = "hfMyBuffIndicatorAlpha",
    frame = "healthFadeAlpha",
}

function DF:GetHealthFadeAlpha(frame, elementKey)
    if not frame then return 1.0 end
    local db = frame.isRaidFrame and DF:GetRaidDB() or DF:GetDB()
    if not db then return 1.0 end
    local dbKey = HEALTH_FADE_ALPHA_MAP[elementKey] or "healthFadeAlpha"
    return db[dbKey] or 0.5
end

