-- MiHealBot v0.5 - Núcleo: datos, cabeceras de grupo/mascotas, click-casting, comandos
local addonName, ns = ...

ns.buttons = {}
ns.errs = {}
ns.auraSets = {}
ns.pendingApply = false
ns.pendingLayout = false

ns.MODS = { none = "", shift = "shift-", ctrl = "ctrl-", alt = "alt-" }
ns.MOD_ORDER = { "none", "shift", "ctrl", "alt" }
ns.MOD_LABELS = { none = "Sin modificador", shift = "Shift", ctrl = "Ctrl", alt = "Alt" }
ns.BUTTON_LABELS = { "Clic izquierdo", "Clic derecho", "Clic central", "Botón 4", "Botón 5" }
ns.TEXTURES = {
    "Interface\\TargetingFrame\\UI-StatusBar",
    "Interface\\Buttons\\WHITE8X8",
    "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
}
ns.TEXTURE_NAMES = { "Clásica", "Plana", "Raid" }
ns.ANCHORS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
ns.ANCHOR_NAMES = { "Arriba izq.", "Arriba", "Arriba der.", "Izquierda", "Centro", "Derecha", "Abajo izq.", "Abajo", "Abajo der." }
ns.GROWS = { "RIGHT", "LEFT", "UP", "DOWN" }
ns.GROW_NAMES = { "Derecha", "Izquierda", "Arriba", "Abajo" }

ns.defaults = {
    bindings = { ["none:1"] = "target", ["none:2"] = "menu" },
    left = 20,
    top = -300,
    minimapAngle = 200,
    opts = {
        width = 90, height = 40,
        spacing = 2, colSpacing = 4, unitsPerColumn = 5,
        orientation = "V", scale = 1,
        showSolo = true, showParty = true, showRaid = true, showPlayer = true,
        classColor = true, showName = true,
        fontSize = 11, bgAlpha = 0.6, texture = 1,
        healthText = "cur", showPct = true, textPos = "B",
        showPower = true, showPowerText = true, powerHeight = 8, powerPos = "B",
        showHealPred = true,
        showPets = true, petPos = "B",
        rangeFade = true, rangeAlpha = 0.4, rangeSpell = "",
        showMinimap = true,
        auraTooltips = true,
        showRole = true, roleSize = 12, rolePos = "TOPLEFT", roleHideDps = false,
        showMarker = true, markerSize = 14, markerPos = "LEFT", markerX = 0, markerY = 0,
        petWidth = 64, petHeight = 22, petFontSize = 9,
        petShowPower = false, petAuras = false, petHealthText = "none", petShowPct = false,
        dispelHighlight = true, dispelFrame = true, dispelFirst = true,
        dispel = { Magic = false, Curse = false, Disease = false, Poison = false },
        buff = { show = true, only = false, size = 14, max = 4, anchor = "BOTTOMLEFT", x = 2, y = 2, grow = "RIGHT", white = "", black = "" },
        debuff = { show = true, only = false, size = 16, max = 4, anchor = "TOPRIGHT", x = -2, y = -2, grow = "LEFT", white = "", black = "" },
        hot = { show = true, size = 14, max = 5, anchor = "BOTTOMRIGHT", x = -2, y = 2, grow = "LEFT", white = "", black = "", useClass = true, separate = true, swipe = true, numbers = false },
    },
}

local header, petHeader, mover

function ns.Print(msg)
    print("|cff66ccffMiHealBot:|r " .. msg)
end

function ns.DeepCopy(t)
    local c = {}
    for k, v in pairs(t) do
        if type(v) == "table" then c[k] = ns.DeepCopy(v) else c[k] = v end
    end
    return c
end

local function MergeDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            MergeDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

-- Tipos de debufo que cada clase suele poder disipar (ajustable en la pestaña Disipar)
local CLASS_DISPELS = {
    PRIEST = { Magic = true, Disease = true },
    PALADIN = { Magic = true, Poison = true, Disease = true },
    DRUID = { Curse = true, Poison = true, Magic = true },
    SHAMAN = { Curse = true, Magic = true },
    MAGE = { Curse = true },
    MONK = { Magic = true, Poison = true, Disease = true },
    EVOKER = { Poison = true, Magic = true },
    WARLOCK = { Magic = true },
}

