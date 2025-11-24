local addonName, DF = ...

-- Event Frame
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("RAID_TARGET_UPDATE")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

-- Debug Flag
DF.debugEnabled = false
DF.demoMode = false
DF.demoPercent = 1

-- Standard WoW Fonts
DF.SharedFonts = {
    ["Fonts\\FRIZQT__.TTF"] = "Friz Quadrata TT",
    ["Fonts\\ARIALN.TTF"] = "Arial Narrow",
    ["Fonts\\skurri.ttf"] = "Skurri",
    ["Fonts\\MORPHEUS.TTF"] = "Morpheus",
    ["Fonts\\2002.TTF"] = "2002",
}

-- ============================================================
-- DUMMY OBJECTS (Prevent Crashes)
-- ============================================================
-- This object absorbs Show/Hide calls so Blizzard code doesn't crash
-- when running on our fake "dandersdemo" unit.
local DummyHighlight = {}
local function DummyFunc() end
setmetatable(DummyHighlight, {
    __index = function(t, k)
        -- Return an empty function for any method call (Show, Hide, SetTexture, etc.)
        return DummyFunc 
    end
})

-- ============================================================
-- DEFAULT SETTINGS (Party vs Raid)
-- ============================================================

DF.PartyDefaults = {
    -- General
    soloMode = false, -- NEW: Show frames while solo
    framePadding = 3,
    useSpecificPadding = false,
    paddingTop = 3,
    paddingBottom = 3,
    paddingLeft = 3,
    paddingRight = 3,
    
    enableTextureColor = true,
    backgroundClassColor = false,
    textureColor = {r = 0.10196079313755, g = 0.10196079313755, b = 0.10196079313755, a = 0.30729147791862},
    
    -- Health Colors
    healthColorMode = "CLASS",
    healthColorLow = {r = 1, g = 0, b = 0, a = 1},
    healthColorLowUseClass = false, 
    healthColorLowWeight = 1, 
    healthColorMedium = {r = 1, g = 1, b = 0, a = 1},
    healthColorMediumUseClass = false, 
    healthColorMediumWeight = 1, 
    healthColorHigh = {r = 0, g = 1, b = 0, a = 1},
    healthColorHighUseClass = false, 
    healthColorHighWeight = 1, 
    classColorAlpha = 1.0,
    healthColor = {r = 0, g = 1, b = 0, a = 1}, 

    -- Buffs
    raidBuffScale = 1,
    raidBuffAlpha = 1,
    raidBuffAnchor = "BOTTOMRIGHT",
    raidBuffGrowth = "LEFT_UP",
    raidBuffWrap = 3,
    raidBuffMax = 6,
    raidBuffOffsetX = -4,
    raidBuffOffsetY = 8,
    raidBuffClickThrough = false,

    -- Debuffs
    raidDebuffScale = 1,
    raidDebuffAlpha = 1,
    raidDebuffAnchor = "BOTTOMLEFT",
    raidDebuffGrowth = "RIGHT_UP",
    raidDebuffWrap = 2,
    raidDebuffMax = 6,
    raidDebuffOffsetX = 4,
    raidDebuffOffsetY = 8,
    raidDebuffClickThrough = false,

    -- Health Text
    healthTextHide = false,
    healthTextEnabled = true,
    healthTextFormat = "Percent",
    healthTextScale = 1.4,
    healthTextFont = "Fonts\\FRIZQT__.TTF",
    healthTextOutline = "OUTLINE",
    healthTextAnchor = "CENTER",
    healthTextX = 0,
    healthTextY = 0,
    healthTextColor = {r = 1, g = 1, b = 1, a = 1},
    healthTextUseClassColor = false,

    -- Name Text
    nameTextHide = false,
    nameTextEnabled = true,
    nameTextShowRealm = false,
    nameTextLength = 0,
    nameTextTruncateMode = "ELLIPSIS", 
    nameTextWrapAlign = "CENTER",
    nameTextWrapDirection = "DOWN",
    nameTextFormat = "Current",
    nameTextScale = 1.1,
    nameTextFont = "Fonts\\FRIZQT__.TTF",
    nameTextOutline = "OUTLINE",
    nameTextAnchor = "TOP",
    nameTextX = 0,
    nameTextY = -13,
    nameTextColor = {r = 1, g = 1, b = 1, a = 1},
    nameTextUseClassColor = false,

    -- Icons
    leaderIconHide = false,
    leaderIconEnabled = true,
    leaderIconScale = 1.2,
    leaderIconAnchor = "TOPLEFT",
    leaderIconX = 0,
    leaderIconY = 4,

    roleIconHide = false,
    roleIconEnabled = true,
    roleIconScale = 1,
    roleIconAnchor = "TOPLEFT",
    roleIconX = 5,
    roleIconY = -5,

    raidIconHide = false,
    raidIconEnabled = true,
    raidIconScale = 1.8,
    raidIconAnchor = "TOP",
    raidIconX = -1,
    raidIconY = 2,

    readyCheckIconEnabled = false,
    readyCheckIconScale = 1,
    readyCheckIconAnchor = "CENTER",
    readyCheckIconX = 0,
    readyCheckIconY = 0,

    centerStatusIconEnabled = false,
    centerStatusIconScale = 1,
    centerStatusIconAnchor = "CENTER",
    centerStatusIconX = 0,
    centerStatusIconY = 0,

    -- Resource Bar
    resourceBarEnabled = true,
    resourceBarHealerOnly = true,
    resourceBarMatchWidth = true,
    resourceBarAnchor = "BOTTOM",
    resourceBarWidth = 50,
    resourceBarHeight = 4,
    resourceBarX = 0,
    resourceBarY = 4,
}

