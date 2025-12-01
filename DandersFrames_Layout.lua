local addonName, DF = ...

-- ============================================================
-- LAYOUT & POSITIONING
-- ============================================================

-- Store original frame sizes for reset functionality
DF.OriginalFrameSizes = {}

-- Draggable Mover Frames
DF.Movers = {}
DF.MoverMode = false

-- Capture original Blizzard frame sizes before we modify them
function DF:CaptureOriginalSize(frame)
    if not frame then return end
    local name = frame:GetName()
    if not name then return end
    
    if not DF.OriginalFrameSizes[name] then
        DF.OriginalFrameSizes[name] = {
            width = frame:GetWidth(),
            height = frame:GetHeight(),
        }
    end
end

-- Reset frame to Blizzard default size
function DF:ResetFrameToDefault(frame)
    if not frame then return end
    if InCombatLockdown() then return end
    
    local name = frame:GetName()
    if not name then return end
    
    local original = DF.OriginalFrameSizes[name]
    if original then
        frame:SetSize(original.width, original.height)
    end
end

-- Apply Frame Layout (Width, Height, Opacity only)
function DF:ApplyFrameLayout(frame)
    if not DF:IsValidFrame(frame) then return end
    if InCombatLockdown() then return end
    
    local db = DF:GetDB(frame)
    
    -- Capture original size before any modifications
    DF:CaptureOriginalSize(frame)
    
    -- If custom layout is disabled, reset to defaults
    if not db.enableFrameLayout then
        DF:ResetFrameToDefault(frame)
        frame:SetAlpha(1.0)
        
        if frame.healthBar then
            local padding = db.framePadding or 3
            frame.healthBar:ClearAllPoints()
            frame.healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", padding, -padding)
            frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -padding, padding)
        end
        return
    end
    
    -- Apply custom sizing
    local width = db.frameWidth or 72
    local height = db.frameHeight or 36
    local opacity = db.frameOpacity or 1.0
    
    frame:SetSize(width, height)
    frame:SetAlpha(opacity)
    
    -- Ensure health bar fills the resized frame (respecting padding)
    if frame.healthBar then
        local pt = db.useSpecificPadding and db.paddingTop or db.framePadding
        local pb = db.useSpecificPadding and db.paddingBottom or db.framePadding
        local pl = db.useSpecificPadding and db.paddingLeft or db.framePadding
        local pr = db.useSpecificPadding and db.paddingRight or db.framePadding
        
        frame.healthBar:ClearAllPoints()
        frame.healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", pl, -pt)
        frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pr, pb)
    end
end

-- ============================================================
-- DRAGGABLE MOVER SYSTEM WITH DEMO FRAMES
-- ============================================================

