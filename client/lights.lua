--[[
    gc_els | client/lights.lua
    Licht-Pattern-Engine mit XML-Fahrzeugkonfiguration und Auto-Detection-Fallback.

    XML-KONFIGURATION (VCF):
    - Fahrzeugeigene Configs in vcf/<modellname>.xml
    - Alle Modelle werden automatisch aus vcf/models.lua geladen (Config.VCFModels)
    - Unterstuetzt Standard ELS VCF Format (EOVERRIDE) UND GC ELS Einfach-Format
    - Fallback auf Auto-Detection wenn kein XML fuer das Fahrzeug vorhanden

    LICHT vs. UMGEBUNG:
    - Extras (physische Lichtmodelle): blinken mit Pattern-Thread (jede 60ms)
    - SetVehicleSiren: wird einmalig gesetzt (kein per-Frame Toggle → kein Umgebungs-Flackern)
    - DrawLightWithRangeAndShadow: laeuft in eigenem Frame-Thread (kein Flackern)
    - Config.EnvLight.syncWithPattern = false → Umgebungslicht als Dauerlicht
    - Config.EnvLight.syncWithPattern = true  → Umgebungslicht blinkt mit

    DEBUG-LOG:
    - Jedes Fahrzeug wird beim Betreten analysiert und geloggt
    - Fehler (fehlende Extras, keine XML) werden immer geloggt (nicht nur im Debug-Modus)
    - Erfolgreiche Configs nur bei Config.Debug = true
--]]

-- ─── VCF Cache ─────────────────────────────────────────────────────────────────

local vcfCache = {}   -- [modelHash] = { modelName, groupA = {...}, groupB = {...}, colorA, colorB }

-- Farb-Mapping: XML-Farbname → RGB  (österr. Standard = blau)
local colorMap = {
    blue   = { r = 0,   g = 20,  b = 255 },
    red    = { r = 255, g = 0,   b = 0   },
    green  = { r = 0,   g = 200, b = 0   },
    white  = { r = 255, g = 255, b = 255 },
    amber  = { r = 255, g = 140, b = 0   },
    yellow = { r = 255, g = 220, b = 0   },
}

-- ─── Aktueller Lichtzustand (für Env-Corona Thread in main.lua) ───────────────

local lightState = { a = false, b = false }  -- Wird von ApplyPattern gesetzt
local envColorA  = nil  -- Aktive Env-Farbe Gruppe A (aus XML, nil = Config-Fallback)
local envColorB  = nil  -- Aktive Env-Farbe Gruppe B (aus XML, nil = Config-Fallback)

function GetLightState()
    return lightState
