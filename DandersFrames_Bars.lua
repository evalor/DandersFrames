local addonName, DF = ...

-- ============================================================
-- RESOURCE BAR LOGIC
-- ============================================================

function DF:ApplyResourceBarLayout(frame)
    if not DF:IsValidFrame(frame) then return end

    local unit = frame.unit or frame.displayedUnit
    local db = DF:GetDB(frame)
    local isEditMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()

    -- UPDATED: Always hide the default power bar (override enabled by default)
    if frame.powerBar then
        frame.powerBar:Hide()
        frame.powerBar:SetAlpha(0)
        -- Unregister events to prevent it from reappearing or updating
        if frame.powerBar.UnregisterAllEvents then 
            frame.powerBar:UnregisterAllEvents() 
        end
    end

    if db.resourceBarEnabled then
        -- Updated Padding Logic (Only applies if using custom bar to avoid conflict)
        if frame.healthBar then
             local pt = db.useSpecificPadding and db.paddingTop or db.framePadding or 0
             local pb = db.useSpecificPadding and db.paddingBottom or db.framePadding or 0
             local pl = db.useSpecificPadding and db.paddingLeft or db.framePadding or 0
             local pr = db.useSpecificPadding and db.paddingRight or db.framePadding or 0
             
             frame.healthBar:ClearAllPoints()
             frame.healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", pl, -pt)
             frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pr, pb)
        end

        local showBar = true
        if db.resourceBarHealerOnly then
            if isEditMode then
                showBar = true 
            elseif DF.demoMode and unit == "dandersdemo" then
                showBar = true -- Force show in demo mode
            elseif unit then
                local role = UnitGroupRolesAssigned(unit)
                if role ~= "HEALER" then
                    showBar = false
                end
            end
        end

        if not frame.dfPowerBar then
            frame.dfPowerBar = CreateFrame("StatusBar", nil, frame)
            frame.dfPowerBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
            frame.dfPowerBar:SetMinMaxValues(0, 1)
            frame.dfPowerBar:SetFrameLevel(frame.healthBar:GetFrameLevel() + 2)
            
            local bg = frame.dfPowerBar:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(true)
            bg:SetColorTexture(0, 0, 0, 0.5)
            frame.dfPowerBar.bg = bg
        end

        local bar = frame.dfPowerBar
        
        if showBar then
            bar:Show()
            bar:ClearAllPoints()
            
            -- Orientation & Fill Direction
            bar:SetOrientation(db.resourceBarOrientation or "HORIZONTAL")
            bar:SetReverseFill(db.resourceBarReverseFill)

            local isVertical = (db.resourceBarOrientation == "VERTICAL")
            local length = db.resourceBarWidth or 50
            local thickness = db.resourceBarHeight or 4

            if isVertical then
                 -- SWAP: "Width" Value applies to Height (Length), "Height" value applies to Width (Thickness)
                 bar:SetWidth(thickness)
                 bar:SetHeight(length)
                 
                 if db.resourceBarMatchWidth then
                     -- MATCH HEIGHT LOGIC (Overrides Length)
                     local h = 50 
                     local success = pcall(function()
                         local hh = frame.healthBar:GetHeight()
                         if hh and hh > 1 then h = hh else h = frame:GetHeight() end
                     end)
                     bar:SetHeight(h)
                 end
            else
                 -- NORMAL: "Width" Value applies to Width, "Height" value applies to Height
                 bar:SetWidth(length)
                 bar:SetHeight(thickness)
                 
                 if db.resourceBarMatchWidth then
                     -- MATCH WIDTH LOGIC (Overrides Length)
                     local w = 50 
                     local success = pcall(function()
                         local hw = frame.healthBar:GetWidth()
                         if hw and hw > 1 then w = hw else w = frame:GetWidth() end
                     end)
                     bar:SetWidth(w)
                 end
            end
            
            local anchor = db.resourceBarAnchor or "CENTER"
            bar:SetPoint(anchor, frame, anchor, db.resourceBarX or 0, db.resourceBarY or 0)
        else
            bar:Hide()
        end
    else
        -- If Custom Bar is disabled, just hide it. 
        if frame.dfPowerBar then frame.dfPowerBar:Hide() end
    end
end

