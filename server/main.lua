--[[
    gc_els | server/main.lua
    Server-seitige Synchronisation und wm-serversirens Integration.

    WM-SERVERSIRENS:
    - Wenn wm-serversirens installiert und gestartet ist, wird der Sirenenklang
      serverseitig fuer alle nahen Spieler abgespielt (nicht nur der Fahrer hoert ihn)
    - Bei Stage 2 (Lichter + Sirene) wird der aktive Ton-Index an wm-serversirens uebergeben
    - Bei Stage 0/1 oder beim Verlassen wird die Sirene gestoppt
--]]

local RESOURCE_VERSION = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or 'unknown'

-- ─── Lizenz-Prüfung ───────────────────────────────────────────────────────────

local licenseValid = false

local function stopResourceWithError(reason)
    print('^1')
    print('^1  ################################################################')
    print('^1  ##  LIZENZ-FEHLER: ' .. tostring(reason))
    print('^1  ##  Die Resource wird gestoppt.')
    print('^1  ################################################################^7')
    ExecuteCommand('stop ' .. GetCurrentResourceName())
end

Citizen.CreateThread(function()
    Citizen.Wait(1000) -- warten bis Config geladen ist

    if type(ServerSecrets) ~= 'table' then
        print('^1[gc_els] FEHLER: server/server_secrets.lua nicht geladen! Bitte ensure prüfen.^7')
        licenseValid = true
        return
    end

    local apiUrl    = ServerSecrets.LicenseApiUrl       or ''
    local apiSecret = ServerSecrets.LicenseApiSecret    or ''
    local resName   = ServerSecrets.LicenseResourceName or GetCurrentResourceName()
    local licKey    = ServerSecrets.LicenseKey          or ''

    if apiUrl == '' then
        print('^3[gc_els] Kein Lizenzserver konfiguriert – überspringe API-Prüfung.^7')
        licenseValid = true
        return
    end

    local licDone    = false
    local licenseMsg = 'Unbekannter Fehler'

    PerformHttpRequest(
        apiUrl .. '/api/check_license.php',
        function(statusCode, body, headers)
            licDone = true
            if statusCode == 0 or statusCode >= 500 then
                print('^3[gc_els] Lizenzserver nicht erreichbar (HTTP ' .. tostring(statusCode) .. ') – Offline-Toleranz aktiv.^7')
                licenseValid = true
                return
            end
            local resp = body and json.decode(body)
            if not resp then
                local preview = body and body:sub(1, 300) or '(leer)'
                print('^1[gc_els] Ungültige API-Antwort (HTTP ' .. tostring(statusCode) .. ')^7')
                print('^1[gc_els] Body: ' .. preview .. '^7')
                licenseMsg   = 'Ungültige Antwort vom Lizenzserver (HTTP ' .. tostring(statusCode) .. ')'
                licenseValid = false
                return
            end
            if resp.valid == true then
                licenseValid = true
                print('^2[gc_els] Lizenz gültig: ' .. tostring(resp.message or 'OK') .. '^7')
            else
                licenseValid = false
                licenseMsg   = tostring(resp.message or 'Unbekannter Fehler')
            end
        end,
        'POST',
        'license_key=' .. licKey .. '&resource_name=' .. resName .. '&resource_version=' .. RESOURCE_VERSION .. '&api_secret=' .. apiSecret,
        { ['Content-Type'] = 'application/x-www-form-urlencoded' }
    )

    -- Auf Antwort warten (max. 10 Sekunden)
    local waited = 0
    while not licDone and waited < 10000 do
        Citizen.Wait(250)
        waited = waited + 250
    end
    if not licDone then
        print('^3[gc_els] Lizenzserver Timeout – Offline-Toleranz aktiv.^7')
        licenseValid = true
    end

    if not licenseValid then
        stopResourceWithError(licenseMsg)
        return
    end

    -- Version prüfen (nur Info, kein Stop)
    PerformHttpRequest(
        apiUrl .. '/api/check_version.php?' ..
            'resource_name=' .. resName .. '&current_version=' .. RESOURCE_VERSION .. '&api_secret=' .. apiSecret,
        function(statusCode, body, headers)
            if statusCode ~= 200 or not body then return end
            local resp = json.decode(body)
            if not resp or resp.up_to_date then return end
            print('^3')
            print('^3  ┌──────────────────────────────────────────────────────────────')
            print('^3  │  UPDATE VERFÜGBAR: v' .. tostring(resp.latest_version or '?') .. ' (Aktuell: v' .. RESOURCE_VERSION .. ')')
            if resp.changelog and resp.changelog ~= '' then
                print('^3  │  ' .. tostring(resp.changelog))
            end
            print('^3  └──────────────────────────────────────────────────────────────^7')
        end,
        'GET',
        '',
        {}
    )
end)

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