DF.RaidDefaults = {
    -- General
    framePadding = 3,
    useSpecificPadding = false,
    paddingTop = 3,
    paddingBottom = 3,
    paddingLeft = 3,
    paddingRight = 3,

    enableTextureColor = true,
    backgroundClassColor = false,
    textureColor = {r = 0.10196079313755, g = 0.10196079313755, b = 0.10196079313755, a = 0.30729147791862},

    -- Health Colors
    healthColorMode = "CLASS",
    healthColorLow = {r = 1, g = 0, b = 0, a = 1},
    healthColorLowUseClass = false, 
    healthColorLowWeight = 1, 
    healthColorMedium = {r = 1, g = 1, b = 0, a = 1},
    healthColorMediumUseClass = false, 
    healthColorMediumWeight = 1, 
    healthColorHigh = {r = 0, g = 1, b = 0, a = 1},
    healthColorHighUseClass = false, 
    healthColorHighWeight = 1, 
    classColorAlpha = 1.0,
    healthColor = {r = 0, g = 1, b = 0, a = 1},

    -- Buffs
    raidBuffScale = 1,
    raidBuffAlpha = 1,
    raidBuffAnchor = "BOTTOMRIGHT",
    raidBuffGrowth = "LEFT_UP",
    raidBuffWrap = 3,
    raidBuffMax = 3,
    raidBuffOffsetX = -4,
    raidBuffOffsetY = 8,
    raidBuffClickThrough = false,

    -- Debuffs
    raidDebuffScale = 1,
    raidDebuffAlpha = 1,
    raidDebuffAnchor = "BOTTOMLEFT",
    raidDebuffGrowth = "RIGHT_UP",
    raidDebuffWrap = 2,
    raidDebuffMax = 3,
    raidDebuffOffsetX = 4,
    raidDebuffOffsetY = 8,
    raidDebuffClickThrough = false,

    -- Health Text
    healthTextHide = true, 
    healthTextEnabled = true,
    healthTextFormat = "Percent",
    healthTextScale = 1.4,
    healthTextFont = "Fonts\\FRIZQT__.TTF",
    healthTextOutline = "OUTLINE",
    healthTextAnchor = "CENTER",
    healthTextX = 0,
    healthTextY = 0,
    healthTextColor = {r = 1, g = 1, b = 1, a = 1},
    healthTextUseClassColor = false,

    -- Name Text
    nameTextHide = false,
    nameTextEnabled = true,
    nameTextShowRealm = false,
    nameTextLength = 5, 
    nameTextTruncateMode = "ELLIPSIS", 
    nameTextWrapAlign = "CENTER",
    nameTextWrapDirection = "DOWN",
    nameTextFormat = "Current",
    nameTextScale = 1.1,
    nameTextFont = "Fonts\\FRIZQT__.TTF",
    nameTextOutline = "OUTLINE",
    nameTextAnchor = "CENTER", 
    nameTextX = 0,
    nameTextY = 0,
    nameTextColor = {r = 1, g = 1, b = 1, a = 1},
    nameTextUseClassColor = false,

    -- Icons
    leaderIconHide = false,
    leaderIconEnabled = true,
    leaderIconScale = 1.2,
    leaderIconAnchor = "TOPLEFT",
    leaderIconX = 0,
    leaderIconY = 4,

    roleIconHide = false,
    roleIconEnabled = true,
    roleIconScale = 1,
    roleIconAnchor = "TOPLEFT",
    roleIconX = 5,
    roleIconY = -5,

    raidIconHide = false,
    raidIconEnabled = true,
    raidIconScale = 1.8,
    raidIconAnchor = "TOP",
    raidIconX = -1,
    raidIconY = 2,

    readyCheckIconEnabled = false,
    readyCheckIconScale = 1,
    readyCheckIconAnchor = "CENTER",
    readyCheckIconX = 0,
    readyCheckIconY = 0,

    centerStatusIconEnabled = false,
    centerStatusIconScale = 1,
    centerStatusIconAnchor = "CENTER",
    centerStatusIconX = 0,
    centerStatusIconY = 0,

    -- Resource Bar
    resourceBarEnabled = true,
    resourceBarHealerOnly = true,
    resourceBarMatchWidth = true,
    resourceBarAnchor = "BOTTOM",
    resourceBarWidth = 50,
    resourceBarHeight = 4,
    resourceBarX = 0,
    resourceBarY = 4,
}

