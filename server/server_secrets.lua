-- ═══════════════════════════════════════════════════════════════════════════
--  gc_elsmenu – Server-only Secrets
--  ⚠  Diese Datei wird NUR serverseitig geladen und NIE an Clients gesendet.
--  ⚠  Trage hier alle sensiblen Zugangsdaten ein.
--  ⚠  Füge diese Datei in .gitignore ein wenn du Git verwendest!
-- ═══════════════════════════════════════════════════════════════════════════

ServerSecrets = ServerSecrets or {}

-- Lizenzschlüssel (vom Lizenzserver erhalten)
ServerSecrets.LicenseKey          = '' -- Lizenzschlüssel hier eintragen

-- URL des CG Lizenzservers (kein trailing slash)
ServerSecrets.LicenseApiUrl       = 'https://development.gamingcommunity.at'

-- API-Secret (muss mit API_SECRET in config.php übereinstimmen)
ServerSecrets.LicenseApiSecret    = '097adbc4cb3a17b19cf51ec73166c39d6c26af8c1b5a5de2c7641ced600c7481'

-- Ressourcen-Name wie er auf dem Lizenzserver eingetragen ist
ServerSecrets.LicenseResourceName = 'gc_elsmenu' -- Nicht ändern, sonst funktioniert die Abfrage nicht
