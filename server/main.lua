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

-- ─── Startbanner ──────────────────────────────────────────────────────────────
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    local R = '^7'
    local T = '^1'
    local D = '^8'
    local G = '^2'
    local W = '^7'
    print(R)
    print(T .. '   ____   ____   _____ _     ____  __  __ _____ _   _ _   _ ' .. R)
    print(T .. '  / ___| / ___| | ____| |   / ___||  \\/  | ____| \\ | | | | |' .. R)
    print(W .. ' | |  _ | |     |  _| | |   \\___ \\| |\\/| |  _| |  \\| | | | |' .. R)
    print(W .. ' | |_| || |___  | |___| |___ ___) | |  | | |___| |\\  | |_| |' .. R)
    print(T .. '  \\____| \\____| |_____|_____|____/|_|  |_|_____|_| \\_|\\___/ ' .. R)
    print(R)
    print(D .. ' ##########################################################################' .. R)
    print(D .. ' ##                                                                      ##' .. R)
    print(D .. ' ##  ^7ELS Menu                            by GamingDevelopment    ##' .. R)
    print(D .. ' ##  ^7Version  ' .. G .. RESOURCE_VERSION .. D .. '                                              ##' .. R)
    print(D .. ' ##                                                                      ##' .. R)
    print(D .. ' ##########################################################################' .. R)
    print(R)
end)

-- ─── Lizenz-Prüfung ───────────────────────────────────────────────────────────

local licenseValid = false

local function stopResourceWithError(reason)
    print('^1')
    print('^1 ##########################################################################')
    print('^1 ##                                                                      ##')
    print('^1 ##  LIZENZ-FEHLER: gc_elsmenu                                          ##')
    print('^1 ##  ' .. tostring(reason))
    print('^1 ##                                                                      ##')
    print('^1 ##  Die Resource wird gestoppt. Bitte Lizenzkey prüfen.                ##')
    print('^1 ##########################################################################^7')
    StopResource(GetCurrentResourceName())
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

-- Sendet den Sirenen-Befehl an wm-serversirens.
-- Standard-API: SetVehicleSiren(netId, bool) – von den meisten Versionen unterstützt.
-- Fallback: Entity-Handle statt netId (ältere WolfKnight-Versionen).
-- netId   = Netzwerk-ID des Fahrzeugs
-- vehicle = Server-seitiger Entity-Handle (Fallback)
-- active  = boolean
local function SetWMSiren(netId, vehicle, toneIndex, active)
    if not Config.WMSirens.enabled then return end
    local res = Config.WMSirens.resource
    if GetResourceState(res) ~= 'started' then
        print(string.format('[gc_els] ⚠ wm-serversirens nicht gestartet! Resource: "%s"', res))
        return
    end

    -- Versuch 1: Standard-API mit netId (häufigste Version)
    local ok, err = pcall(function()
        exports[res]:SetVehicleSiren(netId, active)
    end)
    if ok then
        if Config.Debug then
            print(string.format('[gc_els] wm-serversirens OK: SetVehicleSiren(netId=%d, %s)', netId, tostring(active)))
        end
        return
    end

    -- Versuch 2: Entity-Handle statt netId (ältere WolfKnight-Versionen)
    ok = pcall(function()
        exports[res]:SetVehicleSiren(vehicle, active)
    end)
    if ok then
        if Config.Debug then
            print(string.format('[gc_els] wm-serversirens OK: SetVehicleSiren(entity, %s) [Fallback]', tostring(active)))
        end
        return
    end

    -- Letztmöglicher Fallback: Client-Event
    pcall(function()
        if active then
            TriggerClientEvent(res .. ':playServerSiren', -1, netId, toneIndex)
        else
            TriggerClientEvent(res .. ':stopServerSiren', -1, netId)
        end
    end)

    -- Immer loggen wenn alle Versuche fehlgeschlagen (nicht nur im Debug)
    print(string.format('[gc_els] ⚠ wm-serversirens: alle Server-Methoden fehlgeschlagen (letzter Fehler: %s)\n' ..
        '         → Client-seitige Aufrufe laufen parallel (main.lua). Falls keine Sirene: Config.WMSirens.resource pruefen.',
        tostring(err)))
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

    -- wm-serversirens steuern (netId bevorzugt, vehicle als Fallback)
    if DoesEntityExist(vehicle) then
        SetWMSiren(netId, vehicle, toneIndex, active)
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
AddEventHandler('gc_els:syncStage', function(netId, stage, pattern, warning, tone)
    local src = source

    -- Validierung
    if not ValidateDriver(src, netId) then return end
    if stage < 0 or stage > 2 then return end

    -- An alle Clients senden (inkl. Sender – damit remote-Clients den Sound spielen)
    TriggerClientEvent('gc_els:receiveStage', -1, netId, stage, pattern, warning, tone or 0)

    if Config.Debug then
        print(string.format('[gc_els] Stage | NetID: %d | Stage: %d | Muster: %d | Warnung: %s | Ton: %d',
            netId, stage, pattern, tostring(warning), tone or 0))
    end
end)

-- ─── Resource-Lifecycle ───────────────────────────────────────────────────────

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    -- Clients werden über den Resource-Stop informiert (Sirenen stoppen sich clientseitig)
    print('[gc_els] Resource gestoppt.')
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print('[gc_els] Server gestartet.')
        print('[gc_els] wm-serversirens: integriert (dlc_wmsirens/ Audio-Pack built-in)')
    end
end)
