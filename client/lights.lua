--[[
    gc_els | client/lights.lua
    Licht-Pattern-Engine und automatische Extras-Erkennung.

    AUTO-DETECTION PRINZIP:
    - Das Skript scannt alle Extras (1-20) des Fahrzeugs
    - Gefundene Extras werden automatisch in Gruppe A (links/vorne) und
      Gruppe B (rechts/hinten) aufgeteilt
    - GTA's internes Sirenen-System wird fuer die Corona-Lichter genutzt
      (Position und Farbe kommen aus dem Fahrzeugmodell selbst - kein XML!)
    - Rapid-Toggle von SetVehicleSiren erzeugt das Blinklichter-Muster
--]]

-- ─── Extras State ─────────────────────────────────────────────────────────────

local extrasA    = {}   -- Gruppe A (erste Haelfte der gefundenen Extras)
local extrasB    = {}   -- Gruppe B (zweite Haelfte der gefundenen Extras)
local allExtras  = {}   -- Alle gefundenen Extras

-- Gibt Anzahl der erkannten Extras zurueck (extern sichtbar)
function GetDetectedExtrasCount()
    return #allExtras
end

-- ─── Extra-Scanning ───────────────────────────────────────────────────────────

-- Scannt alle moeglichen Extras (1-20) und teilt sie in A/B auf.
-- Extras auf Einsatzfahrzeugen sind typischerweise Lichtgruppen:
--   z.B. Extra 1-3 = vorne links, Extra 4-6 = vorne rechts, usw.
-- Durch automatisches Aufteilen wird ein sinnvoller Wechselblitz erzeugt.
function ScanExtras(vehicle)
    extrasA   = {}
    extrasB   = {}
    allExtras = {}

    if not DoesEntityExist(vehicle) then return 0 end

    for i = 1, 20 do
        if DoesExtraExist(vehicle, i) then
            table.insert(allExtras, i)
        end
    end

    local total = #allExtras
    local half  = math.ceil(total / 2)

    for i, extra in ipairs(allExtras) do
        if i <= half then
            table.insert(extrasA, extra)
        else
            table.insert(extrasB, extra)
        end
    end

    if Config.Debug then
        print(string.format('[gc_els] Extras gesamt: %d | Gruppe A: %d | Gruppe B: %d',
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