-- Helper: Deep Copy Table
function DF:DeepCopy(src)
    if type(src) ~= "table" then return src end
    local dest = {}
    for k, v in pairs(src) do
        dest[k] = DF:DeepCopy(v)
    end
    return dest
end

-- Resets Party or Raid settings within the CURRENT profile
function DF:ResetProfile(mode)
    if not DF.db.profile[mode] then return end
    local defaults = (mode == "party" and DF.PartyDefaults or DF.RaidDefaults)
    DF.db.profile[mode] = DF:DeepCopy(defaults)
    DF:UpdateAll()
    print("|cff00ff00DandersFrames:|r " .. (mode == "party" and "Party" or "Raid") .. " settings reset to defaults.")
end

-- Copies Party->Raid or Raid->Party within CURRENT profile
function DF:CopyProfile(srcMode, destMode)
    if not DF.db.profile[srcMode] or not DF.db.profile[destMode] then return end
    DF.db.profile[destMode] = DF:DeepCopy(DF.db.profile[srcMode])
    DF:UpdateAll()
    local s = srcMode == "party" and "Party" or "Raid"
    local d = destMode == "party" and "Party" or "Raid"
    print("|cff00ff00DandersFrames:|r Copied settings from " .. s .. " to " .. d .. ".")
end

-- Determine which DB to use based on the frame
function DF:GetDB(frame)
    if not frame then return DF.db.profile.party end 
    
    local name
    if type(frame) == "table" and type(frame.GetName) == "function" then
         local ok, res = pcall(frame.GetName, frame)
         if ok then name = res end
    end
    
    if name and string.find(name, "CompactPartyFrame") then
        return DF.db.profile.party
    end
    return DF.db.profile.raid
