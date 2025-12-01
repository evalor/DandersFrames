local addonName, DF = ...
local GUI = {}
DF.GUI = GUI

-- =========================================================================
-- MODERN UI CONSTANTS & STYLING
-- =========================================================================
local C_BACKGROUND = {r = 0.11, g = 0.11, b = 0.11, a = 0.98}
local C_PANEL      = {r = 0.16, g = 0.16, b = 0.16, a = 1}
local C_BORDER     = {r = 0, g = 0, b = 0, a = 1}
local C_ACCENT     = {r = 0.2, g = 0.6, b = 1.0, a = 1} -- Party Blue
local C_RAID       = {r = 1.0, g = 0.4, b = 0.2, a = 1} -- Raid Orange
local C_HOVER      = {r = 0.25, g = 0.25, b = 0.25, a = 1}
local P = 1 -- Pixel size

-- Helper to get current theme color
local function GetThemeColor()
    if GUI.SelectedMode == "raid" then return C_RAID else return C_ACCENT end
end

-- EXPOSE THIS FUNCTION TO OPTIONS FILE
GUI.GetThemeColor = GetThemeColor

-- Helper to create a flat backdrop
local function CreateBackdrop(frame, bgAlpha)
    if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = P,
        insets = {left = P, right = P, top = P, bottom = P}
    })
    local a = bgAlpha or C_BACKGROUND.a
    frame:SetBackdropColor(C_BACKGROUND.r, C_BACKGROUND.g, C_BACKGROUND.b, a)
    frame:SetBackdropBorderColor(C_BORDER.r, C_BORDER.g, C_BORDER.b, C_BORDER.a)
end

-- EXPOSE THIS FUNCTION TO OPTIONS FILE
GUI.CreateBackdrop = CreateBackdrop

-- =========================================================================
-- WIDGET FACTORY
-- =========================================================================

function GUI:CreateHeader(parent, text)
    local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    h:SetText(text)
    local c = GetThemeColor()
    h:SetTextColor(c.r, c.g, c.b)
    h:SetJustifyH("LEFT")
    h.UpdateTheme = function() local nc = GetThemeColor() h:SetTextColor(nc.r, nc.g, nc.b) end
    if not parent.ThemeListeners then parent.ThemeListeners = {} end
    table.insert(parent.ThemeListeners, h)
    return h
end

-- Helper for Description/Label Text
function GUI:CreateLabel(parent, text, width, color)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(width or 380, 40) 
    
    local lbl = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", 0, -5)
    lbl:SetWidth(width or 380)
    lbl:SetJustifyH("LEFT")
    lbl:SetText(text)
    
    if color then
        lbl:SetTextColor(color.r, color.g, color.b, color.a or 1)
    else
        lbl:SetTextColor(0.7, 0.7, 0.7, 1) -- Default gray
    end
    
    -- Expose method to update text dynamically
    frame.SetText = function(self, newText) lbl:SetText(newText) end
    
    return frame
end

