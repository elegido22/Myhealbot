-- MiHealBot v0.4 - Aspecto y actualización de cada marco
-- (vida, textos, recursos, curación prevista, rol, bufos / debufos / HoTs con tooltip, disipables, rango)
local addonName, ns = ...

local PET_COLOR = { 0.6, 0.8, 0.3 }
local KINDS = { "hot", "buff", "debuff" }

-- Ejecuta una función protegida; guarda el primer error de cada etiqueta (ver /mhb debug)
local function Safe(tag, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and not ns.errs[tag] then ns.errs[tag] = err end
end
ns.Safe = Safe

-- Valores efectivos según sea marco de jugador o de mascota
-- devuelve: ancho, alto, fuente, mostrarRecurso, textoVida, mostrarAuras, mostrarPorcentaje
local function Cfg(f)
    local o = ns.db.opts
    if f.isPet then
        return o.petWidth, o.petHeight, o.petFontSize, o.petShowPower, o.petHealthText, o.petAuras, o.petShowPct
    end
    return o.width, o.height, o.fontSize, o.showPower, o.healthText, true, o.showPct
end

---------------------------------------------------------------------
-- Iconos de rol
---------------------------------------------------------------------
local ROLE_ATLAS = { TANK = "roleicon-tiny-tank", HEALER = "roleicon-tiny-healer", DAMAGER = "roleicon-tiny-dps" }
local ROLE_COORDS = {
    TANK = { 0, 19 / 64, 22 / 64, 41 / 64 },
    HEALER = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
    DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
}

function ns.SetRoleTexture(tex, role)
    if not role or not ROLE_COORDS[role] then
        tex:Hide()
        return
    end
    local atlas = ROLE_ATLAS[role]
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        tex:SetAtlas(atlas)
        tex:SetTexCoord(0, 1, 0, 1)
    else
        tex:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        tex:SetTexCoord(unpack(ROLE_COORDS[role]))
    end
    tex:Show()
end

local function UpdateRole(f, unit)
    local o = ns.db.opts
    if f.isPet or not o.showRole then
        f.role:Hide()
        return
    end
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
    if (not role or role == "NONE") and UnitIsUnit(unit, "player") and GetSpecialization and GetSpecializationRole then
        local spec = GetSpecialization()
        if spec then role = GetSpecializationRole(spec) end
    end
    if role == "DAMAGER" and o.roleHideDps then role = nil end
    ns.SetRoleTexture(f.role, role)
end

---------------------------------------------------------------------
-- Iconos de auras (solo icono + número de acumulaciones; el tiempo se ve en el tooltip)
---------------------------------------------------------------------
function ns.SetIconBorder(icon, r, g, b, bw)
    icon.border:ClearAllPoints()
    icon.border:SetPoint("TOPLEFT", -bw, bw)
    icon.border:SetPoint("BOTTOMRIGHT", bw, -bw)
    icon.border:SetColorTexture(r, g, b, 1)
end

local function IconOnEnter(self)
    if not ns.db.opts.auraTooltips then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local ok = false
    if self.fakeSpell then
        ok = pcall(GameTooltip.SetSpellByID, GameTooltip, self.fakeSpell)
    elseif self.unit then
        local helpful = (self.kind ~= "debuff")
        if self.auraID then
            if helpful and GameTooltip.SetUnitBuffByAuraInstanceID then
                ok = pcall(GameTooltip.SetUnitBuffByAuraInstanceID, GameTooltip, self.unit, self.auraID, self.filter)
            elseif not helpful and GameTooltip.SetUnitDebuffByAuraInstanceID then
                ok = pcall(GameTooltip.SetUnitDebuffByAuraInstanceID, GameTooltip, self.unit, self.auraID, self.filter)
            end
        end
        if not ok and GameTooltip.SetUnitAura and self.index then
            ok = pcall(GameTooltip.SetUnitAura, GameTooltip, self.unit, self.index, self.filter)
        end
    end
    if ok then GameTooltip:Show() else GameTooltip:Hide() end
end

local function IconOnLeave()
    GameTooltip:Hide()
end

local function GetAuraIcon(f, kind, i)
    local icon = f.auras[kind][i]
    if icon then return icon end
    icon = CreateFrame("Frame", nil, f.overlay)
    icon:SetFrameLevel(f.overlay:GetFrameLevel() + 2)
    icon.border = icon:CreateTexture(nil, "BACKGROUND")
    icon.border:SetPoint("TOPLEFT", -1, 1)
    icon.border:SetPoint("BOTTOMRIGHT", 1, -1)
    icon.border:SetColorTexture(0, 0, 0, 1)
    icon.tex = icon:CreateTexture(nil, "ARTWORK")
    icon.tex:SetAllPoints()
    icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- solo los HoTs llevan espiral de tiempo (sentido horario, sin quitar el icono)
    if kind == "hot" then
        icon.cd = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
        icon.cd:SetAllPoints()
        icon.cd:SetReverse(true)
        if icon.cd.SetDrawEdge then icon.cd:SetDrawEdge(false) end
        if icon.cd.SetDrawBling then icon.cd:SetDrawBling(false) end
    end
    -- el número de acumulaciones va en un marco superior para que la espiral no lo tape
    local top = CreateFrame("Frame", nil, icon)
    top:SetAllPoints()
    top:SetFrameLevel(icon:GetFrameLevel() + 3)
    icon.count = top:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    icon.count:SetPoint("BOTTOMRIGHT", 1, 0)
    icon.kind = kind
    icon:SetScript("OnEnter", IconOnEnter)
    icon:SetScript("OnLeave", IconOnLeave)
    -- que el clic atraviese el icono hacia el marco (click-casting)
    if icon.SetPropagateMouseClicks then pcall(icon.SetPropagateMouseClicks, icon, true) end
    icon:Hide()
    f.auras[kind][i] = icon
    return icon
end
ns.GetAuraIcon = GetAuraIcon

local GROW = {
    RIGHT = { "LEFT", "RIGHT", 1, 0 },
    LEFT = { "RIGHT", "LEFT", -1, 0 },
    UP = { "BOTTOM", "TOP", 0, 1 },
    DOWN = { "TOP", "BOTTOM", 0, -1 },
}

function ns.PlaceAuras(f)
    local o = ns.db.opts
    for _, kind in ipairs(KINDS) do
        local c = o[kind]
        for i = 1, c.max do GetAuraIcon(f, kind, i) end
        local list = f.auras[kind]
        local g = GROW[c.grow] or GROW.RIGHT
        for i = 1, #list do
            local icon = list[i]
            icon:SetSize(c.size, c.size)
            icon:EnableMouse(o.auraTooltips and true or false)
            if icon.cd then
                icon.cd:SetDrawSwipe(c.swipe and true or false)
                icon.cd:SetHideCountdownNumbers(not c.numbers)
                icon.cd:SetShown((c.swipe or c.numbers) and true or false)
            end
            icon:ClearAllPoints()
            if i > c.max then
                icon:Hide()
            elseif i == 1 then
                icon:SetPoint(c.anchor, f, c.anchor, c.x, c.y)
            else
                icon:SetPoint(g[1], list[i - 1], g[2], g[3], g[4])
            end
        end
    end
end

---------------------------------------------------------------------
-- Construcción y estilo
---------------------------------------------------------------------
function ns.BuildVisual(f)
    local tex = ns.TEXTURES[1]
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0, 0, 0.6)

    f.hp = CreateFrame("StatusBar", nil, f)
    f.hp:SetStatusBarTexture(tex)
    f.hp:SetMinMaxValues(0, 1)
    f.hp:SetValue(1)
    if f.hp.SetClipsChildren then f.hp:SetClipsChildren(true) end

    f.heal = CreateFrame("StatusBar", nil, f.hp)
    f.heal:SetStatusBarTexture(tex)
    f.heal:SetStatusBarColor(0.3, 1, 0.5, 0.6)
    f.heal:SetMinMaxValues(0, 1)
    f.heal:SetValue(0)

    f.power = CreateFrame("StatusBar", nil, f)
    f.power:SetStatusBarTexture(tex)
    f.power:SetMinMaxValues(0, 1)
    f.power:SetValue(1)

    f.overlay = CreateFrame("Frame", nil, f)
    f.overlay:SetAllPoints()
    f.overlay:SetFrameLevel(f:GetFrameLevel() + 10)

    f.nameText = f.overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.nameText:SetWordWrap(false)
    f.numText = f.overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.pctText = f.overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.powerText = f.overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

    f.role = f.overlay:CreateTexture(nil, "OVERLAY")
    f.role:Hide()

    -- marcador de objetivo (calavera, cruz, cuadrado, luna...)
    f.marker = f.overlay:CreateTexture(nil, "OVERLAY")
    f.marker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    f.marker:Hide()

    -- borde resaltado del marco (debufos disipables)
    f.edge = {}
    for i = 1, 4 do
        f.edge[i] = f.overlay:CreateTexture(nil, "OVERLAY")
        f.edge[i]:Hide()
    end
    f.edge[1]:SetPoint("TOPLEFT"); f.edge[1]:SetPoint("TOPRIGHT"); f.edge[1]:SetHeight(2)
    f.edge[2]:SetPoint("BOTTOMLEFT"); f.edge[2]:SetPoint("BOTTOMRIGHT"); f.edge[2]:SetHeight(2)
    f.edge[3]:SetPoint("TOPLEFT"); f.edge[3]:SetPoint("BOTTOMLEFT"); f.edge[3]:SetWidth(2)
    f.edge[4]:SetPoint("TOPRIGHT"); f.edge[4]:SetPoint("BOTTOMRIGHT"); f.edge[4]:SetWidth(2)

    f.auras = { hot = {}, buff = {}, debuff = {} }
