# Forensic repair and Alerts handoff

## Status
PARTIAL - implementation, integrated automated gates, build and installation pass;
physical acceptance remains in progress. Not a release approval.

## Lot
Owner-approved multi-lot forensic repair F01-F20 and C11/C13 Alerts extension.
Plan and live acceptance ledger: .planning/FORENSIC_REPAIR.md.

## Git
- Branch: codex/forensic-alerts.
- Base: 82ce6b80783118ea923ef1c8ceed0f557c31d696, codex/stabilize-current-suite.
- Initial checkpoint: 91b804c. First integrated Alerts checkpoint: e22a186.
- Worktree: C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa.
- Verified build checkpoint: ee7a734 (scanner release fix after 057931d). Delivery HEAD/status follows
  physical evidence; no merge/push.

## Outcome / areas changed
- Wallet scanner diagnostics, origin-scoped protected routes, deletion authorization,
  metadata quarantine and conservative recovery.
- Defense backup recovery; strict purchase draft decoding; onboarding partial-save
  recovery and duplicate checks; dates/explicit owner validation; maintenance refresh.
- Territorial confidence, GPS freshness, Services recovery, CDA tile lifetime,
  previous Trip result retention, synthetic compiler integration, canonical OSRM path.
- New Alerts screen, per-vehicle/category preferences, enriched Android plate
  notification, optional Android alarm bridge and real permission/status handling.
- Dev build recipe explicitly supplies APP_ENV=dev, preserving production demo gates.

## Tests executed
| Test | Result |
| --- | --- |
| Baseline mobile suite, 82ce6b8 | 2959 pass / 11 skip / 0 fail |
| Final server: php -d extension=pdo_sqlite -d extension=sqlite3 vendor/bin/phpunit --colors=never | 493 pass / 1993 assertions |
| Scoped forensic regressions | See FORENSIC_REPAIR.md; included in the final integrated pass |
| Alert screen shell/preview, 5 sizes x 3 text scales | 15 pass; synthetic screenshot inspected |
| Alerts schema8-to9 / per-owner transactions | Passed in final suite |
| Final format / analyze | 365 files unchanged / no issues |
| Final flutter test --no-pub --concurrency=2 --reporter expanded | 3196 pass / 10 conditional simulation skips / zero failures |
| Explicit driving regional suite with PICORADAR_DRIVING_SIMULATION=true | 11 pass |
| Gradle :app:testDevDebugUnitTest --offline --console=plain | 57 pass / zero failures, errors or skips |
| Real Insurance compile configurations | 7 pass; only dev flavor + APP_ENV=dev enables demo |
| Python synthetic fixture / canonical OSRM path | 2 + 1 pass |
| APK build / install | Dev release 101.2 MB, 129.1s / adb install -r Success |
| Scanner release correction | 13 DEX fixtures pass; old APK rejected, rebuilt APK passes real DEX gate; fresh format/analyze clean |

Logs and non-private images: artifacts/current/forensic. Do not sum overlapping
focused counts as a global test count. Historical 87 failures no longer reproduce.

## Physical Android QA
Required, partly completed on the new build.
- Device: Mi A3, serial 116f2191b19a, Android API30, connected.
- Owner confirmed availability to authenticate, without sharing a PIN.
- Corrected APK installed at 12:38:37 Bogota; device base.apk SHA256 equals delivery.
- Alert center loads existing vehicles and Insurance preview banner is visible.
  Physical screenshots: artifacts/current/forensic/physical-alerts-20260919.png
  and physical-insurance-banner-20260919.png. These are not document captures.
- Owner reproduced scanner failure: platform_failed. Screenshot
  physical-scanner-error-20260919.png. App-process log shows ML Kit registrar
  NoSuchMethodException; R8 usage and actual APK DEX confirm removal of its public
  no-argument constructor. Repaired in ee7a734 with narrow keep rule and artifact
  gate. After reinstall, the owner explicitly confirmed "YA funciona" when asked
  to reopen the camera. No registrar error in the new app process (PID6270).
- Camera opening is physically accepted. Saving/reopening both sides, positive
  authentication and private import are NOT inferred from that confirmation.
- Scanner must use fictional content only. FLAG_SECURE remains enabled.
- New banner/Alerts/notices, Stop/Snooze/cutoff/lockscreen and returning from capture
  require observation, not inference from tests. Android14+ special access remains
  a separate platform gate; other projects' emulators must not be reused or changed.

## Data / migration
Drift8-to9 is additive, creating per-vehicle/category delivery settings with FK
cascade. Existing dates, documents, vehicles and legacy preferences stay intact.
Normal notifications remain default; alarm and rich modes are opt-in. Dates have
one source in obligations/datasets; native schedule is reconstructible, no-backup.

## Installed APK
- Path: artifacts/current/apk/PicoRadar-dev-release-scanner-fix-20260919.apk.
- SHA256: A7ABC8D881E814DA68544DBD5472709F6A32F3A0C6C42070B2A957CBE66D21CD.
- Package: co.picoradar.app.dev, version 1.0.0 (1), minSdk24 / targetSdk36.
- Recipe: scripts/build_dev.ps1 -FlutterPath <local Flutter 3.47.1 flutter.bat>.
- Install: adb -s 116f2191b19a install -r <APK>; no uninstall or data clear.

## Security / privacy
No cloud files, continuous GPS, lead capture or analytics containing PII. Native
projection stores opaque IDs/time/routes, not plates. Ordinary/rich Android
notifications use SECRET visibility; generic native alarm controls may be public.
Private navigation requires unlock; Stop does not. No volume/DND override.

## Dependencies
No new runtime packages. Native alarm integration and added Android permissions
are documented in docs/ADR_ALERTS_ANDROID.md. No USE_EXACT_ALARM declaration.

## Risks / debts
- Scanner opening failure reproduced and fixed physically. Full private capture,
  import and authentication lifecycle acceptance remains separate and pending.
- Android14+ and store full-screen eligibility are not certified by Mi A3 API30.
- Bundled Manizales coverage expired Sept14; eight coverages stale Sept23. No
  artificial expiry extension. CDN is unconfigured unless explicitly supplied.
- Existing editorial, import/authentication, performance and B04 debts are not
  silently closed by this repair. No changes or deletion outside PicoRadar.
- Cross-review repairs of alarm retention, mixed permissions, delayed saves and
  consumed-error/background recovery passed. Physical validation is separate.
- Current Gradle succeeds with deprecation warnings (Locale, pre-26 notification
  priority and Gradle10 compatibility); no dependency upgrade was added.

## Next
Complete scanner/authentication, route retirement and notification/alarm physical
QA, then owner visual acceptance. No merge authorized.