function DF:UpdateResourceBar(frame)
    if not DF:IsValidFrame(frame) then return end

    local db = DF:GetDB(frame)
    if not db.resourceBarEnabled then return end
    if not frame.dfPowerBar or not frame.dfPowerBar:IsShown() then return end

    local bar = frame.dfPowerBar
    local unit = frame.unit or frame.displayedUnit
    
    -- FAKE DEMO BAR
    if DF.demoMode and unit == "dandersdemo" then
        bar:SetMinMaxValues(0, 100)
        bar:SetValue(100)
        bar:SetStatusBarColor(0, 0, 1, 1) -- Blue Mana
        bar:Show()
        return
    end
    
    if (not unit or not UnitExists(unit)) and EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        bar:SetMinMaxValues(0, 100)
        bar:SetValue(60) 
        bar:SetStatusBarColor(0, 0, 1, 1) 
        return 
    end

    if not unit or not UnitExists(unit) then 
        bar:Hide()
        return 
    end
    
    local pp = UnitPower(unit)
    local mpp = UnitPowerMax(unit)

    if type(pp) ~= "number" or type(mpp) ~= "number" then 
        bar:Hide() 
        return 
    end

    bar:SetMinMaxValues(0, mpp)
    bar:SetValue(pp)

    local pType, pToken, altR, altG, altB = UnitPowerType(unit)
    local info = PowerBarColor[pToken] or PowerBarColor[pType]
    
    if info then
        bar:SetStatusBarColor(info.r, info.g, info.b)
    elseif altR then
        bar:SetStatusBarColor(altR, altG, altB)
    else
        bar:SetStatusBarColor(0, 0, 1)
    end
end

-- ============================================================
-- ABSORB BAR LOGIC
-- ============================================================

