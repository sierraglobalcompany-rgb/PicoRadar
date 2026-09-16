# C15 Documents Owner Checkpoint

2026-09-13. Owner approved two drivers, optional device authentication, immediate
relock on exit/background, scanner/import and internal secure viewer.

Worktree: C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa/temp/VIAJE-R1-real-planner.
Branch: codex/documents-owner-vault. Previous: codex/taxes-owner-calendar.
Base HEAD: ddf60407174e3ee8d447b7eff3ca45e0fd983789.
Extensive pre-existing WIP preserved, including Taxes installed preview. No reset,
full-file restoration, staging, commit, push or merge. .planning preserved.

Audit: 42 existing Documents/store tests passed; no personal drivers, local auth
or internal viewer exist yet. Current encrypted index is file-based; metadata
must migrate without losing existing encrypted files or vehicle associations.
Before evidence: C:/Users/felip/AppData/Local/Temp/documents-plan-top-20260913.png
and documents-plan-bottom-20260913.png. Neither contains a real document image.

- [ ] Data model, Drift migration and safe legacy import.
- [ ] Session/authentication, capture and secure native viewer bridges.
- [ ] Driver-first Documents UI, vehicle carousel and sheets.
- [ ] Shared SOAT/RTM actions protected; lifecycle/cleanup integration.
- [ ] Focused tests, analysis, build and pre-install checkpoint.
- [ ] Physical fake-document QA and owner visual approval.

No backend, OCR, sharing/export, cloud backup, tax updates or GPS changes.
New dependencies restricted to baseline local_auth 3.0.2 and ML Kit scanner
16.0.0. Scanner/viewer Android-first. User enters device credential during QA.
No personal document captures or disabling secure flags for evidence.

## Pre-build / Pre-install Checkpoint

2026-09-13, same worktree/branch/base, WIP retained. Implementation now present:
driver-first UI, two local profiles, encrypted Drift v7 migration, unified vehicle
store, device-auth visit gate, scanner bridge and internal isolated PDF viewer.
Existing Taxes/Fotomultas/Pico/Garage work has not been reconstructed or reverted.

Verification before candidate build:
- Focused combined command: 357 tests PASS in 64s (Documents, schema migrations,
  legacy store, vehicle cleaner, SOAT/RTM, Settings, native Dart bridge).
- Final cleanup-audit fix: wallet_draft_test.dart 4 PASS; partial plaintext after
  a failed write is removed and the source buffer wiped. Prior 357 batch included
  3 of these tests; the new fourth regression was then executed separately.
- flutter analyze: No issues found after the last fix.
- Scoped format gate: 36 files, zero changes.
- Native Gradle compile and WalletLimitsTest XML: 9 tests, zero failures/errors;
  includes all-page metadata validation without a PDF page-count cap.
- Real asset automated PNGs inspected at 360x780 / 430x932, text 1 and 2:
  ../C15_DOCUMENTS_QA_20260913/. These are widget captures, not physical approval.
- PDF QA fixture has 3 pages, parsed strictly with pypdf; all pages explicitly
  say DOCUMENTO FICTICIO / PRUEBA PICORADAR / SIN VALIDEZ, no personal data.

Known audit fixes before build: legacy copies now removed on explicit deletion
with encrypted retry journal; off-route wallet releases secure-window ownership;
native secure acknowledgement precedes private painting; late reads/saves respect
session epoch; temporary partial-write cleanup corrected.

Next: optimized dev release build, hash/size, adb install -r on Mi A3 serial
116f2191b19a, physical fictitious-file QA and owner authentication/visual approval.
No APK from this C15 candidate installed yet. Release has no debug simulation.
Full-suite/publication/CI and unrelated debt remain pending, no merge.

## Recovery / Final Candidate Checkpoint

2026-09-13, recovered after Codex desktop closed. Same branch/HEAD/worktree;
previous WIP preserved. No surviving Flutter/build process or worker was running.
Settings guard was saved before interruption and has now been inspected and tested:
explicit session unlock before private deletion, epoch forwarded to WalletStore,
finally lock, cancelled/late authentication cannot delete. Garage deletion API
unchanged. First APK was NOT installed because it predates this guard.

Fresh gates on recovered source:
- Combined focused suite: 365 PASS, 51 seconds, concurrency 1, timeout 45s.
- Scoped format: 38 files, zero changes.
- flutter analyze: No issues found, 15 seconds.
- Mi A3 serial 116f2191b19a authorized and connected.

Next operation: rebuild dev release with APP_ENV=dev, install -r preserving data,
then physical fictitious-document checks. Owner credential interaction requested;
never request or record PIN. No C15 APK installed at this checkpoint.

## Installed Preview / Physical Audit

Final rebuilt APK installed successfully with adb install -r on Mi A3, without
data reset. SHA256 d4ec8f5cd0d43640c8422afeb7da628e9b928c0d15054b8bde6e0b2ded8f9b01,
98,837,475 bytes. Export and physical screenshots: ../C15_DOCUMENTS_QA_20260913.
365 fresh tests pass, analysis clean, 38 scoped files formatted without changes.

Physical UI, second-driver add/delete and auth cancellation checked. Test driver
and PDF upload removed; existing vehicles retained. Import was NOT completed:
Android file picker did not select the valid QA PDF and storage root showed a
load error. Scanner returned unavailable. Root cause not established; do not
mark these gates passed or work around by clearing phone data. Positive auth
awaits owner confirmation; no credential collected, protection not auto-enabled.

Handoff updated: codex/C15_DOCUMENTS_OWNER_HANDOFF.md. Status PARTIAL preview,
not stable/approved. Next: device availability/import/scanner/auth QA, approval,
then full suite/docs/publication per plan. No active build/test command remains.
