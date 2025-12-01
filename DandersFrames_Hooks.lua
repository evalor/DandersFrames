local addonName, DF = ...

-- Helper function to enforce DispelOverlay level for sandwich mode
local function EnforceDispelOverlayLevel(frame)
    if not frame or not frame.DispelOverlay or not frame.healthBar then return end
    if not DF.db or not DF.db.profile then return end
    
    local db = DF:GetDB(frame)
    if not db then return end
    
    local absorbStrata = db.absorbBarStrata or "MEDIUM"
    local healAbsorbStrata = db.healAbsorbBarStrata or "MEDIUM"
    local usingSandwich = (absorbStrata == "SANDWICH" or absorbStrata == "SANDWICH_LOW" or
                           healAbsorbStrata == "SANDWICH" or healAbsorbStrata == "SANDWICH_LOW")
    
    if usingSandwich then
        local healthLevel = frame.healthBar:GetFrameLevel()
        local targetLevel = healthLevel + 15
        
        local mt = getmetatable(frame.DispelOverlay).__index
        if mt and mt.SetFrameLevel then
            mt.SetFrameLevel(frame.DispelOverlay, targetLevel)
        else
            frame.DispelOverlay:SetFrameLevel(targetLevel)
        end
    end
end

-- Hook the DispelOverlay with OnShow to enforce level whenever it becomes visible
local function HookDispelOverlay(frame)
    if not frame or not frame.DispelOverlay then return end
    if frame.DispelOverlay.dfLevelHooked then return end
    
    local ov = frame.DispelOverlay
    
    ov:HookScript("OnShow", function(self)
        EnforceDispelOverlayLevel(frame)
    end)
    
    hooksecurefunc(ov, "SetShown", function(self, shown)
        if shown then
            C_Timer.After(0, function()
                EnforceDispelOverlayLevel(frame)
            end)
        end
    end)
    
    hooksecurefunc(ov, "SetFrameLevel", function(self, level)
        if not DF.db or not DF.db.profile then return end
        local db = DF:GetDB(frame)
        if not db then return end
        
        local absorbStrata = db.absorbBarStrata or "MEDIUM"
        local healAbsorbStrata = db.healAbsorbBarStrata or "MEDIUM"
        local usingSandwich = (absorbStrata == "SANDWICH" or absorbStrata == "SANDWICH_LOW" or
                               healAbsorbStrata == "SANDWICH" or healAbsorbStrata == "SANDWICH_LOW")
        
        if usingSandwich and frame.healthBar then
            local healthLevel = frame.healthBar:GetFrameLevel()
            local targetLevel = healthLevel + 15
            
            if level < targetLevel then
                C_Timer.After(0, function()
                    if self and self.SetFrameLevel then
                        local mt = getmetatable(self)
                        if mt and mt.__index and mt.__index.SetFrameLevel then
                            mt.__index.SetFrameLevel(self, targetLevel)
                        end
                    end
                end)
            end
        end
    end)
    
    ov.dfLevelHooked = true
end

-- ============================================================
-- SAFE HIGHLIGHT SYSTEM V4
-- 
-- Simplified animated border using 4 separate edge frames
-- with proper anchoring to parent corners.
-- ============================================================

-- Animation settings
local ANIMATION_SPEED = 40  -- pixels per second
local DASH_LENGTH = 6
local GAP_LENGTH = 6
local PATTERN_LENGTH = DASH_LENGTH + GAP_LENGTH

-- Global animator
local SelectionAnimator = CreateFrame("Frame")
SelectionAnimator.elapsed = 0
SelectionAnimator.frames = {}

SelectionAnimator:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    local offset = (self.elapsed * ANIMATION_SPEED) % PATTERN_LENGTH
    
    for highlightFrame, _ in pairs(self.frames) do
        if highlightFrame:IsShown() then
            UpdateAnimatedBorder(highlightFrame, offset)
        end
    end
end)

-- Create dashes for one edge
local function CreateEdgeDashes(parent, count)
    local dashes = {}
    for i = 1, count do
        local dash = parent:CreateTexture(nil, "OVERLAY")
        dash:SetColorTexture(1, 1, 1, 1)
        dash:Hide()
        dashes[i] = dash
    end
    return dashes