-- Create demo unit frames inside the mover
function DF:CreateDemoFrames(mover, mode, db)
    if mover.demoFrames then
        -- Clear existing demo frames
        for _, frame in ipairs(mover.demoFrames) do
            frame:Hide()
        end
    end
    mover.demoFrames = {}
    
    local frameWidth = db.frameWidth or 72
    local frameHeight = db.frameHeight or 36
    local spacing = 2
    local isHorizontal = false  -- Always use vertical layout (default WoW behavior)
    
    -- Determine number of frames and layout
    -- Party: 5 frames
    -- Raid: 40 frames in groups of 5
    local numFrames = (mode == "raid") and 40 or 5
    local framesPerGroup = 5
    local numGroups = math.ceil(numFrames / framesPerGroup)
    
    -- Demo class colors for variety
    local classColors = {
        {r=0.78, g=0.61, b=0.43}, -- Warrior
        {r=1.00, g=0.96, b=0.41}, -- Rogue  
        {r=0.00, g=0.44, b=0.87}, -- Shaman
        {r=0.96, g=0.55, b=0.73}, -- Paladin
        {r=1.00, g=0.49, b=0.04}, -- Druid
        {r=0.64, g=0.19, b=0.79}, -- Warlock
        {r=0.00, g=1.00, b=0.59}, -- Monk
        {r=0.77, g=0.12, b=0.23}, -- Death Knight
    }
    
    for i = 1, numFrames do
        local demo = CreateFrame("Frame", nil, mover, "BackdropTemplate")
        demo:SetSize(frameWidth, frameHeight)
        
        -- Calculate position based on orientation
        local groupIndex = math.floor((i - 1) / framesPerGroup)  -- Which group (0-indexed)
        local indexInGroup = (i - 1) % framesPerGroup             -- Position within group (0-indexed)
        
        local xOffset, yOffset
        
        if isHorizontal then
            -- Horizontal: frames go left-to-right within a group, groups stack top-to-bottom
            xOffset = indexInGroup * (frameWidth + spacing)
            yOffset = -groupIndex * (frameHeight + spacing)
        else
            -- Vertical (default): frames go top-to-bottom within a group, groups go left-to-right
            xOffset = groupIndex * (frameWidth + spacing)
            yOffset = -indexInGroup * (frameHeight + spacing)
        end
        
        demo:SetPoint("TOPLEFT", mover, "TOPLEFT", 10 + xOffset, -35 + yOffset)
        
        -- Style the demo frame
        demo:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        
        local color = classColors[(i % #classColors) + 1]
        demo:SetBackdropColor(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.9)
        demo:SetBackdropBorderColor(0, 0, 0, 1)
        
        -- Add a "health bar" visual
        local healthBar = demo:CreateTexture(nil, "ARTWORK")
        healthBar:SetPoint("TOPLEFT", 2, -2)
        healthBar:SetColorTexture(color.r, color.g, color.b, 1)
        
        -- Simulate different health levels
        local healthPercent = 0.5 + (math.random() * 0.5)
        healthBar:SetPoint("BOTTOMRIGHT", demo, "BOTTOMLEFT", 2 + (frameWidth - 4) * healthPercent, 2)
        
        -- Use minimal border styling
        demo:SetBackdropBorderColor(0, 0, 0, 0)
        
        demo:Show()
        table.insert(mover.demoFrames, demo)
    end
    
    -- Calculate total size needed based on orientation
    local totalWidth, totalHeight
    
    if isHorizontal then
        -- Horizontal: width = frames per group, height = number of groups
        local framesWide = math.min(numFrames, framesPerGroup)
        totalWidth = (framesWide * (frameWidth + spacing)) - spacing + 20
        totalHeight = (numGroups * (frameHeight + spacing)) - spacing + 55
    else
        -- Vertical: width = number of groups, height = frames per group
        local framesTall = math.min(numFrames, framesPerGroup)
        totalWidth = (numGroups * (frameWidth + spacing)) - spacing + 20
        totalHeight = (framesTall * (frameHeight + spacing)) - spacing + 55
    end
    
    mover:SetSize(math.max(totalWidth, 150), math.max(totalHeight, 100))
end

-- Create a mover frame for a container
function DF:CreateMover(name, targetFrame, mode)
    if DF.Movers[name] then 
        return DF.Movers[name] 
    end
    if not targetFrame then return nil end
    
    local mover = CreateFrame("Frame", "DFMover_" .. name, UIParent, "BackdropTemplate")
    mover:SetFrameStrata("FULLSCREEN_DIALOG")
    mover:SetClampedToScreen(true)
    mover:EnableMouse(true)
    mover:SetMovable(true)
    mover:RegisterForDrag("LeftButton")
    mover:Hide()
    
    -- Visual styling
    mover:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    
    local themeColor = (mode == "raid") and {r=1, g=0.4, b=0.2} or {r=0.2, g=0.6, b=1}
    mover:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    mover:SetBackdropBorderColor(themeColor.r, themeColor.g, themeColor.b, 1)
    
    -- Title bar
    local titleBar = CreateFrame("Frame", nil, mover, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetHeight(30)
    titleBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    titleBar:SetBackdropColor(themeColor.r, themeColor.g, themeColor.b, 0.8)
    
    -- Label
    local label = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("TOP", titleBar, "TOP", 0, -8)
    label:SetText(mode == "raid" and "Raid Frames" or "Party Frames")
    label:SetTextColor(1, 1, 1, 1)
    mover.label = label
    
    -- Instructions at bottom
    local instructions = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    instructions:SetPoint("BOTTOM", mover, "BOTTOM", 0, 5)
    instructions:SetText("Drag to move | Right-click to lock")
    instructions:SetTextColor(0.7, 0.7, 0.7, 1)
    mover.instructions = instructions
    
    -- Store references
    mover.targetFrame = targetFrame
    mover.mode = mode
    mover.themeColor = themeColor
    
    -- Drag handlers - MOVE THE ACTUAL BLIZZARD FRAME
    mover:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then 
            print("|cffff0000DandersFrames:|r Cannot move frames in combat.")
            return 
        end
        self:StartMoving()
        self.isMoving = true
    end)
    
    mover:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.isMoving = false
        
        -- Save and apply position to actual Blizzard frame
        DF:SaveAndApplyMoverPosition(self)
    end)
    
    -- Right-click to lock
    mover:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            DF:ToggleMoverMode(false)
        end
    end)
    
    DF.Movers[name] = mover
    return mover
end

-- Save mover position and apply to actual Blizzard frame
function DF:SaveAndApplyMoverPosition(mover)
    if not mover or not mover.targetFrame then return end
    if InCombatLockdown() then return end
    
    local db = DF.db.profile[mover.mode]
    
    -- Get mover center position relative to screen center
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    local moverCenterX, moverCenterY = mover:GetCenter()
    
    if moverCenterX and moverCenterY then
        -- Calculate offset from screen center
        db.framePositionX = math.floor(moverCenterX - (screenWidth / 2) + 0.5)
        db.framePositionY = math.floor(moverCenterY - (screenHeight / 2) + 0.5)
        db.frameAnchor = "CENTER"
        
        -- Apply to actual Blizzard frame immediately
        local target = mover.targetFrame
        target:ClearAllPoints()
        target:SetPoint("CENTER", UIParent, "CENTER", db.framePositionX, db.framePositionY)
    end
end

-- Initialize mover position from saved data or current frame position  
function DF:InitializeMoverPosition(mover)
    if not mover or not mover.targetFrame then return end
    
    local db = DF.db.profile[mover.mode]
    
    mover:ClearAllPoints()
    
    if db.framePositionX ~= 0 or db.framePositionY ~= 0 then
        -- Use saved position
        mover:SetPoint("CENTER", UIParent, "CENTER", db.framePositionX, db.framePositionY)
    else
        -- Match current target frame position
        local targetCenterX, targetCenterY = mover.targetFrame:GetCenter()
        if targetCenterX and targetCenterY then
            local screenWidth = GetScreenWidth()
            local screenHeight = GetScreenHeight()
            local offsetX = targetCenterX - (screenWidth / 2)
            local offsetY = targetCenterY - (screenHeight / 2)
            mover:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY)
        else
            mover:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end
end

