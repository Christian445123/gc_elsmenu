--[[
    gc_els | client/lights.lua
    Licht-Pattern-Engine mit XML-Fahrzeugkonfiguration und Auto-Detection-Fallback.

    XML-KONFIGURATION (VCF):
    - Fahrzeugeigene Configs in vcf/<modellname>.xml
    - Definiert exakt welche Extras zu Gruppe A (links/vorne) und B (rechts/hinten) gehoeren
    - Config.VCFModels in config.lua listet alle Modelle mit XML-Datei auf
    - Fallback auf Auto-Detection wenn kein XML fuer das Fahrzeug vorhanden

    AUTO-DETECTION FALLBACK:
    - Scannt alle Extras (1-20) des Fahrzeugs
    - Teilt sie gleichmaessig in Gruppe A und B auf
    - GTA's internes Sirenen-System wird fuer die Corona-Lichter genutzt
--]]

-- ─── VCF Cache ─────────────────────────────────────────────────────────────────

local vcfCache = {}   -- [modelHash] = { modelName, groupA = {...}, groupB = {...} }

-- ─── XML Parser ───────────────────────────────────────────────────────────────

-- Parst komma- oder leerzeichen-getrennte Zahlen aus einem XML-Attributwert
local function ParseExtras(str)
    local result = {}
    if not str then return result end
    for n in str:gmatch('%d+') do
        result[#result + 1] = tonumber(n)
    end
    return result
end

-- Parst Standard-ELS-VCF-Format (EOVERRIDE-Sektion mit IsElsControlled + OffsetX)
-- Extras mit OffsetX < 0  → Gruppe A (links/vorne)
-- Extras mit OffsetX >= 0 → Gruppe B (rechts/hinten)
-- Extras ohne OffsetX aber IsElsControlled="true" → Gruppe A (Fallback)
local function ParseELSVCFFormat(content, modelName)
    local gA = {}
    local gB = {}

    for line in content:gmatch('[^\r\n]+') do
        local extraNum = line:match('<Extra(%d+)%s')
        if extraNum and line:find('IsElsControlled="true"') then
            local num     = tonumber(extraNum)
            local offsetX = tonumber(line:match('OffsetX="([^"]+)"'))
            if num then
                if offsetX and offsetX > 0 then
                    gB[#gB + 1] = num
                else
                    -- Negative OffsetX (links), OffsetX=0 (Mitte) oder kein Offset → Gruppe A
                    gA[#gA + 1] = num
                end
            end
        end
    end

    if #gA == 0 and #gB == 0 then return nil end
    return { modelName = modelName, groupA = gA, groupB = gB }
end

-- Parst den Inhalt einer VCF-XML-Datei.
-- Unterstuetzt beide Formate:
--   1. GC ELS Format   (<metadata><modelName> + <lightingGroup><groupA extras="...">)
--   2. Standard ELS VCF (<EOVERRIDE> mit IsElsControlled="true" und OffsetX)
local function ParseVehicleXML(content, modelName)
    if not content then return nil end

    -- ── Format 1: GC ELS Einfach-Format ─────────────────────────────────────
    local gcModel = content:match('<modelName%s+value="([^"]+)"')
    if gcModel then
        local gA = ParseExtras(content:match('<groupA%s+extras="([^"]+)"'))
        local gB = ParseExtras(content:match('<groupB%s+extras="([^"]+)"'))
        if #gA > 0 or #gB > 0 then
            return { modelName = gcModel, groupA = gA, groupB = gB }
        end
    end

    -- ── Format 2: Standard ELS VCF (EOVERRIDE) ───────────────────────────────
    if content:find('<EOVERRIDE') then
        return ParseELSVCFFormat(content, modelName)
    end

    return nil
end

-- Laedt alle VCF-Configs beim Ressourcenstart (aus Config.VCFModels)
local function LoadAllVCFConfigs()
    local resName = GetCurrentResourceName()
    local loaded  = 0
    local failed  = 0

    for _, modelName in ipairs(Config.VCFModels or {}) do
        local path    = 'vcf/' .. modelName .. '.xml'
        local content = LoadResourceFile(resName, path)
        if content then
            local cfg = ParseVehicleXML(content, modelName)
            if cfg then
                vcfCache[GetHashKey(modelName)] = cfg
                loaded = loaded + 1
                if Config.Debug then
                    print(string.format('[gc_els] VCF geladen: %s | A: %d | B: %d',
                        modelName, #cfg.groupA, #cfg.groupB))
                end
            else
                failed = failed + 1
                print('[gc_els] VCF Parse-Fehler: ' .. path)
            end
        else
            failed = failed + 1
            if Config.Debug then
                print('[gc_els] VCF nicht gefunden: ' .. path)
            end
        end
    end

    print(string.format('[gc_els] VCF-Configs: %d geladen, %d fehlgeschlagen', loaded, failed))
end

Citizen.CreateThread(function()
    LoadAllVCFConfigs()
end)

-- ─── Extras State ─────────────────────────────────────────────────────────────

local extrasA    = {}   -- Gruppe A (aus XML oder Auto-Detection)
local extrasB    = {}   -- Gruppe B (aus XML oder Auto-Detection)
local allExtras  = {}   -- Alle aktiven Extras des aktuellen Fahrzeugs

-- Gibt Anzahl der erkannten Extras zurueck (extern sichtbar)
function GetDetectedExtrasCount()
    return #allExtras
end

-- ─── Extra-Scanning ───────────────────────────────────────────────────────────

function ScanExtras(vehicle)
    extrasA   = {}
    extrasB   = {}
    allExtras = {}

    if not DoesEntityExist(vehicle) then return 0 end

    local modelHash = GetEntityModel(vehicle)

    -- ── XML-Config vorhanden → Extras aus VCF laden ────────────────────────────
    if vcfCache[modelHash] then
        local cfg = vcfCache[modelHash]

        for _, extra in ipairs(cfg.groupA) do
            if DoesExtraExist(vehicle, extra) then
                extrasA[#extrasA + 1]   = extra
                allExtras[#allExtras + 1] = extra
            end
        end
        for _, extra in ipairs(cfg.groupB) do
            if DoesExtraExist(vehicle, extra) then
                extrasB[#extrasB + 1]   = extra
                allExtras[#allExtras + 1] = extra
            end
        end

        if Config.Debug then
            print(string.format('[gc_els] XML-Config | %s | A: %d | B: %d',
                cfg.modelName, #extrasA, #extrasB))
        end
        return #allExtras
    end

    -- ── Fallback: Auto-Detection ───────────────────────────────────────────────
    for i = 1, 20 do
        if DoesExtraExist(vehicle, i) then
            allExtras[#allExtras + 1] = i
        end
    end

    local total = #allExtras
    local half  = math.ceil(total / 2)

    for i, extra in ipairs(allExtras) do
        if i <= half then
            extrasA[#extrasA + 1] = extra
        else
            extrasB[#extrasB + 1] = extra
        end
    end

    if Config.Debug then
        print(string.format('[gc_els] Auto-Detection | Gesamt: %d | A: %d | B: %d',
            total, #extrasA, #extrasB))
    end

    return total
end

-- ─── Extra-Steuerung ──────────────────────────────────────────────────────────

local function SetExtrasVisible(vehicle, extras, visible)
    -- SetVehicleExtra 3. Parameter: disabled (true = aus, false = an)
    local disabled = not visible
    for _, extra in ipairs(extras) do
        SetVehicleExtra(vehicle, extra, disabled)
    end
end

-- Alle Extras eines Fahrzeugs ausschalten
function LightsOff(vehicle)
    if not DoesEntityExist(vehicle) then return end
    SetVehicleSiren(vehicle, false)
    -- Extras in ihren Standard-Zustand zuruecksetzen (an)
    for _, extra in ipairs(allExtras) do
        SetVehicleExtra(vehicle, extra, false)
    end
end

-- ─── Pattern-Logik ────────────────────────────────────────────────────────────

-- Liest den Pattern-Wert an Position 'frame' (mod Laenge des Strings)
local function GetPatternBit(pattern, frame)
    if not pattern or #pattern == 0 then return false end
    local idx = (frame % #pattern) + 1
    return pattern:sub(idx, idx) == '1'
end

-- Haupt-Funktion: Wendet das aktuelle Pattern auf das Fahrzeug an.
-- Wird vom Pattern-Thread in main.lua aufgerufen.
function ApplyPattern(vehicle, stage, patternIdx, warningActive, frame)
    if not DoesEntityExist(vehicle) then return end

    -- Stage 0: alles aus
    if stage == 0 then
        SetVehicleSiren(vehicle, false)
        SetExtrasVisible(vehicle, allExtras, false)
        return
    end

    -- Warnlichter-Modus: alle Lichter gemeinsam nach Warnmuster
    if warningActive then
        local on = GetPatternBit(Config.WarningPattern, frame)
        SetVehicleSiren(vehicle, on)
        SetExtrasVisible(vehicle, allExtras, on)
        return
    end

    -- Normal-Modus: Gruppe A und B alternierend
    local pattern = Config.LightPatterns[patternIdx] or Config.LightPatterns[1]
    local aOn     = GetPatternBit(pattern.a, frame)
    local bOn     = GetPatternBit(pattern.b, frame)

    -- Extras steuern (wenn vorhanden)
    if #extrasA > 0 or #extrasB > 0 then
        SetExtrasVisible(vehicle, extrasA, aOn)
        SetExtrasVisible(vehicle, extrasB, bOn)
    end

    -- GTA Sirenen-Corona (internes Licht-System des Fahrzeugs)
    -- SetVehicleSiren aktiviert die im Fahrzeugmodell definierten Corona-Lichter.
    -- Durch Rapid-Toggle entsteht ein Blinkmuster OHNE externe XML-Config.
    -- Die Position und Farbe kommen direkt aus dem Fahrzeugmodell (sirenSettings).
    SetVehicleSiren(vehicle, aOn or bOn)
end

-- ─── Umgebungs-Corona-Licht ───────────────────────────────────────────────────

-- Zeichnet ein blaues/rotes Corona rund ums Fahrzeug (Bodenreflexion etc.)
-- Alterniert mit dem Pattern-Frame fuer einen Blitzeffekt
function DrawVehicleCoronaLight(vehicle)
    if not Config.EnvLight.enabled then return end
    if not DoesEntityExist(vehicle) then return end

    local coords = GetEntityCoords(vehicle)
    local heading = GetEntityHeading(vehicle)
    local rad = math.rad(heading)

    -- Offset links/rechts vom Fahrzeug berechnen
    local offsetDist = 0.8
    local lx = coords.x + math.sin(rad + math.pi / 2) * offsetDist
    local ly = coords.y - math.cos(rad + math.pi / 2) * offsetDist
    local rx = coords.x - math.sin(rad + math.pi / 2) * offsetDist
    local ry = coords.y + math.cos(rad + math.pi / 2) * offsetDist
    local z  = coords.z + 1.0

    local c    = Config.EnvLight.color
    local ca   = Config.EnvLight.altColor
    local rng  = Config.EnvLight.range
    local bri  = Config.EnvLight.brightness
    local fall = Config.EnvLight.falloff

    -- Blau links, Rot rechts (typisch fuer Oesterreich/Deutschland)
    DrawLightWithRangeAndShadow(lx, ly, z, c.r,  c.g,  c.b,  rng, bri, fall)
    DrawLightWithRangeAndShadow(rx, ry, z, ca.r, ca.g, ca.b, rng, bri, fall)
end
