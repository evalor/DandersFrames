local addonName, DF = ...

function DF:ApplyResourceBarLayout(frame)
    if not DF:IsValidFrame(frame) then return end

    local unit = frame.unit or frame.displayedUnit
    local db = DF:GetDB(frame)
    local isEditMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()

    if db.resourceBarEnabled then
        if frame.powerBar then
            frame.powerBar:Hide()
            frame.powerBar:SetAlpha(0)
        end
        
        -- Updated Padding Logic
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
            
            if db.resourceBarMatchWidth and frame.healthBar then
                local w = 50 
                local success = pcall(function()
                    local hw = frame.healthBar:GetWidth()
                    if hw and hw > 1 then 
                        w = hw 
                    else
                        local fw = frame:GetWidth()
                        local pad = db.framePadding or 0
                        if fw then w = fw - (pad*2) end
                    end
                end)
                bar:SetWidth(w)
            else
                bar:SetWidth(db.resourceBarWidth or 50)
            end
            
            bar:SetHeight(db.resourceBarHeight or 4)
            local anchor = db.resourceBarAnchor or "CENTER"
            bar:SetPoint(anchor, frame, anchor, db.resourceBarX or 0, db.resourceBarY or 0)
        else
            bar:Hide()
        end
    else
        if frame.dfPowerBar then frame.dfPowerBar:Hide() end
        if frame.powerBar then 
            frame.powerBar:Show() 
            frame.powerBar:SetAlpha(1)
        end
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