-- NEW: Gradient Preview Bar
function GUI:CreateGradientBar(parent, width, height, db)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width or 360, height or 20)
    CreateBackdrop(f)
    f:SetBackdropColor(0, 0, 0, 1)
    
    -- Label - Moved inside to prevent overlap
    local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
    lbl:SetPoint("LEFT", f, "LEFT", 5, 0)
    lbl:SetText("0%")
    lbl:SetTextColor(1,1,1,1)
    
    local lbl2 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
    lbl2:SetPoint("RIGHT", f, "RIGHT", -5, 0)
    lbl2:SetText("100%")
    lbl2:SetTextColor(1,1,1,1)
    
    f.TexPool = {}
    
    -- Function to recreate the visual representation of the weights
    f.UpdatePreview = function()
        if not db then return end
        
        -- Hide old textures
        for _, tex in ipairs(f.TexPool) do tex:Hide() end
        
        -- Get Player Class Color
        local _, pClass = UnitClass("player")
        local classCol = RAID_CLASS_COLORS[pClass] or {r=0.5, g=0.5, b=0.5}

        -- Fetch Colors (Fallback to defaults if missing)
        local function GetC(stage)
            -- Check "Use Class Color" setting
            if db["healthColor"..stage.."UseClass"] then
                return CreateColor(classCol.r, classCol.g, classCol.b, 1)
            end
            
            local c = db["healthColor"..stage]
            -- FIX: Check for c.r to ensure table isn't empty or malformed during reset
            if not c or not c.r then return CreateColor(1,1,1,1) end
            return CreateColor(c.r, c.g, c.b, 1)
        end
        
        local lCol = GetC("Low")
        local mCol = GetC("Medium")
        local hCol = GetC("High")
        
        -- Fetch Weights
        local lowW = math.max(1, math.floor(db.healthColorLowWeight or 1))
        local medW = math.max(1, math.floor(db.healthColorMediumWeight or 1))
        local highW = math.max(1, math.floor(db.healthColorHighWeight or 1))
        
        -- Build Point List (Mimics DandersFrames_Health.lua logic)
        local points = {}
        for i = 1, lowW do table.insert(points, lCol) end
        for i = 1, medW do table.insert(points, mCol) end
        for i = 1, highW do table.insert(points, hCol) end
        
        if #points < 2 then points = {lCol, hCol} end
        
        -- Render Segments
        local numSegments = #points - 1
        local segWidth = f:GetWidth() / numSegments
        
        for i = 1, numSegments do
            local tex = f.TexPool[i]
            if not tex then
                tex = f:CreateTexture(nil, "ARTWORK")
                table.insert(f.TexPool, tex)
            end
            
            tex:Show()
            tex:ClearAllPoints()
            tex:SetPoint("LEFT", f, "LEFT", (i-1) * segWidth, 0)
            tex:SetSize(segWidth, f:GetHeight() - 2)
            
            local c1 = points[i]
            local c2 = points[i+1]
            
            -- Apply Gradient
            tex:SetColorTexture(1, 1, 1, 1)
            tex:SetGradient("HORIZONTAL", c1, c2)
        end
    end
    
    f:SetScript("OnShow", f.UpdatePreview)
    f.UpdatePreview()
    return f
end

function GUI:CreateButton(parent, text, width, height, func)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width or 120, height or 24)
    CreateBackdrop(btn, 1)
    btn:SetBackdropColor(C_PANEL.r, C_PANEL.g, C_PANEL.b, 1)
    btn.Text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.Text:SetPoint("CENTER")
    btn.Text:SetText(text)
    btn:SetScript("OnEnter", function(self) if self:IsEnabled() then self:SetBackdropColor(C_HOVER.r, C_HOVER.g, C_HOVER.b, 1) end end)
    btn:SetScript("OnLeave", function(self) 
        if self:IsEnabled() then 
            if self.isTab and self.isActive then
                local tc = GetThemeColor()
                self:SetBackdropColor(tc.r, tc.g, tc.b, 0.8)
            else
                self:SetBackdropColor(C_PANEL.r, C_PANEL.g, C_PANEL.b, 1) 
            end
        end 
    end)
    btn:SetScript("OnClick", function(self) if func then func(self) end PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end)
    return btn
end

function GUI:CreateCheckbox(parent, label, dbTable, dbKey, callback, customGet, customSet)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetSize(20, 20)
    CreateBackdrop(cb)
    cb:SetBackdropColor(0, 0, 0, 0.5)
    cb.Check = cb:CreateTexture(nil, "OVERLAY")
    cb.Check:SetTexture("Interface\\Buttons\\WHITE8x8")
    local c = GetThemeColor()
    cb.Check:SetVertexColor(c.r, c.g, c.b)
    cb.Check:SetPoint("CENTER")
    cb.Check:SetSize(12, 12)
    cb:SetCheckedTexture(cb.Check)
    cb.Text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cb.Text:SetPoint("LEFT", cb, "RIGHT", 8, 0)
    cb.Text:SetText(label)
    
    local function UpdateState()
        local val = false
        if customGet then val = customGet() elseif dbTable and dbKey then val = dbTable[dbKey] end
        cb:SetChecked(val)
    end
    
    cb.UpdateTheme = function() local nc = GetThemeColor() cb.Check:SetVertexColor(nc.r, nc.g, nc.b) end
    if not parent.ThemeListeners then parent.ThemeListeners = {} end
    table.insert(parent.ThemeListeners, cb)

    cb:SetScript("OnShow", UpdateState)
    cb:SetScript("OnClick", function(self)
        local val = self:GetChecked()
        if customSet then customSet(val) elseif dbTable and dbKey then dbTable[dbKey] = val end
        if callback then callback() end
        if parent.RefreshStates then parent:RefreshStates() end
        DF:UpdateAll()
    end)
    UpdateState()
    return cb
