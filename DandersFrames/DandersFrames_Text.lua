local addonName, DF = ...

-- Utility to ensure a texture frame exists for icons
local function EnsureIcon(parent, key, texturePath)
    if not parent[key] then
        parent[key] = parent:CreateTexture(nil, "OVERLAY")
        if texturePath then parent[key]:SetTexture(texturePath) end
        parent[key]:SetSize(12, 12)
    end
    return parent[key]
end

-- Utility to get a high-strata overlay frame to force icons on top
local function GetIconOverlay(frame)
    if not frame.dfIconOverlay then
        -- Create a frame that sits significantly higher than the health bar
        frame.dfIconOverlay = CreateFrame("Frame", nil, frame.healthBar or frame)
        frame.dfIconOverlay:SetAllPoints(frame)
        -- Use a dynamic frame level higher than the parent
        frame.dfIconOverlay:SetFrameLevel((frame.healthBar and frame.healthBar:GetFrameLevel() or frame:GetFrameLevel()) + 50)
    end
    return frame.dfIconOverlay
end

-- Update Leader, Assistant, Role, and Raid Target Icons
function DF:UpdateIcons(frame)
    -- Use strict validation to block nameplates
    if not DF:IsValidFrame(frame) then return end

    local unit = frame.unit or frame.displayedUnit
    local db = DF:GetDB(frame)
    local isEditMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()
    
    -- Leader/Assistant Icons
    local leader = EnsureIcon(frame, "leaderIcon", "Interface\\GroupFrame\\UI-Group-LeaderIcon")
    local assist = EnsureIcon(frame, "assistantIcon", "Interface\\GroupFrame\\UI-Group-AssistantIcon")
    
    local isLeader = unit and UnitIsGroupLeader(unit)
    local isAssist = unit and UnitIsGroupAssistant(unit) and not isLeader
    
    local function ApplyIconLayout(icon)
        icon:Show()
        icon:SetAlpha(1)
        if db.leaderIconEnabled then
            icon:ClearAllPoints()
            icon:SetScale(db.leaderIconScale or 1)
            icon:SetPoint(db.leaderIconAnchor, frame, db.leaderIconAnchor, db.leaderIconX, db.leaderIconY)
        else
            -- Reset Scale to default if override is disabled
            icon:SetScale(1)
        end
    end

    -- Edit Mode Mocking & DEMO MODE
    local leaderActive = isLeader or (isEditMode and leader:IsShown()) or (DF.demoMode and unit == "dandersdemo")
    local assistActive = isAssist or (isEditMode and assist:IsShown())

    if leaderActive and not db.leaderIconHide then 
        ApplyIconLayout(leader) 
    else 
        leader:Hide() 
        leader:SetScale(1)
    end
    
    if assistActive and not db.leaderIconHide then 
        ApplyIconLayout(assist) 
    else 
        assist:Hide() 
        assist:SetScale(1)
    end

    -- Role Icon
    local roleIcon = EnsureIcon(frame, "roleIcon")
    local role = unit and UnitGroupRolesAssigned(unit)
    local hasRole = role and (role == "TANK" or role == "HEALER" or role == "DAMAGER")
    local roleActive = hasRole or (isEditMode and roleIcon:IsShown()) or (DF.demoMode and unit == "dandersdemo")
    
    -- FIX: Ensure Role Texture is set for Demo Mode
    if DF.demoMode and unit == "dandersdemo" then
        roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        roleIcon:SetTexCoord(0, 19/64, 22/64, 41/64) -- Tank Icon
    end

    if roleActive and not db.roleIconHide then
        roleIcon:Show()
        roleIcon:SetAlpha(1)
        if db.roleIconEnabled then
            roleIcon:ClearAllPoints()
            roleIcon:SetScale(db.roleIconScale or 1)
            roleIcon:SetPoint(db.roleIconAnchor, frame, db.roleIconAnchor, db.roleIconX, db.roleIconY)
        else
            roleIcon:SetScale(1)
        end
    else
        roleIcon:Hide()
        roleIcon:SetScale(1)
    end

    -- Raid Target Marker
    local raidIcon = EnsureIcon(frame, "raidTargetIcon", "Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    local index = unit and GetRaidTargetIndex(unit)
    local raidActive = index or (isEditMode and raidIcon:IsShown()) or (DF.demoMode and unit == "dandersdemo")

    if raidActive and not db.raidIconHide then
        if DF.demoMode then SetRaidTargetIconTexture(raidIcon, 8) -- Skull
        elseif index then SetRaidTargetIconTexture(raidIcon, index) end
        
        raidIcon:Show()
        raidIcon:SetAlpha(1)
        if db.raidIconEnabled then
            raidIcon:ClearAllPoints()
            raidIcon:SetScale(db.raidIconScale or 1)
            raidIcon:SetPoint(db.raidIconAnchor, frame, db.raidIconAnchor, db.raidIconX, db.raidIconY)
        else
            raidIcon:SetScale(1)
        end
    else
        raidIcon:Hide()
        raidIcon:SetScale(1)
    end

    -- Get the high-strata overlay for sensitive icons
    local overlay = GetIconOverlay(frame)

    -- NEW: Ready Check Icon
    if frame.readyCheckIcon then
        local rIcon = frame.readyCheckIcon
        
        -- Force parent to high overlay to fix Z-order issues
        if rIcon:GetParent() ~= overlay then
            rIcon:SetParent(overlay)
        end

        local rActive = rIcon:IsShown() or (isEditMode and rIcon:IsShown()) or (DF.demoMode and unit == "dandersdemo")
        
        if DF.demoMode then
            rIcon:SetTexture(READY_CHECK_READY_TEXTURE)
        end
        
        if db.readyCheckIconEnabled then
            if rActive then
                rIcon:ClearAllPoints()
                rIcon:SetScale(db.readyCheckIconScale or 1)
                rIcon:SetPoint(db.readyCheckIconAnchor, frame, db.readyCheckIconAnchor, db.readyCheckIconX, db.readyCheckIconY)
                rIcon:Show()
            end
        else
            if rActive then rIcon:SetScale(1) end
        end
        
        if not rActive and not isEditMode then rIcon:Hide() end
    end

    -- NEW: Center Status Icon
    if frame.centerStatusIcon then
        local sIcon = frame.centerStatusIcon
        
        -- Force parent to high overlay
        if sIcon:GetParent() ~= overlay then
            sIcon:SetParent(overlay)
        end

        local sActive = sIcon:IsShown() or (isEditMode and sIcon:IsShown())

        if db.centerStatusIconEnabled then
            if sActive then
                sIcon:ClearAllPoints()
                sIcon:SetScale(db.centerStatusIconScale or 1)
                sIcon:SetPoint(db.centerStatusIconAnchor, frame, db.centerStatusIconAnchor, db.centerStatusIconX, db.centerStatusIconY)
            end
        else
            if sActive then sIcon:SetScale(1) end
        end

        if not sActive and not isEditMode then sIcon:Hide() end
    end
end

-- Update Name Text coloring and positioning
function DF:UpdateNameText(frame)
    -- Use strict validation to block nameplates
    if not DF:IsValidFrame(frame) then return end

    local unit = frame.unit or frame.displayedUnit
    if not frame.name then return end
    
    local db = DF:GetDB(frame)

    if db.nameTextHide then
        frame.name:Hide()
        return
    end
    frame.name:Show()

    -- Apply Font & Outline (Do this early to ensure font properties exist)
    local font = db.nameTextFont or "Fonts\\FRIZQT__.TTF"
    local outline = db.nameTextOutline or "NONE"
    local _, currentSize = frame.name:GetFont()
    if not currentSize or currentSize < 1 then currentSize = 10 end
    frame.name:SetFont(font, currentSize, outline)

    -- Layout & Truncation Modes
    local maxLen = db.nameTextLength or 0
    local mode = db.nameTextTruncateMode or "ELLIPSIS"
    local align = db.nameTextWrapAlign or "CENTER"
    local direction = db.nameTextWrapDirection or "DOWN"

    if mode == "WRAP" then
        -- WRAP MODE: Requires specific settings to allow multi-line
        frame.name:SetWordWrap(true)
        frame.name:SetNonSpaceWrap(true)
        frame.name:SetMaxLines(0) -- Unlimited lines
        frame.name:SetHeight(0)   -- Auto-expand height
        
        -- Ensure width is constrained so wrapping actually happens
        local fWidth = frame:GetWidth()
        if fWidth and fWidth > 4 then
            frame.name:SetWidth(fWidth - 4)
        end
        
        frame.name:SetJustifyH(align)
    else
        -- STANDARD MODE: Enforce single line limits to prevent layout crashes
        frame.name:SetWordWrap(false)
        frame.name:SetNonSpaceWrap(false)
        frame.name:SetMaxLines(1)
        
        -- Reset height to standard font height + padding to be safe
        frame.name:SetHeight(currentSize + 2)
        
        -- Reset width to allow natural expansion (or constrained by points)
        -- We don't forcibly set width here to allow SetPoint to handle it if needed, 
        -- but setting it to 0 allows auto-width behavior for single lines.
        frame.name:SetWidth(0) 
        
        frame.name:SetJustifyH("CENTER")
    end

    -- Override Text Content (Realm Name Logic & TRUNCATION)
    if DF.demoMode then
        frame.name:SetText("Demo Unit")
    elseif unit then
        local name, realm = UnitName(unit)
        if name then
            if db.nameTextShowRealm and realm and realm ~= "" then
                name = name .. "-" .. realm
            end
            
            if maxLen > 0 and #name > maxLen then
                if mode == "ELLIPSIS" then
                    name = string.sub(name, 1, maxLen) .. "..."
                elseif mode == "CLIP" then
                    name = string.sub(name, 1, maxLen)
                elseif mode == "WRAP" then
                    local p1 = string.sub(name, 1, maxLen)
                    local p2 = string.sub(name, maxLen + 1)
                    
                    if direction == "UP" then
                        name = p2 .. "\n" .. p1 -- Inverted Order
                    else
                        name = p1 .. "\n" .. p2 -- Normal Order
                    end
                end
            end
            
            frame.name:SetText(name)
        end
    else
        -- FIX: Clear text if unit is nil (prevents stuck "Demo Unit" text)
        frame.name:SetText("")
    end

    -- Apply Color
    local r, g, b = 1, 1, 1
    local useClass = db.nameTextUseClassColor
    local customCol = db.nameTextColor or {r=1, g=1, b=1}

    if useClass then
        local class
        if unit then _, class = UnitClass(unit) end
        if EditModeManagerFrame and EditModeManagerFrame:IsShown() and not class then 
            _, class = UnitClass("player") 
        end

        local c = class and RAID_CLASS_COLORS[class]
        if c then
            r, g, b = c.r, c.g, c.b
        else
            r, g, b = customCol.r, customCol.g, customCol.b
        end
    else
        r, g, b = customCol.r, customCol.g, customCol.b
    end

    frame.name:SetTextColor(r, g, b)

    -- Apply Scale
    frame.name:SetScale(db.nameTextScale or 1.0)

    -- Apply Positioning
    if not db.nameTextEnabled then 
        return 
    end
    
    frame.name:ClearAllPoints()
    frame.name:SetPoint(db.nameTextAnchor, frame, db.nameTextAnchor, db.nameTextX, db.nameTextY)
end

-- Update Health Text format and positioning
function DF:UpdateHealthText(frame)
    -- Use strict validation to block nameplates
    if not DF:IsValidFrame(frame) then return end

    local unit = frame.unit or frame.displayedUnit
    if not frame.healthBar or not frame.healthBar.CreateFontString then return end

    local db = DF:GetDB(frame)

    if db.healthTextHide then
        if frame.dfHealthText then frame.dfHealthText:Hide() end
        if frame.statusText then frame.statusText:Hide() end
        return
    end

    if not db.healthTextEnabled then
        if frame.dfHealthText then frame.dfHealthText:Hide() end
        if frame.statusText then frame.statusText:Show() end
        return
    end
    
    if not frame.dfHealthText then
        frame.dfHealthText = frame.healthBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    end

    local font = db.healthTextFont or "Fonts\\FRIZQT__.TTF"
    local outline = db.healthTextOutline or "NONE"
    local _, currentSize = frame.dfHealthText:GetFont()
    if not currentSize then currentSize = 10 end
    
    frame.dfHealthText:SetFont(font, currentSize, outline)

    frame.dfHealthText:ClearAllPoints()
    frame.dfHealthText:SetScale(db.healthTextScale or 1)
    frame.dfHealthText:SetPoint(db.healthTextAnchor, frame.healthBar, db.healthTextAnchor, db.healthTextX, db.healthTextY)
    
    local r, g, b = 1, 1, 1
    local useClass = db.healthTextUseClassColor
    local customCol = db.healthTextColor or {r=1, g=1, b=1}

    if useClass then
        local class
        if unit then _, class = UnitClass(unit) end
        if EditModeManagerFrame and EditModeManagerFrame:IsShown() and not class then 
            _, class = UnitClass("player") 
        end
        
        if DF.demoMode and unit == "dandersdemo" then class = "PALADIN" end

        local c = class and RAID_CLASS_COLORS[class]
        if c then
            r, g, b = c.r, c.g, c.b
        else
            r, g, b = customCol.r, customCol.g, customCol.b
        end
    else
        r, g, b = customCol.r, customCol.g, customCol.b
    end
    
    frame.dfHealthText:SetTextColor(r, g, b)

    if (not unit or not UnitExists(unit)) and EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        if frame.statusText then frame.statusText:Hide() end
        frame.dfHealthText:SetText("100%")
        frame.dfHealthText:Show()
        return
    end

    if not unit or not UnitExists(unit) or UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) then
        if frame.statusText then frame.statusText:Show() end
        frame.dfHealthText:Hide()
        return 
    end

    if frame.statusText then frame.statusText:Hide() end
    frame.dfHealthText:Show()

    local fmt = db.healthTextFormat
    
    -- DEMO MODE OVERRIDE
    if DF.demoMode then
        frame.dfHealthText:Show() -- FIX: Ensure text is shown
        local fakeP = DF.demoPercent * 100
        if fmt == "Percent" then
            frame.dfHealthText:SetFormattedText("%.0f%%", fakeP)
        else
            -- Just show percent for simplicity in demo for other formats too, or fake raw numbers
            local max = UnitHealthMax(unit) or 100
            local curr = max * DF.demoPercent
            
            if fmt == "Deficit" then
                frame.dfHealthText:SetFormattedText("-%.0f", max - curr)
            elseif fmt == "CurrentMax" then
                frame.dfHealthText:SetFormattedText("%.0f / %.0f", curr, max)
            else
                frame.dfHealthText:SetFormattedText("%.0f", curr)
            end
        end
        return
    end

    -- IMPORTANT: We must avoid fetching UnitHealth/UnitHealthMax indiscriminately
    -- as they might return secret values, causing a crash if we try to perform arithmetic on them.
    
    local status, err = pcall(function()
        if fmt == "Percent" then
            local p = UnitHealthPercent(unit, true, true)
            if p then 
                frame.dfHealthText:SetFormattedText("%.0f%%", p)
            else
                frame.dfHealthText:SetText("100%")
            end
        elseif fmt == "Deficit" then
            -- UnitHealthMissing is a safe API that returns the deficit directly
            local miss = UnitHealthMissing(unit, true)
            frame.dfHealthText:SetFormattedText("-%s", miss)
        elseif fmt == "CurrentMax" then
            -- We must access these here for this mode, but if they are secret, this mode might still fail.
            local curr = UnitHealth(unit, true)
            local max = UnitHealthMax(unit, true)
            if curr and max then
                frame.dfHealthText:SetFormattedText("%s / %s", curr, max)
            end
        else 
            local curr = UnitHealth(unit)
            if curr then
                frame.dfHealthText:SetFormattedText("%s", curr)
            end
        end
    end)

    if not status then
        -- Suppress error printing spam, just fallback to safe text
        frame.dfHealthText:SetText("")
    end
end