end

function ns.SetEdge(f, r, g, b)
    for i = 1, 4 do
        if r then
            f.edge[i]:SetColorTexture(r, g, b, 1)
            f.edge[i]:Show()
        else
            f.edge[i]:Hide()
        end
    end
end

local function Inset(anchor)
    local dx, dy = 0, 0
    if anchor:find("LEFT") then dx = 2 elseif anchor:find("RIGHT") then dx = -2 end
    if anchor:find("TOP") then dy = -2 elseif anchor:find("BOTTOM") then dy = 2 end
    return dx, dy
end

function ns.LayoutVisual(f)
    local o = ns.db.opts
    local w, _, _, showPower, mode, _, showPct = Cfg(f)
    local ph = f.isPet and math.min(o.powerHeight, 6) or o.powerHeight
    if not showPower then ph = 0 end

    f.hp:ClearAllPoints()
    f.power:ClearAllPoints()
    if showPower then
        f.power:Show()
        f.power:SetHeight(ph)
        if o.powerPos == "T" then
            f.power:SetPoint("TOPLEFT", 1, -1)
            f.power:SetPoint("TOPRIGHT", -1, -1)
            f.hp:SetPoint("TOPLEFT", 1, -(ph + 2))
            f.hp:SetPoint("BOTTOMRIGHT", -1, 1)
        else
            f.power:SetPoint("BOTTOMLEFT", 1, 1)
            f.power:SetPoint("BOTTOMRIGHT", -1, 1)
            f.hp:SetPoint("TOPLEFT", 1, -1)
            f.hp:SetPoint("BOTTOMRIGHT", -1, ph + 2)
        end
    else
        f.power:Hide()
        f.hp:SetPoint("TOPLEFT", 1, -1)
        f.hp:SetPoint("BOTTOMRIGHT", -1, 1)
    end

    -- % del recurso, centrado sobre la barra de recursos
    f.powerText:ClearAllPoints()
    f.powerText:SetPoint("CENTER", f.power, "CENTER", 0, 0)
    f.powerText:SetFont(STANDARD_TEXT_FONT, math.max(6, math.min(11, ph - 1)), "OUTLINE")
    f.powerText:SetShown(showPower and o.showPowerText and true or false)

    -- barra de curación prevista: arranca donde acaba la vida actual
    local tex = f.hp:GetStatusBarTexture()
    f.heal:ClearAllPoints()
    f.heal:SetPoint("TOPLEFT", tex, "TOPRIGHT")
    f.heal:SetPoint("BOTTOMLEFT", tex, "BOTTOMRIGHT")
    f.heal:SetWidth(math.max(1, w - 2))

    -- textos de nombre y vida
    local up = (o.textPos == "T")
    f.nameText:ClearAllPoints()
    f.nameText:SetPoint(up and "BOTTOM" or "TOP", f.hp, up and "BOTTOM" or "TOP", 0, up and 3 or -3)
    f.numText:ClearAllPoints()
    f.pctText:ClearAllPoints()
    if o.textPos == "T" then
        f.numText:SetPoint("TOPLEFT", f.hp, "TOPLEFT", 3, -3)
        f.pctText:SetPoint("TOPRIGHT", f.hp, "TOPRIGHT", -3, -3)
    elseif o.textPos == "C" then
        f.numText:SetPoint("CENTER", f.hp, "CENTER", -w / 4, -4)
        f.pctText:SetPoint("CENTER", f.hp, "CENTER", w / 4, -4)
    else
        f.numText:SetPoint("BOTTOMLEFT", f.hp, "BOTTOMLEFT", 3, 3)
        f.pctText:SetPoint("BOTTOMRIGHT", f.hp, "BOTTOMRIGHT", -3, 3)
    end
    f.numText:SetShown(mode == "cur" or mode == "curmax")
    f.pctText:SetShown(showPct and true or false)

    -- icono de rol
    f.role:ClearAllPoints()
    if f.isPet or not o.showRole then
        f.role:Hide()
    else
        f.role:SetSize(o.roleSize, o.roleSize)
        local dx, dy = Inset(o.rolePos)
        f.role:SetPoint(o.rolePos, f.hp, o.rolePos, dx, dy)
    end

    -- marcador de objetivo
    f.marker:ClearAllPoints()
    if not o.showMarker then
        f.marker:Hide()
    else
        f.marker:SetSize(o.markerSize, o.markerSize)
        local mx, my = Inset(o.markerPos)
        f.marker:SetPoint(o.markerPos, f.hp, o.markerPos, mx + o.markerX, my + o.markerY)
    end

    ns.PlaceAuras(f)
