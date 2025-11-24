local addonName, DF = ...

-- Updates the cache when settings change.
-- Called by DF:UpdateAll()
function DF:UpdateColorCurve()
    -- Clear the cache so curves are rebuilt with new settings (colors/class options)
    DF.CurveCache = {}
end

-- Retrieves (or creates) a Color Curve specific to the unit's class.
-- This allows us to use "Class Color" as a gradient endpoint while still using Blizzard's native function.
function DF:GetCurveForUnit(unit, db)
    if not unit then return nil end
    
    -- Determine if we need a specific class curve or just the generic one
    local useClass = db.healthColorLowUseClass or db.healthColorMediumUseClass or db.healthColorHighUseClass
    local class = "DEFAULT"
    
    if useClass then
        _, class = UnitClass(unit)
        if not class then 
            if EditModeManagerFrame and EditModeManagerFrame:IsShown() then 
                _, class = UnitClass("player") 
            else
                class = "DEFAULT" 
            end
        end
    end

    -- Ensure Cache Exists
    if not DF.CurveCache then DF.CurveCache = {} end
    
    -- Return cached curve if it exists for this class
    if DF.CurveCache[class] then return DF.CurveCache[class] end

    -- Create new curve for this class
    if not C_CurveUtil or not C_CurveUtil.CreateColorCurve then return nil end
    local curve = C_CurveUtil.CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Linear)

    -- Helper to resolve the color for a stage (Low/Med/High)
    local function GetStageColor(stage)
        -- If checkbox is enabled for this stage, use Class Color
        if db["healthColor"..stage.."UseClass"] and class ~= "DEFAULT" then
            local c = RAID_CLASS_COLORS[class]
            if c then return c.r, c.g, c.b, 1.0 end
            return 0.5, 0.5, 0.5, 1.0 -- Fallback
        else
            -- Otherwise use the user-selected color from settings
            local c = db["healthColor"..stage]
            return c.r, c.g, c.b, c.a
        end
    end

    -- Get Weights (Default to 1 if missing)
    local lowW = math.max(1, math.floor(db.healthColorLowWeight or 1))
    local medW = math.max(1, math.floor(db.healthColorMediumWeight or 1))
    local highW = math.max(1, math.floor(db.healthColorHighWeight or 1))

    -- Prepare Colors
    local lr, lg, lb, la = GetStageColor("Low")
    local mr, mg, mb, ma = GetStageColor("Medium")
    local hr, hg, hb, ha = GetStageColor("High")

    local lCol = CreateColor(lr, lg, lb, la)
    local mCol = CreateColor(mr, mg, mb, ma)
    local hCol = CreateColor(hr, hg, hb, ha)

    -- Build a list of points based on weight
    -- Example: 1, 3, 1 => {Low, Med, Med, Med, High}
    -- This forces the gradient to spend "more time" (more points) on the weighted colors.
    local colorPoints = {}

    for i = 1, lowW do table.insert(colorPoints, lCol) end
    for i = 1, medW do table.insert(colorPoints, mCol) end
    for i = 1, highW do table.insert(colorPoints, hCol) end

    -- Safety check: We need at least 2 points to make a curve (Start/End)
    if #colorPoints < 2 then
        colorPoints = {lCol, hCol}
    end

    -- Distribute points evenly from 0.0 to 1.0
    local numPoints = #colorPoints
    for i, col in ipairs(colorPoints) do
        -- Calculate position: Index 1 is 0.0, Last Index is 1.0
        local position = (i - 1) / (numPoints - 1)
        curve:AddPoint(position, col)
    end

    -- Cache it so we don't recreate it every frame
    DF.CurveCache[class] = curve
    return curve
end

