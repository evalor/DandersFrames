local addonName, DF = ...

-- ============================================================
-- EDIT MODE STUB
-- 
-- The custom Position Frames functionality has been removed.
-- This file maintains API compatibility for any code that might
-- reference the old functions.
-- ============================================================

DF.FilteredEditMode = {
    active = false,
    hiddenSelections = {},
    settingHooked = false,
}

-- Stub functions for API compatibility
function DF:OpenFilteredEditMode()
    -- Feature removed - does nothing
end

function DF:CloseFilteredEditMode()
    -- Feature removed - does nothing
end

function DF:ToggleFilteredEditMode()
    -- Feature removed - does nothing
end

function DF:IsFilteredEditModeActive()
    return false
end