-- Toggle mover mode on/off
function DF:ToggleMoverMode(enable)
    if InCombatLockdown() then
        print("|cffff0000DandersFrames:|r Cannot toggle mover mode in combat.")
        return
    end
    
    DF.MoverMode = enable
    
    if enable then
        -- Create/show party mover
        if CompactPartyFrame then
            local partyMover = DF:CreateMover("Party", CompactPartyFrame, "party")
            if partyMover then
                local db = DF.db.profile.party
                DF:CreateDemoFrames(partyMover, "party", db)
                DF:InitializeMoverPosition(partyMover)
                partyMover:Show()
            end
        end
        
        -- Create/show raid mover
        if CompactRaidFrameContainer then
            local raidMover = DF:CreateMover("Raid", CompactRaidFrameContainer, "raid")
            if raidMover then
                local db = DF.db.profile.raid
                DF:CreateDemoFrames(raidMover, "raid", db)
                DF:InitializeMoverPosition(raidMover)
                raidMover:Show()
            end
        end
        
        print("|cff00ff00DandersFrames:|r Frame movers unlocked. Drag to reposition. Right-click to lock.")
    else
        -- Hide all movers
        for name, mover in pairs(DF.Movers) do
            mover:Hide()
        end
        
        print("|cff00ff00DandersFrames:|r Frame movers locked.")
        
        -- Refresh the GUI if open
        if DF.GUIFrame and DF.GUIFrame:IsShown() and DF.GUI.RefreshCurrentPage then
            DF.GUI:RefreshCurrentPage()
        end
    end
end

-- Check if mover mode is active
function DF:IsMoverModeActive()
    return DF.MoverMode
end

-- ============================================================
-- CONTAINER LAYOUT FUNCTIONS  
-- ============================================================

-- Apply container-level settings (simplified - border/layout removed)
function DF:ApplyContainerLayout()
    if InCombatLockdown() then return end
    
    -- Border and horizontal layout features have been removed
    -- This function is kept for compatibility but does minimal work now
end

-- Legacy function name for compatibility
function DF:ApplyFrameSize(frame)
    DF:ApplyFrameLayout(frame)
end

function DF:ApplyFrameInset(frame)
    if not DF:IsValidFrame(frame) then return end
    if InCombatLockdown() then return end
    
    local db = DF:GetDB(frame)
    if db.resourceBarEnabled then return end 
    
    if frame.healthBar then
        local pt = db.useSpecificPadding and db.paddingTop or db.framePadding
        local pb = db.useSpecificPadding and db.paddingBottom or db.framePadding
        local pl = db.useSpecificPadding and db.paddingLeft or db.framePadding
        local pr = db.useSpecificPadding and db.paddingRight or db.framePadding
        
        frame.healthBar:ClearAllPoints()
        frame.healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", pl, -pt)
        frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pr, pb)
    end
end

-- APPLIES TEXTURE TO HEALTH BAR
function DF:ApplyTexture(frame)
    if not DF:IsValidFrame(frame) then return end
    local db = DF:GetDB(frame)
    
    if frame.healthBar then
        local tex = db.healthTexture or "Interface\\TargetingFrame\\UI-StatusBar"
        frame.healthBar:SetStatusBarTexture(tex)
    end
end

-- ============================================================
-- FRAME TITLE VISIBILITY
-- ============================================================

function DF:UpdateFrameTitles()
    -- 1. PARTY TITLE ("Party" text in CompactPartyFrame)
    if CompactPartyFrame then
        local db = DF.db.profile.party
        if CompactPartyFrameTitle then
            if db.hidePartyTitle then
                CompactPartyFrameTitle:Hide()
            else
                CompactPartyFrameTitle:Show()
            end
        end
    end
    
    -- 2. RAID GROUP NUMBERS (Group 1, Group 2, etc.)
    if CompactRaidFrameContainer then
        local db = DF.db.profile.raid
        
        -- Method 1: Check CompactRaidGroup frames directly (1-8 groups possible)
        for i = 1, 8 do
            local groupFrame = _G["CompactRaidGroup" .. i]
            if groupFrame then
                if groupFrame.title then
                    groupFrame.title:SetShown(not db.hideRaidGroupNumbers)
                end
                
                local titleFrame = _G["CompactRaidGroup" .. i .. "Title"]
                if titleFrame then
                    titleFrame:SetShown(not db.hideRaidGroupNumbers)
                end
                
                if groupFrame.borderFrame and groupFrame.borderFrame.title then
                    groupFrame.borderFrame.title:SetShown(not db.hideRaidGroupNumbers)
                end
            end
        end
        
        -- Method 2: Also iterate container children for any Header frames
        for _, child in ipairs({CompactRaidFrameContainer:GetChildren()}) do
            local name = child:GetName()
            if name and string.find(name, "Header") then
                child:SetShown(not db.hideRaidGroupNumbers)
            end
            if child.title then
                child.title:SetShown(not db.hideRaidGroupNumbers)
            end
        end
    end
end

-- ============================================================
-- SOLO MODE & DEMO MODE
-- ============================================================

local Hook_CompactPartyFrame_UpdateVisibility = function() end

