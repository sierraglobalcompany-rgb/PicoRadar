# C15 Documents Owner Handoff

## Status
PARTIAL. Recovered implementation verified and dev release preview installed on
Mi A3. UI and cancellation checks performed; end-to-end physical import/scanner,
positive authentication and owner visual approval remain open. Not a stable C15
closure. No publication or merge.

## Git
- Branch: codex/documents-owner-vault.
- HEAD: ddf60407174e3ee8d447b7eff3ca45e0fd983789.
- Base branch at start: codex/taxes-owner-calendar, with extensive existing WIP.
- Worktree: C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa/temp/VIAJE-R1-real-planner.
- No restoration, staging, commit, push or merge. Previous changes remain intact.
- Checkpoints: .planning/DOCUMENTS_OWNER_CHECKPOINT.md.

## Outcome
- Driver-first Documents, Principal plus optional second driver, vehicle carousel
  and seven vehicle document types. No vehicle required for personal copies.
- Optional system authentication, whole-visit gate and shared SOAT/RTM document
  access. Private previews use secure internal image/PDF rendering, not another app.
- Scanner/import, explicit preview before save, two-face support, actual content
  validation, bounded decoding and encrypted pending captures.
- Drift v7 encrypted metadata, resumable legacy migration and exact-reference
  legacy cleanup on explicit deletion. Failed cleanup is journaled and visible.
- Android no-backup rules, secure window scopes and isolated PDF rendering.

## Files / Areas
- mobile/lib/features/documents/{application,data,platform,presentation}.
- mobile/lib/core/database/app_database.dart and generated app_database.g.dart.
- Minimal legacy-store, vehicle-cleaner, SOAT/RTM and Settings adapters.
- App lifecycle/shell/startup privacy integration; test harness overrides.
- Android wallet bridge/service, MainActivity integration, themes, manifest,
  backup rules and scanner dependency. Existing TTS/widget code preserved.
- Focused tests and clearly fictitious PDF fixtures under mobile/test.
- Native details: mobile/android/C15_NATIVE_HANDOFF.md.

## Tests Executed
- Fresh recovery run: 365 PASS in 51 seconds. Exact command from mobile:
  `flutter test --no-pub --concurrency=1 --timeout=45s test/features/documents test/core/database/wallet_migration_test.dart test/core/database/app_database_test.dart test/features/garage/application/vehicle_associated_data_cleaner_test.dart test/features/vehicle_status/application/vehicle_wallet_document_provider_test.dart test/features/vehicle_status/data/private_vehicle_document_store_test.dart test/features/vehicle_status/presentation/vehicle_status_screen_test.dart test/features/settings/presentation/settings_screen_test.dart android/bridge_tests/wallet_platform_test.dart`.
- Fresh recovery `flutter analyze`: No issues found (15s).
- Fresh scoped `dart format --output=none --set-exit-if-changed`: 38 files,
  zero changes, including final Settings/cleaner tests.
- Final `flutter build apk --release --flavor dev --dart-define=APP_ENV=dev`:
  PASS (97.5s). SDK XML tooling warning, no compilation failure.

Earlier implementation-stage evidence (not counted in addition to final run):
- Combined focused Flutter command: 357 PASS in 64 seconds, concurrency 1,
  timeout 45s; Documents, wallet/database migrations, vehicle cleaner, legacy
  store, projection, SOAT/RTM, Settings and Android Dart bridge.
- Additional partial-write regression: wallet_draft_test.dart 4 PASS (three
  overlap the combined run; one additional failure-injection test).
- flutter analyze: No issues found after cleanup fix.
- Scoped Dart format gate: 36 files, zero changes.
- Native Gradle compile and JUnit report: 9 tests, zero failures/errors/skips.
- Native backup verification script: 60 scope/path checks passed in worker run.
- Real-asset automated PNGs: ../C15_DOCUMENTS_QA_20260913, 360x780 and 430x932,
  text 1 and 2. Main inspected all normal-size overview and 360 enlarged captures.
- Complete UI matrix covers 360x780, 360x800, 390x844, 412x915, 430x932,
  text 1/1.5/2. These are automated widget checks, not physical approval.

## Physical Android QA
Required and incomplete: UI passed, scanner/import not completed on this device.
- Device: Mi A3, serial 116f2191b19a, Android 11.
- Before: documents-plan-top-20260913.png and documents-plan-bottom-20260913.png
  under C:/Users/felip/AppData/Local/Temp.