end

function ns.StyleFrame(f)
    local o = ns.db.opts
    local w, h, fontSize = Cfg(f)
    if not (InCombatLockdown() and f:IsProtected()) then
        f:SetSize(w, h)
    end
    f.bg:SetColorTexture(0, 0, 0, o.bgAlpha)
    local tex = ns.TEXTURES[o.texture] or ns.TEXTURES[1]
    f.hp:SetStatusBarTexture(tex)
    f.heal:SetStatusBarTexture(tex)
    f.heal:SetStatusBarColor(0.3, 1, 0.5, 0.6)
    f.power:SetStatusBarTexture(tex)

    local font = STANDARD_TEXT_FONT
    f.nameText:SetFont(font, fontSize, "OUTLINE")
    f.nameText:SetWidth(math.max(10, w - 4))
    f.nameText:SetShown(o.showName)
    local small = math.max(7, fontSize - 1)
    f.numText:SetFont(font, small, "OUTLINE")
    f.pctText:SetFont(font, small, "OUTLINE")
    ns.LayoutVisual(f)
end

function ns.ColorBar(f, class)
    local c = ns.db.opts.classColor and class and RAID_CLASS_COLORS[class]
    if c then
        f.hp:SetStatusBarColor(c.r, c.g, c.b)
    else
        f.hp:SetStatusBarColor(0.1, 0.7, 0.2)
    end