-- Updates the absorb glow overlay and the absorb bar (floating or overlay)
function DF:UpdateAbsorb(frame)
    if not DF:IsValidFrame(frame) then return end
    local db = DF:GetDB(frame)
    local unit = frame.unit or frame.displayedUnit
    
    -- CHECK: Valid Unit
    if not unit then 
        if frame.dfAbsorbBar then frame.dfAbsorbBar:Hide() end
        return 
    end
    
    -- Blizzard Frames use these names for the absorb glow and the overlay container
    local glow = frame.overAbsorbGlow
    local absorbFrame = frame.totalAbsorb
    local overlay = frame.totalAbsorbOverlay -- The texture frame you want hidden
    local mode = db.absorbBarMode or "OVERLAY"

    -- ============================================================
    -- MODE: BLIZZARD DEFAULT
    -- ============================================================
    if mode == "BLIZZARD" then
        -- Reset/Hide Custom Bar
        if frame.dfAbsorbBar then frame.dfAbsorbBar:Hide() end
        
        -- Restore Blizzard Frames
        if absorbFrame then absorbFrame:Show() end
        if overlay then overlay:Show() end
        
        -- Restore Glow Logic (or leave it to Blizzard)
        if glow then 
             glow:SetAlpha(1)
             -- We don't mess with anchoring here, effectively letting Blizzard (or other addons) handle it
        end
        return
    end

    -- ============================================================
    -- CUSTOM MODES (OVERLAY & FLOATING)
    -- ============================================================
    
    -- Hide Blizzard's default absorb frame & overlay to avoid duplicates/clutter
    if absorbFrame then absorbFrame:Hide() end
    if overlay then overlay:Hide() end

    -- Create Custom Absorb Bar if needed
    if not frame.dfAbsorbBar then
        -- Default to frame parent for flexibility (Floating support)
        frame.dfAbsorbBar = CreateFrame("StatusBar", nil, frame)
        frame.dfAbsorbBar:SetMinMaxValues(0, 1)
        frame.dfAbsorbBar:EnableMouse(false)
        
        -- Create Background for floating mode visibility (Dark Container)
        local bg = frame.dfAbsorbBar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.5)
        frame.dfAbsorbBar.bg = bg

        -- Create Solid Backing for Stripes (The colored bar BEHIND the stripe texture)
        local solid = CreateFrame("StatusBar", nil, frame.dfAbsorbBar)
        solid:SetAllPoints(frame.dfAbsorbBar)
        solid:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        solid:GetStatusBarTexture():SetDrawLayer("ARTWORK", 0)
        frame.dfAbsorbBar.solid = solid
    end
    
    local customBar = frame.dfAbsorbBar
    local solidBar = customBar.solid
    
    -- STRATA LOGIC
    local strata = db.absorbBarStrata or "MEDIUM"
    local useSandwich = (strata == "SANDWICH")
    local useSandwichLow = (strata == "SANDWICH_LOW")
    local healthLevel = frame.healthBar:GetFrameLevel()
    
    -- Calculate absorb level based on mode
    -- For SANDWICH modes, we put the bar between healthBar (level 3) and DispelOverlay (which we'll raise to level 10+)
    local absorbLevel
    if useSandwich then
        -- SANDWICH: Above health (3), below raised DispelOverlay (10)
        absorbLevel = healthLevel + 3  -- Level 6
    elseif useSandwichLow then
        -- SANDWICH_LOW: Just above health
        absorbLevel = healthLevel + 1  -- Level 4
    else
        -- Standard: High above everything
        absorbLevel = healthLevel + 15
    end
    
    -- Apply to bar
    customBar:SetParent(frame)
    customBar:SetFrameStrata(frame:GetFrameStrata())
    customBar:SetFrameLevel(absorbLevel)
    if solidBar then
        solidBar:SetFrameLevel(absorbLevel)
    end
    
    -- CRITICAL FIX: Raise DispelOverlay level ABOVE our bar for sandwich modes
    if (useSandwich or useSandwichLow) and frame.DispelOverlay then
        local ov = frame.DispelOverlay
        -- Ensure same strata
        ov:SetFrameStrata(frame:GetFrameStrata())
        -- Raise DispelOverlay to be ABOVE our absorb bar
        local dispelLevel = absorbLevel + 5  -- e.g., Level 11 for SANDWICH, Level 9 for SANDWICH_LOW
        ov:SetFrameLevel(dispelLevel)
    end
    
    -- Update Appearance (Texture & Color)
    local tex = db.absorbBarTexture or "Interface\\Buttons\\WHITE8x8"
    local col = db.absorbBarColor or {r=0, g=0.835, b=1, a=0.7}
    
    -- PROCEDURAL STRIPES - Using custom TGA texture
    if tex == "DF_STRIPES" then
        -- Hide solid backing - not needed
        if solidBar then solidBar:Hide() end
        
        -- Hide any borders from previous runs
        if customBar.borderTop then customBar.borderTop:Hide() end
        if customBar.borderBottom then customBar.borderBottom:Hide() end
        if customBar.borderLeft then customBar.borderLeft:Hide() end
        if customBar.borderRight then customBar.borderRight:Hide() end
        
        -- Use the custom stripe texture from addon folder
        -- 128x128 with thin stripes and built-in border
        customBar:SetStatusBarTexture("Interface\\AddOns\\DandersFrames\\DF_Stripes")
        local barTex = customBar:GetStatusBarTexture()
        
        -- Disable tiling so the border only appears once around edges
        barTex:SetHorizTile(false)
        barTex:SetVertTile(false)
        barTex:SetTexCoord(0, 1, 0, 1)
        barTex:SetDesaturated(false)
        barTex:SetDrawLayer("ARTWORK", 2)
        barTex:SetBlendMode("BLEND")
        
        -- Apply user's color directly - white texture takes color perfectly
        customBar:SetStatusBarColor(col.r, col.g, col.b, col.a or 0.8)
        
    -- SHIELD OVERLAY - Keep original behavior
    elseif tex == "Interface\\RaidFrame\\Shield-Overlay" then
        if solidBar then solidBar:Hide() end
        
        -- Hide stripe borders if they exist
        if customBar.borderTop then customBar.borderTop:Hide() end
        if customBar.borderBottom then customBar.borderBottom:Hide() end
        if customBar.borderLeft then customBar.borderLeft:Hide() end
        if customBar.borderRight then customBar.borderRight:Hide() end
        if customBar.border then customBar.border:Hide() end
        
        customBar:SetStatusBarTexture(tex)
        local barTex = customBar:GetStatusBarTexture()
        if barTex then
            barTex:SetHorizTile(true)
            barTex:SetVertTile(true)
            barTex:SetTexCoord(0, 2, 0, 1)
            barTex:SetDesaturated(true)
            barTex:SetDrawLayer("ARTWORK", 2)
            barTex:SetBlendMode("ADD")
        end
        
        customBar:SetStatusBarColor(col.r * 2, col.g * 2, col.b * 2, 1)
        
    else
        -- Standard Texture Mode - no solid backing needed
        if solidBar then solidBar:Hide() end
        
        -- Hide stripe borders if they exist
        if customBar.borderTop then customBar.borderTop:Hide() end
        if customBar.borderBottom then customBar.borderBottom:Hide() end
        if customBar.borderLeft then customBar.borderLeft:Hide() end
        if customBar.borderRight then customBar.borderRight:Hide() end
        if customBar.border then customBar.border:Hide() end
        
        customBar:SetStatusBarTexture(tex)
        local barTex = customBar:GetStatusBarTexture()
        if barTex then
            barTex:SetHorizTile(false)
            barTex:SetVertTile(false)
            barTex:SetTexCoord(0, 1, 0, 1)
            barTex:SetDesaturated(false)
            barTex:SetBlendMode("BLEND")
            barTex:SetDrawLayer("ARTWORK", 1)
        end
        
        -- Apply Color to Main Bar
        customBar:SetStatusBarColor(col.r, col.g, col.b, col.a)
    end

    customBar:Show()
    customBar:ClearAllPoints()
    
    local maxHealth = UnitHealthMax(unit)
    local absorbs = UnitGetTotalAbsorbs(unit)
    if maxHealth <= 0 then maxHealth = 1 end

    -- ============================================================
    -- MODE: FLOATING RESOURCE BAR
    -- ============================================================
    if mode == "FLOATING" then
        customBar:SetParent(frame)
        customBar:SetFrameStrata(frame:GetFrameStrata())
        customBar:SetFrameLevel(absorbLevel)
        if solidBar then solidBar:SetFrameLevel(absorbLevel) end
        
        -- For non-sandwich modes, apply user-selected strata
        if not useSandwich and not useSandwichLow then
            customBar:SetFrameStrata(strata)
            if solidBar then solidBar:SetFrameStrata(strata) end
        end
        
        -- CRITICAL: For sandwich modes, raise DispelOverlay ABOVE our bar
        if useSandwich or useSandwichLow then
            if frame.DispelOverlay then
                local ov = frame.DispelOverlay
                local newLevel = absorbLevel + 10
                ov:SetFrameStrata(frame:GetFrameStrata())
                ov:SetFrameLevel(newLevel)
                
                if DF.debugEnabled then
                    print("DF: Set DispelOverlay level to " .. newLevel .. " (absorbLevel=" .. absorbLevel .. ")")
                end
            else
                if DF.debugEnabled then
                    print("DF: frame.DispelOverlay is nil!")
                end
            end
        end
        
        -- Dimensions & Orientation
        local orientation = db.absorbBarOrientation or "HORIZONTAL"
        customBar:SetOrientation(orientation)
        customBar:SetReverseFill(db.absorbBarReverse)
        
        local w = db.absorbBarWidth or 50
        local h = db.absorbBarHeight or 6
        
        if orientation == "VERTICAL" then
             customBar:SetWidth(h)
             customBar:SetHeight(w)
        else
             customBar:SetWidth(w)
             customBar:SetHeight(h)
        end
        
        local anchor = db.absorbBarAnchor or "CENTER"
        local x = db.absorbBarX or 0
        local y = db.absorbBarY or 0
        customBar:SetPoint(anchor, frame, anchor, x, y)
        
        customBar:SetMinMaxValues(0, maxHealth)
        customBar:SetValue(absorbs)
        
        if customBar.bg then 
            customBar.bg:Show() 
            local bgC = db.absorbBarBackgroundColor or {r=0, g=0, b=0, a=0.5}
            customBar.bg:SetColorTexture(bgC.r, bgC.g, bgC.b, bgC.a)
        end

    -- ============================================================
    -- MODE: OVERLAY (Original Behavior)
    -- ============================================================
    else 
        customBar:SetParent(frame.healthBar)
        -- Set frame level above health bar for proper layering
        customBar:SetFrameLevel(absorbLevel)
        if solidBar then solidBar:SetFrameLevel(absorbLevel) end
        
        if customBar.bg then customBar.bg:Hide() end
        
        if frame.healthBar then
            local healthOrient = db.healthOrientation or "HORIZONTAL"
            local overlayReverse = db.absorbBarOverlayReverse or false
            
            customBar:SetAllPoints(frame.healthBar)
            
            customBar:SetMinMaxValues(0, maxHealth)
            customBar:SetValue(absorbs)
            
            -- Default: Absorbs fill from full HP side (reverse=true for normal, reverse=false for inverted)
            -- If overlayReverse is checked, flip the behavior
            if healthOrient == "HORIZONTAL" then
                customBar:SetOrientation("HORIZONTAL")
                customBar:SetReverseFill(not overlayReverse)
            elseif healthOrient == "HORIZONTAL_INV" then
                customBar:SetOrientation("HORIZONTAL")
                customBar:SetReverseFill(overlayReverse)
            elseif healthOrient == "VERTICAL" then
                customBar:SetOrientation("VERTICAL")
                customBar:SetReverseFill(not overlayReverse)
            elseif healthOrient == "VERTICAL_INV" then
                customBar:SetOrientation("VERTICAL")
                customBar:SetReverseFill(overlayReverse)
            end
        else
            customBar:Hide()
        end
    end
    
    -- ============================================================
    -- SYNC SOLID BAR (For Stripes Mode)
    -- ============================================================
    if solidBar and solidBar:IsShown() then
        solidBar:SetMinMaxValues(0, maxHealth)
        solidBar:SetValue(absorbs)
        solidBar:SetOrientation(customBar:GetOrientation())
        solidBar:SetReverseFill(customBar:GetReverseFill())
        -- Ensure size matches if not anchored by SetAllPoints (Floating)
        if mode == "FLOATING" then
            solidBar:SetWidth(customBar:GetWidth())
            solidBar:SetHeight(customBar:GetHeight())
        end
    end

    -- ============================================================
    -- GLOW LOGIC
    -- ============================================================
    if glow then
        local alpha = db.absorbGlowAlpha or 1
        glow:SetAlpha(alpha)
        
        if frame.healthBar then
            glow:ClearAllPoints()
            
            -- Parent glow to frame and set frame level higher than absorb bar
            if glow:GetParent() ~= frame then glow:SetParent(frame) end
            
            -- Create a glow overlay frame if needed to ensure proper z-ordering
            if not frame.dfGlowOverlay then
                frame.dfGlowOverlay = CreateFrame("Frame", nil, frame)
                frame.dfGlowOverlay:SetAllPoints(frame)
            end
            -- Set glow overlay frame level above absorb bar
            -- FIX: Bumped Glow to +18 to sit on top of the Absorb Bar (+15)
            frame.dfGlowOverlay:SetFrameLevel(frame.healthBar:GetFrameLevel() + 18)
            
            -- Reparent glow to the overlay frame
            if glow:GetParent() ~= frame.dfGlowOverlay then 
                glow:SetParent(frame.dfGlowOverlay) 
            end
            glow:SetDrawLayer("OVERLAY", 7)
            
            glow:SetRotation(0)
            glow:SetTexCoord(0, 1, 0, 1)
            
            local anchor = db.absorbGlowAnchor or "RIGHT"
            
            if db.absorbMatchHealthOrientation then
                local healthOrient = db.healthOrientation or "HORIZONTAL"
                if healthOrient == "HORIZONTAL" then anchor = "RIGHT"
                elseif healthOrient == "HORIZONTAL_INV" then anchor = "LEFT"
                elseif healthOrient == "VERTICAL" then anchor = "TOP"
                elseif healthOrient == "VERTICAL_INV" then anchor = "BOTTOM" end
            end
            
            if anchor == "RIGHT" then
                glow:SetWidth(16)
                glow:SetHeight(0) 
                glow:SetPoint("TOPLEFT", frame.healthBar, "TOPRIGHT", -7, 0)
                glow:SetPoint("BOTTOMLEFT", frame.healthBar, "BOTTOMRIGHT", -7, 0)
            elseif anchor == "LEFT" then
                glow:SetWidth(16)
                glow:SetHeight(0)
                glow:SetTexCoord(1, 0, 0, 1)
                glow:SetPoint("TOPRIGHT", frame.healthBar, "TOPLEFT", 7, 0)
                glow:SetPoint("BOTTOMRIGHT", frame.healthBar, "BOTTOMLEFT", 7, 0)
            elseif anchor == "TOP" then
                glow:SetWidth(0)
                glow:SetHeight(16)
                glow:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
                glow:SetPoint("BOTTOMLEFT", frame.healthBar, "TOPLEFT", 0, -7)
                glow:SetPoint("BOTTOMRIGHT", frame.healthBar, "TOPRIGHT", 0, -7)
            elseif anchor == "BOTTOM" then
                glow:SetWidth(0)
                glow:SetHeight(16)
                glow:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
                glow:SetPoint("TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, 7)
                glow:SetPoint("TOPRIGHT", frame.healthBar, "BOTTOMRIGHT", 0, 7)
            end
        end
    end
end

-- ============================================================
-- HEALING ABSORB BAR LOGIC (Necrotic/Heal Absorb Bar)
-- ============================================================
-- NOTE: In WoW Midnight (12.0), UnitGetTotalHealAbsorbs() returns a
-- "secret value" that cannot be compared with ANY Lua operators.
-- We must pass it directly to SetValue() without any checks.
-- The StatusBar will show 0 width if the value is 0, effectively hiding it.
-- ============================================================

function DF:UpdateHealAbsorb(frame)
    if not DF:IsValidFrame(frame) then return end
    if not frame.healthBar then return end
    
    local db = DF:GetDB(frame)
    local unit = frame.unit or frame.displayedUnit
    local mode = db.healAbsorbBarMode or "OVERLAY"
    
    -- ============================================================
    -- MODE: BLIZZARD DEFAULT
    -- ============================================================
    if mode == "BLIZZARD" then
        -- Hide Custom Bar
        if frame.dfHealAbsorbBar then frame.dfHealAbsorbBar:Hide() end
        
        -- Restore Blizzard Frames (don't hide them)
        return
    end
    
    -- ============================================================
    -- CUSTOM MODES: Hide Blizzard elements
    -- ============================================================
    if frame.myHealAbsorb then frame.myHealAbsorb:Hide() end
    if frame.myHealAbsorbLeftShadow then frame.myHealAbsorbLeftShadow:Hide() end
    if frame.myHealAbsorbRightShadow then frame.myHealAbsorbRightShadow:Hide() end
    
    -- Create Custom Bar if needed
    if not frame.dfHealAbsorbBar then
        frame.dfHealAbsorbBar = CreateFrame("StatusBar", nil, frame)
        frame.dfHealAbsorbBar:SetMinMaxValues(0, 1)
        frame.dfHealAbsorbBar:EnableMouse(false)
        
        -- Create Background for floating mode
        local bg = frame.dfHealAbsorbBar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.5)
        frame.dfHealAbsorbBar.bg = bg
    end
    
    local bar = frame.dfHealAbsorbBar
    
    -- Set frame level - Heal absorb should be below regular absorb but above health
    -- STRATA LOGIC: "SANDWICH" MODE
    local strata = db.healAbsorbBarStrata or "MEDIUM"
    local useSandwich = (strata == "SANDWICH")
    local useSandwichLow = (strata == "SANDWICH_LOW")
    local healthLevel = frame.healthBar:GetFrameLevel()

    -- Calculate heal absorb level based on mode
    -- For SANDWICH modes, we put the bar between healthBar (level 3) and DispelOverlay (which we'll raise)
    local healAbsorbLevel
    if useSandwich then
        -- SANDWICH: Above health, below raised DispelOverlay
        healAbsorbLevel = healthLevel + 3
    elseif useSandwichLow then
        -- SANDWICH_LOW: Just above health
        healAbsorbLevel = healthLevel + 1
    else
        -- Standard: High above everything
        healAbsorbLevel = healthLevel + 12
    end
    
    -- Apply parent, strata, and level
    bar:SetParent(frame)
    bar:SetFrameStrata(frame:GetFrameStrata())
    bar:SetFrameLevel(healAbsorbLevel)
    
    -- For non-sandwich modes, apply user-selected strata
    if not useSandwich and not useSandwichLow then
        bar:SetFrameStrata(strata)
    end
    
    -- CRITICAL FIX: Raise DispelOverlay level ABOVE our bar for sandwich modes
    if (useSandwich or useSandwichLow) and frame.DispelOverlay then
        local ov = frame.DispelOverlay
        ov:SetFrameStrata(frame:GetFrameStrata())
        -- Raise DispelOverlay to be ABOVE our heal absorb bar
        ov:SetFrameLevel(healAbsorbLevel + 5)
    end
    
    -- Update Appearance (Texture & Color)
    local tex = db.healAbsorbBarTexture or "Interface\\RaidFrame\\Absorb-Fill"
    local col = db.healAbsorbBarColor or {r = 0.1, g = 0.1, b = 0.1, a = 0.6}
    
    -- Handle special textures like DF_STRIPES
    if tex == "DF_STRIPES" then
        bar:SetStatusBarTexture("Interface\\AddOns\\DandersFrames\\DF_Stripes")
        local barTex = bar:GetStatusBarTexture()
        if barTex then
            barTex:SetHorizTile(false)
            barTex:SetVertTile(false)
            barTex:SetTexCoord(0, 1, 0, 1)
            barTex:SetDesaturated(false)
            barTex:SetDrawLayer("ARTWORK", 2)
            barTex:SetBlendMode("BLEND")
        end
        bar:SetStatusBarColor(col.r, col.g, col.b, col.a or 0.8)
    elseif tex == "DF_STRIPES_FLIP" then
        -- Flipped stripes - creates cross pattern when overlaid with regular stripes
        bar:SetStatusBarTexture("Interface\\AddOns\\DandersFrames\\DF_Stripes")
        local barTex = bar:GetStatusBarTexture()
        if barTex then
            barTex:SetHorizTile(false)
            barTex:SetVertTile(false)
            -- Flip the texture coordinates to reverse the stripe direction
            barTex:SetTexCoord(1, 0, 0, 1)
            barTex:SetDesaturated(false)
            barTex:SetDrawLayer("ARTWORK", 2)
            barTex:SetBlendMode("BLEND")
        end
        bar:SetStatusBarColor(col.r, col.g, col.b, col.a or 0.8)
    elseif tex == "Interface\\RaidFrame\\Shield-Overlay" then
        bar:SetStatusBarTexture(tex)
        local barTex = bar:GetStatusBarTexture()
        if barTex then
            barTex:SetHorizTile(true)
            barTex:SetVertTile(true)
            barTex:SetTexCoord(0, 2, 0, 1)
            barTex:SetDesaturated(true)
            barTex:SetDrawLayer("ARTWORK", 2)
            barTex:SetBlendMode("ADD")
        end
        bar:SetStatusBarColor(col.r * 2, col.g * 2, col.b * 2, 1)
    else
        -- Standard texture
        bar:SetStatusBarTexture(tex)
        local barTex = bar:GetStatusBarTexture()
        if barTex then
            barTex:SetHorizTile(false)
            barTex:SetVertTile(false)
            barTex:SetTexCoord(0, 1, 0, 1)
            barTex:SetDesaturated(false)
            barTex:SetBlendMode("BLEND")
            barTex:SetDrawLayer("ARTWORK", 1)
        end
        bar:SetStatusBarColor(col.r, col.g, col.b, col.a)
    end
    
    -- Check for valid unit
    if not unit or not UnitExists(unit) then 
        bar:Hide()
        return 
    end

    -- Test Heal Absorb mode - show fake bar on real units for testing
    if DF.testHealAbsorb then
        local maxHealth = UnitHealthMax(unit) or 100000
        
        bar:ClearAllPoints()
        
        -- Force a VERY visible color for testing (bright red)
        bar:SetStatusBarColor(1, 0, 0, 0.8)
        
        if mode == "FLOATING" then
            bar:SetParent(frame)
            bar:SetFrameLevel(healAbsorbLevel)
            
            if bar.bg then 
                bar.bg:Show() 
                bar.bg:SetColorTexture(0, 0, 0, 0.8)
            end
            
            local orientation = db.healAbsorbBarOrientation or "HORIZONTAL"
            bar:SetOrientation(orientation)
            bar:SetReverseFill(db.healAbsorbBarReverse or false)
            
            local w = db.healAbsorbBarWidth or 50
            local h = db.healAbsorbBarHeight or 6
            
            if orientation == "VERTICAL" then
                bar:SetWidth(h)
                bar:SetHeight(w)
            else
                bar:SetWidth(w)
                bar:SetHeight(h)
            end
            
            local anchor = db.healAbsorbBarAnchor or "CENTER"
            local x = db.healAbsorbBarX or 0
            local y = db.healAbsorbBarY or 0
            bar:SetPoint(anchor, frame, anchor, x, y)
        else
            -- OVERLAY MODE - parent to healthBar
            bar:SetParent(frame.healthBar)
            bar:SetFrameLevel(healAbsorbLevel)
            if bar.bg then bar.bg:Hide() end
            
            -- Use SetAllPoints to match health bar exactly
            bar:SetAllPoints(frame.healthBar)
            
            local healthOrient = db.healthOrientation or "HORIZONTAL"
            if healthOrient == "HORIZONTAL" then
                bar:SetOrientation("HORIZONTAL")
                bar:SetReverseFill(false)
            elseif healthOrient == "HORIZONTAL_INV" then
                bar:SetOrientation("HORIZONTAL")
                bar:SetReverseFill(true)
            elseif healthOrient == "VERTICAL" then
                bar:SetOrientation("VERTICAL")
                bar:SetReverseFill(false)
            elseif healthOrient == "VERTICAL_INV" then
                bar:SetOrientation("VERTICAL")
                bar:SetReverseFill(true)
            end
        end
        
        -- Show test value (30% of health as heal absorb)
        bar:SetMinMaxValues(0, maxHealth)
        bar:SetValue(maxHealth * 0.3)
        bar:Show()
        
        -- Debug print once per frame
        if DF.debugEnabled then
            local name = frame:GetName() or "?"
            print(string.format("DF: TestHeal on %s - Mode: %s, Parent: %s", 
                name, mode, bar:GetParent():GetName() or "?"))
        end
        return
    end
    
    -- Skip demo unit to avoid secret value errors
    if unit == "dandersdemo" then
        bar:Hide()
        return
    end

    -- Get max health (this is NOT a secret value)
    local maxHealth = UnitHealthMax(unit)
    if not maxHealth or maxHealth <= 0 then maxHealth = 1 end
    
    -- Get heal absorb - this IS a secret value in WoW 12.0+
    -- CRITICAL: Do NOT compare, test, or manipulate this value in any way
    -- Just pass it directly to SetValue()
    local healAbsorb = UnitGetTotalHealAbsorbs(unit)

    bar:ClearAllPoints()
    
    -- ============================================================
    -- MODE: FLOATING BAR
    -- ============================================================
    if mode == "FLOATING" then
        bar:SetParent(frame)
        bar:SetFrameStrata(frame:GetFrameStrata())
        bar:SetFrameLevel(healAbsorbLevel)
        
        -- For non-sandwich modes, apply user-selected strata
        if not useSandwich and not useSandwichLow then
            local barStrata = db.healAbsorbBarStrata or "MEDIUM"
            bar:SetFrameStrata(barStrata)
        end
        
        -- CRITICAL: For sandwich modes, raise DispelOverlay ABOVE our bar
        if (useSandwich or useSandwichLow) and frame.DispelOverlay then
            local ov = frame.DispelOverlay
            ov:SetFrameStrata(frame:GetFrameStrata())
            ov:SetFrameLevel(healAbsorbLevel + 5)
        end
        
        if bar.bg then 
            bar.bg:Show() 
            local bgC = db.healAbsorbBarBackgroundColor or {r = 0, g = 0, b = 0, a = 0.5}
            bar.bg:SetColorTexture(bgC.r, bgC.g, bgC.b, bgC.a)
        end
        
        -- Dimensions & Orientation
        local orientation = db.healAbsorbBarOrientation or "HORIZONTAL"
        bar:SetOrientation(orientation)
        bar:SetReverseFill(db.healAbsorbBarReverse or false)
        
        local w = db.healAbsorbBarWidth or 50
        local h = db.healAbsorbBarHeight or 6
        
        if orientation == "VERTICAL" then
            bar:SetWidth(h)
            bar:SetHeight(w)
        else
            bar:SetWidth(w)
            bar:SetHeight(h)
        end
        
        local anchor = db.healAbsorbBarAnchor or "CENTER"
        local x = db.healAbsorbBarX or 0
        local y = db.healAbsorbBarY or 0
        bar:SetPoint(anchor, frame, anchor, x, y)
        
    -- ============================================================
    -- MODE: OVERLAY (Match Health Bar)
    -- ============================================================
    else
        bar:SetParent(frame.healthBar)
        bar:SetFrameLevel(healAbsorbLevel)
        
        if bar.bg then bar.bg:Hide() end
        
        bar:SetAllPoints(frame.healthBar)
        
        -- Match health bar orientation
        -- Default: Heal absorbs fill from low HP side (opposite of absorbs)
        -- If overlayReverse is checked, flip the behavior
        local healthOrient = db.healthOrientation or "HORIZONTAL"
        local overlayReverse = db.healAbsorbBarOverlayReverse or false
        
        if healthOrient == "HORIZONTAL" then
            bar:SetOrientation("HORIZONTAL")
            bar:SetReverseFill(overlayReverse)
        elseif healthOrient == "HORIZONTAL_INV" then
            bar:SetOrientation("HORIZONTAL")
            bar:SetReverseFill(not overlayReverse)
        elseif healthOrient == "VERTICAL" then
            bar:SetOrientation("VERTICAL")
            bar:SetReverseFill(overlayReverse)
        elseif healthOrient == "VERTICAL_INV" then
            bar:SetOrientation("VERTICAL")
            bar:SetReverseFill(not overlayReverse)
        end
    end
    
    -- CRITICAL: Set min/max BEFORE SetValue, and always show the bar
    -- The bar will render with 0 width if healAbsorb is 0
    bar:SetMinMaxValues(0, maxHealth)
    bar:SetValue(healAbsorb)
    bar:Show()
end

-- Kept empty to satisfy hook calls in DandersFrames_Hooks.lua
function DF:ApplyAbsorbLayout(frame)
    -- Intentionally left blank
end

-- Layout function for heal absorb bar - called when settings change
function DF:ApplyHealAbsorbLayout(frame)
    if DF.UpdateHealAbsorb then
        DF:UpdateHealAbsorb(frame)
    end
end