- Never use real identity documents in screenshots; do not disable FLAG_SECURE.
- QA PDFs explicitly say DOCUMENTO FICTICIO / PRUEBA PICORADAR / SIN VALIDEZ.
- `adb -s 116f2191b19a install -r <exported APK>`: Success. No uninstall,
  clear-data, phone clock/configuration change or rollback. Installed package
  co.picoradar.app.dev, version 1.0.0+1, target 36, update 2026-09-13 14:25:02.
- Physical evidence folder: ../C15_DOCUMENTS_QA_20260913. New files:
  physical-overview.png, physical-vehicles.png, physical-vehicle-sheet.png,
  physical-two-drivers.png, physical-auth-cancel.png.
- Inspected real overview and scrolled vehicle area: personal cards first, full
  vehicle image, approved plate and seven document types. Four existing vehicles
  preserved. No personal identity document was opened or captured.
- Created QA_FICTICIO second driver, verified two-driver selector, then removed
  ONLY that test profile with confirmation. Principal and vehicle data remain.
- Imported test attempt used only PicoRadar_C15_FICTICIO.pdf (two valid pages).
  Android DocumentsUI displayed it but did not return a selection; its Mi A3
  storage root then displayed "No se puede cargar el contenido en este momento".
  Cancel returned to a locked wallet; no document was saved/replaced. Root cause
  is not established. No storage reset, provider cache clearing or permission
  workaround was performed. Device reported 7.8 GB available, so no full-disk
  condition was observed. Original test upload was removed afterwards.
- Scanner attempt returned the handled unavailable error before scanner UI.
  Capture, crop, two-sided save, PDF render/zoom, secure screenshot enforcement
  and restart-decryption therefore remain UNVERIFIED physically. Unit/widget/
  native tests are not a substitute for these gates.
- System biometric prompt appeared with device PIN alternative. Owner was asked
  to confirm on phone, but no confirmation arrived. Cancel was tested: explicit
  cancellation message and no silent activation. Protection remains OFF, as
  selected at first-use offer; no PIN was requested, read or recorded.

## Data / Security
- Schema upgrade 6 to 7; images remain outside SQLite. No destructive reset or
  downgrade is part of delivery. Do not install an older schema app as rollback.
- Personal names/metadata encrypted; driver and vehicle ownership independent.
- Lock/session epochs prevent late authorization and wrong-owner commits.
- No cloud, OCR, sharing, external private viewer or GPS behavior added.
- FLAG_SECURE mitigates screenshots/recents; it is not protection against a
  compromised OS, and does not control the SDK-owned scanner activity.
- Existing devices' historical backups cannot be retroactively erased by this
  update. New rules exclude private data, keys and metadata from app backups.

## Dependencies
- local_auth 3.0.2, BSD-3-Clause, official OS credential UI; no app PIN.
- ML Kit scanner 16.0.0, basic mode, Android SDK terms and optional first-use
  component download. Import remains available when scanning is unsupported.
- Android PdfRenderer, no extra PDF runtime package. iOS wallet native support
  remains pending and fails explicitly rather than opening an external viewer.

## APK
- Export: ../C15_DOCUMENTS_QA_20260913/PicoRadar-C15-documentos-dev-release.apk.
- Size: 98,837,475 bytes (Flutter reports 94.3 MB).
- SHA256: d4ec8f5cd0d43640c8422afeb7da628e9b928c0d15054b8bde6e0b2ded8f9b01.
- This is the rebuilt candidate with the Settings guard, not the earlier build.

## Risks / Remaining Gates
- Final Settings deletion authentication guard is saved, reviewed and covered by
  the fresh 365-test run. Existing Garage deletion API is unchanged.
- Physical scanner, credential allow/cancel, background/restart, secure screenshots
  and owner visual approval remain gates until recorded below.
- Full Flutter suite, publication, CI and live design/current documentation follow
  visual approval; prior APK-size/performance and unrelated-module debts stay open.
- Dev release is a preview, uses the existing dev signing configuration and does
  not expose debug-only driving simulation.

## Next
Complete device import/scanner and positive-authentication checks, then request
owner visual approval. Investigate DocumentsUI/scanner availability without
clearing user storage or bypassing security. No other lot is declared complete
or newly unblocked by this preview.

## Recovery Git State
`git status --short`: 144 modified/untracked entries, combining preserved WIP
and this lot. No staging/commit/push/merge; HEAD unchanged. C15 areas are listed
above. Do not claim the worktree is clean or include all these entries in C15.
The checkpoint records the recovery and pre-install gates; source was not reset
after either Codex interruption.