end

---------------------------------------------------------------------
-- Actualizaciones
---------------------------------------------------------------------
local function ShortNum(n)
    if n >= 1000000 then return string.format("%.1fM", n / 1000000)
    elseif n >= 10000 then return string.format("%.1fk", n / 1000) end
    return tostring(math.floor(n))
end

local function UpdateName(f, unit)
    f.nameText:SetText(UnitName(unit))
end

local function UpdateColor(f, unit)
    if unit:find("pet") then
        f.hp:SetStatusBarColor(PET_COLOR[1], PET_COLOR[2], PET_COLOR[3])
    else
        local _, class = UnitClass(unit)
        ns.ColorBar(f, class)
    end
end

-- Texto de vida: "345" o "345/500" (según opción) y, aparte, el %
local function UpdateHealthText(f, unit)
    local _, _, _, _, mode, _, showPct = Cfg(f)
    if mode == "none" and not showPct then return end
    local ok = pcall(function()
        local hp, mx = UnitHealth(unit), UnitHealthMax(unit)
        if mode == "curmax" then
            f.numText:SetText(ShortNum(hp) .. "/" .. ShortNum(mx))
        else
            f.numText:SetText(ShortNum(hp))
        end
        local pct = (mx > 0) and math.floor(hp / mx * 100 + 0.5) or 0
        f.pctText:SetText(pct .. "%")
    end)
    if ok then return end
    -- valores restringidos en combate: formato alternativo
    pcall(function()
        if AbbreviateNumbers then
            if mode == "curmax" then
                f.numText:SetFormattedText("%s/%s", AbbreviateNumbers(UnitHealth(unit)), AbbreviateNumbers(UnitHealthMax(unit)))
            else
                f.numText:SetText(AbbreviateNumbers(UnitHealth(unit)))
            end
        end
    end)
    pcall(function()
        if UnitHealthPercent then
            local scale = CurveConstants and CurveConstants.ScaleTo100
            f.pctText:SetFormattedText("%d%%", UnitHealthPercent(unit, true, scale))
        end
    end)