function DF:SetupSoloMode()
    Hook_CompactPartyFrame_UpdateVisibility = function()
        if not DF.db or not DF.db.profile then return end
        
        local shouldShow = (DF.db.profile.party.soloMode or DF.demoMode)
        
        -- FIX: Robust check for "Use Raid-Style Party Frames"
        local useCompact = false
        if EditModeManagerFrame and EditModeManagerFrame.UseRaidStylePartyFrames then
            useCompact = EditModeManagerFrame:UseRaidStylePartyFrames()
        else
            useCompact = GetCVarBool("useCompactPartyFrames")
        end
        
        if shouldShow and (not IsInGroup() and not IsInRaid()) then
            if InCombatLockdown() then
                C_Timer.After(1, Hook_CompactPartyFrame_UpdateVisibility)
                return
            end
            
            -- Only show if the Blizzard Feature is enabled
            if CompactPartyFrame and useCompact then
                CompactPartyFrame:SetShown(true)
                
                -- FIX: Force Layout update to prevent empty/collapsed frame on reload
                if CompactPartyFrame.Layout then 
                    CompactPartyFrame:Layout() 
                end
                
                -- NEW: Immediately check for center anchoring when solo mode becomes active
                if DF.EnforceCenterAnchor then
                    DF:EnforceCenterAnchor()
                    C_Timer.After(0.2, function() DF:EnforceCenterAnchor() end)
                    C_Timer.After(0.5, function() DF:EnforceCenterAnchor() end)
                    C_Timer.After(1.0, function() DF:EnforceCenterAnchor() end)
                end
            end
        end
    end

    if CompactPartyFrame then
        hooksecurefunc(CompactPartyFrame, "UpdateVisibility", Hook_CompactPartyFrame_UpdateVisibility)
        Hook_CompactPartyFrame_UpdateVisibility()
    else
        local loader = CreateFrame("Frame")
        loader:RegisterEvent("ADDON_LOADED")
        loader:SetScript("OnEvent", function(self, event, arg1)
            if arg1 == "Blizzard_CompactRaidFrames" then
                if CompactPartyFrame then
                    hooksecurefunc(CompactPartyFrame, "UpdateVisibility", Hook_CompactPartyFrame_UpdateVisibility)
                    Hook_CompactPartyFrame_UpdateVisibility()
                end
                self:UnregisterAllEvents()
            end
        end)
    end
    
    -- NEW: Hook Raid Container Layout to catch Edit Mode changes instantly
    if CompactRaidFrameContainer then
        hooksecurefunc(CompactRaidFrameContainer, "Layout", function()
            -- Only run detection if Edit Mode is open
            if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
                if DF.debugEnabled then print("DF DEBUG: Raid Layout Updated inside Edit Mode - Triggering Detection") end
                DF:DetectAndCacheRaidSize()
            end
        end)
    end
end

-- DUMMY OBJECTS
local DummyHighlight = {}
local function DummyFunc() end
setmetatable(DummyHighlight, {
    __index = function(t, k)
        return DummyFunc 
    end
})

-- DEMO MODE LOOP
function DF:ToggleDemoMode(enable)
    DF.demoMode = enable
    
    if InCombatLockdown() then 
        print("|cffff0000DandersFrames:|r Cannot toggle Demo Mode in combat.")
        return 
    end

    if enable then
        -- FIX: Prevent crash if Raid Style Frames are disabled
        local useCompact = false
        if EditModeManagerFrame and EditModeManagerFrame.UseRaidStylePartyFrames then
            useCompact = EditModeManagerFrame:UseRaidStylePartyFrames()
        else
            useCompact = GetCVarBool("useCompactPartyFrames")
        end

        if not useCompact then
             print("|cffff0000DandersFrames:|r Cannot start Demo Mode: 'Use Raid-Style Party Frames' is disabled in Blizzard Options.")
             DF.demoMode = false
             return
        end
        
        if CompactPartyFrame then
            CompactPartyFrame:SetShown(true)
            for i = 1, 5 do
                local member = _G["CompactPartyFrameMember"..i]
                if member then
                    UnregisterUnitWatch(member)
                    
                    -- Disable optionTable range display to prevent Blizzard range checks
                    if member.optionTable then
                        member._originalDisplayInRange = member.optionTable.displayInRange
                        member.optionTable.displayInRange = false
                        -- Also disable other options that query unit data
                        member._originalDisplaySelectionHighlight = member.optionTable.displaySelectionHighlight
                        member.optionTable.displaySelectionHighlight = false
                        member._originalDisplayAggroHighlight = member.optionTable.displayAggroHighlight
                        member.optionTable.displayAggroHighlight = false
                    end
                    
                    -- Replace selectionHighlight with dummy to prevent errors
                    if member.selectionHighlight ~= DummyHighlight then
                        if member.selectionHighlight then member.selectionHighlight:Hide() end
                        member._originalSelectionHighlight = member.selectionHighlight
                        member.selectionHighlight = DummyHighlight
                    end
                    if member.aggroHighlight ~= DummyHighlight then
                        if member.aggroHighlight then member.aggroHighlight:Hide() end
                        member._originalAggroHighlight = member.aggroHighlight
                        member.aggroHighlight = DummyHighlight
                    end
                    
                    -- Disable mouse to prevent interaction
                    member:EnableMouse(false)
                    member:SetScript("OnEnter", nil)
                    member:SetScript("OnLeave", nil)
                    
                    -- IMPORTANT: Set unit BEFORE showing to prevent Blizzard from querying real units
                    member.unit = "dandersdemo"
                    member.displayedUnit = "dandersdemo"
                    
                    -- Force unitExists to false to prevent Blizzard API calls
                    member.unitExists = false
                    
                    member:SetShown(true)
                    
                    -- Manually set up the visual appearance without triggering Blizzard updates
                    if member.healthBar then
                        member.healthBar:SetMinMaxValues(0, 100)
                        member.healthBar:SetValue(100)
                    end
                    if member.name then
                        member.name:SetText("Demo Unit " .. i)
                    end
                end
            end
            
            -- Enforce Center Anchor immediately when demo starts
            DF:EnforceCenterAnchor()
        end
        
        if not DF.DemoFrame then
            DF.DemoFrame = CreateFrame("Frame")
            DF.DemoFrame.elapsed = 0
            DF.DemoFrame.direction = -1
            DF.DemoFrame:SetScript("OnUpdate", function(self, elapsed)
                self.elapsed = self.elapsed + elapsed
                if self.elapsed > 0.05 then
                    self.elapsed = 0
                    DF.demoPercent = DF.demoPercent + (0.02 * self.direction)
                    if DF.demoPercent >= 1 then
                        DF.demoPercent = 1
                        self.direction = -1
                    elseif DF.demoPercent <= 0 then
                        DF.demoPercent = 0
                        self.direction = 1
                    end
                    -- Use a lighter update that doesn't trigger Blizzard code paths
                    DF:UpdateDemoFramesOnly()
                end
            end)
        end
        DF.DemoFrame:Show()
        DF:UpdateAll()
    else
        if DF.DemoFrame then 
            DF.DemoFrame:Hide() 
        end
        
        if CompactPartyFrame then
            for i = 1, 5 do
                local member = _G["CompactPartyFrameMember"..i]
                if member then
                    -- Restore UnitWatch
                    local unit = "party"..i
                    if i == 1 then unit = "player" end
                    
                    member.unit = unit
                    member.displayedUnit = unit
                    member.unitExists = nil -- Let Blizzard recalculate
                    RegisterUnitWatch(member)
                    
                    -- Restore optionTable settings
                    if member.optionTable then
                        if member._originalDisplayInRange ~= nil then
                            member.optionTable.displayInRange = member._originalDisplayInRange
                        end
                        if member._originalDisplaySelectionHighlight ~= nil then
                            member.optionTable.displaySelectionHighlight = member._originalDisplaySelectionHighlight
                        end
                        if member._originalDisplayAggroHighlight ~= nil then
                            member.optionTable.displayAggroHighlight = member._originalDisplayAggroHighlight
                        end
                    end
                    
                    -- Restore Selection Highlight
                    if member._originalSelectionHighlight then
                        member.selectionHighlight = member._originalSelectionHighlight
                        member._originalSelectionHighlight = nil
                    end
                    
                    -- Restore Aggro Highlight
                    if member._originalAggroHighlight then
                        member.aggroHighlight = member._originalAggroHighlight
                        member._originalAggroHighlight = nil
                    end
                    
                    -- Re-enable mouse
                    member:EnableMouse(true)
                end
            end
            
            -- Use Blizzard's function to force a layout update after restoring
            if CompactPartyFrame.UpdateVisibility then
                CompactPartyFrame:UpdateVisibility()
            end
        end
        
        DF:UpdateAll()
    end
