local addonName, DF = ...

-- Get required libraries
local LDB = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub("LibDBIcon-1.0", true)

-- ============================================================
-- Global Function for Blizzard Addon Compartment
-- This is called when you click DandersFrames in the WoW Game Menu
-- ============================================================
function DandersFrames_OnAddonCompartmentClick(addonName, buttonName)
    -- Use new GUI Toggle
    if DF.ToggleGUI then 
        DF:ToggleGUI()
    end
end

if not LDB or not LDBIcon then
    print("|cffff0000DandersFrames:|r Missing libraries (LibDataBroker or LibDBIcon). Minimap icon will not be loaded.")
    return
end

-- Create a separate frame for handling the login event to initialize the icon
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        
        -- 1. Ensure Database Defaults for the icon exist
        if DF.db and DF.db.profile then
            if not DF.db.profile.minimap then
                DF.db.profile.minimap = { hide = false }
            end
        end

        -- 2. Create the DataBroker Object
        local dandersLDB = LDB:NewDataObject("DandersFrames", {
            type = "data source",
            text = "DandersFrames",
            icon = "Interface\\AddOns\\DandersFrames\\DF_Icon", 
            
            -- Handle Clicks
            OnClick = function(clickedframe, button)
                -- Always toggle new GUI on any click
                if DF.ToggleGUI then 
                    DF:ToggleGUI()
                end
            end,
            
            -- Tooltip
            OnTooltipShow = function(tooltip)
                tooltip:AddLine("DandersFrames")
                tooltip:AddLine("|cffeda55fClick|r to open settings.", 1, 1, 1)
            end,
        })

        -- 3. Register the Icon with LibDBIcon
        if DF.db and DF.db.profile and DF.db.profile.minimap then
            LDBIcon:Register("DandersFrames", dandersLDB, DF.db.profile.minimap)
        end
        
        -- Note: Options toggle for the minimap is now handled directly in DandersFrames_GUI.lua
    end
end)