fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'GC Dev'
description 'Auto-detecting ELS fuer alle Einsatzfahrzeuge - keine XML-Konfiguration noetig'
version '1.0.0'

-- Markiert dieses Resource als ELS-Resource (erkannt von anderen Scripts)
is_els 'true'

-- NUI Panel
ui_page 'ui/index.html'

client_scripts {
    'client/lights.lua',  -- Zuerst: ScanExtras, ApplyPattern
    'client/hud.lua',     -- ShowHUDNotification
    'client/ui.lua',      -- NUI Bridge (ShowPanel, UpdatePanel ...)
    'client/main.lua',    -- Hauptlogik (nutzt alles oben)
    'client/input.lua',   -- Tastenbelegung
}

server_scripts {
    'server/server_secrets.lua',
    'server/main.lua',
}

shared_scripts {
    'config.lua',
    'vcf/models.lua',  -- Auto-Index aller VCF-Fahrzeuge (wird vor lights.lua geladen)
}

files {
    'ui/index.html',
    'vcf/*.xml',
    'vcf/models.lua',
    -- wm-serversirens Audio (integriert – keine externe Resource nötig)
    'dlc_wmsirens/sirenpack_one.awc',
    'data/wmsirens_sounds.dat54.nametable',
    'data/wmsirens_sounds.dat54.rel',
}

-- Serverseitige Sirenen-Audio-Dateien (wm-serversirens, integriert)
data_file 'AUDIO_WAVEPACK'   'dlc_wmsirens'
data_file 'AUDIO_SOUNDDATA'  'data/wmsirens_sounds.dat'