end

-- Initialize the animated border structure
local function InitAnimatedBorder(ch)
    if ch.animBorder then return ch.animBorder end
    
    ch.animBorder = {
        topDashes = CreateEdgeDashes(ch, 20),
        bottomDashes = CreateEdgeDashes(ch, 20),
        leftDashes = CreateEdgeDashes(ch, 20),
        rightDashes = CreateEdgeDashes(ch, 20),
    }
    
    return ch.animBorder
end

-- Update animated border
function UpdateAnimatedBorder(ch, offset)
    local border = ch.animBorder
    if not border then return end
    
    local thick = ch.animThickness or 2
    local r, g, b, a = ch.animR or 1, ch.animG or 1, ch.animB or 1, ch.animA or 1
    
    local width = ch:GetWidth()
    local height = ch:GetHeight()
    
    if width <= 0 or height <= 0 then return end
    
    -- Helper to draw dashes along an edge
    local function DrawHorizontalEdge(dashes, y, leftToRight, edgeOffset)
        local numDashes = math.ceil(width / PATTERN_LENGTH) + 2
        
        -- Hide all first
        for i, dash in ipairs(dashes) do
            dash:Hide()
        end
        
        local startPos = -(edgeOffset % PATTERN_LENGTH)
        
        for i = 1, numDashes do
            local dashStart = startPos + (i - 1) * PATTERN_LENGTH
            local dashEnd = dashStart + DASH_LENGTH
            
            -- Clamp to bounds
            local visStart = math.max(0, dashStart)
            local visEnd = math.min(width, dashEnd)
            
            if visEnd > visStart and dashes[i] then
                local dash = dashes[i]
                dash:ClearAllPoints()
                dash:SetSize(visEnd - visStart, thick)
                
                if y == 0 then
                    -- Top edge
                    dash:SetPoint("TOPLEFT", ch, "TOPLEFT", visStart, 0)
                else
                    -- Bottom edge
                    dash:SetPoint("BOTTOMLEFT", ch, "BOTTOMLEFT", visStart, 0)
                end
                
                dash:SetVertexColor(r, g, b, a)
                dash:Show()
            end
        end
    end
    
    local function DrawVerticalEdge(dashes, x, topToBottom, edgeOffset)
        local numDashes = math.ceil(height / PATTERN_LENGTH) + 2
        
        -- Hide all first
        for i, dash in ipairs(dashes) do
            dash:Hide()
        end
        
        local startPos = -(edgeOffset % PATTERN_LENGTH)
        
        for i = 1, numDashes do
            local dashStart = startPos + (i - 1) * PATTERN_LENGTH
            local dashEnd = dashStart + DASH_LENGTH
            
            -- Clamp to bounds
            local visStart = math.max(0, dashStart)
            local visEnd = math.min(height, dashEnd)
            
            if visEnd > visStart and dashes[i] then
                local dash = dashes[i]
                dash:ClearAllPoints()
                dash:SetSize(thick, visEnd - visStart)
                
                if x == 0 then
                    -- Left edge
                    dash:SetPoint("TOPLEFT", ch, "TOPLEFT", 0, -visStart)
                else
                    -- Right edge
                    dash:SetPoint("TOPRIGHT", ch, "TOPRIGHT", 0, -visStart)
                end
                
                dash:SetVertexColor(r, g, b, a)
                dash:Show()
            end
        end
    end
    
    -- Calculate offsets for continuous clockwise animation
    -- Top: moves right (offset increases)
    -- Right: moves down (offset increases after top)
    -- Bottom: moves left (offset increases after top+right, but reversed visually)
    -- Left: moves up (offset increases after top+right+bottom, but reversed visually)
    
    local topOffset = offset
    local rightOffset = offset + width
    local bottomOffset = offset + width + height
    local leftOffset = offset + 2 * width + height
    
    -- For bottom and left, we reverse the direction by using pattern - offset
    DrawHorizontalEdge(border.topDashes, 0, true, topOffset)
    DrawVerticalEdge(border.rightDashes, 1, true, rightOffset)
    DrawHorizontalEdge(border.bottomDashes, 1, false, PATTERN_LENGTH - (bottomOffset % PATTERN_LENGTH))
    DrawVerticalEdge(border.leftDashes, 0, false, PATTERN_LENGTH - (leftOffset % PATTERN_LENGTH))