end

function GUI:CreateSlider(parent, label, minVal, maxVal, step, dbTable, dbKey, callback)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(220, 60) 
    local slider = CreateFrame("Slider", nil, container, "BackdropTemplate")
    slider:SetPoint("TOPLEFT", 0, -20) 
    slider:SetPoint("TOPRIGHT", -45, -20) 
    slider:SetHeight(6)
    CreateBackdrop(slider)
    slider:SetBackdropColor(0, 0, 0, 0.8)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(8, 14)
    local c = GetThemeColor()
    thumb:SetColorTexture(c.r, c.g, c.b, 1)
    slider:SetThumbTexture(thumb)
    
    local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    lbl:SetText(label)
    
    local input = CreateFrame("EditBox", nil, container)
    input:SetPoint("TOPRIGHT", 0, -13)
    input:SetSize(40, 20)
    CreateBackdrop(input)
    input:SetBackdropColor(0, 0, 0, 0.5)
    input:SetFontObject(GameFontHighlightSmall)
    input:SetJustifyH("CENTER")
    input:SetAutoFocus(false)
    input:SetTextInsets(2, 2, 0, 0)

    container.SetEnabled = function(self, enabled)
        slider:SetEnabled(enabled)
        input:EnableMouse(enabled)
        local tc = GetThemeColor()
        if enabled then
            lbl:SetTextColor(1, 1, 1)
            thumb:SetColorTexture(tc.r, tc.g, tc.b, 1)
        else
            lbl:SetTextColor(0.5, 0.5, 0.5)
            thumb:SetColorTexture(0.3, 0.3, 0.3, 1)
        end
    end
    
    container.UpdateTheme = function() local nc = GetThemeColor() if slider:IsEnabled() then thumb:SetColorTexture(nc.r, nc.g, nc.b, 1) end end
    if not parent.ThemeListeners then parent.ThemeListeners = {} end
    table.insert(parent.ThemeListeners, container)

    local suppressCallback = false
    local function UpdateValue(val)
        val = val or minVal
        suppressCallback = true
        slider:SetValue(val)
        suppressCallback = false
        if step < 1 then input:SetText(string.format("%.2f", val)) else input:SetText(string.format("%d", val)) end
    end

    slider:SetScript("OnShow", function() if dbTable then UpdateValue(dbTable[dbKey]) end end)
    
    slider:SetScript("OnValueChanged", function(self, value)
        if suppressCallback then return end
        if not dbTable then return end
        if step >= 1 then value = math.floor(value + 0.5) end
        dbTable[dbKey] = value
        if not input:HasFocus() then 
            if step < 1 then input:SetText(string.format("%.2f", value)) else input:SetText(string.format("%d", value)) end 
        end
        
        -- Live Update
        DF:UpdateAll()
        if callback then callback() end
    end)
    
    -- Keep fallback for ensuring state on release, but logic is now in OnValueChanged
    slider:SetScript("OnMouseUp", function()
        -- Optional: Ensure final value is set or cleanup
    end)
    
    input:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then
            if val < minVal then val = minVal end
            if val > maxVal then val = maxVal end
            dbTable[dbKey] = val
            slider:SetValue(val)
            if callback then callback() end 
        else 
            UpdateValue(dbTable[dbKey]) 
        end
        self:ClearFocus()
    end)
    
    if dbTable then UpdateValue(dbTable[dbKey]) end
    return container
end