function ns.ApplyClassDispels(db)
    local _, class = UnitClass("player")
    local d = CLASS_DISPELS[class] or {}
    for k in pairs(db.opts.dispel) do
        db.opts.dispel[k] = d[k] and true or false
    end
    db.dispelInit = true
end

-- Acceso a opciones con ruta "buff.size"
function ns.GetOpt(path)
    local a, b = path:match("^(%w+)%.(%w+)$")
    if a then return ns.db.opts[a][b] end
    return ns.db.opts[path]
end

function ns.SetOpt(path, value)
    local a, b = path:match("^(%w+)%.(%w+)$")
    if a then ns.db.opts[a][b] = value else ns.db.opts[path] = value end
end

---------------------------------------------------------------------
-- Widget básico (botón) compartido
---------------------------------------------------------------------
function ns.MakeButton(parent, text, w, onclick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, 22)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.15, 0.15, 0.22, 1)
    b.bg = bg
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.15)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("CENTER")
    fs:SetText(text)
    b.text = fs
    b:SetScript("OnClick", onclick)
    function b:SetLabel(t) self.text:SetText(t) end
    return b
end

---------------------------------------------------------------------
-- Click-casting
---------------------------------------------------------------------
local function SetAction(b, prefix, btn, value)
    if value == "target" then
        b:SetAttribute(prefix .. "type" .. btn, "target")
    elseif value == "menu" then
        b:SetAttribute(prefix .. "type" .. btn, "togglemenu")
    elseif value:sub(1, 6) == "macro:" then
        b:SetAttribute(prefix .. "type" .. btn, "macro")
        b:SetAttribute(prefix .. "macrotext" .. btn, strtrim(value:sub(7)))
    else
        b:SetAttribute(prefix .. "type" .. btn, "spell")
        b:SetAttribute(prefix .. "spell" .. btn, value)
    end
end

function ns.ApplyBindings(b)
    for _, prefix in pairs(ns.MODS) do
        for btn = 1, 5 do
            b:SetAttribute(prefix .. "type" .. btn, nil)
            b:SetAttribute(prefix .. "spell" .. btn, nil)
            b:SetAttribute(prefix .. "macrotext" .. btn, nil)
        end
    end
    for key, value in pairs(ns.db.bindings) do
        local mod, btn = key:match("^(%a+):(%d)$")
        if mod and ns.MODS[mod] then
            SetAction(b, ns.MODS[mod], btn, value)
        end
    end
end

function ns.ApplyAllBindings()
    if InCombatLockdown() then
        ns.pendingApply = true
        return
    end
    for b in pairs(ns.buttons) do
        ns.ApplyBindings(b)
    end
end

---------------------------------------------------------------------
-- Cabeceras (jugadores y mascotas) y diseño
---------------------------------------------------------------------
local function SetupHeader(h, isPet)
    local o = ns.db.opts
    local show = (not isPet) or o.showPets
    h:SetAttribute("showSolo", (o.showSolo and show) and true or false)
    h:SetAttribute("showParty", (o.showParty and show) and true or false)
    h:SetAttribute("showRaid", (o.showRaid and show) and true or false)
    h:SetAttribute("showPlayer", o.showPlayer and true or false)

    if o.orientation == "H" then
        h:SetAttribute("point", "LEFT")
        h:SetAttribute("xOffset", o.spacing)
        h:SetAttribute("yOffset", 0)
        h:SetAttribute("columnAnchorPoint", "TOP")
    else
        h:SetAttribute("point", "TOP")
        h:SetAttribute("xOffset", 0)
        h:SetAttribute("yOffset", -o.spacing)
        h:SetAttribute("columnAnchorPoint", "LEFT")
    end
    h:SetAttribute("columnSpacing", o.colSpacing)
    h:SetAttribute("unitsPerColumn", o.unitsPerColumn)
    h:SetAttribute("maxColumns", math.ceil(40 / o.unitsPerColumn))
    h:SetScale(o.scale)
    h:SetAttribute("mhbRefresh", GetTime())
end

function ns.ApplyLayout()
    if ns.RefreshPreview then ns.RefreshPreview() end
    if ns.UpdateMinimap then ns.UpdateMinimap() end
    if not header then return end
    if InCombatLockdown() then
        ns.pendingLayout = true
        return
    end
    local o = ns.db.opts

    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", UIParent, "TOPLEFT", ns.db.left, ns.db.top)

    -- primero estilo de los botones existentes (tamaños), luego la cabecera los recoloca
    for b in pairs(ns.buttons) do
        ns.StyleFrame(b)
    end
    SetupHeader(header, false)

    petHeader:ClearAllPoints()
    if o.petPos == "R" then
        petHeader:SetPoint("TOPLEFT", header, "TOPRIGHT", 10, 0)
    else
        petHeader:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -10)
    end
    SetupHeader(petHeader, true)

    for b in pairs(ns.buttons) do
        ns.UpdateButton(b)
    end
