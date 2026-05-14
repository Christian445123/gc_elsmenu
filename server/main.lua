--[[
    gc_els | server/main.lua
    Server-seitige Synchronisation und wm-serversirens Integration.

    WM-SERVERSIRENS:
    - Wenn wm-serversirens installiert und gestartet ist, wird der Sirenenklang
      serverseitig fuer alle nahen Spieler abgespielt (nicht nur der Fahrer hoert ihn)
    - Bei Stage 2 (Lichter + Sirene) wird der aktive Ton-Index an wm-serversirens uebergeben
    - Bei Stage 0/1 oder beim Verlassen wird die Sirene gestoppt
--]]

-- ─── wm-serversirens Hilfsfunktion ────────────────────────────────────────────

-- Sendet den Sirenen-Befehl an wm-serversirens (mit Fehlerbehandlung)
local function SetWMSiren(vehicle, toneIndex, active)
    if not Config.WMSirens.enabled then return end
    if GetResourceState(Config.WMSirens.resource) ~= 'started' then
        if Config.Debug then
            print('[gc_els] wm-serversirens nicht gestartet, ueberspringe.')
        end
        return
    end

    -- wm-serversirens API (pcall fuer Fehlertoleranz falls API sich aendert)
    local ok, err = pcall(function()
        if active and toneIndex > 0 then
            -- Sirene aktivieren mit Ton-Index
            -- wm-serversirens erwartet: vehicle (entity), tone (number)
            exports[Config.WMSirens.resource]:SetSirenTone(vehicle, toneIndex)
        else
            -- Sirene deaktivieren (Ton 0 = aus)
            exports[Config.WMSirens.resource]:SetSirenTone(vehicle, 0)
        end
    end)

    if not ok then
        -- Fallback: Versuche alternativen Event-Namen (verschiedene wm-serversirens Versionen)
        local ok2, err2 = pcall(function()
            if active then
                TriggerEvent(Config.WMSirens.resource .. ':setTone', vehicle, toneIndex)
            else
                TriggerEvent(Config.WMSirens.resource .. ':stopSiren', vehicle)
            end
        end)

        if Config.Debug then
            if not ok2 then
                print('[gc_els] wm-serversirens Fehler: ' .. tostring(err))
                print('[gc_els] wm-serversirens Fallback Fehler: ' .. tostring(err2))
            end
        end
    end
end

-- ─── Validierung ──────────────────────────────────────────────────────────────

-- Prueft ob der Spieler tatsaechlich im angegebenen Fahrzeug sitzt
local function ValidateDriver(source, netId)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then return false end

    local ped = GetPlayerPed(source)
    local driverPed = GetPedInVehicleSeat(vehicle, -1)

    -- Nur der Fahrer (Sitz -1) darf ELS steuern
    return ped == driverPed
end

-- ─── Events ───────────────────────────────────────────────────────────────────

-- Client -> Server: Sirene setzen (wm-serversirens weiterleiten)
RegisterNetEvent('gc_els:setSiren')
AddEventHandler('gc_els:setSiren', function(netId, toneIndex, active)
    local src     = source
    local vehicle = NetworkGetEntityFromNetworkId(netId)

    -- Sicherheits-Check: Ist der Spieler der Fahrer?
    if not ValidateDriver(src, netId) then
        if Config.Debug then
            print(string.format('[gc_els] Spieler %s ist kein Fahrer von NetID %d - ignoriert.', src, netId))
        end
        return
    end

    -- Ton-Index validieren
    if toneIndex < 0 or toneIndex > #Config.SirenTones then
        toneIndex = 0
        active    = false
    end

    -- wm-serversirens steuern
    if DoesEntityExist(vehicle) then
        SetWMSiren(vehicle, toneIndex, active)
    end

    -- An alle Clients weiterleiten (fuer Licht-Sync ohne wm-serversirens)
    TriggerClientEvent('gc_els:receiveSiren', -1, netId, toneIndex, active)

    if Config.Debug then
        print(string.format('[gc_els] Sirene | NetID: %d | Ton: %d | Aktiv: %s | Von: %s',
            netId, toneIndex, tostring(active), src))
    end
end)

-- Client -> Server: Licht-Stage synchronisieren
RegisterNetEvent('gc_els:syncStage')
AddEventHandler('gc_els:syncStage', function(netId, stage, pattern, warning)
    local src = source

    -- Validierung
    if not ValidateDriver(src, netId) then return end
    if stage < 0 or stage > 2 then return end

    -- An alle anderen Clients senden (nicht zurueck an den Sender)
    TriggerClientEvent('gc_els:receiveStage', -1, netId, stage, pattern, warning)

    if Config.Debug then
        print(string.format('[gc_els] Stage | NetID: %d | Stage: %d | Muster: %d | Warnung: %s',
            netId, stage, pattern, tostring(warning)))
    end
end)

-- ─── Resource-Lifecycle ───────────────────────────────────────────────────────

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Alle aktiven Sirenen stoppen wenn Resource gestoppt wird
    if Config.WMSirens.enabled and GetResourceState(Config.WMSirens.resource) == 'started' then
        local ok = pcall(function()
            -- wm-serversirens reset (falls Export vorhanden)
            exports[Config.WMSirens.resource]:StopAll()
        end)
        -- Kein Fehler-Log noetig - Stop-All ist optional
    end

    print('[gc_els] Resource gestoppt.')
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print('[gc_els] Server gestartet.')
        print(string.format('[gc_els] wm-serversirens: %s',
            Config.WMSirens.enabled and 'aktiviert' or 'deaktiviert'))
    end
end)
