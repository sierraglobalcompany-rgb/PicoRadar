# Scripts

## Server preflight

`server_preflight.ps1` inspects Laravel/panel and OSRM as separate profiles.
Its default mode is read-only: it does not read or write `.env`, connect to a
database, install packages, migrate databases, open ports or start services.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/server_preflight.ps1 -Profile laravel -AsJson
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/server_preflight.ps1 -Profile osrm -AsJson
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/test_server_preflight.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/test_post_c11_mode_matrix.ps1
```

Use `-RequireReady` only in a controlled gate that should fail closed. A
`-FixturePath` is always synthetic and never proves production. Use
`-TargetHostEvidencePath` only with an inventory collected on the target host
using its native tools; PowerShell is not required there. Neither file may
contain secrets.
