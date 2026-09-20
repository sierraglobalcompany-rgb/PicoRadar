# Scripts

## Server preflight

`server_preflight.ps1` inspects the local or hosting capabilities required by
the Laravel control plane. Its default mode is read-only: it does not install,
write `.env`, migrate databases, open ports or start services.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/server_preflight.ps1 -AsJson
```

Use `-RequireReady` only in a controlled gate that should fail closed. The
`-FixturePath` option exists for synthetic tests and must not contain secrets.
