--[[
    gc_els | config.lua
    Zentrale Konfiguration - hier werden alle Einstellungen vorgenommen.
    Keine XML-Dateien pro Fahrzeug noetig!
--]]

Config = {}

-- Debug-Modus: Gibt zusaetzliche Infos in der Konsole aus
Config.Debug = false

-- Flash-Delay in Millisekunden pro Pattern-Tick (kleiner = schneller flashen)
-- 60ms = realistische Blaulicht-Frequenz (ca. 8 Hz bei einfachem Wechselblitz)
Config.FlashDelay = 60

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

-- ─── VCF-FAHRZEUGKONFIGURATION ────────────────────────────────────────────────
-- Die Fahrzeugliste wird AUTOMATISCH aus vcf/models.lua geladen.
-- Neue Fahrzeuge in vcf/models.lua eintragen, nicht hier.
-- Config.VCFModels wird von vcf/models.lua gesetzt (wird nach config.lua geladen).

-- ─── WM-SERVERSIRENS ──────────────────────────────────────────────────────────
Config.WMSirens = {
    enabled  = true,              -- wm-serversirens Unterstuetzung aktivieren
    resource = 'wm-serversirens', -- Name des wm-serversirens Resources
}

-- ─── SIRENEN-TÖNE ─────────────────────────────────────────────────────────────
-- index = Ton-Index der an wm-serversirens gesendet wird
-- Die Ton-Namen entsprechen den AudioStrings in den VCF-XML-Dateien
-- (wmsiren/siren_alpha = Ton 1, siren_bravo = Ton 2, siren_charlie = Ton 3, usw.)
Config.SirenTones = {
    [1] = { name = 'Alpha (Wail)',    index = 1 },
    [2] = { name = 'Bravo (Yelp)',   index = 2 },
    [3] = { name = 'Charlie (Prio)', index = 3 },
    [4] = { name = 'Air Horn',       index = 4 },
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
-- 'a' = Gruppe A (linke/vordere Lichter aus EOVERRIDE OffsetX < 0)
-- 'b' = Gruppe B (rechte/hintere Lichter aus EOVERRIDE OffsetX > 0)
-- '1' = an, '0' = aus (pro Tick, Laenge bestimmt Zyklusdauer)
-- Bei Config.FlashDelay = 60ms: 1 Tick = 60ms
Config.LightPatterns = {
    [1] = {
        -- Oesterreichischer Wechselblitz: Links 3x, dann Rechts 3x (klassisch)
        name = 'Wechselblitz AT',
        a    = '111000111000',
        b    = '000111000111',
    },
    [2] = {
        -- Schneller Wechsel (Doppelblitz links/rechts, hohe Frequenz)
        name = 'Doppelblitz Schnell',
        a    = '110110000000',
        b    = '000000110110',
    },
    [3] = {
        -- Dreifachblitz (3 schnelle Impulse, dann Pause)
        name = 'Dreifachblitz',
        a    = '101010000000101010000000',
        b    = '000000101010000000101010',
    },
    [4] = {
        -- Simultanblitz (alle Lichter gleichzeitig)
        name = 'Simultanblitz',
        a    = '111000111000',
        b    = '111000111000',
    },
    [5] = {
        -- Wig-Wag (langsames Links-Rechts wie US-Fahrzeuge)
        name = 'Wig-Wag',
        a    = '111111000000',
        b    = '000000111111',
    },
    [6] = {
        -- California-Muster (2 kurze + 1 langer Impuls)
        name = 'California',
        a    = '110110111111000000',
        b    = '000000000000110110',
    },
    [7] = {
        -- Strobe (sehr schnelle Einzelblitze)
        name = 'Strobe',
        a    = '10101010',
        b    = '01010101',
    },
    [8] = {
        -- Dauerlicht (beide Seiten dauerhaft an)
        name = 'Dauerlicht',
        a    = '11111111',
        b    = '11111111',
    },
}

-- Warnlicht-Muster (alle Lichter gemeinsam - z.B. Spurwechselwarnung)
-- Langsames, auffaelliges Blinken (~1 Hz)
Config.WarningPattern = '111111000000111111000000'

-- ─── UMGEBUNGS-CORONA-LICHT ───────────────────────────────────────────────────
-- Zeichnet ein farbiges Licht-Corona rund ums Fahrzeug (Bodenreflexion, Umgebungsbeleuchtung).
-- Laeuft in einem eigenen Frame-Thread → kein Flackern, saubere Trennung vom Blink-Pattern.
Config.EnvLight = {
    enabled         = true,

    -- SYNCHRONISATION:
    --   false (Standard) = Dauerlicht wenn ELS aktiv, kein Mitblinken → nur die Extras blinken
    --   true             = Blinkt synchron mit dem Lichtmuster (Umgebung blinkt mit)
    syncWithPattern = false,

    -- REICHWEITE & HELLIGKEIT:
    range           = 14.0,   -- Wie weit das Umgebungslicht reicht (in Metern)
    brightness      = 2.0,    -- Helligkeit (1.0 = normal, 3.0 = sehr hell)
    falloff         = 3.5,    -- Abfall mit Distanz (niedrig = sanft, hoch = scharf)

    -- POSITION (relativ zum Fahrzeugmittelpunkt):
    sideOffset      = 0.8,    -- Seitlicher Abstand vom Fahrzeug in Metern
    heightOffset    = 1.0,    -- Hoehenversatz ueber dem Fahrzeugboden in Metern

    -- FARBEN:
    color           = { r = 0,   g = 20,  b = 255 },  -- Linke Seite  (Blau)
    altColor        = { r = 255, g = 0,   b = 0   },  -- Rechte Seite (Rot)
}

-- ─── HUD POSITION ─────────────────────────────────────────────────────────────
Config.HUD = {
    x      = 0.012,  -- Links
    y      = 0.50,   -- Vertikal mittig
    size   = 0.38,   -- Schriftgroesse
    width  = 0.13,   -- Breite des HUD-Panels
}