end

function DF:ApplyFrameInset(frame)
    if not DF:IsValidFrame(frame) then return end
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

function DF:RefreshConfig()
    DF:UpdateAll()
end

-- CHECK FOR PROFILE SWITCH (SPEC BASED)
function DF:CheckProfileAutoSwitch()
    if not DF.db or not DF.db.char or not DF.db.char.enableSpecSwitch then return end
    
    local specIndex = GetSpecialization()
    if not specIndex then return end
    
    local profileName = DF.db.char.specProfiles and DF.db.char.specProfiles[specIndex]
    
    -- If a profile is assigned and it is NOT the current profile
    if profileName and profileName ~= "" and profileName ~= DF.db:GetCurrentProfile() then
        -- Verify profile exists in DB
        local profiles = DF.db:GetProfiles()
        local exists = false
        for _, p in ipairs(profiles) do 
            if p == profileName then exists = true break end 
        end
        
        if exists then
            DF.db:SetProfile(profileName)
            print("|cff00ff00DandersFrames:|r Auto-switched to profile: " .. profileName)
            
            -- Refresh GUI if open
            if DF.GUIFrame and DF.GUIFrame:IsShown() and DF.GUI.RefreshCurrentPage then 
                DF.GUI:RefreshCurrentPage() 
            end
        end
    end
end

-- SOLO MODE HOOK
local Hook_CompactPartyFrame_UpdateVisibility = function() end

function DF:SetupSoloMode()
    Hook_CompactPartyFrame_UpdateVisibility = function()
        if not DF.db or not DF.db.profile then return end
        
        local shouldShow = (DF.db.profile.party.soloMode or DF.demoMode)
        
        if shouldShow and (not IsInGroup() and not IsInRaid()) then
            if InCombatLockdown() then
                C_Timer.After(1, Hook_CompactPartyFrame_UpdateVisibility)
                return
            end
            if CompactPartyFrame then
                CompactPartyFrame:SetShown(true)
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
end

-- CUSTOM DEMO TOOLTIP (Prevents C_TooltipInfo.GetUnit Crash)
local function DemoOnEnter(self)
    -- Do nothing. Tooltips are annoying in demo mode and can cause crashes.
end

