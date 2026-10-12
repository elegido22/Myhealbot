-- MalvaeHoT - Exportar / importar la configuración de un perfil
-- Formato: "MHOT1:<checksum>:<base64>" (texto seguro para copiar y pegar).
-- No se ejecuta código del texto importado: se lee con un analizador propio y se valida cada valor.
local addonName, ns = ...

---------------------------------------------------------------------
-- Base64 y suma de comprobación
---------------------------------------------------------------------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64REV = {}
for i = 1, 64 do B64REV[B64:sub(i, i)] = i - 1 end

local function B64Encode(s)
    local out = {}
    for i = 1, #s, 3 do
        local a, b, c = s:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
            .. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end

local function B64Decode(s)
    s = s:gsub("[^%w%+/=]", "")
    local out = {}
    for i = 1, #s, 4 do
        local c1, c2, c3, c4 = s:sub(i, i), s:sub(i + 1, i + 1), s:sub(i + 2, i + 2), s:sub(i + 3, i + 3)
        local n1, n2 = B64REV[c1], B64REV[c2]
        if not n1 or not n2 then return nil end
        local n = n1 * 262144 + n2 * 4096 + (B64REV[c3] or 0) * 64 + (B64REV[c4] or 0)
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        if c3 ~= "=" and c3 ~= "" then out[#out + 1] = string.char(math.floor(n / 256) % 256) end
        if c4 ~= "=" and c4 ~= "" then out[#out + 1] = string.char(n % 256) end
    end
    return table.concat(out)
end

local function Checksum(s)
    local a, b = 1, 0
    for i = 1, #s do
        a = (a + s:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return b * 65536 + a
end

---------------------------------------------------------------------
-- Serializador / analizador propio (tablas con claves de texto)
---------------------------------------------------------------------
local function Ser(v, out)
    local t = type(v)
    if t == "number" then
        out[#out + 1] = "n" .. string.format("%.10g", v) .. ";"
    elseif t == "string" then
        out[#out + 1] = "s" .. #v .. ":" .. v
    elseif t == "boolean" then
        out[#out + 1] = v and "b1" or "b0"
    elseif t == "table" then
        out[#out + 1] = "t"
        local keys = {}
        for k in pairs(v) do
            if type(k) == "string" then keys[#keys + 1] = k end
        end
        table.sort(keys)
        for _, k in ipairs(keys) do
            out[#out + 1] = #k .. ":" .. k
            Ser(v[k], out)
        end
        out[#out + 1] = "e"
    else
        error("tipo no admitido")
    end
end

local function Parse(s)
    local pos, depth = 1, 0
    local readValue

    local function readLen(stopChar)
        local e = s:find(stopChar, pos, true)
        if not e then error("formato") end
        local n = tonumber(s:sub(pos, e - 1))
        if not n or n < 0 or n > 2000 or n ~= math.floor(n) then error("formato") end
        pos = e + 1
        return n
    end

    function readValue()
        local c = s:sub(pos, pos)
        if c == "n" then
            local e = s:find(";", pos, true)
            if not e then error("formato") end
            local num = tonumber(s:sub(pos + 1, e - 1))
            if not num then error("formato") end
            pos = e + 1
            return num
        elseif c == "s" then
            pos = pos + 1
            local len = readLen(":")
            local str = s:sub(pos, pos + len - 1)
            if #str ~= len then error("formato") end
            pos = pos + len
            return str
        elseif c == "b" then
            local b = s:sub(pos + 1, pos + 1)
            pos = pos + 2
            if b == "1" then return true elseif b == "0" then return false end
            error("formato")
        elseif c == "t" then
            depth = depth + 1
            if depth > 6 then error("demasiado anidado") end
            pos = pos + 1
            local tbl = {}
            while true do
                if pos > #s then error("formato") end
                if s:sub(pos, pos) == "e" then
                    pos = pos + 1
                    break
                end
                local klen = readLen(":")
                local key = s:sub(pos, pos + klen - 1)
                if #key ~= klen then error("formato") end
                pos = pos + klen
                tbl[key] = readValue()
            end
            depth = depth - 1
            return tbl
        end
        error("formato")
    end

    local v = readValue()
    if pos <= #s then error("datos sobrantes") end
    return v
end

---------------------------------------------------------------------
-- Validación: solo se aceptan claves conocidas, con su tipo y rango
---------------------------------------------------------------------
local RANGES = {
    width = { 40, 200 }, height = { 16, 80 }, spacing = { 0, 20 }, colSpacing = { 0, 30 },
    unitsPerColumn = { 1, 40 }, scale = { 0.5, 2 }, fontSize = { 8, 18 }, bgAlpha = { 0, 1 },
    texture = { 1, 3 }, powerHeight = { 2, 14 }, rangeAlpha = { 0.1, 0.9 },
    roleSize = { 8, 24 }, markerSize = { 8, 32 }, markerX = { -80, 80 }, markerY = { -50, 50 },
    petWidth = { 30, 200 }, petHeight = { 12, 80 }, petFontSize = { 7, 14 },
    size = { 8, 32 }, max = { 1, 8 }, x = { -60, 60 }, y = { -40, 40 },
}

local function Set(list)
    local t = {}
    for _, v in ipairs(list) do t[v] = true end
    return t
end
local ENUMS = {
    orientation = Set({ "V", "H" }),
    textPos = Set({ "B", "T", "C" }),
    powerPos = Set({ "B", "T" }),
    petPos = Set({ "B", "R" }),
    healthText = Set({ "none", "cur", "curmax" }),
    petHealthText = Set({ "none", "cur", "curmax" }),
    rolePos = Set(ns.ANCHORS),
    markerPos = Set(ns.ANCHORS),
    anchor = Set(ns.ANCHORS),
    grow = Set(ns.GROWS),
}

local function SanitizeOpts(src, def)
    local out = {}
    for k, dv in pairs(def) do
        local sv = type(src) == "table" and src[k] or nil
        if type(dv) == "table" then
            out[k] = SanitizeOpts(sv, dv)
        elseif type(sv) == type(dv) then
            if type(sv) == "number" then
                local r = RANGES[k]
                if sv ~= sv then sv = dv end -- NaN
                if r then sv = math.max(r[1], math.min(r[2], sv)) end
                out[k] = sv
            elseif type(sv) == "string" then
                if ENUMS[k] and not ENUMS[k][sv] then
                    out[k] = dv
                else
                    out[k] = sv:sub(1, 300)
                end
            else
                out[k] = sv
            end
        else
            out[k] = dv
        end
    end
    return out
end

local function SanitizeBindings(src)
    local out = {}
    if type(src) ~= "table" then return ns.DeepCopy(ns.defaults.bindings) end
    for k, v in pairs(src) do
        if type(k) == "string" and type(v) == "string" then
            local mod, btn = k:match("^(%a+):(%d)$")
            if mod and ns.MODS[mod] and tonumber(btn) >= 1 and tonumber(btn) <= 5 and #v <= 255 then
                out[k] = v
            end
        end
    end
    return out
end

---------------------------------------------------------------------
-- API pública
---------------------------------------------------------------------
function ns.ExportProfile()
    local data = {
        v = 1,
        opts = ns.db.opts,
        bindings = ns.db.bindings,
        left = ns.db.left,
        top = ns.db.top,
    }
    local parts = {}
    Ser(data, parts)
    local raw = table.concat(parts)
    return "MHOT1:" .. string.format("%x", Checksum(raw)) .. ":" .. B64Encode(raw)
end

-- Devuelve true, o false + mensaje de error
function ns.ImportProfile(text)
    if InCombatLockdown() then return false, "No se puede importar en combate." end
    text = strtrim(text or "")
    local sum, b64 = text:match("^MHOT1:(%x+):(.+)$")
    if not sum then return false, "El texto no tiene el formato de MalvaeHoT (debe empezar por MHOT1:)." end
    local raw = B64Decode(b64)
    if not raw or raw == "" then return false, "El texto está dañado o incompleto." end
    if string.format("%x", Checksum(raw)) ~= sum:lower() then
        return false, "El texto está dañado o incompleto (la suma de comprobación no coincide)."
    end
    local ok, data = pcall(Parse, raw)
    if not ok or type(data) ~= "table" or data.v ~= 1 or type(data.opts) ~= "table" then
        return false, "No se pudo leer la configuración del texto."
    end

    local p = ns.db
    p.opts = SanitizeOpts(data.opts, ns.defaults.opts)
    p.bindings = SanitizeBindings(data.bindings)
    if type(data.left) == "number" and type(data.top) == "number" then
        p.left = math.max(-5000, math.min(5000, data.left))
        p.top = math.max(-5000, math.min(5000, data.top))
    end
    p.dispelInit = true
    ns.auraSets = {}
    ns.ApplyAllBindings()
    ns.ApplyLayout()
    if ns.RefreshOptions then ns.RefreshOptions() end
    return true
end