end

-- Hide animated border
local function HideAnimatedBorder(ch)
    if ch.animBorder then
        for _, dashes in pairs(ch.animBorder) do
            for _, dash in ipairs(dashes) do
                dash:Hide()
            end
        end
    end
    SelectionAnimator.frames[ch] = nil
end

-- Hook Blizzard's highlight to hide it when using custom mode
-- These hooks run when Blizzard shows/hides the highlight, which works in combat
local function HookBlizzardHighlight(frame)
    if frame.dfHighlightHooked then return end
    
    -- Hook selection highlight Show
    if frame.selectionHighlight and not frame.selectionHighlight.dfShowHooked then
        frame.selectionHighlight:HookScript("OnShow", function(self)
            local db = DF:GetDB(frame)
            if db and db.selectionHighlightMode ~= "BLIZZARD" then
                self:SetAlpha(0)
            end
        end)
        frame.selectionHighlight.dfShowHooked = true
    end
    
    -- Hook aggro highlight Show
    if frame.aggroHighlight and not frame.aggroHighlight.dfShowHooked then
        frame.aggroHighlight:HookScript("OnShow", function(self)
            local db = DF:GetDB(frame)
            if db and db.aggroHighlightMode ~= "BLIZZARD" then
                self:SetAlpha(0)
            end
        end)
        frame.aggroHighlight.dfShowHooked = true
    end
    
    frame.dfHighlightHooked = true
end

-- Create or get the custom highlight frame for selection
local function GetSelectionHighlight(frame)
    if frame.dfSelectionHighlight then return frame.dfSelectionHighlight end
    
    local ch = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    ch:SetFrameLevel(frame:GetFrameLevel() + 10)
    ch:SetAllPoints(frame)
    ch:Hide()
    
    frame.dfSelectionHighlight = ch
    return ch
end

-- Create or get the custom highlight frame for aggro
local function GetAggroHighlight(frame)
    if frame.dfAggroHighlight then return frame.dfAggroHighlight end
    
    local ch = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    ch:SetFrameLevel(frame:GetFrameLevel() + 11) -- Slightly higher than selection
    ch:SetAllPoints(frame)
    ch:Hide()
    
    frame.dfAggroHighlight = ch
    return ch
end