-- Helper to manual calculation for Demo Mode (since we can't inject fake health into UnitHealthPercentColor)
function DF:GetDemoColor(percent, db, unit)
    local class = "DEFAULT"
    if unit and unit ~= "dandersdemo" then 
        _, class = UnitClass(unit) 
    end
    
    -- FIX: Force "PALADIN" class color for Demo Unit so it's not grey
    if unit == "dandersdemo" or not class then 
        class = "PALADIN" 
    end
    
    local function GetC(stage)
        if db["healthColor"..stage.."UseClass"] then
            local c = RAID_CLASS_COLORS[class]
            -- Safety check: Ensure c is not nil before indexing
            if c then 
                return c.r, c.g, c.b
            else
                return 0.5, 0.5, 0.5
            end
        end
        local c = db["healthColor"..stage]
        return c.r, c.g, c.b
    end
    
    local lR, lG, lB = GetC("Low")
    local mR, mG, mB = GetC("Medium")
    local hR, hG, hB = GetC("High")
    
    local lowW = math.max(1, math.floor(db.healthColorLowWeight or 1))
    local medW = math.max(1, math.floor(db.healthColorMediumWeight or 1))
    local highW = math.max(1, math.floor(db.healthColorHighWeight or 1))
    
    local points = {}
    for i = 1, lowW do table.insert(points, {r=lR, g=lG, b=lB}) end
    for i = 1, medW do table.insert(points, {r=mR, g=mG, b=mB}) end
    for i = 1, highW do table.insert(points, {r=hR, g=hG, b=hB}) end
    
    if #points < 2 then points = {{r=lR,g=lG,b=lB}, {r=hR,g=hG,b=hB}} end
    
    -- Map percent (0.0-1.0) to the segment index
    local numSegments = #points - 1
    local scaled = percent * numSegments
    local index = math.floor(scaled) + 1
    local t = scaled - math.floor(scaled)
    
    if index >= #points then return points[#points].r, points[#points].g, points[#points].b end
    
    local c1 = points[index]
    local c2 = points[index+1]
    
    -- Linear Interpolation
    local r = c1.r + (c2.r - c1.r) * t
    local g = c1.g + (c2.g - c1.g) * t
    local b = c1.b + (c2.b - c1.b) * t
    
    return r, g, b
end

-- Applies health bar coloring and background textures
function DF:ApplyHealthColors(frame)
    if not DF:IsValidFrame(frame) then return end
    
    local unit = frame.unit or frame.displayedUnit
    if not frame.healthBar then return end
    
    local db = DF:GetDB(frame)
    local isEditMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()
    local mode = db.healthColorMode
    local a = db.classColorAlpha or 1.0
    
    -- Handle PERCENT mode (Gradient)
    if mode == "PERCENT" then
        -- Check Demo Mode Override
        if DF.demoMode then
            local dr, dg, db_b = DF:GetDemoColor(DF.demoPercent, db, unit)
            local tex = frame.healthBar:GetStatusBarTexture()
            if tex then
                tex:SetVertexColor(dr, dg, db_b)
                tex:SetAlpha(a)
            end
        else
            -- Normal Operation
            local curve = DF:GetCurveForUnit(unit, db)
            if curve and unit and UnitHealthPercentColor then
                local color = UnitHealthPercentColor(unit, curve)
                local tex = frame.healthBar:GetStatusBarTexture()
                if color and tex then
                    tex:SetVertexColor(color:GetRGB())
                    tex:SetAlpha(a)
                end
            end
        end
        
    -- Handle CLASS/CUSTOM modes
    else
        local r, g, b = 0, 1, 0
        
        if DF.demoMode and unit == "dandersdemo" and mode == "CLASS" then
             -- FIX: Fake Class Color for Demo
             local c = RAID_CLASS_COLORS["PALADIN"]
             r, g, b = c.r, c.g, c.b
        elseif unit and UnitIsEnemy("player", unit) then
            r, g, b = 1, 0, 0
        else
            if mode == "CLASS" then 
                local class
                if unit then _, class = UnitClass(unit) end
                if isEditMode then _, class = UnitClass("player") end
                local classColor = class and RAID_CLASS_COLORS[class]
                if classColor then r, g, b = classColor.r, classColor.g, classColor.b end
            elseif mode == "CUSTOM" then
                local c = db.healthColor
                r, g, b, a = c.r, c.g, c.b, c.a
            end
        end

        if type(r) == "number" then
            frame.healthBar:SetStatusBarColor(r, g, b, a)
            frame.healthBar.r, frame.healthBar.g, frame.healthBar.b = r, g, b
        else
            frame.healthBar:SetStatusBarColor(0, 1, 0, 1)
        end
    end

    -- Apply Background Color
    if db.enableTextureColor then
        local c = db.textureColor
        local bgR, bgG, bgB, bgA = c.r, c.g, c.b, c.a
        
        -- Overwrite with class color if enabled
        if db.backgroundClassColor then
            local class
            if unit then _, class = UnitClass(unit) end
            if isEditMode then _, class = UnitClass("player") end
            
            -- FIX: Demo Background Class
            if DF.demoMode and unit == "dandersdemo" then class = "PALADIN" end
            
            local cc = class and RAID_CLASS_COLORS[class]
            if cc then
                bgR, bgG, bgB = cc.r, cc.g, cc.b
                bgA = c.a or 1 
            end
        end

        if frame.background then
            frame.background:SetTexture("Interface\\Buttons\\WHITE8x8")
            frame.background:SetVertexColor(bgR, bgG, bgB, bgA)
            frame.background:SetDesaturated(true)
        end
        if frame.healthBar.background then
            frame.healthBar.background:SetTexture("Interface\\Buttons\\WHITE8x8")
            frame.healthBar.background:SetVertexColor(bgR, bgG, bgB, bgA)
        end
    end
end