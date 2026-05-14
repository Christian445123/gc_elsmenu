--[[
    gc_els | vcf/models.lua
    Auto-Index aller Fahrzeuge mit eigener VCF-XML-Konfiguration.

    DIESES FILE WIRD AUTOMATISCH AUSGELESEN.
    Jeder Eintrag hier muss eine passende .xml-Datei im vcf/ Ordner haben.
    Dateiname (ohne .xml) = Eintrag hier = Interner GTA-Modellname.

    NEUES FAHRZEUG HINZUFÜGEN:
      1. XML-Datei nach vcf/<modellname>.xml legen
      2. '<modellname>' in dieser Liste eintragen
      Das Fahrzeug wird beim nächsten Ressourcen-Start automatisch geladen.

    FORMAT-UNTERSTÜTZUNG:
      - Standard ELS VCF Format  (<EOVERRIDE IsElsControlled="true" OffsetX=...>)
      - GC ELS Einfach-Format    (<lightingGroup><groupA extras="1 3 5">)
--]]

-- Alle Fahrzeuge deren XML automatisch geladen werden soll
Config.VCFModels = {

    -- ── Polizei (LPD Wien) ───────────────────────────────────────────────────
    'police',
    'lpd_octaviaw3',
    'lpd_skodakodiaqw3',
    'lpd_touranw3',
    'lpd_touareg',
    'lpd_tiguan',
    'lpd_t6.1',
    'lpd_vwt6_p9000',
    'lpd_vwt6_w3',
    'lpd_vwtouareg',
    'lpd_vwtouranp9000',
    'lpd_vwtouranp9000ea',
    'lpd_vwtouranw3earlywarner',
    'lpd_amarok',
    'lpd_cupra',
    'lpd_frosch',
    'lpd_vuk',
    'lpd_zivilskodakodiaq2024',
    'skodakodiaqp9000',
    'skodapol2',
    'golf8unmarked',
    'wolfvariant',
    'survivor',
    'wegasurvivor',
    'wega2',
    'wl_sharan',
    'bh_streife',

    -- ── Zivil / Observ ───────────────────────────────────────────────────────
    'a6zivil',
    'audia4zivil',
    's5zivi',
    'lvaaudia6',

    -- ── Rettungsdienst (RTW / NEF / SEG) ────────────────────────────────────
    'ambulance',
    'rtwwienars',
    'rtwwienasp',
    'rtwwienbri',
    'rtwwienfav',
    'rtwwienflo',
    'rtwwienher',
    'rtwwienleo',
    'rtwwienlsg',
    'rtwwienmhf',
    'rtwwienpzg',
    'rtwwiensim',
    's1nef',
    'rebs1p2',
    'br_vito',
    'br_evito',
    'br_bit',
    'br_caddy',
    'br_kodiaq',
    'br_kodiaqoberarzt',
    'br_seg1',
    'br_seg3',
    'br_hoehenrettung',
    'seg_sprinter',
    'seg-10',

    -- ── Feuerwehr ────────────────────────────────────────────────────────────
    'ffhlf1200',
    'ffhlfneu4',
    'ffhrf',
    'ffkdf22',
    'fflfa',
    'tlf4k',
    'MZF1',
    'linghlfbt',
    'linghlfbtn',
    'bohlf',
    'bf_klf',
    't6_seiltechniker',

    -- ── ÖAMTC / ÖAMDC ────────────────────────────────────────────────────────
    'oeamtc',
    'oeamtc1',
    'oeamtclala',
    'oeamtclkw2',
    'oeamtcpassat',
    'oamtctiguan',
    'oeamdc',

    -- ── Wrecker / Bergung ────────────────────────────────────────────────────
    'c3wrecker',
    'c3ramwrecker',
    'scavareheavywrecker',
    'tow2',
    'flatbed3',
    'gravelcargo',
    'xm_atego_adac6f',

    -- ── Sonstige Einsatzfahrzeuge ────────────────────────────────────────────
    '23xc90bs',
    'atcaddy',
    'att6',
    'benefactorvan',
    'brtwby',
    'brtwby4x4',
    'f750gs',
    'joelrhodon',
    'joeltouran',
    'Kodiaq22EW',
    'kodiaqw3',
    'r1250',
    'vwt5mtw',
}
