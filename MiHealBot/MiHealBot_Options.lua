-- MiHealBot v0.4 - Ventana de opciones
-- Pestañas: General, Barra, Auras, HoTs, Mascotas, Disipar, Click-cast
local addonName, ns = ...

local frame
local refreshers = {}
local function RefreshAll()
    for _, r in ipairs(refreshers) do r() end
end

---------------------------------------------------------------------
-- Widgets propios
---------------------------------------------------------------------
local function MakeCheck(parent, label, key)
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(290, 20)
    local box = c:CreateTexture(nil, "BACKGROUND")
    box:SetSize(16, 16)
    box:SetPoint("LEFT")
    box:SetColorTexture(0.12, 0.12, 0.16, 1)
    local tick = c:CreateTexture(nil, "ARTWORK")
    tick:SetSize(10, 10)
    tick:SetPoint("CENTER", box)
    tick:SetColorTexture(0.3, 0.8, 1, 1)
    local fs = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", box, "RIGHT", 6, 0)
    fs:SetText(label)
    local function refresh() tick:SetShown(ns.GetOpt(key) and true or false) end
    c:SetScript("OnClick", function()
        ns.SetOpt(key, not ns.GetOpt(key))
        refresh()
        ns.OptionsChanged()
    end)
    refreshers[#refreshers + 1] = refresh
    return c
end

local function MakeSlider(parent, label, key, min, max, step)
    local s = CreateFrame("Slider", nil, parent)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(240, 14)
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end

    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(4)
    track:SetColorTexture(0.2, 0.2, 0.28, 1)

    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(10, 16)
    thumb:SetColorTexture(0.3, 0.8, 1, 1)
    s:SetThumbTexture(thumb)

    local fs = s:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 4)

    local function fmt(v)
        if step < 1 then return string.format("%.2f", v) end
        return tostring(math.floor(v + 0.5))
    end
    local updating = false
    s:SetScript("OnValueChanged", function(self, v)
        if updating then return end
        v = math.floor(v / step + 0.5) * step
        v = tonumber(string.format("%.3f", v))
        fs:SetText(label .. ": " .. fmt(v))
        if ns.GetOpt(key) ~= v then
            ns.SetOpt(key, v)
            ns.OptionsChanged()
        end
    end)
    refreshers[#refreshers + 1] = function()
        updating = true
        s:SetValue(ns.GetOpt(key))
        fs:SetText(label .. ": " .. fmt(ns.GetOpt(key)))
        updating = false
    end
    return s
end

local function MakeCycle(parent, label, key, values, names, width)
    local b
    local function text()
        local cur = ns.GetOpt(key)
        for i, v in ipairs(values) do
            if v == cur then return label .. ": " .. names[i] end
        end
        return label
    end
    b = ns.MakeButton(parent, label, width or 220, function()
        local cur = ns.GetOpt(key)
        local idx = 0
        for i, v in ipairs(values) do if v == cur then idx = i end end
        idx = idx % #values + 1
        ns.SetOpt(key, values[idx])
        b:SetLabel(text())
        ns.OptionsChanged()
    end)
    refreshers[#refreshers + 1] = function() b:SetLabel(text()) end
    return b
end

-- Desplegable propio: un botón que abre una lista con todas las opciones
local dropList, dropCatcher

local function CloseDropdown()
    if dropList then dropList:Hide() end
    if dropCatcher then dropCatcher:Hide() end
end

local function OpenDropdown(anchor, values, names, current, onSelect)
    if not dropList then
        dropCatcher = CreateFrame("Button", nil, UIParent)
        dropCatcher:SetAllPoints(UIParent)
        dropCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
        dropCatcher:SetFrameLevel(1)
        dropCatcher:SetScript("OnClick", CloseDropdown)
        dropCatcher:Hide()

        dropList = CreateFrame("Frame", nil, UIParent)
        dropList:SetFrameStrata("FULLSCREEN_DIALOG")
        dropList:SetFrameLevel(10)
        dropList:EnableMouse(true)
        local bg = dropList:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.1, 0.1, 0.16, 1)
        local border = dropList:CreateTexture(nil, "BACKGROUND", nil, -1)
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        border:SetColorTexture(0.3, 0.8, 1, 1)
        dropList.items = {}
        dropList:Hide()
    end
    local width = anchor:GetWidth()
    for i, v in ipairs(values) do
        local it = dropList.items[i]
        if not it then
            it = CreateFrame("Button", nil, dropList)
            it:SetHeight(22)
            local hl = it:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(0.3, 0.5, 0.9, 0.5)
            it.text = it:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            it.text:SetPoint("LEFT", 8, 0)
            dropList.items[i] = it
        end
        it:SetWidth(width)
        it:ClearAllPoints()
        it:SetPoint("TOPLEFT", dropList, "TOPLEFT", 0, -2 - (i - 1) * 22)
        it.text:SetText(names[i])
        if v == current then
            it.text:SetTextColor(1, 0.82, 0)
        else
            it.text:SetTextColor(1, 1, 1)
        end
        it:SetScript("OnClick", function()
            CloseDropdown()
            onSelect(v)
        end)
        it:Show()
    end
    for i = #values + 1, #dropList.items do dropList.items[i]:Hide() end
    dropList:SetSize(width, #values * 22 + 4)
    dropList:ClearAllPoints()
    dropList:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    dropCatcher:Show()
    dropList:Show()
end

local function MakeDropdown(parent, label, key, values, names, width)
    local b
    local function text()
        local cur = ns.GetOpt(key)
        for i, v in ipairs(values) do
            if v == cur then return label .. ": " .. names[i] end
        end
        return label
    end
    b = ns.MakeButton(parent, label, width or 220, function()
        OpenDropdown(b, values, names, ns.GetOpt(key), function(v)
            ns.SetOpt(key, v)
            b:SetLabel(text())
            ns.OptionsChanged()
        end)
    end)
    local arrow = b:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(14, 14)
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    refreshers[#refreshers + 1] = function() b:SetLabel(text()) end
    return b
end

local function MakeHint(parent, text, x, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

-- Arrastrar hechizos desde el libro de hechizos a una casilla de texto
local function SpellNameFromCursor()
    local kind, a, _, c = GetCursorInfo()
    if kind ~= "spell" then return nil end
    local id = (type(c) == "number" and c) or (type(a) == "number" and a) or nil
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(id)
    elseif GetSpellInfo then
        return (GetSpellInfo(id))
    end
end

local function AttachDrop(e, commit)
    local function tryDrop()
        local name = SpellNameFromCursor()
        if name then
            e:SetText(name)
            commit()
            ClearCursor()
        end
    end
    e:SetScript("OnReceiveDrag", tryDrop)
    e:SetScript("OnMouseUp", function() tryDrop() end)
end

local function StyleEdit(e)
    e:SetAutoFocus(false)
    e:SetFontObject("GameFontHighlightSmall")
    e:SetTextInsets(4, 4, 0, 0)
    e:SetMaxLetters(300)
    local bg = e:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.15, 1)
end

local function MakeOptEdit(parent, label, key, width, allowDrop)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, 40)
    local fs = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT")
    fs:SetText(label)
    local e = CreateFrame("EditBox", nil, holder)
    e:SetSize(width, 22)
    e:SetPoint("TOPLEFT", 0, -16)
    StyleEdit(e)
    local function commit()
        local t = strtrim(e:GetText() or "")
        if t ~= ns.GetOpt(key) then
            ns.SetOpt(key, t)
            ns.OptionsChanged()
        end
    end
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEscapePressed", function(self)
        self:SetText(ns.GetOpt(key) or "")
        self:ClearFocus()
    end)
    e:SetScript("OnEditFocusLost", commit)
    if allowDrop then AttachDrop(e, commit) end
    refreshers[#refreshers + 1] = function() e:SetText(ns.GetOpt(key) or "") end
    return holder
end

local function MakeBindingBox(parent, mod, btn)
    local key = mod .. ":" .. btn
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(112, 24)
    StyleEdit(e)
    local function current() return ns.db.bindings[key] or "" end
    local function save()
        local t = strtrim(e:GetText() or "")
        ns.db.bindings[key] = (t ~= "") and t or nil
        ns.ApplyAllBindings()
    end
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEscapePressed", function(self)
        self:SetText(current())
        self:ClearFocus()
    end)
    e:SetScript("OnEditFocusLost", save)
    e:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            self:SetText("")
            save()
        end
    end)
    AttachDrop(e, save)
    refreshers[#refreshers + 1] = function() e:SetText(current()) end
    return e
end

---------------------------------------------------------------------
-- Pestañas
---------------------------------------------------------------------
local function BuildGeneral(page)
    local left = {
        { "Ancho", "width", 40, 200, 1 },
        { "Alto", "height", 16, 80, 1 },
        { "Separación vertical", "spacing", 0, 20, 1 },
        { "Separación entre columnas", "colSpacing", 0, 30, 1 },
        { "Unidades por columna", "unitsPerColumn", 1, 40, 1 },
    }
    for i, d in ipairs(left) do
        MakeSlider(page, d[1], d[2], d[3], d[4], d[5]):SetPoint("TOPLEFT", 20, -95 - (i - 1) * 52)
    end
    local right = {
        { "Escala", "scale", 0.5, 2, 0.05 },
        { "Tamaño de fuente", "fontSize", 8, 18, 1 },
        { "Opacidad del fondo", "bgAlpha", 0, 1, 0.05 },
    }
    for i, d in ipairs(right) do
        MakeSlider(page, d[1], d[2], d[3], d[4], d[5]):SetPoint("TOPLEFT", 340, -95 - (i - 1) * 52)
    end
    local checks = {
        { "Mostrar en solitario", "showSolo" },
        { "Mostrar en grupo", "showParty" },
        { "Mostrar en banda", "showRaid" },
        { "Incluirme en el marco", "showPlayer" },
        { "Color de clase", "classColor" },
        { "Mostrar nombre", "showName" },
        { "Botón del minimapa", "showMinimap" },
        { "Tooltip al pasar el ratón por los iconos", "auraTooltips" },
    }
    for i, d in ipairs(checks) do
        MakeCheck(page, d[1], d[2]):SetPoint("TOPLEFT", 340, -250 - (i - 1) * 22)
    end
    MakeCycle(page, "Orientación", "orientation", { "V", "H" }, { "Vertical", "Horizontal" })
        :SetPoint("TOPLEFT", 20, -380)
    MakeCycle(page, "Textura de barra", "texture", { 1, 2, 3 }, ns.TEXTURE_NAMES)
        :SetPoint("TOPLEFT", 20, -408)

    local b1 = ns.MakeButton(page, "Vista previa", 120, function() ns.TogglePreview() end)
    b1:SetPoint("BOTTOMLEFT", 20, 14)
    local b2 = ns.MakeButton(page, "Mover marcos", 120, function() ns.ToggleMover() end)
    b2:SetPoint("LEFT", b1, "RIGHT", 8, 0)
    local b3 = ns.MakeButton(page, "Restaurar ajustes", 140, function()
        ns.db.opts = ns.DeepCopy(ns.defaults.opts)
        ns.ApplyClassDispels(ns.db)
        RefreshAll()
        ns.OptionsChanged()
    end)
    b3:SetPoint("LEFT", b2, "RIGHT", 8, 0)
end

local function BuildBar(page)
    local L, R = 20, 340
    -- vida
    MakeDropdown(page, "Texto de vida", "healthText", { "none", "cur", "curmax" },
        { "Ninguno", "Vida actual", "Actual/Máxima" }, 280):SetPoint("TOPLEFT", L, -80)
    MakeCheck(page, "Mostrar también el porcentaje", "showPct"):SetPoint("TOPLEFT", L, -108)
    MakeDropdown(page, "Posición del texto", "textPos", { "B", "T", "C" },
        { "Abajo", "Arriba", "Centro" }, 280):SetPoint("TOPLEFT", L, -134)
    -- recursos
    MakeCheck(page, "Mostrar barra de recursos (maná, energía, rabia...)", "showPower"):SetPoint("TOPLEFT", L, -176)
    MakeCheck(page, "Mostrar el % en la barra de recursos", "showPowerText"):SetPoint("TOPLEFT", L, -198)
    MakeSlider(page, "Altura de la barra de recursos", "powerHeight", 2, 14, 1):SetPoint("TOPLEFT", L, -240)
    MakeCycle(page, "Posición del recurso", "powerPos", { "B", "T" }, { "Abajo", "Arriba" }, 280)
        :SetPoint("TOPLEFT", L, -262)
    -- curación prevista
    MakeCheck(page, "Predicción de curación (mis casteos)", "showHealPred"):SetPoint("TOPLEFT", L, -304)

    -- rango
    MakeCheck(page, "Atenuar miembros fuera de rango", "rangeFade"):SetPoint("TOPLEFT", R, -80)
    MakeSlider(page, "Opacidad fuera de rango", "rangeAlpha", 0.1, 0.9, 0.05):SetPoint("TOPLEFT", R, -125)
    MakeOptEdit(page, "Hechizo para medir el rango (opcional)", "rangeSpell", 240, true):SetPoint("TOPLEFT", R, -155)
    MakeHint(page, "Escribe el nombre de un hechizo de curación (o arrástralo desde el libro). "
        .. "Vacío = rango estándar del juego.", R, -205, 280)
    -- rol
    MakeCheck(page, "Mostrar icono de rol (tanque / sanador / dps)", "showRole"):SetPoint("TOPLEFT", R, -272)
    MakeCheck(page, "Ocultar el icono de DPS", "roleHideDps"):SetPoint("TOPLEFT", R, -294)
    MakeSlider(page, "Tamaño del icono de rol", "roleSize", 8, 24, 1):SetPoint("TOPLEFT", R, -338)
    MakeCycle(page, "Posición del icono", "rolePos", ns.ANCHORS, ns.ANCHOR_NAMES, 240):SetPoint("TOPLEFT", R, -360)
end

-- kind: "buff" | "debuff" | "hot"
local function BuildAuraColumn(page, kind, x, title, onlyLabel, whiteLabel)
    local t = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", x, -74)
    t:SetText(title)
    MakeCheck(page, "Mostrar", kind .. ".show"):SetPoint("TOPLEFT", x, -102)
    if onlyLabel then
        MakeCheck(page, onlyLabel, kind .. ".only"):SetPoint("TOPLEFT", x, -124)
    end
    MakeSlider(page, "Tamaño del icono", kind .. ".size", 8, 32, 1):SetPoint("TOPLEFT", x, -166)
    MakeSlider(page, "Cantidad máxima", kind .. ".max", 1, 8, 1):SetPoint("TOPLEFT", x, -208)
    MakeSlider(page, "Desplazamiento X", kind .. ".x", -60, 60, 1):SetPoint("TOPLEFT", x, -250)
    MakeSlider(page, "Desplazamiento Y", kind .. ".y", -40, 40, 1):SetPoint("TOPLEFT", x, -292)
    MakeCycle(page, "Posición en el marco", kind .. ".anchor", ns.ANCHORS, ns.ANCHOR_NAMES, 240)
        :SetPoint("TOPLEFT", x, -316)
    MakeCycle(page, "Crecimiento", kind .. ".grow", ns.GROWS, ns.GROW_NAMES, 240)
        :SetPoint("TOPLEFT", x, -344)
    MakeOptEdit(page, whiteLabel or "Mostrar solo estos (nombres o IDs, con comas)", kind .. ".white", 290)
        :SetPoint("TOPLEFT", x, -380)
    MakeOptEdit(page, "Ocultar estos (nombres o IDs, con comas)", kind .. ".black", 290)
        :SetPoint("TOPLEFT", x, -428)
end

local function BuildAuras(page)
    BuildAuraColumn(page, "buff", 20, "Bufos", "Solo los lanzados por mí")
    BuildAuraColumn(page, "debuff", 350, "Debufos", "Solo los que puedo quitar")
end

local function BuildHots(page)
    BuildAuraColumn(page, "hot", 20, "HoTs (mis curas en el tiempo)", nil,
        "Añadir HoTs a la lista (nombres o IDs, con comas)")
    MakeCheck(page, "Usar la lista de HoTs de mi clase", "hot.useClass"):SetPoint("TOPLEFT", 350, -102)
    MakeCheck(page, "Quitar mis HoTs de la lista de bufos", "hot.separate"):SetPoint("TOPLEFT", 350, -124)
    MakeCheck(page, "Espiral de tiempo restante (sentido horario)", "hot.swipe"):SetPoint("TOPLEFT", 350, -146)
    MakeCheck(page, "Mostrar también los segundos en número", "hot.numbers"):SetPoint("TOPLEFT", 350, -168)
    MakeHint(page, "Los HoTs son tus propias curas en el tiempo (Rejuvenación, Renovar, Florecer...). "
        .. "Se detectan por el nombre del hechizo en el idioma de tu cliente.\n\n"
        .. "Si tu clase no tiene lista predefinida o quieres otros hechizos, escribe sus nombres "
        .. "en \"Añadir HoTs\", separados por comas.\n\n"
        .. "Si la lista queda vacía, se muestran todos tus bufos sobre el aliado.", 350, -205, 290)
end

local function BuildPets(page)
    local L = 20
    MakeCheck(page, "Mostrar marcos de mascotas", "showPets"):SetPoint("TOPLEFT", L, -80)
    MakeCycle(page, "Posición de las mascotas", "petPos", { "B", "R" }, { "Debajo", "A la derecha" }, 290)
        :SetPoint("TOPLEFT", L, -108)
    MakeSlider(page, "Ancho de las mascotas", "petWidth", 30, 200, 1):SetPoint("TOPLEFT", L, -160)
    MakeSlider(page, "Alto de las mascotas", "petHeight", 12, 80, 1):SetPoint("TOPLEFT", L, -202)
    MakeSlider(page, "Tamaño de fuente", "petFontSize", 7, 14, 1):SetPoint("TOPLEFT", L, -244)
    MakeCycle(page, "Texto de vida", "petHealthText", { "none", "cur", "curmax" },
        { "Ninguno", "Vida actual", "Actual/Máxima" }, 290):SetPoint("TOPLEFT", L, -272)
    MakeCheck(page, "Mostrar el porcentaje", "petShowPct"):SetPoint("TOPLEFT", L, -304)
    MakeCheck(page, "Mostrar barra de recursos", "petShowPower"):SetPoint("TOPLEFT", L, -326)
    MakeCheck(page, "Mostrar bufos, debufos y HoTs", "petAuras"):SetPoint("TOPLEFT", L, -348)
    MakeHint(page, "Los marcos de las mascotas tienen su propio tamaño: cambiarlos no afecta a los marcos "
        .. "de los jugadores. Úsalos más pequeños para que ocupen poco espacio.", 350, -80, 290)
end

local function BuildDispel(page)
    local L = 20
    MakeCheck(page, "Resaltar los debufos que puedo disipar", "dispelHighlight"):SetPoint("TOPLEFT", L, -80)
    MakeCheck(page, "Resaltar también el borde del marco", "dispelFrame"):SetPoint("TOPLEFT", L, -102)
    MakeCheck(page, "Mostrar primero los disipables", "dispelFirst"):SetPoint("TOPLEFT", L, -124)

    local t = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("TOPLEFT", L, -168)
    t:SetText("Tipos de debufo que puedo disipar")
    MakeCheck(page, "Magia", "dispel.Magic"):SetPoint("TOPLEFT", L, -192)
    MakeCheck(page, "Maldición", "dispel.Curse"):SetPoint("TOPLEFT", L, -214)
    MakeCheck(page, "Enfermedad", "dispel.Disease"):SetPoint("TOPLEFT", L, -236)
    MakeCheck(page, "Veneno", "dispel.Poison"):SetPoint("TOPLEFT", L, -258)
    MakeHint(page, "Los tipos vienen preseleccionados según tu clase, pero dependen también de la "
        .. "especialización y de los talentos: ajústalos si en tu caso son distintos.\n\n"
        .. "Un debufo disipable se muestra con el borde más grueso y del color de su tipo "
        .. "(azul = magia, morado = maldición, marrón = enfermedad, verde = veneno), "
        .. "y el marco del jugador se resalta con ese mismo color.", 350, -80, 290)
end

local function BuildBindings(page)
    MakeHint(page, "Escribe el nombre exacto de un hechizo, o: target, menu, macro:/cast ... "
        .. "También puedes ARRASTRAR un hechizo desde el libro de hechizos a una casilla. "
        .. "Clic derecho sobre una casilla la vacía.", 20, -70, 630)
    for c, mod in ipairs(ns.MOD_ORDER) do
        local fs = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", 120 + (c - 1) * 130, -125)
        fs:SetText(ns.MOD_LABELS[mod])
    end
    for btn = 1, 5 do
        local y = -150 - (btn - 1) * 38
        local fs = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fs:SetPoint("TOPLEFT", 20, y - 5)
        fs:SetText(ns.BUTTON_LABELS[btn])
        for c, mod in ipairs(ns.MOD_ORDER) do
            MakeBindingBox(page, mod, btn):SetPoint("TOPLEFT", 120 + (c - 1) * 130, y)
        end
    end
    local reset = ns.MakeButton(page, "Restaurar asignaciones", 170, function()
        ns.db.bindings = ns.DeepCopy(ns.defaults.bindings)
        ns.ApplyAllBindings()
        RefreshAll()
    end)
    reset:SetPoint("BOTTOMLEFT", 20, 14)
end

---------------------------------------------------------------------
-- Ventana
---------------------------------------------------------------------
local function CreateOptions()
    frame = CreateFrame("Frame", "MiHealBotOptions", UIParent)
    frame:SetSize(680, 560)
    frame:SetPoint("CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.08, 0.95)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -10)
    title:SetText("MiHealBot")

    local close = ns.MakeButton(frame, "X", 22, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT", -6, -6)

    local builders = { BuildGeneral, BuildBar, BuildAuras, BuildHots, BuildPets, BuildDispel, BuildBindings }
    local labels = { "General", "Barra", "Auras", "HoTs", "Mascotas", "Disipar", "Click-cast" }
    local pages, tabs = {}, {}
    for i, build in ipairs(builders) do
        pages[i] = CreateFrame("Frame", nil, frame)
        pages[i]:SetAllPoints()
        build(pages[i])
    end
    local function showTab(i)
        for k = 1, #pages do
            pages[k]:SetShown(k == i)
            if k == i then
                tabs[k].bg:SetColorTexture(0.2, 0.4, 0.7, 1)
            else
                tabs[k].bg:SetColorTexture(0.15, 0.15, 0.22, 1)
            end
        end
    end
    for i = 1, #pages do
        tabs[i] = ns.MakeButton(frame, labels[i], 88, function() showTab(i) end)
        if i == 1 then
            tabs[i]:SetPoint("TOPLEFT", 20, -38)
        else
            tabs[i]:SetPoint("LEFT", tabs[i - 1], "RIGHT", 4, 0)
        end
    end
    showTab(1)

    frame:SetScript("OnShow", RefreshAll)
    frame:SetScript("OnHide", CloseDropdown)
    tinsert(UISpecialFrames, "MiHealBotOptions")
    RefreshAll()
    frame:Hide()
end

function ns.ToggleOptions(forceShow)
    if not ns.db then return end
    if not frame then CreateOptions() end
    if frame:IsShown() and not forceShow then
        frame:Hide()
    else
        frame:Show()
    end
end

---------------------------------------------------------------------
-- Entrada en el menú de AddOns de Blizzard (Esc > Opciones > AddOns)
---------------------------------------------------------------------
local function RegisterBlizzardPanel()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local panel = CreateFrame("Frame")
    panel.name = "MiHealBot"
    local t = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText("MiHealBot")
    local d = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -10)
    d:SetText("Unit frames con click-casting. También puedes abrir las opciones con /mhb")
    local open = ns.MakeButton(panel, "Abrir configuración", 180, function()
        if SettingsPanel and SettingsPanel:IsShown() then SettingsPanel:Hide() end
        ns.ToggleOptions(true)
    end)
    open:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -16)
    local prev = ns.MakeButton(panel, "Vista previa", 180, function()
        if SettingsPanel and SettingsPanel:IsShown() then SettingsPanel:Hide() end
        ns.TogglePreview()
    end)
    prev:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -8)
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
end

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function()
    pcall(RegisterBlizzardPanel)
end)