end
ns.OptionsChanged = ns.ApplyLayout

local function CreateHeaders()
    header = CreateFrame("Frame", "MiHealBotHeader", UIParent, "SecureGroupHeaderTemplate")
    header:SetAttribute("template", "MiHealBotUnitTemplate")
    header:SetAttribute("templateType", "Button")
    header:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")
    header:SetAttribute("groupBy", "GROUP")
    header:SetAttribute("groupingOrder", "1,2,3,4,5,6,7,8")
    header:SetMovable(true)
    header:SetPoint("TOPLEFT", UIParent, "TOPLEFT", ns.db.left, ns.db.top)
    header:Show()

    petHeader = CreateFrame("Frame", "MiHealBotPetHeader", UIParent, "SecureGroupPetHeaderTemplate")
    petHeader:SetAttribute("template", "MiHealBotUnitTemplate")
    petHeader:SetAttribute("templateType", "Button")
    petHeader:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")
    petHeader:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -10)
    petHeader:Show()

    mover = CreateFrame("Frame", nil, UIParent)
    mover:SetSize(90, 14)
    mover:SetPoint("BOTTOMLEFT", header, "TOPLEFT", 0, 2)
    local t = mover:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(0.2, 0.5, 1, 0.8)
    local fs = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("CENTER")
    fs:SetText("Mover")
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", function()
        if not InCombatLockdown() then header:StartMoving() end
    end)
    mover:SetScript("OnDragStop", function()
        header:StopMovingOrSizing()
        local s = header:GetEffectiveScale()
        ns.db.left = header:GetLeft()
        ns.db.top = header:GetTop() - UIParent:GetTop() * UIParent:GetEffectiveScale() / s
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", UIParent, "TOPLEFT", ns.db.left, ns.db.top)
    end)
    mover:Hide()
end

function ns.ToggleMover()
    if not mover then return end
    mover:SetShown(not mover:IsShown())
end

---------------------------------------------------------------------
-- Comandos
---------------------------------------------------------------------
local function yn(v) return v and "sí" or "NO" end