-- Apply the custom highlight styling
local function ApplyHighlightStyle(ch, mode, thickness, inset, r, g, b, alpha)
    -- Reset previous styling
    if ch.corners then 
        for _, tex in ipairs(ch.corners) do tex:Hide() end 
    end
    if ch.glow then ch.glow:Hide() end
    ch:SetBackdrop(nil)
    HideAnimatedBorder(ch)
    
    -- Apply positioning with inset
    ch:ClearAllPoints()
    local ins = inset or 0
    ch:SetPoint("TOPLEFT", ch:GetParent(), "TOPLEFT", ins, -ins)
    ch:SetPoint("BOTTOMRIGHT", ch:GetParent(), "BOTTOMRIGHT", -ins, ins)
    
    local thick = thickness or 2
    local alp = alpha or 1
    
    if mode == "SOLID" then
        ch:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = thick,
        })
        ch:SetBackdropBorderColor(r, g, b, alp)
        
    elseif mode == "ANIMATED" then
        InitAnimatedBorder(ch)
        ch.animThickness = thick
        ch.animR, ch.animG, ch.animB, ch.animA = r, g, b, alp
        
        SelectionAnimator.frames[ch] = true
        UpdateAnimatedBorder(ch, 0)
        
    elseif mode == "DASHED" then
        InitAnimatedBorder(ch)
        ch.animThickness = thick
        ch.animR, ch.animG, ch.animB, ch.animA = r, g, b, alp
        
        -- Static - just draw once with offset 0
        UpdateAnimatedBorder(ch, 0)
        
    elseif mode == "CORNERS" then
        if not ch.corners then ch.corners = {} end
        local function GetTex(i)
            if not ch.corners[i] then 
                ch.corners[i] = ch:CreateTexture(nil, "OVERLAY") 
            end
            ch.corners[i]:SetColorTexture(1, 1, 1, 1)
            return ch.corners[i]
        end
        
        local lineLen = 10 
        
        local t1 = GetTex(1); t1:ClearAllPoints(); t1:SetPoint("TOPLEFT"); t1:SetSize(lineLen, thick); t1:Show()
        local t2 = GetTex(2); t2:ClearAllPoints(); t2:SetPoint("TOPLEFT"); t2:SetSize(thick, lineLen); t2:Show()
        local t3 = GetTex(3); t3:ClearAllPoints(); t3:SetPoint("TOPRIGHT"); t3:SetSize(lineLen, thick); t3:Show()
        local t4 = GetTex(4); t4:ClearAllPoints(); t4:SetPoint("TOPRIGHT"); t4:SetSize(thick, lineLen); t4:Show()
        local t5 = GetTex(5); t5:ClearAllPoints(); t5:SetPoint("BOTTOMLEFT"); t5:SetSize(lineLen, thick); t5:Show()
        local t6 = GetTex(6); t6:ClearAllPoints(); t6:SetPoint("BOTTOMLEFT"); t6:SetSize(thick, lineLen); t6:Show()
        local t7 = GetTex(7); t7:ClearAllPoints(); t7:SetPoint("BOTTOMRIGHT"); t7:SetSize(lineLen, thick); t7:Show()
        local t8 = GetTex(8); t8:ClearAllPoints(); t8:SetPoint("BOTTOMRIGHT"); t8:SetSize(thick, lineLen); t8:Show()
        
        for _, tex in ipairs(ch.corners) do
            if tex:IsShown() then tex:SetVertexColor(r, g, b, alp) end
        end
        
    elseif mode == "GLOW" then
        ch:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = thick,
        })
        ch:SetBackdropBorderColor(r, g, b, alp)
        
        if not ch.glow then 
            ch.glow = ch:CreateTexture(nil, "BACKGROUND")
            ch.glow:SetAllPoints()
            ch.glow:SetTexture("Interface\\Buttons\\WHITE8x8")
        end
        ch.glow:Show()
        ch.glow:SetVertexColor(r, g, b, alp * 0.15)
    end
end

