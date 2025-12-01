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

-- Utility to get a high-strata overlay frame to force icons AND TEXT on top
-- Renamed from GetIconOverlay to GetContentOverlay to reflect it now handles text too
local function GetContentOverlay(frame)
    if not frame.dfContentOverlay then
        -- Create a frame that sits significantly higher than the health bar and absorb bars
        -- Absorb bars are typically HealthLevel + 2
        -- We set this to 999 to ensure it sits above everything else
        frame.dfContentOverlay = CreateFrame("Frame", nil, frame)
        frame.dfContentOverlay:SetAllPoints(frame)
        frame.dfContentOverlay:SetFrameLevel(999) 
    end
    return frame.dfContentOverlay
end

-- Update Leader, Assistant, Role, and Raid Target Icons
function DF:UpdateIcons(frame)
    -- Use strict validation to block nameplates
    if not DF:IsValidFrame(frame) then return end

    local unit = frame.unit or frame.displayedUnit
    local db = DF:GetDB(frame)
    local isEditMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()
    
    -- NEW: Hide Blizzard's OOR/Connectivity Icon if requested
    if db.hideRangeIcon then
        if frame.connectivityIcon then frame.connectivityIcon:Hide() end
        -- Speculative 12.0 icons - if they exist, hide them
        if frame.rangeIcon then frame.rangeIcon:Hide() end
        if frame.outOfRangeIcon then frame.outOfRangeIcon:Hide() end
    end
    
    -- 1. GET OVERLAY (Ensures icons float above health textures)
    local overlay = GetContentOverlay(frame)

    -- 2. LEADER & ASSISTANT
    local leader = EnsureIcon(frame, "leaderIcon", "Interface\\GroupFrame\\UI-Group-LeaderIcon")
    local assist = EnsureIcon(frame, "assistantIcon", "Interface\\GroupFrame\\UI-Group-AssistantIcon")
    
    -- FIX: Re-parent to overlay to prevent hiding behind texture
    if leader:GetParent() ~= overlay then leader:SetParent(overlay) end
    if assist:GetParent() ~= overlay then assist:SetParent(overlay) end
    
    local isLeader = unit and UnitIsGroupLeader(unit)
    local isAssist = unit and UnitIsGroupAssistant(unit) and not isLeader
    
    local function ApplyIconLayout(icon)
        icon:Show()
        icon:SetAlpha(1)
        -- Ensure draw layer is high
        icon:SetDrawLayer("OVERLAY", 7) 
        
        if db.leaderIconEnabled then
            icon:ClearAllPoints()
            icon:SetScale(db.leaderIconScale or 1)
            icon:SetPoint(db.leaderIconAnchor, frame, db.leaderIconAnchor, db.leaderIconX, db.leaderIconY)
        else
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

    -- 3. ROLE ICON
    local roleIcon = EnsureIcon(frame, "roleIcon")
    
    -- FIX: Re-parent to overlay
    if roleIcon:GetParent() ~= overlay then roleIcon:SetParent(overlay) end
    
    local role = unit and UnitGroupRolesAssigned(unit)
    local hasRole = role and (role == "TANK" or role == "HEALER" or role == "DAMAGER")
    local roleActive = hasRole or (isEditMode and roleIcon:IsShown()) or (DF.demoMode and unit == "dandersdemo")
    
    if DF.demoMode and unit == "dandersdemo" then
        roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        roleIcon:SetTexCoord(0, 19/64, 22/64, 41/64) -- Tank Icon
    end

    if roleActive and not db.roleIconHide then
        roleIcon:Show()
        roleIcon:SetAlpha(1)
        roleIcon:SetDrawLayer("OVERLAY", 7)
        
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

    -- 4. RAID TARGET MARKER
    local raidIcon = EnsureIcon(frame, "raidTargetIcon", "Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    
    -- FIX: Re-parent to overlay
    if raidIcon:GetParent() ~= overlay then raidIcon:SetParent(overlay) end
    
    local index = unit and GetRaidTargetIndex(unit)
    local raidActive = index or (isEditMode and raidIcon:IsShown()) or (DF.demoMode and unit == "dandersdemo")

    if raidActive and not db.raidIconHide then
        if DF.demoMode then SetRaidTargetIconTexture(raidIcon, 8) -- Skull
        elseif index then SetRaidTargetIconTexture(raidIcon, index) end
        
        raidIcon:Show()
        raidIcon:SetAlpha(1)
        raidIcon:SetDrawLayer("OVERLAY", 7)
        
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

    -- 5. READY CHECK ICON
    if frame.readyCheckIcon then
        local rIcon = frame.readyCheckIcon
        
        -- FIX: Force parent to high overlay
        if rIcon:GetParent() ~= overlay then rIcon:SetParent(overlay) end

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
                rIcon:SetDrawLayer("OVERLAY", 7)
            end
        else
            if rActive then rIcon:SetScale(1) end
        end
        
        if not rActive and not isEditMode then rIcon:Hide() end
    end

    -- 6. CENTER STATUS ICON
    if frame.centerStatusIcon then
        local sIcon = frame.centerStatusIcon
        
        -- FIX: Force parent to high overlay
        if sIcon:GetParent() ~= overlay then sIcon:SetParent(overlay) end

        -- NEW: AGGRESSIVE HOOKING to catch Blizzard's automatic updates
        if not sIcon.dfHooked then
            -- Determine if sIcon is the texture or a wrapper frame
            local textureToHook = sIcon
            if not sIcon.SetAtlas and sIcon.texture then
                textureToHook = sIcon.texture
            end

            -- Only hook if valid object with SetAtlas
            if textureToHook and textureToHook.SetAtlas then
                hooksecurefunc(textureToHook, "SetAtlas", function(self, atlas)
                    -- We capture 'frame' from the outer scope, which persists safely in this closure
                    local freshDB = DF:GetDB(frame)
                    
                    if DF.debugEnabled then
                        -- Safe print - avoid printing restricted values if possible, or wrap in pcall
                        pcall(function() print("DF Icon Debug: SetAtlas -> " .. tostring(atlas)) end)
                    end
                    
                    if freshDB and freshDB.hideRangeIcon then
                        if atlas and (atlas == "RaidFrame-Icon-outofsight" or atlas == "RaidFrame-Icon-Outofsight") then
                            self:SetAlpha(0) -- Force invisible
                            self:Hide()
                            -- If wrapper exists, hide it too
                            if sIcon ~= self then sIcon:Hide() end
                        end
                    end
                end)
            end
            
            -- Also hook Show on the main icon frame to double check
            hooksecurefunc(sIcon, "Show", function(self)
                local freshDB = DF:GetDB(frame)
                if freshDB and freshDB.hideRangeIcon then
                    -- Get the atlas from the texture (handle both wrapper/direct cases)
                    local tex = self.texture or self
                    local atlas = nil
                    if tex.GetAtlas then 
                        -- Wrap in pcall to avoid crash if GetAtlas is restricted (though usually getters are safe)
                        pcall(function() atlas = tex:GetAtlas() end) 
                    end
                    
                    if atlas and (atlas == "RaidFrame-Icon-outofsight" or atlas == "RaidFrame-Icon-Outofsight") then
                        self:SetAlpha(0)
                        self:Hide()
                        if tex ~= self then tex:SetAlpha(0) tex:Hide() end
                    end
                end
            end)
            
            sIcon.dfHooked = true
        end

        -- Initial Check (for when function is called manually)
        if db.hideRangeIcon then
            local tex = sIcon.texture or sIcon
            local atlas = nil
            if tex.GetAtlas then 
                 pcall(function() atlas = tex:GetAtlas() end) 
            end
            
            if atlas and (atlas == "RaidFrame-Icon-outofsight" or atlas == "RaidFrame-Icon-Outofsight") then
                sIcon:SetAlpha(0)
                sIcon:Hide()
            else
                -- If it's NOT the range icon (e.g. Resurrect), ensure it's visible (alpha 1)
                -- We removed the GetAlpha() comparison to avoid secret value error
                sIcon:SetAlpha(1) 
            end
        end

        local sActive = sIcon:IsShown() or (isEditMode and sIcon:IsShown())

        if db.centerStatusIconEnabled then
            if sActive then
                sIcon:ClearAllPoints()
                sIcon:SetScale(db.centerStatusIconScale or 1)
                sIcon:SetPoint(db.centerStatusIconAnchor, frame, db.centerStatusIconAnchor, db.centerStatusIconX, db.centerStatusIconY)
                sIcon:SetDrawLayer("OVERLAY", 7)
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
    
    -- 1. GET OVERLAY (Use shared overlay for text too)
    local overlay = GetContentOverlay(frame)
    
    -- 2. REPARENT TEXT to High Level Overlay
    -- This ensures text sits above Absorb bars (Level+2) and other bars
    if frame.name:GetParent() ~= overlay then
         frame.name:SetParent(overlay)
         -- We keep DrawLayer high just in case, though FrameLevel handles the heavy lifting
         frame.name:SetDrawLayer("OVERLAY", 7)
    end

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
        -- NEW: Use wrapper function to get name (support for external addons)
        local name, realm = DF:GetUnitName(unit)
        
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
        -- Show status text (Dead/Offline/Ghost) if option is enabled
        if db.showStatusText then
            -- FIX: Ensure we only show status text if the unit is actually Dead/Offline.
            -- Blizzard's default frame logic does NOT clear the "Dead" text string when a unit revives; 
            -- it simply Hides the frame. If we unconditionally Show() it here, "Dead" remains visible on living targets.
            if unit and (UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit)) then
                if frame.statusText then frame.statusText:Show() end
            else
                if frame.statusText then frame.statusText:Hide() end
            end
        else
            if frame.statusText then frame.statusText:Hide() end
        end
        return
    end

    if not db.healthTextEnabled then
        if frame.dfHealthText then frame.dfHealthText:Hide() end
        if frame.statusText then frame.statusText:Show() end
        return
    end
    
    -- 1. GET OVERLAY (Shared high-level frame)
    local overlay = GetContentOverlay(frame)
    
    -- 2. CREATE or REPARENT Health Text
    if not frame.dfHealthText then
        -- Create directly on the overlay
        frame.dfHealthText = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    elseif frame.dfHealthText:GetParent() ~= overlay then
        -- Reparent if it already existed elsewhere
        frame.dfHealthText:SetParent(overlay)
    end

    local font = db.healthTextFont or "Fonts\\FRIZQT__.TTF"
    local outline = db.healthTextOutline or "NONE"
    local _, currentSize = frame.dfHealthText:GetFont()
    if not currentSize then currentSize = 10 end
    
    frame.dfHealthText:SetFont(font, currentSize, outline)
    
    -- Force High Draw Layer
    frame.dfHealthText:SetDrawLayer("OVERLAY", 7)

    frame.dfHealthText:ClearAllPoints()
    frame.dfHealthText:SetScale(db.healthTextScale or 1)
    
    -- Anchors can still reference healthBar, even if parent is different
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
                if max - curr < 1 then
                     frame.dfHealthText:SetText("")
                else
                     frame.dfHealthText:SetFormattedText("-%.0f", max - curr)
                end
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
        -- Helper for Abbreviation
        -- For secret health values, we can only use Blizzard's API without custom options
        local function FormatValue(val)
            if not val then return val end
            
            -- When abbreviate is enabled, use Blizzard's built-in abbreviation
            -- Try AbbreviateNumbers first (handles K, M, B), fall back to AbbreviateLargeNumbers
            if db.healthTextAbbreviate then
                if AbbreviateNumbers then
                    return AbbreviateNumbers(val)
                elseif AbbreviateLargeNumbers then
                    return AbbreviateLargeNumbers(val)
                end
            end
            
            return val
        end

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
            
            -- FIX: Removed "if tostring(miss) == '0'" check because it breaks protected execution.
            -- We must accept "-0" as a necessary compromise for using protected values.
            frame.dfHealthText:SetFormattedText("-%s", FormatValue(miss))
            
        elseif fmt == "CurrentMax" then
            -- We must access these here for this mode, but if they are secret, this mode might still fail.
            local curr = UnitHealth(unit, true)
            local max = UnitHealthMax(unit, true)
            if curr and max then
                frame.dfHealthText:SetFormattedText("%s / %s", FormatValue(curr), FormatValue(max))
            end
        else 
            local curr = UnitHealth(unit)
            if curr then
                frame.dfHealthText:SetFormattedText("%s", FormatValue(curr))
            end
        end
    end)

    if not status then
        -- Suppress error printing spam, just fallback to safe text
        frame.dfHealthText:SetText("")
    end
end