end

-- Lighter update function for demo mode that doesn't trigger Blizzard code paths
function DF:UpdateDemoFramesOnly()
    if not DF.demoMode then return end
    
    for i = 1, 5 do
        local member = _G["CompactPartyFrameMember"..i]
        if member and member.healthBar then
            member.healthBar:SetValue(DF.demoPercent * 100)
            
            -- Update health colors visually
            if DF.ApplyHealthColors then DF:ApplyHealthColors(member) end
            if DF.UpdateHealthText then DF:UpdateHealthText(member) end
        end
    end
end

-- ============================================================
-- CENTER ANCHOR LOGIC
-- ============================================================

DF.AnchorCache = {}

function DF:SaveDefaultAnchor(frame)
    if not frame then return end
    local name = frame:GetName()
    if not name then return end
    if DF.AnchorCache[name] then return end -- Only save ONCE

    local point, relTo, relPoint, offX, offY = frame:GetPoint(1)
    if point then
        local relToName = nil
        if relTo then relToName = relTo:GetName() or "UIParent" end
        DF.AnchorCache[name] = {
            point = point,
            relToName = relToName,
            relPoint = relPoint,
            offX = offX,
            offY = offY
        }
    end
end

function DF:RestoreDefaultAnchor(frame)
    if not frame then return end
    local name = frame:GetName()
    if not name or not DF.AnchorCache[name] then return end
    
    local info = DF.AnchorCache[name]
    local relTo = (info.relToName and _G[info.relToName]) or UIParent
    
    frame:ClearAllPoints()
    frame:SetPoint(info.point, relTo, info.relPoint, info.offX, info.offY)
    
    -- FIX: Ensure frame is movable before setting user placed (prevents error)
    if not frame:IsMovable() then frame:SetMovable(true) end
    if frame.SetUserPlaced then frame:SetUserPlaced(false) end
end

function DF:EnforceCenterAnchor()
    if InCombatLockdown() then return end
    
    DF:EnforcePartyCenter()
    DF:EnforceRaidCenter()
end

