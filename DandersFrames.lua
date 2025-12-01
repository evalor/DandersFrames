local addonName, DF = ...

-- EXPOSE ADDON TABLE GLOBALLY
_G[addonName] = DF

-- Event Frame
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("RAID_TARGET_UPDATE")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

-- Debug Flags
DF.debugEnabled = false
DF.demoMode = false
DF.demoPercent = 1

-- API Helper
function DF:GetUnitName(unit)
    return UnitName(unit)
end

-- ============================================================
-- DATABASE RETRIEVAL (FIXED)
-- ============================================================
-- This is the ONLY definition of GetDB in the addon.
-- The duplicate in DandersFrames_Profile.lua has been removed.
-- 
-- FIX: Added detection for CompactRaidGroup member frames which
-- are named like "CompactRaidGroup1Member1" instead of "CompactRaidFrame1"
-- ============================================================

function DF:GetDB(frame)
    -- 1. Demo Mode: Return the profile currently selected in the GUI
    if DF.demoMode and DF.GUI and DF.GUI.SelectedMode then
        if frame and (frame.unit == "dandersdemo" or frame:GetName() == "DandersFramesTestUnit") then
            return DF.db.profile[DF.GUI.SelectedMode]
        end
    end

    -- 2. Name-based Detection (Most Accurate)
    if frame then
        local name = frame:GetName()
        if name then
            -- Check for Raid frames first (more specific patterns)
            -- FIX: Added "CompactRaidGroup" detection for raid group member frames
            if string.find(name, "CompactRaidFrame") or string.find(name, "CompactRaidGroup") then
                return DF.db.profile.raid
            elseif string.find(name, "CompactPartyFrame") then
                return DF.db.profile.party
            end
        end
        
        -- 2b. Check parent frame for raid group membership
        local parent = frame:GetParent()
        if parent then
            local pName = parent:GetName()
            if pName and string.find(pName, "CompactRaidGroup") then
                return DF.db.profile.raid
            end
        end
    end
    
    -- 3. Fallback: Check Group State
    if IsInRaid() then
        return DF.db.profile.raid
    end

    -- Default
    return DF.db.profile.party
end

-- Hook Edit Mode to enforce center anchor after moving
if EditModeManagerFrame then
    EditModeManagerFrame:HookScript("OnHide", function()
        if DF.CenterCache then
             if CompactPartyFrame then DF.CenterCache[CompactPartyFrame:GetName()] = nil end
             if CompactRaidFrameContainer then DF.CenterCache[CompactRaidFrameContainer:GetName()] = nil end
        end

        C_Timer.After(0.1, function() DF:EnforceCenterAnchor() end)
        C_Timer.After(0.5, function() DF:EnforceCenterAnchor() end)
        C_Timer.After(1.5, function() DF:EnforceCenterAnchor() end)
    end)
end

