local addonName, DF = ...

-- =========================================================================
-- GUI CONTENT DEFINITIONS
-- =========================================================================
-- This file defines the layout and widgets for every tab.
-- It is called by DandersFrames_GUI.lua when the window is built.
-- =========================================================================

function DF:SetupOptions()
    -- This function essentially creates a "Blank" placeholder in Blizzard options
    -- just so the addon shows up in the list, but points users to the GUI.
    local options = {
        name = "DandersFrames",
        handler = DF,
        type = 'group',
        args = {
            header = {
                order = 1,
                type = "header",
                name = "DandersFrames",
            },
            description = {
                order = 2,
                type = "description",
                name = "All settings have been moved to the dedicated DandersFrames Window.\n\nType /df or use the Minimap icon to open it.",
                fontSize = "medium",
            },
            openGUI = {
                order = 3,
                name = "Open Settings Window",
                desc = "Opens the main DandersFrames configuration window.",
                type = "execute",
                width = "double",
                func = function() 
                    if SettingsPanel and SettingsPanel:IsShown() then
                        -- Delay closing to prevent "Action Blocked" errors
                        C_Timer.After(0.1, function() 
                            SettingsPanel:Close()
                            C_Timer.After(0.1, function() DF:ToggleGUI() end)
                        end)
                    else
                        DF:ToggleGUI()
                    end
                end,
            },
        },
    }
    LibStub("AceConfig-3.0"):RegisterOptionsTable("DandersFrames", options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("DandersFrames", "DandersFrames")
end

function DF:SetupGUIPages(GUI, CreateTab, BuildPage)
    
    -- DEFINE POPUP FOR DEMO MODE
    StaticPopupDialogs["DANDERSFRAMES_DEMO_WARNING"] = {
        text = "|cffff0000WARNING:|r Demo Mode is a Work in Progress.\n\nIt may cause Lua errors or frame taint issues requiring a UI Reload.\n\nAre you sure you want to enable it?",
        button1 = "Enable",
        button2 = "Cancel",
        OnAccept = function() 
            DF:ToggleDemoMode(true)
            if GUI.RefreshCurrentPage then GUI:RefreshCurrentPage() end
        end,
        OnCancel = function()
            DF:ToggleDemoMode(false)
            if GUI.RefreshCurrentPage then GUI:RefreshCurrentPage() end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    -- TAB 1: GENERAL
    BuildPage(CreateTab("general", "General"), function(self, db, Add, AddSpace)
        Add(GUI:CreateHeader(self, "Global Settings"), 30, "both")
        
        -- Minimap Icon Toggle
        local LDBIcon = LibStub("LibDBIcon-1.0", true)
        Add(GUI:CreateCheckbox(self, "Show Minimap Icon", nil, nil, nil, 
            function() return not DF.db.profile.minimap.hide end,
            function(val) 
                DF.db.profile.minimap.hide = not val
                if val then LDBIcon:Show("DandersFrames") else LDBIcon:Hide("DandersFrames") end
            end
        ), 30)
        
        -- Solo Mode Toggle
        local solo = Add(GUI:CreateCheckbox(self, "Solo Mode (Show Party Frames)", db, "soloMode", function()
            if db.soloMode then 
                if CompactPartyFrame and not IsInGroup() then CompactPartyFrame:SetShown(true) end
            else
                if CompactPartyFrame and not IsInGroup() then CompactPartyFrame:SetShown(false) end
            end
        end), 30)
        -- Only valid for Party Frames (Raid usually has its own visibility rules or relies on group)
        solo.disableOn = function() return GUI.SelectedMode ~= "party" end
        
        -- Demo Mode Toggle with Warning
        local demo = Add(GUI:CreateCheckbox(self, "Demo Mode (Work in progress)", nil, nil, nil, 
            function() return DF.demoMode end,
            function(val) 
                if val then
                    StaticPopup_Show("DANDERSFRAMES_DEMO_WARNING")
                    -- Note: We don't enable it here directly. We wait for OnAccept.
                else
                    DF:ToggleDemoMode(false)
                end
            end
        ), 30)
        
        AddSpace(20, 1)

        Add(GUI:CreateHeader(self, "Health Bar Colors"), 30)
        Add(GUI:CreateDropdown(self, "Color Mode", {
            ["CLASS"] = "Class Colors", ["CUSTOM"] = "Custom Color", ["PERCENT"] = "Gradient"
        }, db, "healthColorMode"), 60)
        
        local customCol = Add(GUI:CreateColorPicker(self, "Custom Health Color", db, "healthColor", true), 30)
        customCol.hideOn = function(d) return d.healthColorMode ~= "CUSTOM" end
        
        local barAlpha = Add(GUI:CreateSlider(self, "Bar Alpha", 0, 1, 0.05, db, "classColorAlpha"), 60)
        barAlpha.hideOn = function(d) return d.healthColorMode == "CUSTOM" end
        
        AddSpace(20, 1)
        local gradHeader = Add(GUI:CreateHeader(self, "Gradient Colors"), 30)
        gradHeader.hideOn = function(d) return d.healthColorMode ~= "PERCENT" end
        
        -- Descriptive Text
        local descText = "Weights control the color distribution. Increasing a weight makes that color 'wider' on the health bar.\n\nExample: High 'Medium' weight makes the bar stay Medium color for a larger range of health (e.g., 80% to 30%)."
        
        local desc = Add(GUI:CreateLabel(self.child, descText, 315), 65)
        desc.hideOn = function(d) return d.healthColorMode ~= "PERCENT" end
        
        -- GRADIENT PREVIEW BAR
        local previewBar = GUI:CreateGradientBar(self.child, 315, 20, db)
        local pBar = Add(previewBar, 40)
        pBar.hideOn = function(d) return d.healthColorMode ~= "PERCENT" end
        
        -- Callback to update bar when sliders change
        local function UpdatePreview()
            DF:UpdateColorCurve()
            if previewBar.UpdatePreview then previewBar.UpdatePreview() end
        end
        
        -- HIGH HEALTH
        local cHighCB = Add(GUI:CreateCheckbox(self, "Use Class Color (High)", db, "healthColorHighUseClass", UpdatePreview), 30)
        cHighCB.hideOn = function(d) return d.healthColorMode ~= "PERCENT" end
        
        local cHigh = Add(GUI:CreateColorPicker(self, "High Health Color", db, "healthColorHigh", false, UpdatePreview), 30)
        cHigh.hideOn = function(d) return d.healthColorMode ~= "PERCENT" or d.healthColorHighUseClass end
        
        -- High Weight
        local wHigh = Add(GUI:CreateSlider(self, "High Color Weight", 1, 10, 1, db, "healthColorHighWeight", UpdatePreview), 60)
        wHigh.hideOn = function(d) return d.healthColorMode ~= "PERCENT" end

        -- MEDIUM HEALTH
        local cMedCB = Add(GUI:CreateCheckbox(self, "Use Class Color (Medium)", db, "healthColorMediumUseClass", UpdatePreview), 30)
        cMedCB.hideOn = function(d) return d.healthColorMode ~= "PERCENT" end
        
        local cMed = Add(GUI:CreateColorPicker(self, "Medium Health Color", db, "healthColorMedium", false, UpdatePreview), 30)
        cMed.hideOn = function(d) return d.healthColorMode ~= "PERCENT" or d.healthColorMediumUseClass end
        
        -- Medium Weight
        local wMed = Add(GUI:CreateSlider(self, "Med Color Weight", 1, 10, 1, db, "healthColorMediumWeight", UpdatePreview), 60)
        wMed.hideOn = function(d) return d.healthColorMode ~= "PERCENT" end

        -- LOW HEALTH
        local cLowCB = Add(GUI:CreateCheckbox(self, "Use Class Color (Low)", db, "healthColorLowUseClass", UpdatePreview), 30)
        cLowCB.hideOn = function(d) return d.healthColorMode ~= "PERCENT" end
        
        local cLow = Add(GUI:CreateColorPicker(self, "Low Health Color", db, "healthColorLow", false, UpdatePreview), 30)
        cLow.hideOn = function(d) return d.healthColorMode ~= "PERCENT" or d.healthColorLowUseClass end

        -- Low Weight
        local wLow = Add(GUI:CreateSlider(self, "Low Color Weight", 1, 10, 1, db, "healthColorLowWeight", UpdatePreview), 60)
        wLow.hideOn = function(d) return d.healthColorMode ~= "PERCENT" end
        
        -- Right Column
        Add(GUI:CreateHeader(self, "Background & Layout"), 30, 2)
        Add(GUI:CreateCheckbox(self, "Use Specific Side Padding", db, "useSpecificPadding", function() GUI:RefreshCurrentPage() end), 30, 2)
        
        local framePad = Add(GUI:CreateSlider(self, "Frame Padding (All)", 0, 20, 1, db, "framePadding"), 60, 2)
        framePad.hideOn = function(d) return d.useSpecificPadding end
        
        local pTop = Add(GUI:CreateSlider(self, "Padding Top", 0, 20, 1, db, "paddingTop"), 60, 2)
        pTop.hideOn = function(d) return not d.useSpecificPadding end
        local pBot = Add(GUI:CreateSlider(self, "Padding Bottom", 0, 20, 1, db, "paddingBottom"), 60, 2)
        pBot.hideOn = function(d) return not d.useSpecificPadding end
        local pLeft = Add(GUI:CreateSlider(self, "Padding Left", 0, 20, 1, db, "paddingLeft"), 60, 2)
        pLeft.hideOn = function(d) return not d.useSpecificPadding end
        local pRight = Add(GUI:CreateSlider(self, "Padding Right", 0, 20, 1, db, "paddingRight"), 60, 2)
        pRight.hideOn = function(d) return not d.useSpecificPadding end
        
        -- FIX: Set col to 2 explicitly so it doesn't push down to match left column
        AddSpace(20, 2)
        Add(GUI:CreateCheckbox(self, "Enable Background Color", db, "enableTextureColor"), 30, 2)
        local classBg = Add(GUI:CreateCheckbox(self, "Class Color Background", db, "backgroundClassColor"), 30, 2)
        classBg.disableOn = function(d) return not d.enableTextureColor end
        local cBg = Add(GUI:CreateColorPicker(self, "Background Color", db, "textureColor", true), 30, 2)
        cBg.disableOn = function(d) return not d.enableTextureColor or d.backgroundClassColor end
        
        -- FIX: Set col to 2 explicitly
        AddSpace(30, 2)
        Add(GUI:CreateButton(self, "Open Blizzard Edit Mode", 180, 30, function()
             if InCombatLockdown() then return end
             if EditModeManagerFrame then ShowUIPanel(EditModeManagerFrame) end
        end), 40, 2)
    end)

    -- TAB 2: AURAS
    BuildPage(CreateTab("auras", "Auras"), function(self, db, Add, AddSpace)
        Add(GUI:CreateHeader(self, "Buffs"), 30)
        Add(GUI:CreateCheckbox(self, "Click Through Buffs", db, "raidBuffClickThrough"), 30)
        Add(GUI:CreateSlider(self, "Scale", 0.5, 2.0, 0.1, db, "raidBuffScale"), 60)
        Add(GUI:CreateSlider(self, "Alpha", 0.1, 1.0, 0.05, db, "raidBuffAlpha"), 60)
        Add(GUI:CreateDropdown(self, "Anchor Point", {
            ["TOPLEFT"] = "Top Left", ["TOPRIGHT"] = "Top Right",
            ["BOTTOMLEFT"] = "Bottom Left", ["BOTTOMRIGHT"] = "Bottom Right",
            ["LEFT"] = "Left", ["RIGHT"] = "Right"
        }, db, "raidBuffAnchor"), 60)
        Add(GUI:CreateDropdown(self, "Growth Direction", {
            ["LEFT_DOWN"] = "Left / Down", ["LEFT_UP"] = "Left / Up",
            ["RIGHT_DOWN"] = "Right / Down", ["RIGHT_UP"] = "Right / Up",
        }, db, "raidBuffGrowth"), 60)
        Add(GUI:CreateSlider(self, "Max Buffs Shown", 1, 20, 1, db, "raidBuffMax"), 60)
        Add(GUI:CreateSlider(self, "Wrap After (Icons)", 1, 20, 1, db, "raidBuffWrap"), 60)
        Add(GUI:CreateSlider(self, "Offset X", -50, 50, 1, db, "raidBuffOffsetX"), 60)
        Add(GUI:CreateSlider(self, "Offset Y", -50, 50, 1, db, "raidBuffOffsetY"), 60)
        
        Add(GUI:CreateHeader(self, "Debuffs"), 30, 2)
        Add(GUI:CreateCheckbox(self, "Click Through Debuffs", db, "raidDebuffClickThrough"), 30, 2)
        Add(GUI:CreateSlider(self, "Scale", 0.5, 2.0, 0.1, db, "raidDebuffScale"), 60, 2)
        Add(GUI:CreateSlider(self, "Alpha", 0.1, 1.0, 0.05, db, "raidDebuffAlpha"), 60, 2)
        Add(GUI:CreateDropdown(self, "Anchor Point", {
            ["TOPLEFT"] = "Top Left", ["TOPRIGHT"] = "Top Right",
            ["BOTTOMLEFT"] = "Bottom Left", ["BOTTOMRIGHT"] = "Bottom Right",
            ["LEFT"] = "Left", ["RIGHT"] = "Right"
        }, db, "raidDebuffAnchor"), 60, 2)
        Add(GUI:CreateDropdown(self, "Growth Direction", {
            ["LEFT_DOWN"] = "Left / Down", ["LEFT_UP"] = "Left / Up",
            ["RIGHT_DOWN"] = "Right / Down", ["RIGHT_UP"] = "Right / Up",
        }, db, "raidDebuffGrowth"), 60, 2)
        Add(GUI:CreateSlider(self, "Max Debuffs Shown", 1, 20, 1, db, "raidDebuffMax"), 60, 2)
        Add(GUI:CreateSlider(self, "Wrap After (Icons)", 1, 20, 1, db, "raidDebuffWrap"), 60, 2)
        Add(GUI:CreateSlider(self, "Offset X", -50, 50, 1, db, "raidDebuffOffsetX"), 60, 2)
        Add(GUI:CreateSlider(self, "Offset Y", -50, 50, 1, db, "raidDebuffOffsetY"), 60, 2)
    end)

    -- TAB 3: HEALTH TEXT
    BuildPage(CreateTab("healthtext", "Health Text"), function(self, db, Add, AddSpace)
        Add(GUI:CreateHeader(self, "Visibility & Style"), 30)
        Add(GUI:CreateCheckbox(self, "Hide Completely", db, "healthTextHide"), 30)
        local cbEnable = Add(GUI:CreateCheckbox(self, "Enable Custom Text", db, "healthTextEnabled"), 30)
        cbEnable.disableOn = function(d) return d.healthTextHide end
        AddSpace(20)
        local fmt = Add(GUI:CreateDropdown(self, "Format", {
            ["Current"] = "Current", ["Percent"] = "Percent",
            ["CurrentMax"] = "Curr / Max", ["Deficit"] = "Deficit"
        }, db, "healthTextFormat"), 60)
        fmt.disableOn = function(d) return d.healthTextHide or not d.healthTextEnabled end
        local font = Add(GUI:CreateDropdown(self, "Font Face", DF.SharedFonts, db, "healthTextFont"), 60)
        font.disableOn = function(d) return d.healthTextHide or not d.healthTextEnabled end
        local out = Add(GUI:CreateDropdown(self, "Outline", {
            ["NONE"] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick", ["MONOCHROME"] = "Mono"
        }, db, "healthTextOutline"), 60)
        out.disableOn = function(d) return d.healthTextHide or not d.healthTextEnabled end
        local scale = Add(GUI:CreateSlider(self, "Font Scale", 0.5, 2.5, 0.1, db, "healthTextScale"), 60)
        scale.disableOn = function(d) return d.healthTextHide or not d.healthTextEnabled end
        
        Add(GUI:CreateHeader(self, "Position & Color"), 30, 2)
        local anch = Add(GUI:CreateDropdown(self, "Anchor", {
            ["CENTER"]="Center", ["LEFT"]="Left", ["RIGHT"]="Right", ["TOP"]="Top", ["BOTTOM"]="Bottom"
        }, db, "healthTextAnchor"), 60, 2)
        anch.disableOn = function(d) return d.healthTextHide or not d.healthTextEnabled end
        local offX = Add(GUI:CreateSlider(self, "Offset X", -100, 100, 1, db, "healthTextX"), 60, 2)
        offX.disableOn = function(d) return d.healthTextHide or not d.healthTextEnabled end
        local offY = Add(GUI:CreateSlider(self, "Offset Y", -100, 100, 1, db, "healthTextY"), 60, 2)
        offY.disableOn = function(d) return d.healthTextHide or not d.healthTextEnabled end
        AddSpace(20)
        local useClass = Add(GUI:CreateCheckbox(self, "Use Class Color", db, "healthTextUseClassColor"), 30, 2)
        useClass.disableOn = function(d) return d.healthTextHide or not d.healthTextEnabled end
        local colPick = Add(GUI:CreateColorPicker(self, "Custom Text Color", db, "healthTextColor", false), 30, 2)
        colPick.disableOn = function(d) return d.healthTextHide or not d.healthTextEnabled or d.healthTextUseClassColor end
    end)

    -- TAB 4: NAME TEXT
    BuildPage(CreateTab("nametext", "Name Text"), function(self, db, Add, AddSpace)
        Add(GUI:CreateHeader(self, "Visibility & Style"), 30)
        Add(GUI:CreateCheckbox(self, "Hide Name", db, "nameTextHide"), 30)
        local realm = Add(GUI:CreateCheckbox(self, "Show Realm", db, "nameTextShowRealm"), 30)
        realm.disableOn = function(d) return d.nameTextHide end
        AddSpace(20)
        local font = Add(GUI:CreateDropdown(self, "Font Face", DF.SharedFonts, db, "nameTextFont"), 60)
        font.disableOn = function(d) return d.nameTextHide end
        local out = Add(GUI:CreateDropdown(self, "Outline", {
            ["NONE"] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick"
        }, db, "nameTextOutline"), 60)
        out.disableOn = function(d) return d.nameTextHide end
        local scale = Add(GUI:CreateSlider(self, "Font Scale", 0.5, 2.5, 0.1, db, "nameTextScale"), 60)
        scale.disableOn = function(d) return d.nameTextHide end
        
        -- FIX: Added callback function to refresh page when slider changes
        -- This fixes the issue where dropdowns stayed disabled until something else was clicked.
        local len = Add(GUI:CreateSlider(self, "Max Length (0 = Unlimited)", 0, 20, 1, db, "nameTextLength", function() GUI:RefreshCurrentPage() end), 60)
        len.disableOn = function(d) return d.nameTextHide end
        
        -- Truncation Mode
        local trunc = Add(GUI:CreateDropdown(self, "Length Mode", {
            ["ELLIPSIS"] = "Truncate with ...",
            ["CLIP"] = "Truncate (Clip)",
            ["WRAP"] = "Wrap to New Line"
        }, db, "nameTextTruncateMode", function() GUI:RefreshCurrentPage() end), 60)
        
        -- FIX: Changed from disableOn to hideOn as requested.
        -- It will now disappear if Length is 0.
        trunc.hideOn = function(d) return d.nameTextHide or d.nameTextLength == 0 end
        
        -- Wrap Alignment
        local wAlign = Add(GUI:CreateDropdown(self, "Wrap Alignment", {
            ["LEFT"] = "Left", ["CENTER"] = "Center", ["RIGHT"] = "Right"
        }, db, "nameTextWrapAlign"), 60)
        wAlign.hideOn = function(d) return d.nameTextHide or d.nameTextTruncateMode ~= "WRAP" or d.nameTextLength == 0 end

        -- Wrap Direction
        local wDir = Add(GUI:CreateDropdown(self, "Wrap Direction", {
            ["DOWN"] = "Down (Normal)", ["UP"] = "Up (Inverted)"
        }, db, "nameTextWrapDirection"), 60)
        wDir.hideOn = function(d) return d.nameTextHide or d.nameTextTruncateMode ~= "WRAP" or d.nameTextLength == 0 end
        
        Add(GUI:CreateHeader(self, "Position & Color"), 30, 2)
        local override = Add(GUI:CreateCheckbox(self, "Override Position", db, "nameTextEnabled"), 30, 2)
        override.disableOn = function(d) return d.nameTextHide end
        local anch = Add(GUI:CreateDropdown(self, "Anchor", {
            ["CENTER"]="Center", ["LEFT"]="Left", ["RIGHT"]="Right", ["TOP"]="Top", ["BOTTOM"]="Bottom"
        }, db, "nameTextAnchor"), 60, 2)
        anch.disableOn = function(d) return d.nameTextHide or not d.nameTextEnabled end
        local x = Add(GUI:CreateSlider(self, "Offset X", -100, 100, 1, db, "nameTextX"), 60, 2)
        x.disableOn = function(d) return d.nameTextHide or not d.nameTextEnabled end
        local y = Add(GUI:CreateSlider(self, "Offset Y", -100, 100, 1, db, "nameTextY"), 60, 2)
        y.disableOn = function(d) return d.nameTextHide or not d.nameTextEnabled end
        AddSpace(20)
        local useClass = Add(GUI:CreateCheckbox(self, "Use Class Color", db, "nameTextUseClassColor"), 30, 2)
        useClass.disableOn = function(d) return d.nameTextHide end
        local col = Add(GUI:CreateColorPicker(self, "Custom Name Color", db, "nameTextColor", false), 30, 2)
        col.disableOn = function(d) return d.nameTextHide or d.nameTextUseClassColor end
    end)

    -- TAB 5: RESOURCE BAR
    BuildPage(CreateTab("resource", "Resource Bar"), function(self, db, Add, AddSpace)
        Add(GUI:CreateHeader(self, "Custom Power Bar"), 30)
        Add(GUI:CreateCheckbox(self, "Enable Custom Bar", db, "resourceBarEnabled"), 30)
        local heal = Add(GUI:CreateCheckbox(self, "Healer Only", db, "resourceBarHealerOnly"), 30)
        heal.disableOn = function(d) return not d.resourceBarEnabled end
        local match = Add(GUI:CreateCheckbox(self, "Match Frame Width", db, "resourceBarMatchWidth"), 30)
        match.disableOn = function(d) return not d.resourceBarEnabled end
        AddSpace(20)
        local w = Add(GUI:CreateSlider(self, "Width", 10, 200, 1, db, "resourceBarWidth"), 60)
        w.disableOn = function(d) return not d.resourceBarEnabled or d.resourceBarMatchWidth end
        local h = Add(GUI:CreateSlider(self, "Height", 1, 30, 1, db, "resourceBarHeight"), 60)
        h.disableOn = function(d) return not d.resourceBarEnabled end
        
        Add(GUI:CreateHeader(self, "Positioning"), 30, 2)
        local anch = Add(GUI:CreateDropdown(self, "Anchor", {
             ["CENTER"]="Center", ["BOTTOM"]="Bottom", ["TOP"]="Top"
        }, db, "resourceBarAnchor"), 60, 2)
        anch.disableOn = function(d) return not d.resourceBarEnabled end
        local x = Add(GUI:CreateSlider(self, "Offset X", -50, 50, 1, db, "resourceBarX"), 60, 2)
        x.disableOn = function(d) return not d.resourceBarEnabled end
        local y = Add(GUI:CreateSlider(self, "Offset Y", -50, 50, 1, db, "resourceBarY"), 60, 2)
        y.disableOn = function(d) return not d.resourceBarEnabled end
    end)

    -- TAB 6: ICONS
    BuildPage(CreateTab("icons", "Icons"), function(self, db, Add, AddSpace)
        Add(GUI:CreateHeader(self, "Leader Icon"), 30)
        Add(GUI:CreateCheckbox(self, "Hide Leader Icon", db, "leaderIconHide"), 30)
        local ledEnabled = Add(GUI:CreateCheckbox(self, "Override Position", db, "leaderIconEnabled"), 30)
        ledEnabled.disableOn = function(d) return d.leaderIconHide end
        local ledS = Add(GUI:CreateSlider(self, "Scale", 0.5, 2.5, 0.1, db, "leaderIconScale"), 60)
        ledS.disableOn = function(d) return d.leaderIconHide or not d.leaderIconEnabled end
        local ledAnch = Add(GUI:CreateDropdown(self, "Anchor", {
            ["CENTER"]="Center", ["LEFT"]="Left", ["RIGHT"]="Right", ["TOP"]="Top", ["BOTTOM"]="Bottom",
            ["TOPLEFT"]="Top Left", ["TOPRIGHT"]="Top Right", ["BOTTOMLEFT"]="Bottom Left", ["BOTTOMRIGHT"]="Bottom Right"
        }, db, "leaderIconAnchor"), 60)
        ledAnch.disableOn = function(d) return d.leaderIconHide or not d.leaderIconEnabled end
        local ledX = Add(GUI:CreateSlider(self, "Offset X", -50, 50, 1, db, "leaderIconX"), 60)
        ledX.disableOn = function(d) return d.leaderIconHide or not d.leaderIconEnabled end
        local ledY = Add(GUI:CreateSlider(self, "Offset Y", -50, 50, 1, db, "leaderIconY"), 60)
        ledY.disableOn = function(d) return d.leaderIconHide or not d.leaderIconEnabled end
        
        AddSpace(20)
        Add(GUI:CreateHeader(self, "Role Icon"), 30)
        Add(GUI:CreateCheckbox(self, "Hide Role Icon", db, "roleIconHide"), 30)
        local roleEnabled = Add(GUI:CreateCheckbox(self, "Override Position", db, "roleIconEnabled"), 30)
        roleEnabled.disableOn = function(d) return d.roleIconHide end
        local roleS = Add(GUI:CreateSlider(self, "Scale", 0.5, 2.5, 0.1, db, "roleIconScale"), 60)
        roleS.disableOn = function(d) return d.roleIconHide or not d.roleIconEnabled end
        local roleAnch = Add(GUI:CreateDropdown(self, "Anchor", {
            ["CENTER"]="Center", ["LEFT"]="Left", ["RIGHT"]="Right", ["TOP"]="Top", ["BOTTOM"]="Bottom",
            ["TOPLEFT"]="Top Left", ["TOPRIGHT"]="Top Right", ["BOTTOMLEFT"]="Bottom Left", ["BOTTOMRIGHT"]="Bottom Right"
        }, db, "roleIconAnchor"), 60)
        roleAnch.disableOn = function(d) return d.roleIconHide or not d.roleIconEnabled end
        local roleX = Add(GUI:CreateSlider(self, "Offset X", -50, 50, 1, db, "roleIconX"), 60)
        roleX.disableOn = function(d) return d.roleIconHide or not d.roleIconEnabled end
        local roleY = Add(GUI:CreateSlider(self, "Offset Y", -50, 50, 1, db, "roleIconY"), 60)
        roleY.disableOn = function(d) return d.roleIconHide or not d.roleIconEnabled end
        
        Add(GUI:CreateHeader(self, "Raid Target (Skull/X)"), 30, 2)
        Add(GUI:CreateCheckbox(self, "Override Position", db, "raidIconEnabled"), 30, 2)
        local s = Add(GUI:CreateSlider(self, "Scale", 0.5, 2.5, 0.1, db, "raidIconScale"), 60, 2)
        s.disableOn = function(d) return not d.raidIconEnabled end
        local rAnch = Add(GUI:CreateDropdown(self, "Anchor", {
            ["CENTER"]="Center", ["LEFT"]="Left", ["RIGHT"]="Right", ["TOP"]="Top", ["BOTTOM"]="Bottom",
            ["TOPLEFT"]="Top Left", ["TOPRIGHT"]="Top Right", ["BOTTOMLEFT"]="Bottom Left", ["BOTTOMRIGHT"]="Bottom Right"
        }, db, "raidIconAnchor"), 60, 2)
        rAnch.disableOn = function(d) return not d.raidIconEnabled end
        local x = Add(GUI:CreateSlider(self, "Offset X", -50, 50, 1, db, "raidIconX"), 60, 2)
        x.disableOn = function(d) return not d.raidIconEnabled end
        local y = Add(GUI:CreateSlider(self, "Offset Y", -50, 50, 1, db, "raidIconY"), 60, 2)
        y.disableOn = function(d) return not d.raidIconEnabled end
        
        AddSpace(20)
        Add(GUI:CreateHeader(self, "Center Status (Res/Summon)"), 30, 2)
        Add(GUI:CreateCheckbox(self, "Override Position", db, "centerStatusIconEnabled"), 30, 2)
        local cs = Add(GUI:CreateSlider(self, "Scale", 0.5, 2.5, 0.1, db, "centerStatusIconScale"), 60, 2)
        cs.disableOn = function(d) return not d.centerStatusIconEnabled end
        local csAnch = Add(GUI:CreateDropdown(self, "Anchor", {
            ["CENTER"]="Center", ["LEFT"]="Left", ["RIGHT"]="Right", ["TOP"]="Top", ["BOTTOM"]="Bottom",
            ["TOPLEFT"]="Top Left", ["TOPRIGHT"]="Top Right", ["BOTTOMLEFT"]="Bottom Left", ["BOTTOMRIGHT"]="Bottom Right"
        }, db, "centerStatusIconAnchor"), 60, 2)
        csAnch.disableOn = function(d) return not d.centerStatusIconEnabled end
        local cx = Add(GUI:CreateSlider(self, "Offset X", -50, 50, 1, db, "centerStatusIconX"), 60, 2)
        cx.disableOn = function(d) return not d.centerStatusIconEnabled end
        local cy = Add(GUI:CreateSlider(self, "Offset Y", -50, 50, 1, db, "centerStatusIconY"), 60, 2)
        cy.disableOn = function(d) return not d.centerStatusIconEnabled end
        
        AddSpace(20)
        Add(GUI:CreateHeader(self, "Ready Check"), 30, 2)
        Add(GUI:CreateCheckbox(self, "Override Position", db, "readyCheckIconEnabled"), 30, 2)
        local rs = Add(GUI:CreateSlider(self, "Scale", 0.5, 2.5, 0.1, db, "readyCheckIconScale"), 60, 2)
        rs.disableOn = function(d) return not d.readyCheckIconEnabled end
        local rsAnch = Add(GUI:CreateDropdown(self, "Anchor", {
            ["CENTER"]="Center", ["LEFT"]="Left", ["RIGHT"]="Right", ["TOP"]="Top", ["BOTTOM"]="Bottom",
            ["TOPLEFT"]="Top Left", ["TOPRIGHT"]="Top Right", ["BOTTOMLEFT"]="Bottom Left", ["BOTTOMRIGHT"]="Bottom Right"
        }, db, "readyCheckIconAnchor"), 60, 2)
        rsAnch.disableOn = function(d) return not d.readyCheckIconEnabled end
        local rx = Add(GUI:CreateSlider(self, "Offset X", -50, 50, 1, db, "readyCheckIconX"), 60, 2)
        rx.disableOn = function(d) return not d.readyCheckIconEnabled end
        local ry = Add(GUI:CreateSlider(self, "Offset Y", -50, 50, 1, db, "readyCheckIconY"), 60, 2)
        ry.disableOn = function(d) return not d.readyCheckIconEnabled end
    end)

    -- TAB 7: PROFILES
    BuildPage(CreateTab("profiles", "Profiles"), function(self, db, Add, AddSpace)
        Add(GUI:CreateHeader(self, "Profile Management"), 30)
        local currentProfile = DF.db:GetCurrentProfile()
        local profiles = DF.db:GetProfiles()
        Add(GUI:CreateHeader(self, "Current Profile: " .. currentProfile), 30)
        
        local scrollFrame = CreateFrame("ScrollFrame", nil, self.child, "UIPanelScrollFrameTemplate")
        scrollFrame:SetSize(240, 200)
        scrollFrame:SetPoint("TOPLEFT", 10, -80) 
        GUI.CreateBackdrop(scrollFrame)
        scrollFrame:SetBackdropColor(0,0,0,0.3)
        local scrollChild = CreateFrame("Frame")
        scrollChild:SetSize(240, #profiles * 22 + 10)
        scrollFrame:SetScrollChild(scrollChild)
        table.insert(self.children, scrollFrame) 
        
        local py = 0
        for i, p in ipairs(profiles) do
             local btn = GUI:CreateButton(scrollChild, p, 235, 20)
             btn:SetPoint("TOPLEFT", 0, py)
             if p == currentProfile then
                 -- FIX: Call GUI.GetThemeColor() instead of global GetThemeColor()
                 local c = GUI.GetThemeColor()
                 btn:SetBackdropColor(c.r, c.g, c.b, 0.5)
             end
             btn:SetScript("OnClick", function() DF.db:SetProfile(p) GUI:RefreshCurrentPage() end)
             py = py - 22
        end

        Add(GUI:CreateHeader(self, "Create New"), 30, 2)
        local input = GUI:CreateInput(self, "New Profile Name", 180)
        Add(input, 50, 2)
        Add(GUI:CreateButton(self, "Create", 100, 24, function()
             local text = input.EditBox:GetText()
             if text and text ~= "" then DF.db:SetProfile(text) GUI:RefreshCurrentPage() end
        end), 30, 2)
        
        AddSpace(20)
        Add(GUI:CreateButton(self, "Delete Current", 140, 24, function()
             local p = DF.db:GetCurrentProfile()
             if p ~= "Default" then DF.db:DeleteProfile(p) GUI:RefreshCurrentPage()
             else print("Cannot delete Default profile.") end
        end), 30, 2)
        Add(GUI:CreateButton(self, "Reset Profile", 140, 24, function()
             DF:ResetProfile("party") DF:ResetProfile("raid") GUI:RefreshCurrentPage()
        end), 30, 2)
        
        AddSpace(20)
        Add(GUI:CreateHeader(self, "Auto-Switching (Specs)"), 30, 2)
        Add(GUI:CreateCheckbox(self, "Enable Auto Switch", DF.db.char, "enableSpecSwitch"), 30, 2)
        
        local numSpecs = GetNumSpecializations and GetNumSpecializations() or 0
        if numSpecs > 0 then
            local pList = {}
            for _, p in ipairs(profiles) do pList[p] = p end
            for i = 1, numSpecs do
                local id, name, _, icon = GetSpecializationInfo(i)
                if name then
                    Add(GUI:CreateHeader(self, name), 20, 2)
                    if not DF.db.char.specProfiles then DF.db.char.specProfiles = {} end
                    local dd = GUI:CreateDropdown(self, "", pList, DF.db.char.specProfiles, i)
                    Add(dd, 60, 2)
                end
            end
        end
    end)

    -- TAB 8: TOOLS
    BuildPage(CreateTab("tools", "Tools"), function(self, db, Add, AddSpace)
        Add(GUI:CreateHeader(self, "Copy Settings (Current Profile)"), 30)
        Add(GUI:CreateButton(self, "Copy Party -> Raid", 200, 30, function() 
            DF:CopyProfile("party", "raid")
            print("|cff00ff00DandersFrames:|r Copied Party settings to Raid.")
            GUI:RefreshCurrentPage()
        end), 40)
        Add(GUI:CreateButton(self, "Copy Raid -> Party", 200, 30, function() 
            DF:CopyProfile("raid", "party")
            print("|cff00ff00DandersFrames:|r Copied Raid settings to Party.")
            GUI:RefreshCurrentPage()
        end), 40)
        AddSpace(20)
        Add(GUI:CreateHeader(self, "Reset Settings (Current Mode Only)"), 30)
        Add(GUI:CreateButton(self, "Reset " .. (GUI.SelectedMode == "party" and "Party" or "Raid"), 200, 30, function()
             DF:ResetProfile(GUI.SelectedMode)
             DF:UpdateAll()
             GUI:RefreshCurrentPage()
        end), 40)
    end)

    -- TAB 9: IMPORT / EXPORT
    BuildPage(CreateTab("import", "Import / Export"), function(self, db, Add, AddSpace)
        Add(GUI:CreateHeader(self, "Export / Import Settings"), 30, 1) 
        local spacer = CreateFrame("Frame", nil, self.child)
        Add(spacer, 30, 2)
        local scroll = CreateFrame("ScrollFrame", nil, self.child, "UIPanelScrollFrameTemplate")
        scroll:SetSize(320, 300) 
        GUI.CreateBackdrop(scroll)
        scroll:SetBackdropColor(0,0,0,0.5)
        local editBox = CreateFrame("EditBox", nil, scroll)
        editBox:SetMultiLine(true)
        editBox:SetFontObject(GameFontHighlightSmall)
        editBox:SetWidth(300)
        editBox:SetTextInsets(5, 5, 5, 5)
        scroll:SetScrollChild(editBox)
        Add(scroll, 310, 1) 
        
        local btnExport = GUI:CreateButton(self, "Generate Export String", 160, 24, function()
             local str = DF:ExportProfile()
             editBox:SetText(str)
             editBox:HighlightText()
             editBox:SetFocus()
        end)
        Add(btnExport, 30, 2)
        local btnImport = GUI:CreateButton(self, "Import String", 160, 24, function()
             local str = editBox:GetText()
             if str and str ~= "" then
                 DF:ImportProfile(str)
                 GUI:RefreshCurrentPage()
             end
        end)
        Add(btnImport, 30, 2)
    end)
end