function DF:EnforcePartyCenter()
    local frame = CompactPartyFrame
    if not frame or not DF.db or InCombatLockdown() then return end
    
    local config = DF.db.profile.party
    
    -- HANDLE DISABLE - Restore default position when growCenter is disabled
    if not config or not config.growCenter then 
        DF:RestoreDefaultAnchor(frame)
        return 
    end

    -- Save Default BEFORE we move it
    DF:SaveDefaultAnchor(frame)
    
    -- Ensure children lay out first
    if frame.Layout then frame:Layout() end

    -- 1. Identify Orientation & Unit Size
    local member1 = _G["CompactPartyFrameMember1"]
    if not member1 then return end
    
    local unitW, unitH = member1:GetWidth(), member1:GetHeight()
    if unitW < 1 or unitH < 1 then return end
    
    -- Try to detect orientation and gap using Member 2
    local member2 = _G["CompactPartyFrameMember2"]
    
    -- Load cached setting (Default to Vertical/False if nil)
    local isHorizontal = config.layoutHorizontal or false
    local gap = 0
    
    if member2 and member2:IsShown() then
        local x1, y1 = member1:GetCenter()
        local x2, y2 = member2:GetCenter()
        if x1 and x2 and y1 and y2 then
            local detectedHorizontal = false
            -- Determine orientation based on relative positions
            if math.abs(x1 - x2) > math.abs(y1 - y2) then
                detectedHorizontal = true
                gap = math.abs(member2:GetLeft() - member1:GetRight())
            else
                detectedHorizontal = false
                gap = math.abs(member1:GetBottom() - member2:GetTop())
            end
            
            -- Save if changed
            if config.layoutHorizontal ~= detectedHorizontal then
                config.layoutHorizontal = detectedHorizontal
                isHorizontal = detectedHorizontal
                if DF.debugEnabled then 
                    print("DF DEBUG: Party Orientation Saved: " .. (isHorizontal and "HOR" or "VER")) 
                end
            end
        end
    end
    
    -- 2. Calculate MAX vs CURRENT Dimensions
    -- Party is ALWAYS Max 5 Players.
    local maxW, maxH
    local currentW, currentH = frame:GetWidth(), frame:GetHeight()
    
    if isHorizontal then
        -- Grows Right: Width changes, Height fixed
        maxW = (unitW * 5) + (gap * 4)
        maxH = currentH 
    else
        -- Grows Down: Height changes, Width fixed (Standard Party)
        maxH = (unitH * 5) + (gap * 4)
        maxW = currentW 
    end
    
    -- 3. Calculate Required Offset
    -- This is how much "empty space" is missing. We shift by half of this.
    local offX = (maxW - currentW) / 2
    local offY = (maxH - currentH) / 2
    
    if math.abs(offX) < 1 and math.abs(offY) < 1 then return end
    
    -- 4. Apply Offset Relative to BASE Position
    -- We must store the "User Set" position (Base) and offset from there.
    -- If we just added to current position, it would fly off screen.
    
    local point, relTo, relPoint, xOfs, yOfs = frame:GetPoint(1)
    if not point then return end
    
    -- Capture Base if needed (First Run or Reset Detected)
    if not frame.dfBaseX then
        frame.dfBaseX = xOfs
        frame.dfBaseY = yOfs
        if DF.debugEnabled then print("DF DEBUG: Party Base Captured: ", xOfs, yOfs) end
    else
        -- Check for Reset (User drag or Blizz layout reset)
        local lastSetX = frame.dfLastSetX or 99999
        local lastSetY = frame.dfLastSetY or 99999
        
        -- Tolerance check
        if math.abs(xOfs - lastSetX) > 1 or math.abs(yOfs - lastSetY) > 1 then
            -- Position changed externally, update Base
            frame.dfBaseX = xOfs
            frame.dfBaseY = yOfs
            if DF.debugEnabled then print("DF DEBUG: Party Base Reset Detected! New Base: ", xOfs, yOfs) end
        end
    end
    
    -- Calculate New Position
    
    local newX = frame.dfBaseX
    local newY = frame.dfBaseY
    
    if isHorizontal then
        newX = frame.dfBaseX + offX -- Shift Right to center content (was -)
    else
        newY = frame.dfBaseY - offY -- Shift Down to center content (was +)
    end
    
    -- Apply
    if math.abs(xOfs - newX) > 0.5 or math.abs(yOfs - newY) > 0.5 then
        frame:ClearAllPoints()
        frame:SetPoint(point, relTo, relPoint, newX, newY)
        frame.dfLastSetX = newX
        frame.dfLastSetY = newY
        
        if not frame:IsMovable() then frame:SetMovable(true) end
        if frame.SetUserPlaced then frame:SetUserPlaced(true) end
        
        if DF.debugEnabled then
            print(string.format("DF DEBUG: Party Center Adjusted | Orient: %s | Max: %.0fx%.0f | Cur: %.0fx%.0f | Off: %.0f,%.0f | New: %.0f,%.0f", 
                isHorizontal and "HOR" or "VER", maxW, maxH, currentW, currentH, offX, offY, newX, newY))
        end
    end
end

-- ============================================================
-- RAID CENTER LOGIC (FIXED & PERSISTENT)
-- ============================================================

-- Detects the Raid Size specifically while Edit Mode is OPEN
-- and SAVES it to the Database so it persists across reloads.
function DF:DetectAndCacheRaidSize()
    if not EditModeManagerFrame or not EditModeManagerFrame:IsShown() then return end
    
    -- Safety check for DB
    if not DF.db or not DF.db.profile or not DF.db.profile.raid then return end

    -- 1. DETECT RAID SIZE
    -- Helper to check if a specific Raid Group is shown
    local function IsGShown(id)
        local g = _G["CompactRaidGroup"..id]
        if g and g:IsShown() then return true end
        return false
    end

    local detected = nil
    
    -- Add Debug Logging for Detection
    if DF.debugEnabled then
         local g8 = _G["CompactRaidGroup8"]
         local g5 = _G["CompactRaidGroup5"]
         local g2 = _G["CompactRaidGroup2"]
         print(string.format("DF DEBUG: Detection Check - G8: %s (%s), G5: %s (%s), G2: %s (%s)",
             g8 and "Exists" or "Nil", g8 and tostring(g8:IsShown()) or "N/A",
             g5 and "Exists" or "Nil", g5 and tostring(g5:IsShown()) or "N/A",
             g2 and "Exists" or "Nil", g2 and tostring(g2:IsShown()) or "N/A"
         ))
    end

    if IsGShown(8) then
        detected = 8 -- 40 Man
    elseif IsGShown(5) then
        detected = 5 -- 25 Man
    elseif IsGShown(2) then
        detected = 2 -- 10 Man
    end
    
    if detected then
        local current = DF.db.profile.raid.layoutRaidSize
        if detected ~= current then
            DF.db.profile.raid.layoutRaidSize = detected
            if DF.debugEnabled then 
                print("DF DEBUG: EditMode Raid Size Saved to Profile! New Size: " .. detected .. " groups.") 
            end
        end
    elseif DF.debugEnabled then
        print("DF DEBUG: No standard raid group size detected (2, 5, or 8 not strictly visible).")
    end
    
    -- 2. DETECT HORIZONTAL GROUPS (NEW)
    -- We can detect this by checking the dimensions of Group 1.
    -- Standard (Vertical Players): Tall & Narrow (e.g. 50w x 200h)
    -- Horizontal (Horizontal Players): Wide & Short (e.g. 250w x 40h)
    local g1 = _G["CompactRaidGroup1"]
    if g1 then
        local w, h = g1:GetWidth(), g1:GetHeight()
        local isHorizontal = (w > h) -- Heuristic: If width > height, likely horizontal groups
        
        -- Save if changed
        if DF.db.profile.raid.layoutHorizontal ~= isHorizontal then
            DF.db.profile.raid.layoutHorizontal = isHorizontal
            if DF.debugEnabled then 
                print("DF DEBUG: EditMode Orientation Saved! Horizontal Groups: " .. tostring(isHorizontal)) 
            end
        end
    end
