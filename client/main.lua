--[[
    gc_els | client/main.lua
    Fahrzeug-Erkennung, Status-Verwaltung, Haupt-Threads.

    AUTO-DETECTION:
    - Fahrzeuge der Klasse 18 (Einsatzfahrzeuge) werden automatisch erkannt
    - Zusaetzliche Modelle koennen in Config.AdditionalModels eingetragen werden
    - Extras werden automatisch gescannt (siehe lights.lua)
    - kein XML / VCF noetig!
--]]

-- ─── Globaler ELS-Zustand ─────────────────────────────────────────────────────

ELS = {
    vehicle  = 0,     -- Aktives Fahrzeug (Entity-Handle)
    active   = false, -- ELS gerade aktiv?
    stage    = 0,     -- 0=aus | 1=Lichter | 2=Lichter+Sirene
    tone     = 1,     -- Aktiver Sirenentonart-Index
    pattern  = 1,     -- Aktives Lichtmuster-Index
    warning  = false, -- Warnlichter aktiv?
    frame    = 0,     -- Pattern-Frame-Zaehler (wird vom Pattern-Thread hochgezaehlt)
}

-- ─── Interne Hilfsfunktionen ──────────────────────────────────────────────────

-- Prueft ob ein Fahrzeug ELS-faehig ist (auto-detection)
local function IsELSVehicle(vehicle)
    if not DoesEntityExist(vehicle) or vehicle == 0 then return false end

    -- Klassen-basierte Erkennung (Hauptweg)
    local class = GetVehicleClass(vehicle)
    for _, c in ipairs(Config.ELSClasses) do
        if class == c then return true end
    end

    -- Modell-basierte Erkennung (fuer Nicht-Klasse-18 Fahrzeuge)
    local model = GetEntityModel(vehicle)
    for _, name in ipairs(Config.AdditionalModels) do
        if model == GetHashKey(name) then return true end
    end

    return false
end

-- Netzwerk-ID eines Fahrzeugs sicher abfragen
local function GetVehicleNetId(vehicle)
    if not DoesEntityExist(vehicle) then return nil end
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if NetworkIsNetworkIdValid(netId) then
        return netId
    end
    return nil
end

-- ─── Aktivierung / Deaktivierung ──────────────────────────────────────────────

local function DeactivateELS(vehicle)
    if not vehicle or vehicle == 0 then return end

    if Config.SirenOffOnExit then
        LightsOff(vehicle)
        SetVehicleSiren(vehicle, false)
        SetVehicleHasMutedSirens(vehicle, false)

        local netId = GetVehicleNetId(vehicle)
        if netId then
            TriggerServerEvent('gc_els:syncStage', netId, 0, 1, false)
        end
    end

    ELS.vehicle = 0
    ELS.active  = false
    ELS.stage   = 0
    ELS.warning = false
    ELS.frame   = 0

    HidePanel()
    ShowHUDNotification('~r~ELS~w~ deaktiviert.')
end

local function ActivateELS(vehicle)
    ELS.vehicle  = vehicle
    ELS.active   = true
    ELS.stage    = 0
    ELS.warning  = false
    ELS.frame    = 0

    -- Extras automatisch scannen und gruppieren
    local count = ScanExtras(vehicle)

    -- Sound stumm beim Einsteigen (Stage 0 = kein Ton)
    SetVehicleHasMutedSirens(vehicle, true)

    -- NUI-Panel oeffnen
    ShowPanel()

    local cls = GetVehicleClass(vehicle)
    ShowHUDNotification(string.format(
        '~b~ELS~w~ aktiv | Klasse ~y~%d~w~ | ~g~%d~w~ Extras erkannt | ~y~Q~w~ = Stage',
        cls, count
    ))

    if Config.Debug then
        print(string.format('[gc_els] Aktiviert | Vehicle: %d | Klasse: %d | Extras: %d',
            vehicle, cls, count))
    end
end

-- ─── Fahrzeug-Monitor Thread ──────────────────────────────────────────────────
-- Laeuft alle 500ms - erkennt Fahrzeugwechsel

Citizen.CreateThread(function()
    local lastVehicle = 0

    while true do
        local ped     = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= lastVehicle then
            -- Altes ELS-Fahrzeug verlassen
            if lastVehicle ~= 0 and ELS.active then
                DeactivateELS(lastVehicle)
            end

            -- Neues Fahrzeug betreten
            if vehicle ~= 0 and IsELSVehicle(vehicle) then
                ActivateELS(vehicle)
            end

            lastVehicle = vehicle
        end

        Citizen.Wait(500)
    end
end)

-- ─── Pattern-Engine Thread ────────────────────────────────────────────────────
-- Laeuft mit Config.FlashDelay - steuert NUR die Extras (physische Lichtmodelle).
-- SetVehicleSiren und DrawLightWithRangeAndShadow laufen in eigenen Threads
-- damit die Umgebungsbeleuchtung nicht mit dem Pattern flackert.

Citizen.CreateThread(function()
    while true do
        if ELS.active and DoesEntityExist(ELS.vehicle) and ELS.stage > 0 then
            ApplyPattern(ELS.vehicle, ELS.stage, ELS.pattern, ELS.warning, ELS.frame)
            ELS.frame = ELS.frame + 1
            Citizen.Wait(Config.FlashDelay)
        else
            Citizen.Wait(100)
        end
    end
end)