-- DEMO MODE LOOP
function DF:ToggleDemoMode(enable)
    DF.demoMode = enable
    
    if InCombatLockdown() then 
        print("|cffff0000DandersFrames:|r Cannot toggle Demo Mode in combat.")
        return 
    end

    if enable then
        -- 1. Force Show Party Frames (Fill with duplicates)
        if CompactPartyFrame then
            CompactPartyFrame:SetShown(true)
            -- Iterate member frames 1-5
            for i = 1, 5 do
                local member = _G["CompactPartyFrameMember"..i]
                if member then
                    -- Unregister UnitWatch to stop Blizzard from auto-hiding the frame because "dandersdemo" doesn't exist
                    UnregisterUnitWatch(member)
                    
                    -- 1. DISABLE RANGE CHECK (Prevents Secret Value crash)
                    if member.optionTable then
                        member._originalDisplayInRange = member.optionTable.displayInRange
                        member.optionTable.displayInRange = false
                    end
                    
                    -- 2. DISABLE HIGHLIGHTS (Prevents UnitIsUnit crash)
                    -- FIX: Handle nil selectionHighlight safely
                    if member.selectionHighlight ~= DummyHighlight then
                        if member.selectionHighlight then member.selectionHighlight:Hide() end -- Hide old one
                        member._originalSelectionHighlight = member.selectionHighlight
                        member.selectionHighlight = DummyHighlight
                    end
                    
                    if member.aggroHighlight ~= DummyHighlight then
                        if member.aggroHighlight then member.aggroHighlight:Hide() end -- Hide old one
                        member._originalAggroHighlight = member.aggroHighlight
                        member.aggroHighlight = DummyHighlight
                    end

                    -- 3. OVERRIDE TOOLTIP (Prevents C_TooltipInfo.GetUnit crash)
                    -- Also explicitly DISABLE MOUSE to prevent any hover/click interaction
                    member:EnableMouse(false)
                    member:SetScript("OnEnter", nil) -- Ensure no script runs
                    member:SetScript("OnLeave", nil)
                    
                    member:SetShown(true)
                    member.unit = "dandersdemo"
                    member.displayedUnit = "dandersdemo"
                end
            end
        end
        
        -- 2. Start Animation Loop
        if not DF.DemoFrame then
            DF.DemoFrame = CreateFrame("Frame")
            DF.DemoFrame.elapsed = 0
            DF.DemoFrame.direction = -1
            DF.DemoFrame:SetScript("OnUpdate", function(self, elapsed)
                self.elapsed = self.elapsed + elapsed
                if self.elapsed > 0.05 then -- 20fps update
                    self.elapsed = 0
                    
                    local speed = 0.02
                    DF.demoPercent = DF.demoPercent + (speed * self.direction)
                    
                    if DF.demoPercent <= 0 then 
                        DF.demoPercent = 0
                        self.direction = 1 
                    elseif DF.demoPercent >= 1 then 
                        DF.demoPercent = 1
                        self.direction = -1 
                    end
                    
                    -- Update Everything
                    DF:UpdateAll()
                end
            end)
        end
        DF.DemoFrame:Show()
    else
        if DF.DemoFrame then DF.DemoFrame:Hide() end
        DF.demoPercent = 1
        
        -- Stop iteration logic
        -- We DO NOT try to restore the frames here because they are tainted.
        -- Any attempt to set .unit = "player" or enable range checks will crash the game.
        -- Instead, we prompt the user to Reload UI.
        
        StaticPopupDialogs["DANDERSFRAMES_RELOAD"] = {
            text = "DandersFrames: Demo Mode ended.\nA UI Reload is required to restore secure frame functionality (Range Checking).",
            button1 = "Reload UI",
            button2 = "Later",
            OnAccept = function()
                ReloadUI()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("DANDERSFRAMES_RELOAD")
    end
end

-- Initialize Variables and Events
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
                specProfiles = {}, -- Table to hold [SpecIndex] = "ProfileName"
            }
        }
        
        DF.db = LibStub("AceDB-3.0"):New("DandersFramesDB", dbDefaults, true)
        
        DF.db.RegisterCallback(DF, "OnProfileChanged", "RefreshConfig")
        DF.db.RegisterCallback(DF, "OnProfileCopied", "RefreshConfig")
        DF.db.RegisterCallback(DF, "OnProfileReset", "RefreshConfig")

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
            else
                if DF.ToggleGUI then 
                    DF:ToggleGUI() 
                else
                    print("|cffff0000DandersFrames:|r GUI loaded.")
                end
            end
        end
        
        -- Run initial check on login (delayed slightly to ensure specs loaded)
        C_Timer.After(2, function() DF:CheckProfileAutoSwitch() end)
        DF:UpdateAll()
        
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        DF:CheckProfileAutoSwitch()
        
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "RAID_TARGET_UPDATE" then
        -- Force update visibility logic (triggers our hook)
        if CompactPartyFrame and CompactPartyFrame.UpdateVisibility then
             CompactPartyFrame:UpdateVisibility()
        end
        DF:UpdateAll()
    
    elseif event == "PLAYER_REGEN_ENABLED" then
        if DF.needsUpdate then
            DF.needsUpdate = false
            DF:UpdateAll()
            print("|cff00ff00DandersFrames:|r Settings applied.")
        end
    end
end)

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

    -- Support Demo Mode Iteration on Forced Frames
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

