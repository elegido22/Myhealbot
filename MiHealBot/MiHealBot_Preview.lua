-- MiHealBot v0.4 - Ventana de vista previa con miembros y mascotas ficticios
local addonName, ns = ...

local preview
local fakes, fakePets = {}, {}
local MODES = { { "Solo", 1 }, { "Party", 5 }, { "Raid 10", 10 }, { "Raid 25", 25 }, { "Raid 40", 40 } }
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN",
                  "MAGE", "WARLOCK", "DRUID", "DEATHKNIGHT", "MONK", "DEMONHUNTER", "EVOKER" }
local POWER_BY_CLASS = { WARRIOR = "RAGE", ROGUE = "ENERGY", DRUID = "MANA" }
ns.previewCount = 5

local function SpellTex(id)
    local t = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
    return t or 134400
end
local FAKE_IDS = {
    hot = { 774, 8936, 33763, 139, 48438, 61295, 974, 119611 },
    buff = { 17, 1126, 21562, 6673, 465, 1459, 20217, 19740 },
    debuff = { 589, 116, 8921, 5782, 702, 172, 3600, 1822 },
}

local function GetFake(pool, parent, i, isPet)
    if pool[i] then return pool[i] end
    local f = CreateFrame("Button", nil, parent)
    f.isPet = isPet
    ns.BuildVisual(f)
    f.class = CLASSES[(i - 1) % #CLASSES + 1]
    pool[i] = f
    return f
end

local function FillFake(f, i)
    local o = ns.db.opts
    ns.StyleFrame(f)
    f.nameText:SetText((f.isPet and "Mascota " or "Jugador ") .. i)

    -- vida
    local v = 35 + (i * 37) % 66
    local maxhp = 300 + (i % 5) * 60
    local cur = math.floor(maxhp * v / 100)
    f.hp:SetMinMaxValues(0, 100)
    f.hp:SetValue(v)
    if f.isPet then f.hp:SetStatusBarColor(0.6, 0.8, 0.3) else ns.ColorBar(f, f.class) end

    f.heal:SetMinMaxValues(0, 100)
    f.heal:SetValue(18)
    f.heal:SetShown(o.showHealPred and (i % 3 ~= 0))

    local mode = f.isPet and o.petHealthText or o.healthText
    if mode == "curmax" then
        f.numText:SetText(cur .. "/" .. maxhp)
    else
        f.numText:SetText(tostring(cur))
    end
    f.pctText:SetText(v .. "%")

    -- recurso con su %
    local token = POWER_BY_CLASS[f.class] or "MANA"
    local c = PowerBarColor and PowerBarColor[token] or { r = 0.2, g = 0.4, b = 0.9 }
    local pp = 20 + (i * 53) % 81
    f.power:SetStatusBarColor(c.r, c.g, c.b)
    f.power:SetMinMaxValues(0, 100)
    f.power:SetValue(pp)
    f.powerText:SetText(pp .. "%")

    -- rol
    if not f.isPet and o.showRole then
        local role = (i == 1) and "TANK" or ((i % 5 == 2) and "HEALER" or "DAMAGER")
        if role == "DAMAGER" and o.roleHideDps then role = nil end
        ns.SetRoleTexture(f.role, role)
    else
        f.role:Hide()
    end

    -- auras ficticias
    local showAuras = (not f.isPet) or o.petAuras
    local edge = false
    for _, kind in ipairs({ "hot", "buff", "debuff" }) do
        local cfg = o[kind]
        local ids = FAKE_IDS[kind]
        for j = 1, 8 do
            local icon = ns.GetAuraIcon(f, kind, j)
            if showAuras and cfg.show and j <= cfg.max then
                local id = ids[(j + i) % #ids + 1]
                icon.unit = nil
                icon.fakeSpell = id
                icon.tex:SetTexture(SpellTex(id))
                icon.count:SetText(j == 2 and "3" or "")
                if kind == "debuff" then
                    local disp = (j == 1 and o.dispelHighlight and i % 3 == 1)
                    if disp then
                        ns.SetIconBorder(icon, 0.2, 0.5, 1, 3)
                        edge = true
                    else
                        ns.SetIconBorder(icon, 0.6, 0.1, 0.8, 1)
                    end
                else
                    ns.SetIconBorder(icon, 0, 0, 0, 1)
                end
                icon:Show()
            else
                icon:Hide()
            end
        end
    end
    if edge and o.dispelFrame then ns.SetEdge(f, 0.2, 0.5, 1) else ns.SetEdge(f, nil) end

    f:SetAlpha((o.rangeFade and i % 4 == 0) and o.rangeAlpha or 1)
end

-- Coloca n marcos en rejilla; devuelve ancho y alto del conjunto
local function Grid(pool, parent, n, o, isPet)
    local upc = o.unitsPerColumn
    local w, h = o.width, o.height
    if isPet then w, h = o.petWidth, o.petHeight end
    local sp, cs = o.spacing, o.colSpacing
    for i = 1, n do
        local f = GetFake(pool, parent, i, isPet)
        FillFake(f, i)
        local col = math.floor((i - 1) / upc)
        local row = (i - 1) % upc
        local x, y
        if o.orientation == "H" then
            x = row * (w + sp)
            y = col * (h + cs)
        else
            x = col * (w + cs)
            y = row * (h + sp)
        end
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
        f:Show()
    end
    for i = n + 1, #pool do pool[i]:Hide() end
    if n <= 0 then return 0, 0 end
    local cols = math.min(math.ceil(n / upc), math.ceil(40 / upc))
    local rows = math.min(n, upc)
    if o.orientation == "H" then
        return rows * w + (rows - 1) * sp, cols * h + (cols - 1) * cs
    end
    return cols * w + (cols - 1) * cs, rows * h + (rows - 1) * sp
end

function ns.RefreshPreview()
    if not preview or not preview:IsShown() or not ns.db then return end
    local o = ns.db.opts
    local n = ns.previewCount
    local pn = o.showPets and math.min(n, 10) or 0

    local cw, ch = Grid(fakes, preview.container, n, o, false)
    local pw, ph = Grid(fakePets, preview.petContainer, pn, o, true)
    preview.container:SetSize(math.max(cw, 1), math.max(ch, 1))
    preview.petContainer:SetSize(math.max(pw, 1), math.max(ph, 1))
    preview.container:SetScale(o.scale)
    preview.petContainer:SetScale(o.scale)

    preview.petContainer:ClearAllPoints()
    local gap = 10
    local W, H
    if pn > 0 and o.petPos == "R" then
        preview.petContainer:SetPoint("TOPLEFT", preview.container, "TOPRIGHT", gap, 0)
        W, H = (cw + gap + pw) * o.scale, math.max(ch, ph) * o.scale
    elseif pn > 0 then
        preview.petContainer:SetPoint("TOPLEFT", preview.container, "BOTTOMLEFT", 0, -gap)
        W, H = math.max(cw, pw) * o.scale, (ch + gap + ph) * o.scale
    else
        preview.petContainer:SetPoint("TOPLEFT", preview.container, "BOTTOMLEFT", 0, -gap)
        W, H = cw * o.scale, ch * o.scale
    end
    preview.petContainer:SetShown(pn > 0)
    preview:SetSize(math.max(W + 24, 370), H + 24 + 56)
end

local function CreatePreview()
    preview = CreateFrame("Frame", "MiHealBotPreview", UIParent)
    preview:SetFrameStrata("MEDIUM")
    preview:SetPoint("CENTER", 0, 80)
    preview:SetMovable(true)
    preview:EnableMouse(true)
    preview:SetClampedToScreen(true)
    preview:RegisterForDrag("LeftButton")
    preview:SetScript("OnDragStart", preview.StartMoving)
    preview:SetScript("OnDragStop", preview.StopMovingOrSizing)

    local bg = preview:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.08, 0.85)

    local title = preview:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("Vista previa (arrastra para mover)")

    local close = ns.MakeButton(preview, "X", 22, function() preview:Hide() end)
    close:SetPoint("TOPRIGHT", -4, -4)

    local prev
    for _, m in ipairs(MODES) do
        local b = ns.MakeButton(preview, m[1], 62, function()
            ns.previewCount = m[2]
            ns.RefreshPreview()
        end)
        if prev then
            b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        else
            b:SetPoint("TOPLEFT", 10, -28)
        end
        prev = b
    end

    preview.container = CreateFrame("Frame", nil, preview)
    preview.container:SetPoint("TOPLEFT", preview, "TOPLEFT", 12, -56)
    preview.container:SetSize(10, 10)
    preview.petContainer = CreateFrame("Frame", nil, preview)
    preview.petContainer:SetSize(10, 10)

    preview:SetScript("OnShow", ns.RefreshPreview)
    preview:Hide()
end

function ns.TogglePreview()
    if not ns.db then return end
    if not preview then CreatePreview() end
    if preview:IsShown() then
        preview:Hide()
    else
        preview:Show()
    end
end