end

function DF:EnforceRaidCenter()
    local container = CompactRaidFrameContainer
    if not container or not DF.db or InCombatLockdown() then return end
    
    local config = DF.db.profile.raid
    
    -- HANDLE DISABLE - Restore default positions when growCenter is disabled
    if not config or not config.growCenter then 
        -- Restore container position
        DF:RestoreDefaultAnchor(container)
        
        -- Restore individual group positions
        for i = 1, 8 do
            local groupFrame = _G["CompactRaidGroup" .. i]
            if groupFrame then
                DF:RestoreDefaultAnchor(groupFrame)
            end
        end
        return 
    end

    -- 2. Persistence Check: If no size is saved, we default to 8 but warn user
    local maxGroups = config.layoutRaidSize or 8
    local isHorizontalLayout = config.layoutHorizontal or false
    
    -- Debug Log for Saved Value
    if DF.debugEnabled then
        print("DF DEBUG: EnforceRaidCenter - DB Value: " .. tostring(config.layoutRaidSize) .. 
              " | Horizontal: " .. tostring(isHorizontalLayout))
    end
    
    -- Only print this warning once per session to avoid spam
    if not config.layoutRaidSize and not DF.warnedRaidSizeMissing then
        print("|cffeda55fDandersFrames:|r Raid Size not detected! Please open Edit Mode once to calibrate positioning.")
        DF.warnedRaidSizeMissing = true
    end

    -- 3. Identify Visible Groups
    local visibleGroups = {}
    local singleGroupWidth, singleGroupHeight = 0, 0
    local groupSpacingX, groupSpacingY = 0, 0
    
    -- Collect visible groups
    for i = 1, 8 do
        local groupFrame = _G["CompactRaidGroup" .. i]
        if groupFrame and groupFrame:IsShown() then
            table.insert(visibleGroups, groupFrame)
            if singleGroupWidth == 0 then 
                singleGroupWidth = groupFrame:GetWidth() 
                singleGroupHeight = groupFrame:GetHeight()
            end
        end
    end
    
    local numGroups = #visibleGroups
    if numGroups == 0 or singleGroupWidth == 0 then return end
    
    -- 4. Calculate Spacing (between Group 1 and 2 if available)
    if numGroups >= 2 then
        local g1 = visibleGroups[1]
        local g2 = visibleGroups[2]
        
        if isHorizontalLayout then
            -- HORIZONTAL MODE: Groups usually stack VERTICALLY (G1 Top, G2 Bottom)
            -- Spacing is Top of G2 - Bottom of G1
            local bot1 = g1:GetBottom()
            local top2 = g2:GetTop()
            if bot1 and top2 then
                groupSpacingY = math.abs(top2 - bot1)
            end
        else
            -- STANDARD MODE: Groups stack HORIZONTALLY (G1 Left, G2 Right)
            local right1 = g1:GetRight()
            local left2 = g2:GetLeft()
            if right1 and left2 then
                groupSpacingX = math.abs(left2 - right1)
            end
        end
    end
    
    -- 5. Calculate Geometry & Offset
    local requiredOffsetX, requiredOffsetY = 0, 0
    
    if isHorizontalLayout then
        -- VERTICAL GROWTH (Downwards) - We calculate HEIGHT
        local maxH = (singleGroupHeight * maxGroups) + (groupSpacingY * (maxGroups - 1))
        local currentH = (singleGroupHeight * numGroups) + (groupSpacingY * math.max(0, numGroups - 1))
        
        -- Center Logic: Shift UP (+Y) or DOWN (-Y)?
        -- If anchored TOP (standard), growing down moves center down. 
        -- To keep center fixed, we must shift the starting point UP (+Y)?
        -- Actually, visual testing showed -offset worked for horizontal growth.
        -- Let's stick to the previous verified logic: -(Max - Cur)/2
        requiredOffsetY = -(maxH - currentH) / 2
        
        if DF.debugEnabled then
            print(string.format("DF DEBUG: Raid Horizontal Mode | MaxH: %.1f | CurrH: %.1f | OffY: %.1f", 
                maxH, currentH, requiredOffsetY))
        end
        
    else
        -- HORIZONTAL GROWTH (Rightwards) - We calculate WIDTH
        local maxW = (singleGroupWidth * maxGroups) + (groupSpacingX * (maxGroups - 1))
        local currentW = (singleGroupWidth * numGroups) + (groupSpacingX * math.max(0, numGroups - 1))
        
        requiredOffsetX = (maxW - currentW) / 2
        
        if DF.debugEnabled then
            print(string.format("DF DEBUG: Raid Standard Mode | MaxW: %.1f | CurrW: %.1f | OffX: %.1f", 
                maxW, currentW, requiredOffsetX))
        end
    end

    -- 6. Apply Offset to HEAD GROUPS Only
    -- We now manage BOTH X and Y for every frame to ensure resets happen correctly.
    
    for i, group in ipairs(visibleGroups) do
        local point, relTo, relPoint, xOfs, yOfs = group:GetPoint(1)
        
        -- Check if this group is the start of a chain (anchored to container)
        local isChained = false
        if relTo and relTo:GetName() and string.find(relTo:GetName(), "CompactRaidGroup") then
            isChained = true
        end
        
        if not isChained and point then
            -- This is a Head Node
            
            -- CAPTURE BASE POSITIONS (Detect Resets)
            -- X Axis
            if not group.dfBaseX then
                group.dfBaseX = xOfs
            else
                local lastX = group.dfLastSetX or 99999
                if math.abs(xOfs - lastX) > 1 then group.dfBaseX = xOfs end
            end
            
            -- Y Axis
            if not group.dfBaseY then
                group.dfBaseY = yOfs
            else
                local lastY = group.dfLastSetY or 99999
                if math.abs(yOfs - lastY) > 1 then group.dfBaseY = yOfs end
            end
            
            -- CALCULATE TARGETS
            local targetX, targetY
            
            if isHorizontalLayout then
                -- Active Axis: Y (Apply Offset)
                -- Passive Axis: X (Reset to Base)
                targetX = group.dfBaseX
                targetY = group.dfBaseY + requiredOffsetY
            else
                -- Active Axis: X (Apply Offset)
                -- Passive Axis: Y (Reset to Base)
                targetX = group.dfBaseX + requiredOffsetX
                targetY = group.dfBaseY
            end
            
            -- APPLY IF CHANGED
            -- We check both axes. This ensures that if we switch modes, the old axis snaps back to Base.
            if math.abs(xOfs - targetX) > 0.5 or math.abs(yOfs - targetY) > 0.5 then
                group:ClearAllPoints()
                group:SetPoint(point, relTo, relPoint, targetX, targetY)
                
                group.dfLastSetX = targetX
                group.dfLastSetY = targetY
                
                if DF.debugEnabled then 
                    print(string.format("DF DEBUG: Group %d Moved -> X: %.1f Y: %.1f", i, targetX, targetY)) 
                end
            end
        end
    end
