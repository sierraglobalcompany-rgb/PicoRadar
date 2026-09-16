# C13 Taxes Owner Checkpoint

2026-09-13. Owner approved implementation of `temp/TAXES_OWNER_PLAN/PROPUESTA.md`.

Worktree: `C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa/temp/VIAJE-R1-real-planner`.
Base HEAD: `ddf60407174e3ee8d447b7eff3ca45e0fd983789`.
Previous branch: `codex/comparendos-owner-directory`.
Implementation branch: `codex/taxes-owner-calendar`.

Existing uncommitted work in Home/Garage/Pico/Driving-related shell/Fotomultas/Comparendos and docs is preserved. This checkpoint is NOT a commit of that work. No reset, full-file restoration, broad staging or merge.

Before screenshots: `temp/TAXES_OWNER_PLAN/before-top.png`, `before-bottom.png`. Existing installed Comparendos dev release retained until taxes candidate passes focused gates. No installation yet.

Scope approved: taxes presentation, temporary authority preview plus explicit per-vehicle save, truthful national directory, versioned calendar reader/storage and required publisher validation. No tax estimates, personal debt/payment claims, GPS changes or automatic tax reminders. Snapshot protocol selected; no new tables or dependencies planned.

Work sequence:
- [x] Freeze shared payload contract and tests.
- [x] Implement tax dataset/parser/snapshot store and curated partial seed.
- [x] Implement server validation and tests using same contract.
- [x] Implement taxes presentation, selector and transactional explicit save.
- [x] Wire shared sync and targeted regressions; real CDN activation pending.
- [x] Format/analyze/focused tests; checkpoint before APK/install.
- [x] Physical screenshots and preview handoff; visual approval pending.

Remote production is not verified. Do not invent endpoint/configuration or claim automatic remote delivery without same-APK evidence. Missing source evidence remains explicitly pending in UI/data.

## Pre-build / pre-install checkpoint

2026-09-13. Same branch and base HEAD; no commits, reset, staging or merge.
365 focused mobile tests passed (vehicle_status, detail layout/navigation/tax,
core sync and app tax sync); full flutter analyze clean; scoped format check
30 files unchanged; git diff --check clean. Server tax/publisher/manifest subset:
192 tests, 474 assertions passed with explicit PHP SQLite extensions; Pint clean.
Initial artisan invocation lacked the SQLite driver in its spawned process;
direct PHP PHPUnit invocation with extensions passed. Not a code regression.

Independent review fixes covered: same-hash corrupt snapshot repair, explicit
bundled fallback warning, real review instant, additional published concepts,
San Andres resolution, event ordering and supersession identity. Store warning
and all public tax UI preserve data; no tax notification changes.

Seed version 2026.09.13-owner-v2: 33 territories, 14 partial calendars, 19 pending,
32 active events and 2 superseded, 7 officially referred portals. No claim of
complete national coverage. Source audit: temp/TAXES_OWNER_PLAN/SEED_AUDIT.md.

Equivalent physical before screenshots freshly checked:
before-install-taxes-top.png and before-install-taxes-bottom.png in the plan
directory. before-install-current.png is Documents, NOT a Taxes comparison.
Automated layout captures use real plate/icon fonts; they are not physical QA.

Next: build dev release with APP_ENV=dev, export candidate APK/hash, install -r on
Mi A3 116f2191b19a without clearing data, then capture/check Taxes and both sheets.
Do not mark remote updates operational: URL requested from owner, no real endpoint
available yet. Release does not expose debug-only driving simulation.

## Installed preview checkpoint

2026-09-13. Dev release build completed successfully. Exported APK:
temp/TAXES_OWNER_PLAN/PicoRadar-impuestos-dev-release.apk (Flutter reports 92.7 MB).
SHA256 of export AND installed base.apk:
1b3dd80e1c21f7f983a1065176994b1e208b249f36121e5710757913dc808a72.
adb install -r succeeded on Mi A3 116f2191b19a, Android 11. No data cleared.

Physical evidence inspected: after-top.png, after-selector.png, after-search.png,
after-temporary-cundinamarca.png, after-sources-top.png, after-source-history.png,
after-external-portal.png, after-return.png, after-reentry.png,
after-calendar-history.png and after-pending-amazonas.png in the plan directory.
External Cundinamarca portal opened without personal input; return kept temporary
selection. Leaving/reentering Taxes restored Bogota suggestion for BOG127.
No authority was saved on the phone during QA. Saved-selection behavior and
failure/race cases verified with automated fixtures. Phone left on Taxes/Bogota.

Candidate is PARTIAL, awaiting owner visual approval, actual CDN configuration
and remote-delivery evidence. Full Flutter suite and isolated publication/CI have
not been performed. Prior WIP remains preserved; no commits/push/merge.
Detailed handoff: temp/TAXES_OWNER_PLAN/IMPLEMENTATION_HANDOFF.md.
