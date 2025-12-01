local addonName, DF = ...

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

-- ============================================================
-- NOTE: GetDB() function has been REMOVED from this file.
-- It is now defined ONLY in DandersFrames.lua to prevent
-- duplicate function definitions and ensure consistent behavior.
-- ============================================================

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

-- ============================================================
-- IMPORT / EXPORT LOGIC
-- ============================================================

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