end

local function GetIncoming(unit)
    if CreateUnitHealPredictionCalculator and UnitGetDetailedHealPrediction then
        ns.calc = ns.calc or CreateUnitHealPredictionCalculator()
        UnitGetDetailedHealPrediction(unit, "player", ns.calc)
        local v = ns.calc:GetIncomingHeals()
        if v then return v end
    end
    if UnitGetIncomingHeals then
        return UnitGetIncomingHeals(unit, "player")
    end
end

local function UpdateHeal(f, unit)
    if not ns.db.opts.showHealPred then
        f.heal:Hide()
        return
    end
    local incoming = GetIncoming(unit)
    f.heal:SetMinMaxValues(0, UnitHealthMax(unit))
    f.heal:SetValue(incoming or 0)
    f.heal:Show()
end

local function UpdateHealth(f, unit)
    f.hp:SetMinMaxValues(0, UnitHealthMax(unit))
    f.hp:SetValue(UnitHealth(unit))
    Safe("textoVida", UpdateHealthText, f, unit)
    Safe("curacionPrevista", UpdateHeal, f, unit)
end

-- Recurso: barra + texto con el % (sobre la propia barra)
local function UpdatePower(f, unit)
    local _, _, _, showPower = Cfg(f)
    if not showPower then return end
    local ptype, token = UnitPowerType(unit)
    local c = (token and PowerBarColor[token]) or PowerBarColor[ptype] or { r = 0.2, g = 0.4, b = 0.9 }
    f.power:SetStatusBarColor(c.r, c.g, c.b)
    local mx = UnitPowerMax(unit, ptype)
    local cur = UnitPower(unit, ptype)
    f.power:SetMinMaxValues(0, mx)
    f.power:SetValue(cur)
    if not ns.db.opts.showPowerText then return end
    local ok = pcall(function()
        if mx > 0 then
            f.powerText:SetText(math.floor(cur / mx * 100 + 0.5) .. "%")
        else
            f.powerText:SetText("")
        end
    end)
    if not ok then
        pcall(function()
            if UnitPowerPercent then
                local scale = CurveConstants and CurveConstants.ScaleTo100
                f.powerText:SetFormattedText("%d%%", UnitPowerPercent(unit, ptype, false, scale))
            end
        end)
    end
end

---------------------------------------------------------------------
-- Filtros de auras (listas separadas por comas, nombres o IDs)
---------------------------------------------------------------------
local function ParseList(str)
    if not str or strtrim(str) == "" then return nil end
    local set, any = {}, false
    for item in string.gmatch(str, "[^,;]+") do
        item = strtrim(item)
        if item ~= "" then
            set[tonumber(item) or strlower(item)] = true
            any = true
        end
    end
    return any and set or nil
end

local function GetSets(kind)
    local c = ns.db.opts[kind]
    local cache = ns.auraSets[kind]
    if not cache or cache.w ~= c.white or cache.b ~= c.black then
        cache = { w = c.white, b = c.black, white = ParseList(c.white), black = ParseList(c.black) }
        ns.auraSets[kind] = cache
    end
    return cache.white, cache.black
end

