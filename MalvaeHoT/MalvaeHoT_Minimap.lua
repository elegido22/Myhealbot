-- MalvaeHoT v0.4 - Botón del minimapa (hoja verde, icono de Toque de vida), con icono redondo
local addonName, ns = ...

local btn

-- Imagen propia incluida en el addon (Media/leaf.tga)
local ICON = "Interface\\AddOns\\MalvaeHoT\\Media\\leaf"
local function IconTexture()
    return ICON
end

local function UpdatePosition()
    local a = math.rad(ns.db.minimapAngle or 200)
    local r = Minimap:GetWidth() / 2 + 5
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local s = Minimap:GetEffectiveScale()
    cx, cy = cx / s, cy / s
    local atan = math.atan2 or math.atan
    ns.db.minimapAngle = math.deg(atan(cy - my, cx - mx))
    UpdatePosition()
end

local function CreateButton()
    btn = CreateFrame("Button", "MalvaeHoTMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("AnyUp")
    btn:RegisterForDrag("LeftButton")

    -- fondo oscuro y icono, ambos recortados con máscara circular (sin esquinas cuadradas)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)
    bg:SetColorTexture(0, 0, 0, 0.9)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(19, 19)
    icon:SetPoint("TOPLEFT", 6, -5)
    icon:SetTexture(IconTexture())
    icon:SetTexCoord(0, 1, 0, 1)

    local mask = btn:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetSize(20, 20)
    mask:SetPoint("TOPLEFT", 7, -5)
    bg:AddMaskTexture(mask)
    icon:AddMaskTexture(mask)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(50, 50)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- resplandor circular al pasar el ratón (el estándar del minimapa)
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            ns.TogglePreview()
        else
            ns.ToggleOptions()
        end
    end)
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", OnDragUpdate)
    end)
    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("MalvaeHoT")
        GameTooltip:AddLine("Clic izquierdo: opciones", 1, 1, 1)
        GameTooltip:AddLine("Clic derecho: vista previa", 1, 1, 1)
        GameTooltip:AddLine("Arrastrar: mover el botón", 1, 1, 1)
        GameTooltip:AddLine("Creado por |cffffd100Elegido Malvae|r", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    UpdatePosition()
end

function ns.UpdateMinimap()
    if not ns.db then return end
    if not btn then CreateButton() end
    btn:SetShown(ns.db.opts.showMinimap)
end

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function()
    pcall(ns.UpdateMinimap)
end)