function GUI:CreateColorPicker(parent, label, dbTable, dbKey, hasAlpha, callback)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(180, 24)
    CreateBackdrop(btn)
    btn:SetBackdropColor(0, 0, 0, 0.3)
    local swatch = btn:CreateTexture(nil, "OVERLAY")
    swatch:SetSize(20, 16)
    swatch:SetPoint("RIGHT", -4, 0)
    swatch:SetColorTexture(1, 1, 1, 1)
    local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    txt:SetPoint("LEFT", 5, 0)
    txt:SetText(label)
    
    local function UpdateSwatch() 
        if dbTable and dbKey and dbTable[dbKey] then 
            local c = dbTable[dbKey] 
            swatch:SetColorTexture(c.r, c.g, c.b, c.a or 1) 
        end 
    end
    
    btn:SetScript("OnEnable", function() txt:SetTextColor(1, 1, 1) swatch:SetDesaturated(false) end)
    btn:SetScript("OnDisable", function() txt:SetTextColor(0.5, 0.5, 0.5) swatch:SetDesaturated(true) end)
    
    btn:SetScript("OnClick", function()
        if not dbTable then return end
        local c = dbTable[dbKey]
        
        -- FIX: ColorPickerFrame argument handling for modern WoW clients
        local info = {
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = 1
                if hasAlpha then
                    -- Use GetColorAlpha only if supported/enabled
                    a = ColorPickerFrame:GetColorAlpha() or 1
                else
                    a = dbTable[dbKey].a or 1
                end
                
                dbTable[dbKey].r = r
                dbTable[dbKey].g = g
                dbTable[dbKey].b = b
                dbTable[dbKey].a = a
                
                UpdateSwatch()
                DF:UpdateAll()
                if callback then callback() end
            end,
            hasOpacity = hasAlpha,
            opacityFunc = function()
                -- This can sometimes fail if opacityFunc is called before alpha is initialized
                local a = ColorPickerFrame:GetColorAlpha()
                if a then
                    dbTable[dbKey].a = a
                    UpdateSwatch()
                    DF:UpdateAll()
                    if callback then callback() end
                end
            end,
            cancelFunc = function(restore)
                dbTable[dbKey].r = restore.r
                dbTable[dbKey].g = restore.g
                dbTable[dbKey].b = restore.b
                dbTable[dbKey].a = restore.a -- Note: restore struct uses .a or .opacity depending on client vers
                UpdateSwatch()
                DF:UpdateAll()
                if callback then callback() end
            end,
            r = c.r, g = c.g, b = c.b, opacity = c.a,
            
            -- Modern WoW fallback for cancel restore
            extraInfo = { r=c.r, g=c.g, b=c.b, a=c.a }
        }
        
        -- Wrap cancel func to handle the restore object format differences
        local originalCancel = info.cancelFunc
        info.cancelFunc = function(restore)
             local r, g, b, a
             if restore.r then r=restore.r g=restore.g b=restore.b a=restore.a or restore.opacity else
                 r=c.r g=c.g b=c.b a=c.a 
             end
             dbTable[dbKey].r, dbTable[dbKey].g, dbTable[dbKey].b, dbTable[dbKey].a = r, g, b, a
             UpdateSwatch()
             DF:UpdateAll()
             if callback then callback() end
        end

        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)
    UpdateSwatch()
    return btn
end

