--[[
    gc_els | client/input.lua
    Tastenbelegung via FiveM RegisterKeyMapping.
    Spieler koennen alle Tasten in den FiveM-Einstellungen (Esc -> Einstellungen -> Keybinds) anpassen.
--]]

-- ─── GUI-Toggle (P = Panel Interact-Modus) ────────────────────────────────────

RegisterKeyMapping('gc_els_gui', 'ELS Panel (Interagieren ein/aus)', 'keyboard', 'P')
RegisterCommand('gc_els_gui', function()
    TogglePanelInteract()
end, false)

-- ─── Key Mappings registrieren ────────────────────────────────────────────────

-- ELS Stage wechseln (Aus / Lichter / Lichter + Sirene)
RegisterKeyMapping('gc_els_stage', Config.Keys.stage.desc, 'keyboard', Config.Keys.stage.key)
RegisterCommand('gc_els_stage', function()
    CycleELSStage()
end, false)

-- Sirenentonart 1
RegisterKeyMapping('gc_els_tone1', Config.Keys.sirenTone1.desc, 'keyboard', Config.Keys.sirenTone1.key)
RegisterCommand('gc_els_tone1', function()
    SetSirenTone(1)
end, false)

-- Sirenentonart 2
RegisterKeyMapping('gc_els_tone2', Config.Keys.sirenTone2.desc, 'keyboard', Config.Keys.sirenTone2.key)
RegisterCommand('gc_els_tone2', function()
    SetSirenTone(2)
end, false)

-- Sirenentonart 3
RegisterKeyMapping('gc_els_tone3', Config.Keys.sirenTone3.desc, 'keyboard', Config.Keys.sirenTone3.key)
RegisterCommand('gc_els_tone3', function()
    SetSirenTone(3)
end, false)

-- Sirenentonart 4
RegisterKeyMapping('gc_els_tone4', Config.Keys.sirenTone4.desc, 'keyboard', Config.Keys.sirenTone4.key)
RegisterCommand('gc_els_tone4', function()
    SetSirenTone(4)
end, false)

-- Naechstes Lichtmuster
RegisterKeyMapping('gc_els_pattern', Config.Keys.patternNext.desc, 'keyboard', Config.Keys.patternNext.key)
RegisterCommand('gc_els_pattern', function()
    NextPattern()
end, false)

-- Warnlichter
RegisterKeyMapping('gc_els_warning', Config.Keys.warning.desc, 'keyboard', Config.Keys.warning.key)
RegisterCommand('gc_els_warning', function()
    ToggleWarning()
end, false)

-- Manuelle Sirene (nur aktiv solange Taste gehalten)
-- FiveM unterstuetzt kein nativens Key-Hold via RegisterKeyMapping,
-- daher nutzen wir einen Control-Check pro Frame.
local hornKey = nil

-- Mapped Control finden (GTA Control 86 = E-Taste in Fahrzeugen)
-- Wir lauschen auf den Command fuer Press, und ein Tick-Check fuer Release.

local manualHornPressed = false

Citizen.CreateThread(function()
    -- Warten bis alles geladen ist
    Citizen.Wait(2000)

    while true do
        if ELS and ELS.active then
            -- Control 86 = INPUT_VEH_HORN (E im Fahrzeug)
            -- Wir pruefen ob der Spieler gerade 'E' drueckt
            local pressing = IsDisabledControlPressed(0, 86)

            if pressing and not manualHornPressed then
                manualHornPressed = true
                ManualHorn(true)
                -- Nativen Horn-Sound unterdruecken (wm-serversirens uebernimmt)
                DisableControlAction(0, 86, true)
            elseif not pressing and manualHornPressed then
                manualHornPressed = false
                ManualHorn(false)
            end

            -- Horn-Control blockieren wenn ELS aktiv (verhindert nativen Hupklang)
            DisableControlAction(0, 86, true)
        end

        Citizen.Wait(0)
    end
end)

-- ─── Chat-Befehle (optional / Debug) ─────────────────────────────────────────

if Config.Debug then
    RegisterCommand('els', function(source, args)
        local sub = args[1]
        if sub == 'stage' then
            SetELSStage(tonumber(args[2]) or 0)
        elseif sub == 'pattern' then
            local idx = tonumber(args[2]) or 1
            ELS.pattern = idx
            ELS.frame   = 0
        elseif sub == 'info' then
            print(string.format('[gc_els] Stage: %d | Ton: %d | Muster: %d | Warning: %s | Extras: %d',
                ELS.stage, ELS.tone, ELS.pattern, tostring(ELS.warning), GetDetectedExtrasCount()))
        end
    end, false)
end