-- Update All Function
function DF:UpdateAll()
    if InCombatLockdown() then
        DF.needsUpdate = true
        if not DF.warnedCombat then
            print("|cffff0000DandersFrames:|r Cannot update frames while in combat. Changes queued.")
            DF.warnedCombat = true
        end
        return
    end
    DF.warnedCombat = false
    
    if DF.UpdateColorCurve then DF:UpdateColorCurve() end
    
    -- NOTE: Skip container layout updates during Demo Mode to avoid taint errors
    -- Demo Mode uses fake units which trigger protected Blizzard code paths
    if not DF.demoMode then
        -- Force visibility update to ensure Solo Mode state applies immediately on profile switch
        if CompactPartyFrame and CompactPartyFrame.UpdateVisibility then
            CompactPartyFrame:UpdateVisibility()
        end
        
        -- Apply container-level layout settings
        if DF.ApplyContainerLayout then DF:ApplyContainerLayout() end
        
        -- Ensure Center Anchor is applied on all updates
        if DF.EnforceCenterAnchor then DF:EnforceCenterAnchor() end
    end

    DF:IterateCompactFrames(function(frame)
        -- Safe Protected Calls to Blizzard functions - SKIP in Demo Mode to avoid secret value errors
        if not DF.demoMode then
            if CompactUnitFrame_UpdateHealthColor then pcall(CompactUnitFrame_UpdateHealthColor, frame) end
            if CompactUnitFrame_UpdateStatusIcons then pcall(CompactUnitFrame_UpdateStatusIcons, frame) end
            if CompactUnitFrame_UpdateName then pcall(CompactUnitFrame_UpdateName, frame) end
        end
        
        -- Demo Mode Logic: Animate Bars manually
        if DF.demoMode and frame.healthBar and DF.demoPercent then
            frame.healthBar:SetMinMaxValues(0, 100)
            frame.healthBar:SetValue(DF.demoPercent * 100)
        end

        -- Apply custom updates
        if DF.ApplyFrameLayout then DF:ApplyFrameLayout(frame) end
        if DF.ApplyTexture then DF:ApplyTexture(frame) end
        if DF.ApplyBarOrientation then DF:ApplyBarOrientation(frame) end
        if DF.ApplyHealthColors then DF:ApplyHealthColors(frame) end
        if DF.ApplyAuraLayout then DF:ApplyAuraLayout(frame) end
        if DF.UpdateDemoAuras and DF.demoMode then DF:UpdateDemoAuras(frame) end 
        if DF.UpdateDispelIcons then DF:UpdateDispelIcons(frame) end 
        if DF.UpdateMidnightIcon then DF:UpdateMidnightIcon(frame) end
        if DF.UpdateIcons then DF:UpdateIcons(frame) end
        if DF.UpdateNameText then DF:UpdateNameText(frame) end
        if DF.UpdateHealthText then DF:UpdateHealthText(frame) end
        if DF.ApplyFrameInset then DF:ApplyFrameInset(frame) end
        if DF.ApplyResourceBarLayout then DF:ApplyResourceBarLayout(frame) end
        if DF.UpdateResourceBar then DF:UpdateResourceBar(frame) end
        if DF.ApplyAbsorbLayout then DF:ApplyAbsorbLayout(frame) end
        if DF.UpdateAbsorb then DF:UpdateAbsorb(frame) end
        if DF.ApplyHealAbsorbLayout then DF:ApplyHealAbsorbLayout(frame) end
        if DF.UpdateHealAbsorb then DF:UpdateHealAbsorb(frame) end
    end)
    
    -- Update Titles (Handles Party and Raid Group Headers)
    if DF.UpdateFrameTitles then DF:UpdateFrameTitles() end 
end

-- Callback for Config Refresh
function DF:RefreshConfig()
    DF:UpdateAll()
end