function GUI:CreateDropdown(parent, label, values, dbTable, dbKey, callback, isTexture)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(180, 60) 
    local lbl = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", 0, 0)
    lbl:SetText(label)
    local btn = CreateFrame("Button", nil, frame)
    btn:SetPoint("TOPLEFT", 0, -15)
    btn:SetPoint("TOPRIGHT", 0, -15)
    btn:SetHeight(24)
    CreateBackdrop(btn)
    btn:SetBackdropColor(0.1, 0.1, 0.1, 1)
    
    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btnText:SetPoint("LEFT", 8, 0)
    btnText:SetText(values[dbTable[dbKey]] or "Select...")
    
    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrow:SetPoint("RIGHT", -8, 0)
    arrow:SetText("v")
    
    -- NEW: Preview Texture on the Main Button
    local mainPreview = nil
    local previewBg = nil -- Backing for stripes
    
    if isTexture then
        -- Create Background Layer (for Stripes support)
        previewBg = btn:CreateTexture(nil, "ARTWORK")
        previewBg:SetSize(100, 18)
        previewBg:SetPoint("RIGHT", btn, "RIGHT", -25, 0)
        previewBg:SetColorTexture(0, 0.835, 1, 0.7) -- Default Blue
        previewBg:Hide()

        mainPreview = btn:CreateTexture(nil, "OVERLAY")
        mainPreview:SetSize(100, 18)
        mainPreview:SetPoint("RIGHT", btn, "RIGHT", -25, 0)
        
        if dbTable[dbKey] == "DF_STRIPES" then
             -- UPDATED: Use the new Shield-Overlay texture for the preview too
             mainPreview:SetTexture("Interface\\RaidFrame\\Shield-Overlay")
             mainPreview:SetHorizTile(true)
             mainPreview:SetVertTile(true)
             mainPreview:SetTexCoord(0, 5, 0, 1) -- Less repeats for small preview
             mainPreview:SetBlendMode("ADD")
             previewBg:Hide() -- Backing hidden per request
        else
             mainPreview:SetTexture(dbTable[dbKey])
             mainPreview:SetTexCoord(0, 1, 0, 1)
             mainPreview:SetHorizTile(false)
             mainPreview:SetVertTile(false)
             if dbTable[dbKey] == "Interface\\CastingBar\\UI-CastingBar-Flash" then
                 mainPreview:SetBlendMode("ADD")
             else
                 mainPreview:SetBlendMode("BLEND")
             end
             previewBg:Hide()
        end
        mainPreview:SetVertexColor(1, 1, 1, 1) -- Force Full Alpha for Preview
    end
    
    local list = CreateFrame("Frame", nil, btn)
    list:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    list:SetPoint("TOPRIGHT", btn, "BOTTOMRIGHT", 0, -2)
    CreateBackdrop(list)
    list:SetBackdropColor(0.1, 0.1, 0.1, 1)
    list:Hide()
    list:SetFrameStrata("DIALOG")
    
    frame.SetEnabled = function(self, enabled)
        btn:SetEnabled(enabled)
        if enabled then lbl:SetTextColor(1, 1, 1) arrow:SetTextColor(1, 1, 1)
        else lbl:SetTextColor(0.5, 0.5, 0.5) arrow:SetTextColor(0.5, 0.5, 0.5) end
        if mainPreview then mainPreview:SetDesaturated(not enabled) end
    end
    
    local function Select(key, display)
        dbTable[dbKey] = key
        btnText:SetText(display)
        if mainPreview then 
            if key == "DF_STRIPES" then
                 mainPreview:SetTexture("Interface\\RaidFrame\\Shield-Overlay")
                 mainPreview:SetHorizTile(true)
                 mainPreview:SetVertTile(true)
                 mainPreview:SetTexCoord(0, 5, 0, 1) 
                 mainPreview:SetBlendMode("ADD")
                 if previewBg then previewBg:Hide() end
            else
                 mainPreview:SetTexture(key) 
                 mainPreview:SetHorizTile(false)
                 mainPreview:SetVertTile(false)
                 mainPreview:SetTexCoord(0, 1, 0, 1)
                 if key == "Interface\\CastingBar\\UI-CastingBar-Flash" then
                     mainPreview:SetBlendMode("ADD")
                 else
                     mainPreview:SetBlendMode("BLEND")
                 end
                 if previewBg then previewBg:Hide() end
            end
        end
        list:Hide()
        if callback then callback() end
        DF:UpdateAll()
        if parent.RefreshStates then parent:RefreshStates() end
    end
    
    -- UPDATED: Sorting Logic
    local keys = {}
    for k in pairs(values) do table.insert(keys, k) end
    table.sort(keys, function(a, b) 
        -- CUSTOM SORTING: Sandwich always first, then Dialog, then others
        if a == "SANDWICH" then return true end
        if b == "SANDWICH" then return false end
        if a == "DIALOG" then return true end
        if b == "DIALOG" then return false end
        
        local vA = values[a] or ""
        local vB = values[b] or ""
        return vA < vB 
    end)
    
    local yOff, count = -4, 0
    for _, k in ipairs(keys) do
        local v = values[k]
        local opt = CreateFrame("Button", nil, list)
        opt:SetHeight(20)
        opt:SetPoint("TOPLEFT", 4, yOff)
        opt:SetPoint("TOPRIGHT", -4, yOff)
        local t = opt:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        t:SetPoint("LEFT", 4, 0)
        t:SetText(v)
        
        -- NEW: Preview Texture on Dropdown Options
        if isTexture then
            local prev = opt:CreateTexture(nil, "OVERLAY")
            prev:SetSize(90, 16)
            prev:SetPoint("RIGHT", opt, "RIGHT", -2, 0)
            
            if k == "DF_STRIPES" then
                 prev:SetTexture("Interface\\RaidFrame\\Shield-Overlay")
                 prev:SetHorizTile(true)
                 prev:SetVertTile(true)
                 prev:SetTexCoord(0, 5, 0, 1)
                 prev:SetBlendMode("ADD")
            else
                 prev:SetTexture(k)
                 if k == "Interface\\CastingBar\\UI-CastingBar-Flash" then
                     prev:SetBlendMode("ADD")
                 else
                     prev:SetBlendMode("BLEND")
                 end
            end
            
            prev:SetVertexColor(1, 1, 1, 1)
        end
        
        opt:SetScript("OnEnter", function() t:SetTextColor(GetThemeColor().r, GetThemeColor().g, GetThemeColor().b) end)
        opt:SetScript("OnLeave", function() t:SetTextColor(1, 1, 1) end)
        opt:SetScript("OnClick", function() Select(k, v) end)
        yOff = yOff - 20
        count = count + 1
    end
    list:SetHeight((count * 20) + 8)
    btn:SetScript("OnClick", function() if list:IsShown() then list:Hide() else list:Show() end end)
    return frame