function DF:IsValidFrame(frame)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return false end
    local name = frame:GetName()
    local unit = frame.unit or frame.displayedUnit

    -- Allow demo mode frames even if unit is weird
    if DF.demoMode then
        if name and (string.find(name, "CompactRaidFrame") or string.find(name, "CompactPartyFrame")) then return true end
    end

    if name and (string.find(name, "NamePlate") or string.find(name, "ClassNameplate")) then return false end
    
    local parent = frame:GetParent()
    if parent then
        local pName = parent:GetName()
        if pName and (string.find(pName, "NamePlate") or string.find(pName, "ClassNameplate")) then return false end
    end

    if unit and string.find(string.lower(unit), "nameplate") then return false end

    if name and (string.find(name, "CompactRaidFrame") or string.find(name, "CompactPartyFrame")) then return true end
    
    return false
end

local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
function DF:Base64Encode(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b64chars:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

function DF:Base64Decode(data)
    data = string.gsub(data, '[^'..b64chars..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='', (b64chars:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

function DF:Serialize(val)
    local t = type(val)
    if t == "number" or t == "boolean" then
        return tostring(val)
    elseif t == "string" then
        return string.format("%q", val)
    elseif t == "table" then
        local str = "{"
        for k, v in pairs(val) do
            str = str .. "[" .. DF:Serialize(k) .. "]=" .. DF:Serialize(v) .. ","
        end
        return str .. "}"
    else
        return "nil"
    end
end

function DF:ExportProfile()
    local data = DF:Serialize(DF.db.profile)
    return DF:Base64Encode(data)
end

function DF:ImportProfile(str)
    if not str or str == "" then return end
    local decoded = DF:Base64Decode(str)
    local func, err = loadstring("return " .. decoded)
    if not func then print("|cffff0000DandersFrames:|r Import failed (Invalid format).") return end
    local success, newProfile = pcall(func)
    if not success or type(newProfile) ~= "table" then print("|cffff0000DandersFrames:|r Import failed (Corrupt data).") return end
    if newProfile.party then DF.db.profile.party = newProfile.party end
    if newProfile.raid then DF.db.profile.raid = newProfile.raid end
    DF:UpdateAll()
    print("|cff00ff00DandersFrames:|r Profile imported successfully!")
end

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

    DF:IterateCompactFrames(function(frame)
        -- REMOVED: "frame:Show()" inside loop (Fixes "Action Blocked")
        
        -- Safe Protected Calls to Blizzard functions to avoid "Secret" value crashes
        if CompactUnitFrame_UpdateHealthColor then pcall(CompactUnitFrame_UpdateHealthColor, frame) end
        if CompactUnitFrame_UpdateStatusIcons then pcall(CompactUnitFrame_UpdateStatusIcons, frame) end
        if CompactUnitFrame_UpdateName then pcall(CompactUnitFrame_UpdateName, frame) end
        
        -- Demo Mode Logic: Animate Bars manually
        if DF.demoMode and frame.healthBar and DF.demoPercent then
            -- FIX: We force values here instead of reading GetMinMaxValues()
            -- Reading MinMax from a tainted frame returns Secret Values which crashes math comparisons.
            frame.healthBar:SetMinMaxValues(0, 100)
            frame.healthBar:SetValue(DF.demoPercent * 100)
        end

        -- Apply custom updates
        if DF.ApplyHealthColors then DF:ApplyHealthColors(frame) end
        if DF.ApplyAuraLayout then DF:ApplyAuraLayout(frame) end
        if DF.UpdateDemoAuras and DF.demoMode then DF:UpdateDemoAuras(frame) end -- NEW AURA DEMO
        if DF.UpdateIcons then DF:UpdateIcons(frame) end
        if DF.UpdateNameText then DF:UpdateNameText(frame) end
        if DF.UpdateHealthText then DF:UpdateHealthText(frame) end
        if DF.ApplyFrameInset then DF:ApplyFrameInset(frame) end
        if DF.ApplyResourceBarLayout then DF:ApplyResourceBarLayout(frame) end
        if DF.UpdateResourceBar then DF:UpdateResourceBar(frame) end
    end)
end