-- HIGHLIGHT CHECK TIMER
if not DF.HighlightTimer then
    DF.HighlightTimer = C_Timer.NewTicker(0.1, function()
        local inCombat = InCombatLockdown()
        
        DF:IterateCompactFrames(function(frame)
            HookBlizzardHighlight(frame)
            
            if not frame.unit or not UnitExists(frame.unit) then 
                if frame.dfSelectionHighlight then 
                    HideAnimatedBorder(frame.dfSelectionHighlight)
                    frame.dfSelectionHighlight:Hide() 
                end
                if frame.dfAggroHighlight then 
                    HideAnimatedBorder(frame.dfAggroHighlight)
                    frame.dfAggroHighlight:Hide() 
                end
                return 
            end
            
            local db = DF:GetDB(frame)
            if not db then return end
            
            local selectionMode = db.selectionHighlightMode or "BLIZZARD"
            local aggroMode = db.aggroHighlightMode or "BLIZZARD"
            
            -- Check if unit is selected by looking at Blizzard's highlight state
            -- IsShown() returns true even if alpha is 0, which is what we want
            local isSelected = frame.selectionHighlight and frame.selectionHighlight:IsShown()
            
            -- Check aggro status directly via threat API (more reliable than checking highlight)
            local status = UnitThreatSituation(frame.unit)
            local isAggro = status and status > 0
            
            -- Only modify Blizzard's alpha when NOT in combat (to avoid taint)
            if not inCombat then
                -- Hide/show Blizzard's selection highlight based on mode
                if frame.selectionHighlight then
                    local mt = getmetatable(frame.selectionHighlight)
                    if mt and mt.__index and mt.__index.SetAlpha then
                        if isSelected and selectionMode ~= "BLIZZARD" then
                            mt.__index.SetAlpha(frame.selectionHighlight, 0)
                        elseif isSelected and selectionMode == "BLIZZARD" then
                            mt.__index.SetAlpha(frame.selectionHighlight, 1)
                        end
                    end
                end
                
                -- Hide/show Blizzard's aggro highlight based on mode
                if frame.aggroHighlight then
                    local mt = getmetatable(frame.aggroHighlight)
                    if mt and mt.__index and mt.__index.SetAlpha then
                        if isAggro and aggroMode ~= "BLIZZARD" then
                            mt.__index.SetAlpha(frame.aggroHighlight, 0)
                        elseif isAggro and aggroMode == "BLIZZARD" then
                            mt.__index.SetAlpha(frame.aggroHighlight, 1)
                        end
                    end
                end
            end
            
            -- Determine what custom highlights we want
            local wantCustomSelection = isSelected and selectionMode ~= "BLIZZARD" and selectionMode ~= "NONE"
            local wantCustomAggro = isAggro and aggroMode ~= "BLIZZARD" and aggroMode ~= "NONE"
            
            -- Handle Selection Highlight
            local selectionHighlight = GetSelectionHighlight(frame)
            
            if wantCustomSelection then
                local mode = selectionMode
                local thickness = db.selectionHighlightThickness or 2
                local inset = db.selectionHighlightInset or 0
                local alpha = db.selectionHighlightAlpha or 1
                local c = db.selectionHighlightColor or {r=1, g=1, b=1}
                local r, g, b = c.r, c.g, c.b
                
                ApplyHighlightStyle(selectionHighlight, mode, thickness, inset, r, g, b, alpha)
                selectionHighlight:Show()
            else
                HideAnimatedBorder(selectionHighlight)
                selectionHighlight:Hide()
            end
            
            -- Handle Aggro Highlight (separate frame so both can show)
            local aggroHighlight = GetAggroHighlight(frame)
            
            if wantCustomAggro then
                local mode = aggroMode
                local thickness = db.aggroHighlightThickness or 2
                local inset = db.aggroHighlightInset or 0
                local alpha = db.aggroHighlightAlpha or 1
                local r, g, b
                
                if status and status > 0 then
                    r, g, b = GetThreatStatusColor(status)
                else
                    r, g, b = 1, 0, 0
                end
                
                ApplyHighlightStyle(aggroHighlight, mode, thickness, inset, r, g, b, alpha)
                aggroHighlight:Show()
            else
                HideAnimatedBorder(aggroHighlight)
                aggroHighlight:Hide()
            end
        end)
    end)
end