end

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
-- Logik:
--   OffsetX < 0  → Gruppe A (links)
--   OffsetX > 0  → Gruppe B (rechts)
--   OffsetX = 0 oder fehlt → Gruppe A (Mitte/Fallback)
-- Liest auch Color="..." und ermittelt die dominante Farbe je Gruppe.
local function ParseELSVCFFormat(content, modelName)
    local gA = {}
    local gB = {}
    local parsed = 0
    local colorCountA = {}
    local colorCountB = {}

    for line in content:gmatch('[^\r\n]+') do
        local extraNum = line:match('<Extra(%d+)%s')
        if extraNum and line:find('IsElsControlled="true"') then
            local num     = tonumber(extraNum)
            local offsetX = tonumber(line:match('OffsetX="([^"]+)"'))
            local color   = line:match('Color="([^"]+)"')
            if num then
                parsed = parsed + 1
                if offsetX and offsetX > 0 then
                    gB[#gB + 1] = num
                    if color then colorCountB[color] = (colorCountB[color] or 0) + 1 end
                else
                    gA[#gA + 1] = num
                    if color then colorCountA[color] = (colorCountA[color] or 0) + 1 end
                end
            end
        end
    end

    if #gA == 0 and #gB == 0 then
        if Config.Debug then
            print(string.format('[gc_els] ⚠ VCF %s: EOVERRIDE gefunden aber kein IsElsControlled="true" Eintrag', modelName))
        end
        return nil
    end

    -- Dominante Farbe pro Gruppe (die Farbe mit den meisten Extras gewinnt)
    local function dominant(counts)
        local best, bestN = nil, 0
        for c, n in pairs(counts) do if n > bestN then best = c; bestN = n end end
        return best
    end

    return {
        modelName   = modelName,
        groupA      = gA,
        groupB      = gB,
        colorA      = dominant(colorCountA),  -- z.B. "blue"
        colorB      = dominant(colorCountB),
        parsedLines = parsed,
    }
end

-- Parst eine VCF-XML-Datei.
-- Unterstützte Formate:
--   1. GC ELS Einfach-Format   (<metadata><modelName> + <lightingGroup><groupA extras="...">)
--   2. Standard ELS VCF        (<EOVERRIDE IsElsControlled="true" OffsetX=...>)
local function ParseVehicleXML(content, modelName)
    if not content then return nil end

    -- ── Format 1: GC ELS Einfach-Format ──────────────────────────────────────
    local gcModel = content:match('<modelName%s+value="([^"]+)"')
    if gcModel then
        local gA = ParseExtras(content:match('<groupA%s+extras="([^"]+)"'))
        local gB = ParseExtras(content:match('<groupB%s+extras="([^"]+)"'))
        if #gA > 0 or #gB > 0 then
            return { modelName = gcModel, groupA = gA, groupB = gB }
        end
        -- modelName-Tag vorhanden aber keine Extras → weiter zu Format 2
    end

    -- ── Format 2: Standard ELS VCF (EOVERRIDE) ───────────────────────────────
    if content:find('<EOVERRIDE') then
        return ParseELSVCFFormat(content, modelName)
    end

    return nil
end

-- ─── VCF Loader ───────────────────────────────────────────────────────────────

-- Laedt alle VCF-Configs beim Ressourcenstart.
-- Verwendet Config.VCFModels aus vcf/models.lua.
-- Loggt jeden Schritt fuer einfaches Debugging.
local function LoadAllVCFConfigs()
    local resName = GetCurrentResourceName()
    local models  = Config.VCFModels or {}
    local total   = #models
    local loaded  = 0
    local failed  = 0

    if total == 0 then
        print('[gc_els] WARNUNG: Config.VCFModels ist leer! Bitte vcf/models.lua pruefen.')
        return
    end

    for _, modelName in ipairs(models) do
        local path    = 'vcf/' .. modelName .. '.xml'
        local content = LoadResourceFile(resName, path)

        if not content then
            -- XML-Datei nicht gefunden
            failed = failed + 1
            print(string.format('[gc_els] ✘ VCF fehlt:  vcf/%s.xml  (in models.lua eingetragen aber Datei nicht vorhanden)', modelName))
        else
            local cfg = ParseVehicleXML(content, modelName)
            if cfg then
                -- Eintragen fuer beide Hash-Varianten (GTA ist case-insensitive bei Modellnamen)
                local hash = GetHashKey(modelName)
                vcfCache[hash] = cfg
                loaded = loaded + 1

                if Config.Debug then
                    print(string.format('[gc_els] ✓ VCF OK:   %-30s | Gruppe A: [%s] | Gruppe B: [%s]',
                        modelName,
                        table.concat(cfg.groupA, ','),
                        table.concat(cfg.groupB, ',')))
                end
            else
                -- Datei vorhanden aber kein erkanntes Format
                failed = failed + 1
                print(string.format('[gc_els] ✘ VCF Parse-Fehler: %s  (kein EOVERRIDE/groupA-Block – Format pruefen)', path))
            end
        end
    end

    print(string.format('[gc_els] VCF-Index: %d/%d geladen | %d Fehler | %d Fahrzeuge nutzen Auto-Detection',
        loaded, total, failed, failed))
end

Citizen.CreateThread(function()
    LoadAllVCFConfigs()
end)

-- ─── Extras State ─────────────────────────────────────────────────────────────

local extrasA    = {}   -- Gruppe A (linke/vordere Lichter)
local extrasB    = {}   -- Gruppe B (rechte/hintere Lichter)
local allExtras  = {}   -- Alle aktiven Extras des aktuellen Fahrzeugs
local currentModelName = 'unbekannt'

-- Gibt Anzahl der erkannten Extras zurueck (extern sichtbar)
function GetDetectedExtrasCount()
    return #allExtras
end

-- ─── Extra-Scanning & Diagnose ────────────────────────────────────────────────

function ScanExtras(vehicle)
    extrasA         = {}
    extrasB         = {}
    allExtras       = {}
    lightState.a    = false
    lightState.b    = false
    envColorA       = nil
    envColorB       = nil
    currentModelName = 'unbekannt'

    if not DoesEntityExist(vehicle) then return 0 end

    local modelHash  = GetEntityModel(vehicle)
    local modelLabel = GetDisplayNameFromVehicleModel(modelHash) or ''
    -- Fallback auf Hash-Hex wenn kein lesbarer Name
    if modelLabel == '' or modelLabel == 'NULL' then
        modelLabel = string.format('0x%08X', modelHash)
    end

    -- ── XML-Config vorhanden → Extras aus VCF laden ────────────────────────────
    if vcfCache[modelHash] then
        local cfg = vcfCache[modelHash]
        currentModelName = cfg.modelName

        -- Env-Farben aus XML übernehmen (österr. Standard = blau)
        envColorA = cfg.colorA and colorMap[cfg.colorA] or nil
        envColorB = cfg.colorB and colorMap[cfg.colorB] or nil

        local missingA = {}
        local missingB = {}

        for _, extra in ipairs(cfg.groupA) do
            if DoesExtraExist(vehicle, extra) then
                extrasA[#extrasA + 1]     = extra
                allExtras[#allExtras + 1] = extra
            else
                missingA[#missingA + 1] = extra
            end
        end
        for _, extra in ipairs(cfg.groupB) do
            if DoesExtraExist(vehicle, extra) then
                extrasB[#extrasB + 1]     = extra
                allExtras[#allExtras + 1] = extra
            else
                missingB[#missingB + 1] = extra
            end
        end

        -- Diagnose-Log
        local hasMissing = #missingA > 0 or #missingB > 0

        if #allExtras == 0 then
            -- Kritisch: alle XML-Extras fehlen am Modell → Auto-Fix via Scan 1-20
            print(string.format(
                '[gc_els] ✘ %s (%s): Kein XML-Extra am Modell! XML: A:[%s] B:[%s]\n' ..
                '         → Auto-Fix: scanne Extras 1-20 am Fahrzeug …',
                cfg.modelName, modelLabel,
                table.concat(cfg.groupA, ','),
                table.concat(cfg.groupB, ',')))

            local found = {}
            for i = 1, 20 do
                if DoesExtraExist(vehicle, i) then found[#found + 1] = i end
            end
            if #found > 0 then
                local half = math.ceil(#found / 2)
                for i, extra in ipairs(found) do
                    allExtras[#allExtras + 1] = extra
                    if i <= half then extrasA[#extrasA + 1] = extra
                    else              extrasB[#extrasB + 1] = extra end
                end
                print(string.format(
                    '[gc_els]   ✓ Auto-Fix OK: %d Extras | A:[%s] B:[%s]',
                    #allExtras, table.concat(extrasA, ','), table.concat(extrasB, ',')))
            else
                print('[gc_els]   ✘ Auto-Fix: Auch kein Extra 1-20 vorhanden – Blinken nicht moeglich.')
            end
        elseif hasMissing then
            -- Teilweise fehlende Extras (funktionierende bleiben aktiv)
            print(string.format(
                '[gc_els] ⚠ %s (%s): %d von %d XML-Extras fehlen.\n' ..
                '         Fehlend A:[%s]  Fehlend B:[%s]\n' ..
                '         Aktiv: A:[%s] B:[%s] (%d Lichter OK)',
                cfg.modelName, modelLabel,
                #missingA + #missingB,
                #cfg.groupA + #cfg.groupB,
                table.concat(missingA, ','),
                table.concat(missingB, ','),
                table.concat(extrasA, ','),
                table.concat(extrasB, ','),
                #allExtras))
        elseif Config.Debug then
            print(string.format(
                '[gc_els] ✓ %s: %d Lichter OK | A:[%s] | B:[%s] | Farbe A:%s B:%s',
                cfg.modelName, #allExtras,
                table.concat(extrasA, ','),
                table.concat(extrasB, ','),
                cfg.colorA or 'config',
                cfg.colorB or 'config'))
        end

        return #allExtras
    end

    -- ── Fallback: Auto-Detection ───────────────────────────────────────────────
    currentModelName = modelLabel

    local found = {}
    for i = 1, 20 do
        if DoesExtraExist(vehicle, i) then
            found[#found + 1] = i
        end
    end

    if #found == 0 then
        print(string.format(
            '[gc_els] ✘ %s: Keine Extras am Fahrzeug (kein XML, Auto-Detection auch 0). ' ..
            'Blaulicht-Blinken nicht moeglich.',
            modelLabel))
        return 0
    end

    -- Gleichmaessig aufteilen: erste Haelfte A, Rest B
    local half = math.ceil(#found / 2)
    for i, extra in ipairs(found) do
        allExtras[#allExtras + 1] = extra
        if i <= half then
            extrasA[#extrasA + 1] = extra
        else
            extrasB[#extrasB + 1] = extra
        end
    end

    -- Auto-Detection immer loggen (kein XML vorhanden)
    print(string.format(
        '[gc_els] ℹ %s: Auto-Detection | %d Extras | A:[%s] | B:[%s] | (Kein VCF in vcf/models.lua)',
        modelLabel, #allExtras,
        table.concat(extrasA, ','),
        table.concat(extrasB, ',')))

    return #allExtras
end

-- ─── Extra-Steuerung ──────────────────────────────────────────────────────────

local function SetExtrasVisible(vehicle, extras, visible)
    -- SetVehicleExtra: 3. Parameter disabled (true = aus/versteckt, false = an/sichtbar)
    local disabled = not visible
    for _, extra in ipairs(extras) do
        SetVehicleExtra(vehicle, extra, disabled)
    end
end

-- Setzt alle Extras auf ihren Standard-Zustand (sichtbar/an) und Sirene aus
function LightsOff(vehicle)
    if not DoesEntityExist(vehicle) then return end
    SetVehicleSiren(vehicle, false)
    -- Extras wieder sichtbar (disabled=false = sichtbar = Standard)
    for _, extra in ipairs(allExtras) do
        SetVehicleExtra(vehicle, extra, false)
    end
    lightState.a = false
    lightState.b = false
end

-- ─── Pattern-Logik ────────────────────────────────────────────────────────────

-- Liest den Pattern-Wert an Position 'frame' (mod Laenge des Strings)
local function GetPatternBit(pattern, frame)
    if not pattern or #pattern == 0 then return false end
    local idx = (frame % #pattern) + 1
    return pattern:sub(idx, idx) == '1'
end

-- Wendet das aktuelle Pattern auf das Fahrzeug an.
-- Aufgerufen vom Pattern-Thread in main.lua (alle Config.FlashDelay ms).
--
-- WICHTIG: SetVehicleSiren wird hier NICHT pro Frame getoggelt.
-- Die native Sirene bleibt steady an/aus (gesetzt via SetELSStage in main.lua).
-- Nur die Extras blinken per Pattern – das verhindert Umgebungs-Flackern.
function ApplyPattern(vehicle, stage, patternIdx, warningActive, frame)
    if not DoesEntityExist(vehicle) then return end

    -- Warnlichter-Modus: alle Lichter gemeinsam nach Warnmuster
    if warningActive then
        local on = GetPatternBit(Config.WarningPattern, frame)
        SetExtrasVisible(vehicle, allExtras, on)
        lightState.a = on
        lightState.b = on
        return
    end

    -- Normal-Modus: Gruppe A und B nach Pattern
    local pattern = Config.LightPatterns[patternIdx] or Config.LightPatterns[1]
    local aOn     = GetPatternBit(pattern.a, frame)
    local bOn     = GetPatternBit(pattern.b, frame)

    -- Extras blinken (physische Lichtmodelle)
    if #extrasA > 0 then SetExtrasVisible(vehicle, extrasA, aOn) end
    if #extrasB > 0 then SetExtrasVisible(vehicle, extrasB, bOn) end

    -- Wenn KEINE Extras vorhanden: native Sirene als Fallback toggeln
    -- (damit zumindest irgendein visueller Effekt sichtbar ist)
    if #allExtras == 0 then
        SetVehicleSiren(vehicle, aOn or bOn)
    end

    -- Zustand fuer Env-Corona Thread merken
    lightState.a = aOn
    lightState.b = bOn
end

-- ─── Umgebungs-Corona-Licht ───────────────────────────────────────────────────

-- Zeichnet das Umgebungs-Licht-Corona rund ums Fahrzeug.
-- Diese Funktion wird von einem EIGENEN Frame-Thread in main.lua aufgerufen
-- (Citizen.Wait(0)) damit das Licht konstant ohne Flackern leuchtet.
--
-- Config.EnvLight.syncWithPattern:
--   false → Dauerlicht sobald ELS aktiv (Umgebung leuchtet, Extras blinken)
--   true  → Folgt dem lightState (Umgebung blinkt mit – intensiver Effekt)
function DrawVehicleCoronaLight(vehicle)
    if not Config.EnvLight.enabled then return end
    if not DoesEntityExist(vehicle) then return end

    local cfg = Config.EnvLight
    local showL, showR

    if cfg.syncWithPattern then
        -- Synchron mit Pattern: linkes Corona an wenn Gruppe A leuchtet, rechts wenn B
        showL = lightState.a
        showR = lightState.b
    else
        -- Dauerlicht: beide Seiten immer an
        showL = true
        showR = true
    end

    if not showL and not showR then return end

    local coords  = GetEntityCoords(vehicle)
    local heading = GetEntityHeading(vehicle)
    local rad     = math.rad(heading)
    local side    = cfg.sideOffset   or 0.8
    local height  = cfg.heightOffset or 1.0

    -- Linke und rechte Position berechnen (relativ zur Fahrzeug-Ausrichtung)
    local lx = coords.x + math.sin(rad + math.pi / 2) * side
    local ly = coords.y - math.cos(rad + math.pi / 2) * side
    local rx = coords.x - math.sin(rad + math.pi / 2) * side
    local ry = coords.y + math.cos(rad + math.pi / 2) * side
    local z  = coords.z + height

    local rng  = cfg.range      or 14.0
    local bri  = cfg.brightness or 2.0
    local fall = cfg.falloff    or 3.5

    if showL then
        local c = envColorA or cfg.color  -- XML-Farbe wenn vorhanden, sonst Config-Fallback
        DrawLightWithRangeAndShadow(lx, ly, z, c.r, c.g, c.b, rng, bri, fall)
    end
    if showR then
        local c = envColorB or cfg.altColor  -- XML-Farbe wenn vorhanden, sonst Config-Fallback
        DrawLightWithRangeAndShadow(rx, ry, z, c.r, c.g, c.b, rng, bri, fall)
    end
end