end

-- ITERATE FRAMES HELPER
function DF:IterateCompactFrames(callback)
    local processed = {} 
    local function tryProcess(frame)
        if type(frame) ~= "table" or not frame.IsVisible or not frame:IsVisible() then return end
        if frame.IsForbidden and frame:IsForbidden() then return end
        if not DF:IsValidFrame(frame) then return end
        if not frame.healthBar or not frame.optionTable then return end 
        if processed[frame] then return end

        if (frame.unit) or (EditModeManagerFrame and EditModeManagerFrame:IsShown()) or DF.demoMode then
            callback(frame)
            processed[frame] = true
        end
    end

    if DF.demoMode and CompactPartyFrame then
        for i = 1, 5 do 
            local f = _G["CompactPartyFrameMember"..i]
            if f then tryProcess(f) end
        end
    end

    if CompactRaidFrameContainer and CompactRaidFrameContainer.flowFrames then
        for _, frame in pairs(CompactRaidFrameContainer.flowFrames) do tryProcess(frame) end
    end
    if CompactRaidFrameContainer then
        local children = {CompactRaidFrameContainer:GetChildren()}
        for _, child in ipairs(children) do
            tryProcess(child)
            if child.GetChildren then
                 local members = {child:GetChildren()}
                 for _, member in ipairs(members) do tryProcess(member) end
            end
        end
    end
    
    for i = 1, 5 do tryProcess(_G["CompactPartyFrameMember" .. i]) end
    
    if CompactRaidFrame1 and CompactRaidFrame1:IsVisible() then
         local i = 1
         while _G["CompactRaidFrame"..i] do
            tryProcess(_G["CompactRaidFrame"..i])
            i = i + 1
         end
    end
end

-- ============================================================
-- FRAME VALIDATION (FIXED)
-- ============================================================
function DF:IsValidFrame(frame)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return false end
    local name = frame:GetName()
    local unit = frame.unit or frame.displayedUnit

    -- Demo Mode: Accept demo frames
    if DF.demoMode then
        if name and (string.find(name, "CompactRaidFrame") or string.find(name, "CompactPartyFrame") or string.find(name, "CompactRaidGroup")) then 
            return true 
        end
    end
    
    -- Test Frame for GUI Preview
    if name == "DandersFramesTestUnit" then return true end

    -- REJECT: Nameplates (these are NOT raid/party frames)
    if name and (string.find(name, "NamePlate") or string.find(name, "ClassNameplate")) then return false end
    
    local parent = frame:GetParent()
    if parent then
        local pName = parent:GetName()
        if pName and (string.find(pName, "NamePlate") or string.find(pName, "ClassNameplate")) then return false end
    end

    if unit and string.find(string.lower(unit), "nameplate") then return false end

    -- ACCEPT: Standard CompactRaidFrame and CompactPartyFrame
    if name and string.find(name, "CompactRaidFrame") then return true end
    if name and string.find(name, "CompactPartyFrame") then return true end
    
    -- ACCEPT: Raid Group Member Frames
    if name and string.find(name, "CompactRaidGroup") and string.find(name, "Member") then 
        return true 
    end
    
    -- ACCEPT: Frames that are children of CompactRaidGroup containers
    if parent then
        local pName = parent:GetName()
        if pName and string.find(pName, "CompactRaidGroup") then
            if frame.healthBar then
                return true
            end
        end
    end
    
    return false
end