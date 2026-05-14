--[[
    gc_els | client/hud.lua
    Benachrichtigungen (Toast-Messages) fuer Statusaenderungen.
    Das NUI-Panel (ui/index.html) uebernimmt die vollstaendige HUD-Anzeige.
--]]

-- ─── Benachrichtigung (oben links, kurze Status-Meldung) ──────────────────────

function ShowHUDNotification(msg)
    SetNotificationTextEntry('STRING')
    AddTextComponentSubstringPlayerName(msg)
    DrawNotification(false, true)
end

