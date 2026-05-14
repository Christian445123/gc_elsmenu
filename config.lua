--[[
    gc_els | config.lua
    Zentrale Konfiguration - hier werden alle Einstellungen vorgenommen.
    Keine XML-Dateien pro Fahrzeug noetig!
--]]

Config = {}

-- Debug-Modus: Gibt zusaetzliche Infos in der Konsole aus
Config.Debug = false

-- Flash-Delay in Millisekunden pro Pattern-Tick (kleiner = schneller flashen)
Config.FlashDelay = 70

-- Lichter/Sirene beim Verlassen des Fahrzeugs ausschalten
Config.SirenOffOnExit = true

-- HUD-Overlay anzeigen (Stage, Pattern, Ton)
Config.ShowHUD = true

-- ─── FAHRZEUG-ERKENNUNG ────────────────────────────────────────────────────────
-- Fahrzeugklassen die ELS erhalten. 18 = Einsatzfahrzeuge (Police, Ambulance, Fire)
-- Weitere Klassen: 14 = Industrial, 15 = Utility - bei Bedarf hinzufuegen
Config.ELSClasses = { 18 }

-- Zusaetzliche Modell-Namen die ELS erhalten sollen
-- (nuetzlich fuer Fahrzeuge die nicht Klasse 18 sind)
Config.AdditionalModels = {
    -- 'ambulance2',
    -- 'custom_police',
    -- 'fbi2',
}

-- ─── WM-SERVERSIRENS ──────────────────────────────────────────────────────────
Config.WMSirens = {
    enabled  = true,              -- wm-serversirens Unterstuetzung aktivieren
    resource = 'wm-serversirens', -- Name des wm-serversirens Resources
}

-- ─── SIRENEN-TÖNE ─────────────────────────────────────────────────────────────
-- index = Ton-Index der an wm-serversirens gesendet wird
Config.SirenTones = {
    [1] = { name = 'Wail',     index = 1 },
    [2] = { name = 'Yelp',     index = 2 },
    [3] = { name = 'Priority', index = 3 },
    [4] = { name = 'Air Horn', index = 4 },
}

-- ─── TASTEN ───────────────────────────────────────────────────────────────────
-- FiveM Key-Mapping: Spieler koennen die Tasten in den FiveM-Einstellungen anpassen.
-- Werte hier sind nur der Standard beim ersten Login.
Config.Keys = {
    stage       = { key = 'Q',       desc = 'ELS Stage wechseln (Aus/Lichter/Sirene)' },
    sirenTone1  = { key = 'NUMPAD1', desc = 'Sirenentonart 1 (Wail)'                  },
    sirenTone2  = { key = 'NUMPAD2', desc = 'Sirenentonart 2 (Yelp)'                  },
    sirenTone3  = { key = 'NUMPAD3', desc = 'Sirenentonart 3 (Priority)'               },
    sirenTone4  = { key = 'NUMPAD4', desc = 'Sirenentonart 4 (Air Horn)'               },
    patternNext = { key = 'NUMPAD9', desc = 'Naechstes Blinklichter-Muster'            },
    warning     = { key = 'BACK',    desc = 'Warnlichter umschalten'                   },
    manualHorn  = { key = 'E',       desc = 'Manuelle Sirene (Handtaste)'              },
}

-- ─── LICHTMUSTER ──────────────────────────────────────────────────────────────
-- 'a' = Gruppe A (linke/vordere Lichter)
-- 'b' = Gruppe B (rechte/hintere Lichter)
-- '1' = an, '0' = aus (pro Tick, Laenge bestimmt Zyklusdauer)
-- Die Muster werden kontinuierlich wiederholt.
--
-- AUTOMATISCHE ERKENNUNG:
-- Das Skript erkennt automatisch welche Extras ein Fahrzeug hat und
-- teilt sie in Gruppe A und B auf. Kein XML noetig!
Config.LightPatterns = {
    [1] = {
        name = 'Wechselblitz',
        a    = '111000111000111000111000',
        b    = '000111000111000111000111',
    },
    [2] = {
        name = 'Schnell Wechsel',
        a    = '1100110011001100',
        b    = '0011001100110011',
    },
    [3] = {
        name = 'Doppelblitz',
        a    = '110110000000110110000000',
        b    = '000000110110000000110110',
    },
    [4] = {
        name = 'Triple-Blitz',
        a    = '111100000000111100000000',
        b    = '000011110000000011110000',
    },
    [5] = {
        name = 'Strobe',
        a    = '101010101010101010101010',
        b    = '010101010101010101010101',
    },
    [6] = {
        name = 'Dauerlicht',
        a    = '111111111111111111111111',
        b    = '111111111111111111111111',
    },
}

-- Warnlicht-Muster (alle Lichter gemeinsam - z.B. Spurwechselwarnung)
Config.WarningPattern = '111100000000111100000000'

-- ─── UMGEBUNGS-CORONA-LICHT ───────────────────────────────────────────────────
-- Zeichnet ein blaues Licht-Corona rund um das Fahrzeug wenn ELS aktiv ist
Config.EnvLight = {
    enabled    = true,
    color      = { r = 0, g = 30, b = 255 }, -- Blau
    range      = 18.0,
    brightness = 3.0,
    falloff    = 4.0,
    -- Zusaetzlich rotes Corona auf der anderen Seite
    altColor   = { r = 255, g = 0, b = 0 },
}

-- ─── HUD POSITION ─────────────────────────────────────────────────────────────
Config.HUD = {
    x      = 0.012,  -- Links
    y      = 0.50,   -- Vertikal mittig
    size   = 0.38,   -- Schriftgroesse
    width  = 0.13,   -- Breite des HUD-Panels
}