-- HoTs conocidos por clase (se convierten a nombres en el idioma del cliente)
local CLASS_HOTS = {
    DRUID = { 774, 8936, 33763, 48438, 155777 },
    PRIEST = { 139, 194384, 41635 },
    SHAMAN = { 61295, 974 },
    PALADIN = { 156322, 53563 },
    MONK = { 119611, 124682, 115175 },
    EVOKER = { 366155, 364343, 355941 },
}

local function SpellNameOf(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if GetSpellInfo then return (GetSpellInfo(id)) end
end

local function GetHotSet()
    local c = ns.db.opts.hot
    local cache = ns.auraSets.hot
    if not cache or cache.w ~= c.white or cache.b ~= c.black or cache.u ~= c.useClass or cache.n == 0 then
        local set, n = {}, 0
        local user = ParseList(c.white)
        if user then
            for k in pairs(user) do set[k] = true; n = n + 1 end
        end
        if c.useClass then
            local _, class = UnitClass("player")
            for _, id in ipairs(CLASS_HOTS[class] or {}) do
                local nm = SpellNameOf(id)
                if nm then
                    set[strlower(nm)] = true
                    set[id] = true
                    n = n + 1
                end
            end
        end
        cache = { w = c.white, b = c.black, u = c.useClass, n = n,
                  set = (n > 0) and set or nil, black = ParseList(c.black) }
        ns.auraSets.hot = cache
    end
    return cache.set, cache.black
end

local function InSet(set, data)
    local ok, res = pcall(function()
        local nm = data.name and strlower(data.name)
        return (set[nm] or set[data.spellId]) and true or false
    end)
    return ok and res
end

local function IsMine(data)
    local ok, res = pcall(function()
        return data.sourceUnit and UnitIsUnit(data.sourceUnit, "player") and true or false
    end)
    return ok and res
end

local function PassesLists(data, white, black)
    if not white and not black then return true end
    local ok, pass = pcall(function()
        local nm = data.name and strlower(data.name)
        local id = data.spellId
        if black and (black[nm] or black[id]) then return false end
        if white and not (white[nm] or white[id]) then return false end
        return true
    end)
    if not ok then return true end
    return pass
end

---------------------------------------------------------------------
-- Disipables
---------------------------------------------------------------------
-- ¿Puedo disipar este debufo? Primero por tipo (lista de la pestaña Disipar);
-- si el tipo está restringido, se intenta con el filtro nativo del juego.
local function IsDispellable(unit, data)
    local result = false
    local ok = pcall(function()
        local dn = data.dispelName
        if dn and dn ~= "" and ns.db.opts.dispel[dn] then result = true end
    end)
    if not ok then
        pcall(function()
            if C_UnitAuras.IsAuraFilteredOutByInstanceID then
                local out = C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, data.auraInstanceID, "HARMFUL|RAID_PLAYER_DISPELLABLE")
                if out == false then result = true end
            end
        end)
    end
    return result
end

local function DispelColor(data)
    local r, g, b, found = 1, 0.3, 0.3, false
    pcall(function()
        local col = data.dispelName and DebuffTypeColor and DebuffTypeColor[data.dispelName]
        if col then r, g, b, found = col.r, col.g, col.b, true end
    end)
    return r, g, b, found
end

local function SetupIcon(icon, unit, data, kind, index, filter, disp)
    icon.unit, icon.auraID, icon.index, icon.filter, icon.kind = unit, data.auraInstanceID, index, filter, kind
    icon.fakeSpell = nil
    icon.tex:SetTexture(data.icon)
    if icon.cd then
        pcall(function()
            local dur = C_UnitAuras.GetAuraDuration and C_UnitAuras.GetAuraDuration(unit, data.auraInstanceID)
            if dur and icon.cd.SetCooldownFromDurationObject then
                icon.cd:SetCooldownFromDurationObject(dur)
            elseif data.duration and data.duration > 0 then
                icon.cd:SetCooldown(data.expirationTime - data.duration, data.duration)
            else
                icon.cd:Clear()
            end
        end)
    end
    pcall(function()
        if C_UnitAuras.GetAuraApplicationDisplayCount then
            icon.count:SetText(C_UnitAuras.GetAuraApplicationDisplayCount(unit, data.auraInstanceID, 2))
        elseif data.applications and data.applications > 1 then
            icon.count:SetText(data.applications)
        else
            icon.count:SetText("")
        end
    end)
    local r, g, b = 0, 0, 0
    if kind == "debuff" then
        local found
        r, g, b, found = DispelColor(data)
        if not found and not disp then r, g, b = 0, 0, 0 end
    end
    ns.SetIconBorder(icon, r, g, b, disp and 3 or 1)
    icon:Show()