end

function GUI:CreateInput(parent, label, width)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(width or 180, 44)
    local lbl = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", 0, 0)
    lbl:SetText(label)
    local editbox = CreateFrame("EditBox", nil, frame)
    editbox:SetPoint("TOPLEFT", 0, -15)
    editbox:SetPoint("TOPRIGHT", 0, -15)
    editbox:SetHeight(24)
    CreateBackdrop(editbox)
    editbox:SetBackdropColor(0, 0, 0, 0.5)
    editbox:SetFontObject(GameFontHighlightSmall)
    editbox:SetTextInsets(5, 5, 0, 0)
    editbox:SetAutoFocus(false)
    editbox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    frame.EditBox = editbox
    return frame
end

-- =========================================================================
-- MAIN WINDOW CONSTRUCTION
-- =========================================================================

function DF:ToggleGUI()
    if DF.GUIFrame and DF.GUIFrame:IsShown() then
        DF.GUIFrame:Hide()
    else
        if not DF.GUIFrame then GUI:BuildMainFrame() end
        DF.GUIFrame:Show()
    end
end

function GUI:BuildMainFrame()
    local f = CreateFrame("Frame", "DandersFramesGUI", UIParent)
    f:SetSize(850, 600)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG") -- Updated: Higher strata to prevent clipping
    f:SetToplevel(true)        -- Updated: Clicking the frame brings it to the front
    f:EnableMouse(true)
    f:SetMovable(true)
    CreateBackdrop(f)
    DF.GUIFrame = f
    
    -- FIX: Hide Test Frame AND Auto-Disable Overlay when closing GUI
    f:SetScript("OnHide", function()
        if DF.DispelTestFrame then DF.DispelTestFrame:Hide() end

        -- Auto-disable "Show Overlay Frame" for both profiles
        if DF.db and DF.db.profile then
            if DF.db.profile.party then DF.db.profile.party.showDispelOverlay = false end
            if DF.db.profile.raid then DF.db.profile.raid.showDispelOverlay = false end
        end
        
        DF:UpdateAll()
    end)
    
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetHeight(30)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", -30, 0)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", 15, 0)
    
    -- UPDATED: Fetch version from TOC dynamically
    local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "Dev"
    title:SetText("DandersFrames |cff00aaffv" .. version .. "|r")
    
    local close = CreateFrame("Button", nil, f)
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -10, -3)
    close:SetFrameLevel(titleBar:GetFrameLevel() + 10)
    close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    close:SetScript("OnClick", function() f:Hide() end)
    
    local sidebar = CreateFrame("Frame", nil, f)
    titleBar:SetFrameLevel(f:GetFrameLevel() + 5)
    sidebar:SetPoint("TOPLEFT", 10, -40)
    sidebar:SetPoint("BOTTOMLEFT", 10, 10)
    sidebar:SetWidth(160)
    CreateBackdrop(sidebar)
    sidebar:SetBackdropColor(0.15, 0.15, 0.15, 1)
    
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 10, 0)
    content:SetPoint("BOTTOMRIGHT", -10, 10)
    CreateBackdrop(content)
    content:SetBackdropColor(0.15, 0.15, 0.15, 0.5)
    
    -- Mode Switcher
    GUI.SelectedMode = "party"
    local btnParty = CreateFrame("Button", nil, sidebar)
    btnParty:SetSize(75, 30)
    btnParty:SetPoint("TOPLEFT", 5, -5)
    CreateBackdrop(btnParty, 1)
    btnParty.Text = btnParty:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btnParty.Text:SetPoint("CENTER")
    btnParty.Text:SetText("PARTY")
    
    local btnRaid = CreateFrame("Button", nil, sidebar)
    btnRaid:SetSize(75, 30)
    btnRaid:SetPoint("LEFT", btnParty, "RIGHT", 0, 0)
    CreateBackdrop(btnRaid, 1)
    btnRaid.Text = btnRaid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btnRaid.Text:SetPoint("CENTER")
    btnRaid.Text:SetText("RAID")
    
    local function UpdateThemeColors()
        if GUI.SelectedMode == "party" then
            btnParty:SetBackdropColor(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b, 1)
            btnParty.Text:SetTextColor(1, 1, 1)
            btnRaid:SetBackdropColor(0.1, 0.1, 0.1, 1)
            btnRaid.Text:SetTextColor(0.5, 0.5, 0.5)
        else
            btnParty:SetBackdropColor(0.1, 0.1, 0.1, 1)
            btnParty.Text:SetTextColor(0.5, 0.5, 0.5)
            btnRaid:SetBackdropColor(C_RAID.r, C_RAID.g, C_RAID.b, 1)
            btnRaid.Text:SetTextColor(1, 1, 1)
        end
        local c = GetThemeColor()
        if GUI.CurrentPageName and GUI.Tabs[GUI.CurrentPageName] then GUI.Tabs[GUI.CurrentPageName]:SetBackdropColor(c.r, c.g, c.b, 0.8) end
        if GUI.CurrentPageName and GUI.Pages[GUI.CurrentPageName] then
            local page = GUI.Pages[GUI.CurrentPageName]
            if page.child and page.child.ThemeListeners then
                for _, widget in ipairs(page.child.ThemeListeners) do if widget.UpdateTheme then widget:UpdateTheme() end end
            end
        end
    end
    
    btnParty:SetScript("OnClick", function() GUI.SelectedMode = "party" UpdateThemeColors() GUI:RefreshCurrentPage() end)
    btnRaid:SetScript("OnClick", function() GUI.SelectedMode = "raid" UpdateThemeColors() GUI:RefreshCurrentPage() end)
    UpdateThemeColors()
    
    GUI.Tabs = {}
    GUI.Pages = {}
    
    local function SelectTab(name)
        for k, page in pairs(GUI.Pages) do page:Hide() end
        for k, btn in pairs(GUI.Tabs) do btn:SetBackdropColor(C_PANEL.r, C_PANEL.g, C_PANEL.b, 1) btn.isActive = false end
        if GUI.Pages[name] then 
            GUI.Pages[name]:Show()
            GUI.Pages[name]:Refresh() 
            if GUI.Pages[name].RefreshStates then GUI.Pages[name]:RefreshStates() end
        end
        local c = GetThemeColor()
        if GUI.Tabs[name] then GUI.Tabs[name]:SetBackdropColor(c.r, c.g, c.b, 0.8) GUI.Tabs[name].isActive = true end
        GUI.CurrentPageName = name
        UpdateThemeColors()
    end
    
    GUI.RefreshCurrentPage = function()
        if GUI.CurrentPageName and GUI.Pages[GUI.CurrentPageName] then
            GUI.Pages[GUI.CurrentPageName]:Refresh()
            if GUI.Pages[GUI.CurrentPageName].RefreshStates then GUI.Pages[GUI.CurrentPageName]:RefreshStates() end
            UpdateThemeColors()
        end
    end

    local tabY = -45
    local function CreateTab(name, label)
        local btn = GUI:CreateButton(sidebar, label, 140, 28)
        btn:SetPoint("TOP", 0, tabY)
        btn.isTab = true
        btn.tabName = name
        
        local page = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
        page:SetPoint("TOPLEFT", 0, -5)
        page:SetPoint("BOTTOMRIGHT", -30, 5)
        local child = CreateFrame("Frame", nil, page)
        child:SetSize(content:GetWidth() - 30, 1) 
        page:SetScrollChild(child)
        page.child = child
        page:Hide()
        page.Refresh = function() end 
        
        GUI.Tabs[name] = btn
        GUI.Pages[name] = page
        btn:SetScript("OnClick", function() SelectTab(name) end)
        tabY = tabY - 32
        return page
    end

    local function BuildPage(page, builderFunc)
        page.Refresh = function(self)
            local db = DF.db.profile[GUI.SelectedMode]
            if self.children then for _, child in ipairs(self.children) do child:Hide() end end
            self.children = {}
            self.child.ThemeListeners = {}
            local parent = self.child 
            local function Add(widget, height, col)
                table.insert(self.children, widget)
                widget:SetParent(parent) 
                widget.layoutHeight = height or 60
                widget.layoutCol = col or 1
                return widget
            end
            local function AddSpace(h, col) -- FIX: Added 'col' argument
                local spacer = CreateFrame("Frame", nil, parent)
                spacer:SetSize(1, h)
                spacer.layoutHeight = h
                spacer.layoutCol = col or "both"
                table.insert(self.children, spacer)
            end
            builderFunc(self, db, Add, AddSpace)
            self:RefreshStates()
        end
        
        page.RefreshStates = function(self)
            if not self.children then return end
            local db = DF.db.profile[GUI.SelectedMode]
            if not db then return end
            
            -- Visibility Check
            for _, widget in ipairs(self.children) do
                if widget.disableOn then
                    local shouldDisable = widget.disableOn(db)
                    if widget.SetEnabled then widget:SetEnabled(not shouldDisable) 
                    elseif widget.Enable and widget.Disable then
                        if shouldDisable then widget:Disable() else widget:Enable() end
                    end
                end
                if widget.hideOn then
                    if widget.hideOn(db) then widget:Hide() else widget:Show() end
                else widget:Show() end
            end
            
            -- Layout Logic
            local y1, y2, col2X, x1, maxY = -10, -10, 370, 10, 0
            for _, widget in ipairs(self.children) do
                local h = widget.layoutHeight or 0
                if widget:IsShown() then
                    widget:ClearAllPoints()
                    
                    if widget.layoutCol == "both" then 
                        -- FIX: Ensure we align to the lowest point of previous columns to avoid overlap
                        local startY = math.min(y1, y2)
                        widget:SetPoint("TOPLEFT", x1, startY)
                        
                        -- Push both columns down
                        y1 = startY - h
                        y2 = startY - h
                    elseif widget.layoutCol == 2 then
                        widget:SetPoint("TOPLEFT", col2X, y2)
                        y2 = y2 - h
                    else
                        widget:SetPoint("TOPLEFT", x1, y1)
                        y1 = y1 - h
                    end
                    
                    -- Track max height for scrolling
                    local currentBottom = math.min(y1, y2)
                    if math.abs(currentBottom) > maxY then maxY = math.abs(currentBottom) end
                end
            end
            self.child:SetHeight(maxY + 50)
        end
    end

    -- =========================================================================
    -- LOAD CONTENT FROM OPTIONS FILE
    -- =========================================================================
    if DF.SetupGUIPages then
        DF:SetupGUIPages(GUI, CreateTab, BuildPage)
    end

    SelectTab("general")
end