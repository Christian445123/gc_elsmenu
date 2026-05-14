--[[
    gc_els | client/ui.lua
    NUI-Bridge: Verbindet das HTML-Panel mit der Lua-Spiellogik.

    Ablauf:
      - Spieler betritt ELS-Fahrzeug → ShowPanel()
      - Spieler verlässt Fahrzeug   → HidePanel()
      - Taste P                     → TogglePanelInteract() (Cursor ein/aus)
      - Jede Statusänderung         → UpdatePanel()
      - Button-Klick im Panel       → RegisterNUICallback → Lua-Funktion
--]]

local panelVisible   = false
local interactActive = false

-- ─── Panel-Sichtbarkeit ───────────────────────────────────────────────────────

function ShowPanel()
    if panelVisible then
        UpdatePanel()
        return
    end
    panelVisible = true

    -- Tone-Initialisierung (Buttons aufbauen)
    local tones = {}
    for i, t in ipairs(Config.SirenTones) do
        tones[i] = { name = t.name }
    end
    SendNUIMessage({ type = 'init', tones = tones })
    SendNUIMessage({ type = 'show' })
    UpdatePanel()
end

function HidePanel()
    if not panelVisible then return end
    panelVisible = false

    if interactActive then
        interactActive = false
        SetNuiFocus(false, false)
    end

    SendNUIMessage({ type = 'hide' })
end

-- ─── Interact-Modus (Cursor für Maus-Klicks) ──────────────────────────────────

function TogglePanelInteract()
    if not panelVisible then return end

    interactActive = not interactActive
    SetNuiFocus(interactActive, interactActive)
    SendNUIMessage({ type = 'setInteract', value = interactActive })

    if Config.Debug then
        print('[gc_els] Interact-Modus: ' .. tostring(interactActive))
    end
end

-- ─── Panel-Update (sendet aktuellen Zustand ans HTML) ─────────────────────────

function UpdatePanel()
    if not panelVisible then return end

    local pattern  = Config.LightPatterns[ELS.pattern] or {}
    local toneData = Config.SirenTones[ELS.tone]       or {}

    local tones = {}
    for i, t in ipairs(Config.SirenTones) do
        tones[i] = { name = t.name }
    end

    local vClass = 0
    if ELS.active and DoesEntityExist(ELS.vehicle) then
        vClass = GetVehicleClass(ELS.vehicle)
    end

    SendNUIMessage({
        type         = 'update',
        active       = ELS.active,
        stage        = ELS.stage,
        pattern      = ELS.pattern,
        patternName  = pattern.name  or ('Muster ' .. ELS.pattern),
        patternCount = #Config.LightPatterns,
        tone         = ELS.tone,
        toneName     = toneData.name or ('Ton '    .. ELS.tone),
        warning      = ELS.warning,
        extrasCount  = GetDetectedExtrasCount(),
        vehicleClass = vClass,
        tones        = tones,
    })
end

-- ─── NUI Callbacks (HTML-Button → Lua) ───────────────────────────────────────

-- Stage setzen (0=aus, 1=lichter, 2=sirene)
RegisterNUICallback('nuiSetStage', function(data, cb)
    SetELSStage(tonumber(data.stage) or 0)
    cb({})
end)

-- Sirenentonart setzen
RegisterNUICallback('nuiSetTone', function(data, cb)
    SetSirenTone(tonumber(data.tone) or 1)
    cb({})
end)

-- Nächstes Lichtmuster
RegisterNUICallback('nuiNextPattern', function(data, cb)
    NextPattern()
    cb({})
end)

-- Vorheriges Lichtmuster
RegisterNUICallback('nuiPrevPattern', function(data, cb)
    if ELS.active then
        local count = #Config.LightPatterns
        ELS.pattern = ((ELS.pattern - 2) % count) + 1
        ELS.frame   = 0
        UpdatePanel()
    end
    cb({})
end)

-- Warnlichter umschalten
RegisterNUICallback('nuiToggleWarning', function(data, cb)
    ToggleWarning()
    cb({})
end)

-- Interact-Modus schließen (ESC oder Close-Button)
RegisterNUICallback('nuiClose', function(data, cb)
    if interactActive then
        interactActive = false
        SetNuiFocus(false, false)
        SendNUIMessage({ type = 'setInteract', value = false })
    end
    cb({})
end)

-- ─── Panel-Sync Thread ────────────────────────────────────────────────────────
-- Hält das Panel alle 500ms aktuell (Fallback, falls ein Update verpasst wurde)

Citizen.CreateThread(function()
    while true do
        if panelVisible and ELS.active then
            UpdatePanel()
        end
        Citizen.Wait(500)
    end
end)
