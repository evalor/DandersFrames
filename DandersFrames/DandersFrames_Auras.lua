local addonName, DF = ...

-- Applies the custom layout (scale, anchor, growth, wrap) to aura icons
function DF:ApplyAuraLayout(frame)
    -- Use strict validation to block nameplates
    if not DF:IsValidFrame(frame) then return end

    local unit = frame.unit or frame.displayedUnit
    if not frame.buffFrames and not frame.debuffFrames then return end

    local db = DF:GetDB(frame)
    
    -- Calculate Anchor points relative to growth direction
    local function GetRelativePoints(direction)
        if direction == "LEFT" then
            return "RIGHT", "LEFT", -2, 0
        elseif direction == "RIGHT" then
            return "LEFT", "RIGHT", 2, 0
        elseif direction == "UP" then
            return "BOTTOM", "TOP", 0, 2
        elseif direction == "DOWN" then
            return "TOP", "BOTTOM", 0, -2
        else
            -- Fallback
            return "LEFT", "RIGHT", 2, 0
        end
    end

    -- Parse "PRIMARY_SECONDARY" growth strings (e.g., "LEFT_DOWN")
    local function ApplyLayout(auraFrames, scale, alpha, anchor, growthString, limit, offX, offY, maxCount, clickThrough)
        if not auraFrames then return end
        
        -- Split growth direction string
        local primary, secondary = strsplit("_", growthString or "LEFT_DOWN")
        primary = primary or "LEFT"
        secondary = secondary or "DOWN"
        
        -- 1. Determine Primary Growth (Connection between neighbor icons)
        local pPoint, pRelPoint, pX, pY = GetRelativePoints(primary)
        
        -- 2. Determine Secondary Wrap (Connection between new row/col and start of previous)
        local sX, sY = 0, 0
        local wrapSize = 20 * scale -- Base icon size (approx 17px) + gap * scale
        
        if secondary == "DOWN" then
            sY = -wrapSize
        elseif secondary == "UP" then
            sY = wrapSize
        elseif secondary == "LEFT" then
            sX = -wrapSize
        elseif secondary == "RIGHT" then
            sX = wrapSize
        end

        -- Apply layout to each aura
        for i, aura in ipairs(auraFrames) do
            if i > (maxCount or 99) then
                aura:Hide()
            elseif aura:IsShown() then
                aura:SetScale(scale)
                aura:SetAlpha(alpha or 1.0)
                
                -- FORCE CLICK-THROUGH IN DEMO MODE
                if DF.demoMode and unit == "dandersdemo" then
                    aura:EnableMouse(false)
                else
                    aura:EnableMouse(not clickThrough)
                end
                
                aura:ClearAllPoints()
                
                if i == 1 then
                    -- First Icon anchors directly to the frame
                    aura:SetPoint(anchor, frame, anchor, offX, offY)
                else
                    -- Check for Wrap condition
                    local isNewRow = ((i - 1) % limit) == 0
                    
                    if isNewRow then
                        -- Anchor to the start of the previous row (i - limit)
                        local prevRowStart = auraFrames[i - limit]
                        if prevRowStart and prevRowStart:IsShown() then
                            -- Use "TOPLEFT" for consistent wrap alignment relative to the previous row start
                            aura:SetPoint("TOPLEFT", prevRowStart, "TOPLEFT", sX, sY)
                        else
                            -- Fallback
                            aura:SetPoint(anchor, frame, anchor, offX, offY)
                        end
                    else
                        -- Normal Growth (anchors to immediate previous icon)
                        local prev = auraFrames[i-1]
                        if prev and prev:IsShown() then
                            aura:SetPoint(pPoint, prev, pRelPoint, pX, pY)
                        else
                            -- Fallback
                            aura:SetPoint(anchor, frame, anchor, offX, offY)
                        end
                    end
                end
            end
        end
    end

    -- Apply to Buffs
    ApplyLayout(
        frame.buffFrames, 
        db.raidBuffScale, 
        db.raidBuffAlpha,
        db.raidBuffAnchor, 
        db.raidBuffGrowth, 
        db.raidBuffWrap, 
        db.raidBuffOffsetX, 
        db.raidBuffOffsetY,
        db.raidBuffMax, 
        db.raidBuffClickThrough 
    )

    -- Apply to Debuffs
    ApplyLayout(
        frame.debuffFrames, 
        db.raidDebuffScale, 
        db.raidDebuffAlpha,
        db.raidDebuffAnchor, 
        db.raidDebuffGrowth, 
        db.raidDebuffWrap, 
        db.raidDebuffOffsetX, 
        db.raidDebuffOffsetY,
        db.raidDebuffMax, 
        db.raidDebuffClickThrough 
    )
end

-- SHOW FAKE DEMO AURAS
function DF:UpdateDemoAuras(frame)
    -- Ensure Frames Exist
    if not frame.debuffFrames then frame.debuffFrames = {} end
    if not frame.buffFrames then frame.buffFrames = {} end
    
    -- 1. FAKE DEBUFFS
    local fakeDebuffs = {
        { icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", type = "Magic", color = DebuffTypeColor["Magic"] },
        { icon = "Interface\\Icons\\Spell_Nature_Regeneration", type = "Poison", color = DebuffTypeColor["Poison"] },
        { icon = "Interface\\Icons\\Spell_Holy_WordFortitude", type = "Curse", color = DebuffTypeColor["Curse"] },
    }

    for i, debuffInfo in ipairs(fakeDebuffs) do
        local f = frame.debuffFrames[i]
        if not f then
            f = CreateFrame("Button", nil, frame, "CompactAuraTemplate")
            frame.debuffFrames[i] = f
        end
        
        if f then
            f:Show()
            f:EnableMouse(false) -- Disable mouse interaction
            f:SetScript("OnEnter", nil) -- Ensure no tooltips scripts run
            f:SetScript("OnLeave", nil)
            
            if f.icon then f.icon:SetTexture(debuffInfo.icon) end
            if f.border then 
                f.border:SetVertexColor(debuffInfo.color.r, debuffInfo.color.g, debuffInfo.color.b)
                f.border:Show()
            end
        end
    end
    
    -- Hide excess debuffs
    for i = #fakeDebuffs + 1, #frame.debuffFrames do
        if frame.debuffFrames[i] then frame.debuffFrames[i]:Hide() end
    end

    -- 2. FAKE BUFFS (NEW)
    local fakeBuffs = {
        { icon = "Interface\\Icons\\Spell_Holy_PowerWordShield" },
        { icon = "Interface\\Icons\\Spell_Nature_Rejuvenation" },
        { icon = "Interface\\Icons\\Spell_Holy_FlashHeal" },
    }

    for i, buffInfo in ipairs(fakeBuffs) do
        local f = frame.buffFrames[i]
        if not f then
            f = CreateFrame("Button", nil, frame, "CompactAuraTemplate")
            frame.buffFrames[i] = f
        end
        
        if f then
            f:Show()
            f:EnableMouse(false) -- Disable mouse interaction
            f:SetScript("OnEnter", nil) -- Ensure no tooltips scripts run
            f:SetScript("OnLeave", nil)
            
            if f.icon then f.icon:SetTexture(buffInfo.icon) end
            if f.border then f.border:Hide() end -- Buffs usually don't have type borders
        end
    end

    -- Hide excess buffs
    for i = #fakeBuffs + 1, #frame.buffFrames do
        if frame.buffFrames[i] then frame.buffFrames[i]:Hide() end
    end
    
    -- Trigger Layout
    DF:ApplyAuraLayout(frame)
end