function DF:HookRaidFrames()
    if CompactUnitFrame_UpdateHealth then
        hooksecurefunc("CompactUnitFrame_UpdateHealth", function(frame) 
            if DF.ApplyHealthColors then DF:ApplyHealthColors(frame) end
            if DF.UpdateHealthText then DF:UpdateHealthText(frame) end
        end)
    end

    if CompactUnitFrame_UpdateMaxHealth then
        hooksecurefunc("CompactUnitFrame_UpdateMaxHealth", function(frame)
            if DF.UpdateHealthText then DF:UpdateHealthText(frame) end
        end)
    end

    if CompactUnitFrame_UpdateHealthColor then
        hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(frame) 
            if DF.ApplyHealthColors then DF:ApplyHealthColors(frame) end
            if DF.UpdateHealthText then DF:UpdateHealthText(frame) end
        end)
    end
    
    if DF.ApplyAuraLayout then
        hooksecurefunc("CompactUnitFrame_UpdateAuras", function(frame) 
            if frame.unit and UnitExists(frame.unit) and DF.ApplyAuraLayout then 
                DF:ApplyAuraLayout(frame) 
            end
        end)
    end
    
    if DF.UpdateDispelIcons then
        if CompactUnitFrame_UpdateDispelDebuffs then
            hooksecurefunc("CompactUnitFrame_UpdateDispelDebuffs", function(frame) 
                if frame.unit and UnitExists(frame.unit) and DF.UpdateDispelIcons then
                    DF:UpdateDispelIcons(frame) 
                end
            end)
        elseif CompactUnitFrame_UpdateStatusIcons then
            hooksecurefunc("CompactUnitFrame_UpdateStatusIcons", function(frame) 
                if frame.unit and UnitExists(frame.unit) and DF.UpdateDispelIcons then
                    DF:UpdateDispelIcons(frame) 
                end
            end)
        end
    end
    
    if CompactUnitFrame_UpdateName and DF.UpdateNameText then
        hooksecurefunc("CompactUnitFrame_UpdateName", function(frame) DF:UpdateNameText(frame) end)
    end
    
    if CompactUnitFrame_UpdateStatusText and DF.UpdateHealthText then
        hooksecurefunc("CompactUnitFrame_UpdateStatusText", function(frame) DF:UpdateHealthText(frame) end)
    end

    if CompactUnitFrame_UpdateStatusIcons and DF.UpdateIcons then
        hooksecurefunc("CompactUnitFrame_UpdateStatusIcons", function(frame) DF:UpdateIcons(frame) end)
    end
    
    if CompactUnitFrame_UpdateMaxPower and DF.ApplyResourceBarLayout and DF.UpdateResourceBar then
        hooksecurefunc("CompactUnitFrame_UpdateMaxPower", function(frame) 
            DF:ApplyResourceBarLayout(frame)
            DF:UpdateResourceBar(frame)
        end)
    end
    if CompactUnitFrame_UpdatePower and DF.UpdateResourceBar then
        hooksecurefunc("CompactUnitFrame_UpdatePower", function(frame) DF:UpdateResourceBar(frame) end)
    end
    if CompactUnitFrame_UpdatePowerColor and DF.UpdateResourceBar then
        hooksecurefunc("CompactUnitFrame_UpdatePowerColor", function(frame) DF:UpdateResourceBar(frame) end)
    end

    if CompactUnitFrame_UpdateHealPrediction then
        hooksecurefunc("CompactUnitFrame_UpdateHealPrediction", function(frame) 
            if DF.UpdateAbsorb then DF:UpdateAbsorb(frame) end
            if DF.UpdateHealAbsorb then DF:UpdateHealAbsorb(frame) end
        end)
    end

    if DF.ApplyFrameInset then
        if CompactUnitFrame_UpdateAll then
            hooksecurefunc("CompactUnitFrame_UpdateAll", function(frame) 
                if frame.unit and UnitExists(frame.unit) or DF.demoMode then
                    if DF.ApplyFrameLayout then DF:ApplyFrameLayout(frame) end
                    DF:ApplyFrameInset(frame)
                    if DF.ApplyTexture then DF:ApplyTexture(frame) end
                    if DF.ApplyBarOrientation then DF:ApplyBarOrientation(frame) end 
                    if DF.ApplyAbsorbLayout then DF:ApplyAbsorbLayout(frame) end
                    if DF.UpdateAbsorb then DF:UpdateAbsorb(frame) end
                    if DF.UpdateMidnightIcon then DF:UpdateMidnightIcon(frame) end
                    if DF.UpdateHealAbsorb then DF:UpdateHealAbsorb(frame) end
                    HookDispelOverlay(frame)
                    EnforceDispelOverlayLevel(frame)
                end
            end)
        end
        
        if CompactUnitFrame_SetUpFrame then
            hooksecurefunc("CompactUnitFrame_SetUpFrame", function(frame) 
                if frame.unit and UnitExists(frame.unit) or DF.demoMode then
                    if DF.ApplyFrameLayout then DF:ApplyFrameLayout(frame) end
                    DF:ApplyFrameInset(frame) 
                    if DF.ApplyTexture then DF:ApplyTexture(frame) end
                    if DF.ApplyBarOrientation then DF:ApplyBarOrientation(frame) end 
                    if DF.ApplyAbsorbLayout then DF:ApplyAbsorbLayout(frame) end
                    if DF.UpdateMidnightIcon then DF:UpdateMidnightIcon(frame) end
                    if DF.UpdateHealAbsorb then DF:UpdateHealAbsorb(frame) end
                    HookDispelOverlay(frame)
                    EnforceDispelOverlayLevel(frame)
                end
            end)
        end
    end

    if CompactUnitFrame_UpdateVisible then
        hooksecurefunc("CompactUnitFrame_UpdateVisible", function(frame)
            if DF.demoMode and frame.unit == "dandersdemo" then
                frame:Show()
            end
        end)
    end
end