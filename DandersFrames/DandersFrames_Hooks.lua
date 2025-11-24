local addonName, DF = ...

function DF:HookRaidFrames()
    -- Health/Color Hooks
    -- FIX: Combined hooks to ensure Text updates whenever Health updates
    if CompactUnitFrame_UpdateHealth then
        hooksecurefunc("CompactUnitFrame_UpdateHealth", function(frame) 
            if DF.ApplyHealthColors then DF:ApplyHealthColors(frame) end
            if DF.UpdateHealthText then DF:UpdateHealthText(frame) end
        end)
    end

    -- FIX: Ensure text updates if Max Health changes (which changes the percentage)
    if CompactUnitFrame_UpdateMaxHealth then
        hooksecurefunc("CompactUnitFrame_UpdateMaxHealth", function(frame)
            if DF.UpdateHealthText then DF:UpdateHealthText(frame) end
        end)
    end

    -- FIX: Added UpdateHealthText here.
    -- When a unit revives, UpdateHealthColor fires (changing bar from Grey -> Color).
    -- Hooking this ensures we catch the "Revive" event even if other status events lag or fail.
    if CompactUnitFrame_UpdateHealthColor then
        hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(frame) 
            if DF.ApplyHealthColors then DF:ApplyHealthColors(frame) end
            if DF.UpdateHealthText then DF:UpdateHealthText(frame) end
        end)
    end
    
    -- Aura Hooks
    if DF.ApplyAuraLayout then
        hooksecurefunc("CompactUnitFrame_UpdateAuras", function(frame) DF:ApplyAuraLayout(frame) end)
    end
    
    -- Text Hooks
    if CompactUnitFrame_UpdateName and DF.UpdateNameText then
        hooksecurefunc("CompactUnitFrame_UpdateName", function(frame) DF:UpdateNameText(frame) end)
    end
    -- Keep this hook as a fallback for pure status text events
    if CompactUnitFrame_UpdateStatusText and DF.UpdateHealthText then
        hooksecurefunc("CompactUnitFrame_UpdateStatusText", function(frame) DF:UpdateHealthText(frame) end)
    end

    -- Icon Hooks
    if CompactUnitFrame_UpdateStatusIcons and DF.UpdateIcons then
        hooksecurefunc("CompactUnitFrame_UpdateStatusIcons", function(frame) DF:UpdateIcons(frame) end)
    end
    
    -- Resource Bar Hooks
    if CompactUnitFrame_UpdateMaxPower and DF.ApplyResourceBarLayout and DF.UpdateResourceBar then
        hooksecurefunc("CompactUnitFrame_UpdateMaxPower", function(frame) 
            DF:ApplyResourceBarLayout(frame)
            DF:UpdateResourceBar(frame)
        end)
    end
    if CompactUnitFrame_UpdatePower and DF.UpdateResourceBar then
        hooksecurefunc("CompactUnitFrame_UpdatePower", function(frame) DF:UpdateResourceBar(frame) end)
    end
    if CompactUnitFrame_UpdatePowerColor and DF.UpdateResourceBar then
        hooksecurefunc("CompactUnitFrame_UpdatePowerColor", function(frame) DF:UpdateResourceBar(frame) end)
    end

    -- Padding / Inset Hooks
    -- Prevents Edit Mode from resetting the padding
    if DF.ApplyFrameInset then
        if CompactUnitFrame_UpdateAll then
            hooksecurefunc("CompactUnitFrame_UpdateAll", function(frame) DF:ApplyFrameInset(frame) end)
        end
        
        if CompactUnitFrame_SetUpFrame then
            hooksecurefunc("CompactUnitFrame_SetUpFrame", function(frame) DF:ApplyFrameInset(frame) end)
        end
    end

    -- NEW: Visibility Hook for Demo Mode
    -- Ensures frames stay shown even when "dandersdemo" unit doesn't exist
    if CompactUnitFrame_UpdateVisible then
        hooksecurefunc("CompactUnitFrame_UpdateVisible", function(frame)
            if DF.demoMode and frame.unit == "dandersdemo" then
                frame:Show()
            end
        end)
    end
end