-- Main Event Handler
f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        local dbDefaults = {
            profile = {
                party = DF.PartyDefaults,
                raid = DF.RaidDefaults,
                minimap = { hide = false },
            },
            char = {
                enableSpecSwitch = false,
                specProfiles = {}, 
            }
        }
        
        DF.db = LibStub("AceDB-3.0"):New("DandersFramesDB", dbDefaults, true)
        
        DF.db.RegisterCallback(DF, "OnProfileChanged", "RefreshConfig")
        DF.db.RegisterCallback(DF, "OnProfileCopied", "RefreshConfig")
        DF.db.RegisterCallback(DF, "OnProfileReset", "RefreshConfig")

        if DF.ValidateFonts then DF:ValidateFonts() end
        if DF.SetupOptions then DF:SetupOptions() end
        if DF.HookRaidFrames then DF:HookRaidFrames() end
        if DF.UpdateColorCurve then DF:UpdateColorCurve() end
        if DF.SetupSoloMode then DF:SetupSoloMode() end
        
        if EditModeManagerFrame then
            EditModeManagerFrame:HookScript("OnHide", function() 
                C_Timer.After(0.1, function() DF:UpdateAll() end) 
            end)
        end

        SLASH_DANDERSFRAMES1 = "/df"
        SlashCmdList["DANDERSFRAMES"] = function(msg)
            if msg == "debug" then
                DF.debugEnabled = not DF.debugEnabled
                print("|cff00ff00DandersFrames:|r Debug Mode: " .. tostring(DF.debugEnabled))
                if DF.debugEnabled and DF.EnforceCenterAnchor then DF:EnforceCenterAnchor() end
            elseif msg == "testheal" then
                -- Test heal absorb bar visibility
                DF.testHealAbsorb = not DF.testHealAbsorb
                print("|cff00ff00DandersFrames:|r Test Heal Absorb: " .. tostring(DF.testHealAbsorb))
                DF:UpdateAll()
            elseif msg == "hierarchy" then
                -- DEBUG: Dump frame hierarchy for first visible compact frame
                print("|cff00ff00DandersFrames:|r === Frame Hierarchy Debug ===")
                local found = false
                DF:IterateCompactFrames(function(frame)
                    if found then return end
                    found = true
                    
                    local frameName = frame:GetName() or "unnamed"
                    print("Main Frame: " .. frameName)
                    print("  Strata: " .. tostring(frame:GetFrameStrata()))
                    print("  Level: " .. tostring(frame:GetFrameLevel()))
                    
                    if frame.healthBar then
                        local hbParent = frame.healthBar:GetParent()
                        local hbParentName = hbParent and hbParent:GetName() or "unnamed"
                        print("  healthBar Parent: " .. hbParentName)
                        print("  healthBar Strata: " .. tostring(frame.healthBar:GetFrameStrata()))
                        print("  healthBar Level: " .. tostring(frame.healthBar:GetFrameLevel()))
                    end
                    
                    if frame.DispelOverlay then
                        local doParent = frame.DispelOverlay:GetParent()
                        local doParentName = doParent and doParent:GetName() or "unnamed"
                        print("  DispelOverlay Parent: " .. doParentName)
                        print("  DispelOverlay Strata: " .. tostring(frame.DispelOverlay:GetFrameStrata()))
                        print("  DispelOverlay Level: " .. tostring(frame.DispelOverlay:GetFrameLevel()))
                        print("  DispelOverlay Shown: " .. tostring(frame.DispelOverlay:IsShown()))
                        
                        if frame.DispelOverlay.Border then
                            local layer, sublayer = frame.DispelOverlay.Border:GetDrawLayer()
                            print("  DispelOverlay.Border DrawLayer: " .. tostring(layer) .. " sublevel " .. tostring(sublayer))
                        end
                        if frame.DispelOverlay.Gradient then
                            local layer, sublayer = frame.DispelOverlay.Gradient:GetDrawLayer()
                            print("  DispelOverlay.Gradient DrawLayer: " .. tostring(layer) .. " sublevel " .. tostring(sublayer))
                        end
                    else
                        print("  DispelOverlay: NOT FOUND")
                    end
                    
                    if frame.dfAbsorbBar then
                        local abParent = frame.dfAbsorbBar:GetParent()
                        local abParentName = abParent and abParent:GetName() or "unnamed"
                        print("  dfAbsorbBar Parent: " .. abParentName)
                        print("  dfAbsorbBar Strata: " .. tostring(frame.dfAbsorbBar:GetFrameStrata()))
                        print("  dfAbsorbBar Level: " .. tostring(frame.dfAbsorbBar:GetFrameLevel()))
                        local barTex = frame.dfAbsorbBar:GetStatusBarTexture()
                        if barTex then
                            local layer, sublayer = barTex:GetDrawLayer()
                            print("  dfAbsorbBar Texture DrawLayer: " .. tostring(layer) .. " sublevel " .. tostring(sublayer))
                        end
                    end
                    
                    -- List all children of main frame
                    print("  --- Children of main frame ---")
                    local children = {frame:GetChildren()}
                    for i, child in ipairs(children) do
                        local childName = child:GetName() or ("child" .. i)
                        local childLevel = child:GetFrameLevel()
                        local childType = child:GetObjectType()
                        print(string.format("    [%d] %s (%s) Level: %d", i, childName, childType, childLevel))
                    end
                end)
                print("|cff00ff00DandersFrames:|r === End Hierarchy Debug ===")
            elseif msg == "debugheal" then
                -- Debug heal absorb bar - check what's happening
                print("|cff00ff00DandersFrames:|r === Heal Absorb Debug ===")
                print("testHealAbsorb flag: " .. tostring(DF.testHealAbsorb))
                
                local count = 0
                DF:IterateCompactFrames(function(frame)
                    count = count + 1
                    local name = frame:GetName() or "unknown"
                    local unit = frame.unit or "no unit"
                    local hasBar = frame.dfHealAbsorbBar ~= nil
                    local barShown = hasBar and frame.dfHealAbsorbBar:IsShown()
                    local barVisible = hasBar and frame.dfHealAbsorbBar:IsVisible()
                    local barAlpha = hasBar and frame.dfHealAbsorbBar:GetAlpha() or 0
                    local barWidth = hasBar and frame.dfHealAbsorbBar:GetWidth() or 0
                    local barHeight = hasBar and frame.dfHealAbsorbBar:GetHeight() or 0
                    local barValue = hasBar and frame.dfHealAbsorbBar:GetValue() or 0
                    local barMin, barMax = 0, 0
                    if hasBar then barMin, barMax = frame.dfHealAbsorbBar:GetMinMaxValues() end
                    
                    print(string.format("Frame: %s | Unit: %s", name, unit))
                    print(string.format("  HasBar: %s | Shown: %s | Visible: %s", tostring(hasBar), tostring(barShown), tostring(barVisible)))
                    print(string.format("  Size: %.0fx%.0f | Alpha: %.2f", barWidth, barHeight, barAlpha))
                    print(string.format("  Value: %.0f | Min: %.0f | Max: %.0f", barValue, barMin, barMax))
                    
                    if hasBar then
                        local parent = frame.dfHealAbsorbBar:GetParent()
                        local parentName = parent and parent:GetName() or "unknown parent"
                        print(string.format("  Parent: %s | FrameLevel: %d", parentName, frame.dfHealAbsorbBar:GetFrameLevel()))
                    end
                end)
                
                print("Total frames processed: " .. count)
                print("|cff00ff00DandersFrames:|r === End Debug ===")
            elseif msg == "pos" then
                -- Debug: Show current saved positions
                print("|cff00ff00DandersFrames:|r === Saved Positions ===")
                if DF.db and DF.db.profile then
                    local party = DF.db.profile.party
                    local raid = DF.db.profile.raid
                    print("Party: X=" .. tostring(party.framePositionX) .. " Y=" .. tostring(party.framePositionY))
                    print("Raid: X=" .. tostring(raid.framePositionX) .. " Y=" .. tostring(raid.framePositionY))
                    print("Party growCenter: " .. tostring(party.growCenter))
                    print("Raid growCenter: " .. tostring(raid.growCenter))
                end
            elseif msg == "resetpos" then
                -- Reset all saved positions
                if DF.db and DF.db.profile then
                    DF.db.profile.party.framePositionX = 0
                    DF.db.profile.party.framePositionY = 0
                    DF.db.profile.raid.framePositionX = 0
                    DF.db.profile.raid.framePositionY = 0
                    print("|cff00ff00DandersFrames:|r All positions reset to 0,0. Reload UI to apply.")
                end
            else
                if DF.ToggleGUI then 
                    DF:ToggleGUI() 
                else
                    print("|cffff0000DandersFrames:|r GUI loaded.")
                end
            end
        end
        
        C_Timer.After(2, function() DF:CheckProfileAutoSwitch() end)
        C_Timer.After(3, function() DF:EnforceCenterAnchor() end)
        C_Timer.After(5, function() DF:EnforceCenterAnchor() end)
        
        DF:UpdateAll()
        
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        DF:CheckProfileAutoSwitch()
        
    elseif event == "RAID_TARGET_UPDATE" then
        DF:IterateCompactFrames(function(frame) 
             if DF.UpdateIcons then DF:UpdateIcons(frame) end
        end)
        
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        if CompactPartyFrame and CompactPartyFrame.UpdateVisibility then
             CompactPartyFrame:UpdateVisibility()
             
             -- NEW: Faster update cycle for snappy roster changes
             C_Timer.After(0.1, function() 
                 if CompactPartyFrame and CompactPartyFrame.UpdateVisibility then
                     CompactPartyFrame:UpdateVisibility() 
                 end
                 if Hook_CompactPartyFrame_UpdateVisibility then Hook_CompactPartyFrame_UpdateVisibility() end
                 DF:UpdateAll()
                 
                 if DF.EnforceCenterAnchor then 
                     DF:EnforceCenterAnchor() 
                 end
             end)
             
             -- Secondary check for safety (reduced from 1.0s to 0.5s)
             C_Timer.After(0.5, function() 
                 DF:UpdateAll()
                 if DF.EnforceCenterAnchor then 
                     DF:EnforceCenterAnchor() 
                 end
             end)
        end
        DF:UpdateAll()
    
    elseif event == "PLAYER_REGEN_ENABLED" then
        if DF.needsUpdate then
            DF.needsUpdate = false
            DF:UpdateAll()
            print("|cff00ff00DandersFrames:|r Settings applied.")
        end
        DF:EnforceCenterAnchor()
    end
end)