end

local function UpdateAuras(f, unit)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
    local o = ns.db.opts
    local _, _, _, _, _, showAuras = Cfg(f)
    local edge
    for _, kind in ipairs(KINDS) do
        local c = o[kind]
        local list = f.auras[kind]
        local shown = 0
        if c.show and showAuras then
            local isDebuff = (kind == "debuff")
            local filter, white, black, hotSet
            if kind == "hot" then
                filter = "HELPFUL|PLAYER"
                white, black = GetHotSet()
            elseif isDebuff then
                filter = c.only and "HARMFUL|RAID" or "HARMFUL"
                white, black = GetSets(kind)
            else
                filter = c.only and "HELPFUL|PLAYER" or "HELPFUL"
                white, black = GetSets(kind)
                if o.hot.show and o.hot.separate then hotSet = GetHotSet() end
            end
            local entries, disp = {}, {}
            local i = 1
            while i <= 40 do
                local data = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
                if not data then break end
                local pass = PassesLists(data, white, black)
                if pass and hotSet and IsMine(data) and InSet(hotSet, data) then pass = false end
                if pass then
                    local d = isDebuff and o.dispelHighlight and IsDispellable(unit, data)
                    local e = { data = data, index = i, disp = d and true or false }
                    entries[#entries + 1] = e
                    if d then disp[#disp + 1] = e end
                end
                i = i + 1
                if not isDebuff and #entries >= c.max then break end
            end
            local ordered = entries
            if isDebuff and o.dispelFirst and #disp > 0 then
                ordered = {}
                for _, e in ipairs(disp) do ordered[#ordered + 1] = e end
                for _, e in ipairs(entries) do
                    if not e.disp then ordered[#ordered + 1] = e end
                end
            end
            for _, e in ipairs(ordered) do
                if shown >= c.max then break end
                shown = shown + 1
                SetupIcon(GetAuraIcon(f, kind, shown), unit, e.data, kind, e.index, filter, e.disp)
            end
            if isDebuff and o.dispelFrame and #disp > 0 then
                edge = { DispelColor(disp[1].data) }
            end
        end
        for j = shown + 1, #list do list[j]:Hide() end
    end
    if edge then
        ns.SetEdge(f, edge[1], edge[2], edge[3])
    else
        ns.SetEdge(f, nil)
    end
end

---------------------------------------------------------------------
-- Rango
---------------------------------------------------------------------
local function UpdateRange(f, unit)
    local o = ns.db.opts
    if not unit then return end
    if not o.rangeFade then
        f:SetAlpha(1)
        return
    end
    local a = o.rangeAlpha
    local spell = o.rangeSpell or ""
    local ok = pcall(function()
        local r
        if UnitIsUnit(unit, "player") then
            r = true
        elseif not UnitIsConnected(unit) then
            r = false
        else
            if spell ~= "" then
                if C_Spell and C_Spell.IsSpellInRange then
                    r = C_Spell.IsSpellInRange(spell, unit)
                elseif IsSpellInRange then
                    local x = IsSpellInRange(spell, unit)
                    if x == 1 then r = true elseif x == 0 then r = false end
                end
            end
            if r == nil then
                local inR, checked = UnitInRange(unit)
                if checked == false then r = true else r = inR end
            end
        end
        f:SetAlpha(r == false and a or 1)
    end)
    if ok then return end
    if f.SetAlphaFromBoolean then
        pcall(function()
            local r2
            if spell ~= "" and C_Spell and C_Spell.IsSpellInRange then
                r2 = C_Spell.IsSpellInRange(spell, unit)
            else
                r2 = UnitInRange(unit)
            end
            f:SetAlphaFromBoolean(r2, 1, a)
        end)
    end
end

---------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------
local function UpdateMarker(f, unit)
    if not ns.db.opts.showMarker then
        f.marker:Hide()
        return
    end
    local idx = GetRaidTargetIndex(unit)
    if idx then
        SetRaidTargetIconTexture(f.marker, idx)
        f.marker:Show()
    else
        f.marker:Hide()
    end
end

local function UpdateAll(f)
    local unit = f:GetAttribute("unit")
    if not unit or not UnitExists(unit) then return end
    Safe("nombre", UpdateName, f, unit)
    Safe("color", UpdateColor, f, unit)
    Safe("vida", UpdateHealth, f, unit)
    Safe("recurso", UpdatePower, f, unit)
    Safe("rol", UpdateRole, f, unit)
    Safe("marcador", UpdateMarker, f, unit)
    Safe("auras", UpdateAuras, f, unit)
    Safe("rango", UpdateRange, f, unit)
end
ns.UpdateButton = UpdateAll

local HANDLERS = {
    UNIT_HEALTH = function(f, u) Safe("vida", UpdateHealth, f, u) end,
    UNIT_MAXHEALTH = function(f, u) Safe("vida", UpdateHealth, f, u) end,
    UNIT_HEAL_PREDICTION = function(f, u) Safe("curacionPrevista", UpdateHeal, f, u) end,
    UNIT_POWER_UPDATE = function(f, u) Safe("recurso", UpdatePower, f, u) end,
    UNIT_MAXPOWER = function(f, u) Safe("recurso", UpdatePower, f, u) end,
    UNIT_DISPLAYPOWER = function(f, u) Safe("recurso", UpdatePower, f, u) end,
    UNIT_AURA = function(f, u) Safe("auras", UpdateAuras, f, u) end,
    UNIT_NAME_UPDATE = function(f, u) Safe("nombre", UpdateName, f, u) end,
    UNIT_CONNECTION = function(f, u) Safe("rango", UpdateRange, f, u) end,
}

local function OnEvent(self, event)
    local unit = self:GetAttribute("unit")
    if not unit then return end
    local h = HANDLERS[event]
    if h then h(self, unit) end
end

local function OnAttributeChanged(self, name, value)
    if name ~= "unit" or not value then return end
    self:UnregisterAllEvents()
    for event in pairs(HANDLERS) do
        pcall(self.RegisterUnitEvent, self, event, value)
    end
    UpdateAll(self)
end

function MiHealBot_UnitButton_OnLoad(self)
    local parent = self:GetParent()
    self.isPet = (parent and parent.GetName and parent:GetName() == "MiHealBotPetHeader") or false
    self:RegisterForClicks("AnyUp")
    ns.BuildVisual(self)
    ns.StyleFrame(self)

    self:HookScript("OnAttributeChanged", OnAttributeChanged)
    self:SetScript("OnEvent", OnEvent)
    self:HookScript("OnShow", UpdateAll)

    ns.buttons[self] = true
    if InCombatLockdown() then
        ns.pendingApply = true
    else
        ns.ApplyBindings(self)
    end
end

-- Roles: se refrescan cuando cambia el grupo, los roles o la especialización
local roleFrame = CreateFrame("Frame")
for _, ev in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED",
                      "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "PLAYER_SPECIALIZATION_CHANGED",
                      "RAID_TARGET_UPDATE" }) do
    pcall(roleFrame.RegisterEvent, roleFrame, ev)
end
roleFrame:SetScript("OnEvent", function(_, event)
    if not ns.db then return end
    for f in pairs(ns.buttons) do
        local unit = f:GetAttribute("unit")
        if unit and UnitExists(unit) then
            if event == "RAID_TARGET_UPDATE" then
                Safe("marcador", UpdateMarker, f, unit)
            else
                Safe("rol", UpdateRole, f, unit)
                Safe("marcador", UpdateMarker, f, unit)
            end
        end
    end
end)

-- Atenuado por rango: se comprueba 4 veces por segundo
local driver = CreateFrame("Frame")
local acc = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.25 then return end
    acc = 0
    if not ns.db then return end
    for f in pairs(ns.buttons) do
        if f:IsShown() then
            Safe("rango", UpdateRange, f, f:GetAttribute("unit"))
        end
    end
end)