SlashCmdList["MIHEALBOT"] = function(msg)
    local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()

    if cmd == "" or cmd == "config" or cmd == "options" then
        ns.ToggleOptions()
    elseif cmd == "preview" then
        ns.TogglePreview()
    elseif cmd == "bind" then
        local btn, mod, action = rest:match("^(%d)%s+(%a+)%s+(.+)$")
        mod = mod and mod:lower()
        if not btn or not ns.MODS[mod] or tonumber(btn) < 1 or tonumber(btn) > 5 then
            ns.Print("Uso: /mhb bind <botón 1-5> <none|shift|ctrl|alt> <hechizo | target | menu | macro:texto>")
            return
        end
        ns.db.bindings[mod .. ":" .. btn] = action
        ns.ApplyAllBindings()
        ns.Print("Asignado " .. mod .. " + botón " .. btn .. " = " .. action)
    elseif cmd == "clear" then
        local btn, mod = rest:match("^(%d)%s+(%a+)$")
        mod = mod and mod:lower()
        if not btn or not ns.MODS[mod] then
            ns.Print("Uso: /mhb clear <botón 1-5> <none|shift|ctrl|alt>")
            return
        end
        ns.db.bindings[mod .. ":" .. btn] = nil
        ns.ApplyAllBindings()
        ns.Print("Borrado " .. mod .. " + botón " .. btn)
    elseif cmd == "list" then
        local keys = {}
        for k in pairs(ns.db.bindings) do keys[#keys + 1] = k end
        table.sort(keys)
        for _, k in ipairs(keys) do ns.Print(k .. " = " .. ns.db.bindings[k]) end
    elseif cmd == "unlock" then
        if mover then mover:Show() end
    elseif cmd == "lock" then
        if mover then mover:Hide() end
    elseif cmd == "reset" then
        ns.db.bindings = ns.DeepCopy(ns.defaults.bindings)
        ns.ApplyAllBindings()
        ns.Print("Asignaciones restauradas")
    elseif cmd == "debug" then
        ns.Print("APIs disponibles:")
        ns.Print("UnitGetIncomingHeals: " .. yn(UnitGetIncomingHeals))
        ns.Print("CreateUnitHealPredictionCalculator: " .. yn(CreateUnitHealPredictionCalculator))
        ns.Print("C_UnitAuras.GetAuraDataByIndex: " .. yn(C_UnitAuras and C_UnitAuras.GetAuraDataByIndex))
        ns.Print("C_UnitAuras.GetAuraDuration: " .. yn(C_UnitAuras and C_UnitAuras.GetAuraDuration))
        ns.Print("UnitHealthPercent: " .. yn(UnitHealthPercent))
        ns.Print("AbbreviateNumbers: " .. yn(AbbreviateNumbers))
        ns.Print("C_Spell.IsSpellInRange: " .. yn(C_Spell and C_Spell.IsSpellInRange))
        ns.Print("Region:SetAlphaFromBoolean: " .. yn(UIParent.SetAlphaFromBoolean))
        ns.Print("UnitGroupRolesAssigned: " .. yn(UnitGroupRolesAssigned))
        ns.Print("C_UnitAuras.IsAuraFilteredOutByInstanceID: " .. yn(C_UnitAuras and C_UnitAuras.IsAuraFilteredOutByInstanceID))
        ns.Print("GameTooltip.SetUnitBuffByAuraInstanceID: " .. yn(GameTooltip.SetUnitBuffByAuraInstanceID))
        ns.Print("GameTooltip.SetUnitAura: " .. yn(GameTooltip.SetUnitAura))
        local n = 0
        for tag, err in pairs(ns.errs) do
            n = n + 1
            ns.Print("|cffff5555Error en " .. tag .. ":|r " .. tostring(err))
        end
        if n == 0 then ns.Print("Sin errores registrados.") end
    else
        ns.Print("Comandos: /mhb (opciones), preview, bind, clear, list, unlock, lock, reset, debug")
    end
end
SLASH_MIHEALBOT1 = "/mhb"

---------------------------------------------------------------------
-- Inicio
---------------------------------------------------------------------
-- Las cabeceras seguras no siempre crean el marco del jugador a tiempo al iniciar sesión:
-- se vuelve a aplicar el diseño poco después de entrar al mundo y al cambiar el grupo.
local refreshQueued = false
function ns.ScheduleRefresh(delay)
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(delay or 0.5, function()
        refreshQueued = false
        if InCombatLockdown() then
            ns.pendingLayout = true
            return
        end
        ns.ApplyLayout()
    end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        MiHealBotDB = MiHealBotDB or {}
        local db = MiHealBotDB
        if db.bindings == nil then db.bindings = ns.DeepCopy(ns.defaults.bindings) end
        if db.left == nil then db.left = ns.defaults.left end
        if db.top == nil then db.top = ns.defaults.top end
        if db.minimapAngle == nil then db.minimapAngle = ns.defaults.minimapAngle end
        if type(db.opts) ~= "table" then db.opts = {} end
        local oo = db.opts
        -- migración de versiones anteriores (texto de vida y altura del recurso)
        if oo.healthText == "num" then
            oo.healthText = "cur"; oo.showPct = false
        elseif oo.healthText == "pct" then
            oo.healthText = "none"; oo.showPct = true
        elseif oo.healthText == "both" then
            oo.healthText = "cur"; oo.showPct = true
        elseif oo.healthText == "none" and oo.showPct == nil then
            oo.showPct = false
        end
        if (db.ver or 0) < 4 then
            if oo.powerHeight == 4 then oo.powerHeight = 8 end
            db.ver = 4
        end
        MergeDefaults(db.opts, ns.defaults.opts)
        if not db.dispelInit then ns.ApplyClassDispels(db) end
        ns.db = db
        CreateHeaders()
        ns.ApplyLayout()
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if ns.db then
            ns.ScheduleRefresh(0.3)
            C_Timer.After(2, function()
                if not InCombatLockdown() then ns.ApplyLayout() end
            end)
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if ns.db then ns.ScheduleRefresh(0.2) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if ns.pendingApply then
            ns.pendingApply = false
            ns.ApplyAllBindings()
        end
        if ns.pendingLayout then
            ns.pendingLayout = false
            ns.ApplyLayout()
        end
    end
end)