-- ─── Env-Corona-Licht Thread (frame-rate) ─────────────────────────────────────
-- DrawLightWithRangeAndShadow muss JEDEN FRAME gezeichnet werden (sonst flackert es).
-- Trennung vom Pattern-Thread verhindert Umgebungs-Flackern beim Blinken.
-- Config.EnvLight.syncWithPattern steuert ob Umgebung mit blinkt oder Dauerlicht ist.

Citizen.CreateThread(function()
    while true do
        if ELS.active and DoesEntityExist(ELS.vehicle) and ELS.stage > 0 then
            DrawVehicleCoronaLight(ELS.vehicle)
        end
        Citizen.Wait(0)   -- jeden Frame
    end
end)

-- ─── Oeffentliche Steuerungsfunktionen ────────────────────────────────────────

-- Stage setzen (0=aus, 1=lichter, 2=sirene)
function SetELSStage(stage)
    if not ELS.active or not DoesEntityExist(ELS.vehicle) then return end

    ELS.stage = stage

    if stage == 0 then
        -- Alles aus: Extras, Sirene und Sound aus
        LightsOff(ELS.vehicle)
        SetVehicleSiren(ELS.vehicle, false)
        SetVehicleHasMutedSirens(ELS.vehicle, false)
        local netId = GetVehicleNetId(ELS.vehicle)
        if netId then
            TriggerServerEvent('gc_els:syncStage', netId, 0, ELS.pattern, false)
        end

    elseif stage == 1 then
        -- Nur Lichter: native Sirene AN fuer visuelle Effekte, aber Sound stumm
        SetVehicleSiren(ELS.vehicle, true)
        SetVehicleHasMutedSirens(ELS.vehicle, true)  -- kein Sound bei Stage 1
        local netId = GetVehicleNetId(ELS.vehicle)
        if netId then
            TriggerServerEvent('gc_els:syncStage', netId, 1, ELS.pattern, ELS.warning)
        end

    elseif stage == 2 then
        -- Lichter + Sirene: wm-serversirens ist ein Audio-Pack (kein Lua).
        -- Die Sirene spielt automatisch wenn SetVehicleSiren=true und NICHT stumm ist.
        -- SetVehicleHasMutedSirens(false) = Sound freigeben!
        SetVehicleSiren(ELS.vehicle, true)
        SetVehicleHasMutedSirens(ELS.vehicle, false)  -- Sound EIN → wm-serversirens Audio spielt
        local netId = GetVehicleNetId(ELS.vehicle)
        if netId then
            TriggerServerEvent('gc_els:syncStage', netId, 2, ELS.pattern, ELS.warning)
        end
    end

    UpdatePanel()
end

-- Naechste Stage (0->1->2->0)
function CycleELSStage()
    SetELSStage((ELS.stage + 1) % 3)
end

-- Naechstes Lichtmuster
function NextPattern()
    if not ELS.active then return end
    local count = #Config.LightPatterns
    ELS.pattern = (ELS.pattern % count) + 1
    ELS.frame   = 0
    UpdatePanel()

    if Config.Debug then
        local p = Config.LightPatterns[ELS.pattern]
        print('[gc_els] Muster: ' .. (p and p.name or ELS.pattern))
    end
end

-- Warnlichter umschalten
function ToggleWarning()
    if not ELS.active then return end
    ELS.warning = not ELS.warning
    ELS.frame   = 0
    UpdatePanel()
end

-- Sirenentonart setzen
function SetSirenTone(idx)
    if not ELS.active then return end
    if not Config.SirenTones[idx] then return end
    ELS.tone = idx

    -- Wenn Stage 2 aktiv: Ton sofort an Server senden
    if ELS.stage >= 2 then
        local netId = GetVehicleNetId(ELS.vehicle)
        if netId then
            TriggerServerEvent('gc_els:setSiren', netId, ELS.tone, true)
        end
    end
    UpdatePanel()
end

-- Manuelle Sirene (kurzes Hupen)
local manualHornActive = false
function ManualHorn(active)
    if not ELS.active then return end
    if manualHornActive == active then return end
    manualHornActive = active

    -- Nur Siren-Mute toggling noetig (kein Export, wm-serversirens ist Audio-Pack)
    SetVehicleHasMutedSirens(ELS.vehicle, not active)
end

-- ─── Netzwerk-Events (von Server) ─────────────────────────────────────────────

-- Licht-Stage anderer Spieler empfangen und anzeigen
RegisterNetEvent('gc_els:receiveStage')
AddEventHandler('gc_els:receiveStage', function(netId, stage, pattern, warning)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then return end
    if vehicle == ELS.vehicle then return end -- Eigenes Fahrzeug ignorieren

    -- Vereinfachte Remote-Darstellung: Siren an/aus
    if stage == 0 then
        SetVehicleSiren(vehicle, false)
    else
        SetVehicleSiren(vehicle, true)
        -- Remote Fahrzeuge bekommen ihren eigenen nativen Sound (falls kein wm-serversirens)
        SetVehicleHasMutedSirens(vehicle, stage == 1)
    end
end)

-- ─── Exports fuer andere Resources ───────────────────────────────────────────

exports('getState',  function() return ELS         end)
exports('isActive',  function() return ELS.active  end)
exports('getStage',  function() return ELS.stage   end)
exports('setStage',  function(s) SetELSStage(s)    end)
exports('setTone',   function(t) SetSirenTone(t)   end)
