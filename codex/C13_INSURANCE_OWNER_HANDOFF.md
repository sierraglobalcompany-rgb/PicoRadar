# C13 Seguro y Asistencia: Owner Preview

## Status
PARTIAL: implementation and focused gates complete; final dev release installed.
Physical visual preview collected. Owner approval, full-suite/publication closure
and positive physical Wallet import/authentication remain pending.

## Git
- Branch: codex/insurance-owner-mockup.
- HEAD/base: ddf60407174e3ee8d447b7eff3ca45e0fd983789.
- Previous branch: codex/documents-owner-vault.
- Worktree: temp/VIAJE-R1-real-planner.
- Extensive previous tracked/untracked WIP and .planning remain preserved.
  HEAD alone does not reproduce this or the previously installed preview.
- No stage-all, commit, push, merge, reset or unrelated rollback.

## Outcome and Ownership
- Insurance-only delegation from vehicle_status_screen.dart; other obligation
  modules retain their existing presentation and behavior.
- New insurance_owner_content.dart: non-scrolling owner presentation, dev-only
  bitmap banner, stable vehicle focus, horizontal 96 dp plate, adaptive internal
  views and accessible actions. More height increases vehicle space.
- New insurance_owner_sheets.dart: policy editing, directory, assistance and
  protected access to the existing Wallet voluntaryInsurance document.
- New insurance_quote_demo.dart: local three-step demonstration with fictitious
  applicant, separate unticked consents, no transport or lead persistence.
- New insurance_directory.dart and assets/catalogs/insurance_directory_v1.json.
  16/16 Fasecolda reference labels audited, 54 enabled channels, 6 inactive
  observations. This is not a claim of exhaustive national/current coverage.
- New generated bitmap assets/pico/insurance_owner_banner_v1.png; no embedded UI
  text or brand/insurer logo. Existing asset directories already in pubspec.
- Focused new directory, owner layout, review regressions, sheets and demo tests;
  three existing phone tests updated to the new assistance entry point.
- C13 owner extension recorded in codex/lots/C13_VEHICLE_STATUS_MODULES.md.
  C25 transmission, public sponsored placement and monetization remain OFF.

## Data and Dependencies
No new runtime dependency, schema migration, backend or network loader.
Policy details preserve the existing vehicle_obligations contract and original
vehicle ID. Do not describe all policy metadata as encrypted. Policy documents
reuse encrypted Wallet storage, session authentication and internal viewer.
Phone actions open the dialer; WhatsApp is an explicit official-channel action
without message, plate or GPS query parameters. Channels retain scope labels.

## Evidence and Gates
Before: C:/Users/felip/AppData/Local/Temp/insurance-plan-before-20260913.png
and insurance-plan-bottom-20260913.png.
Automated candidates: temp-insurance-preview/ (not physical screenshots).
Initial expanded gates: 126 directory/demo/existing screen tests passed;
41 layout tests passed before review refinements. Final run recorded below.
Final combined run: 211/211 passed across six insurance and vehicle-status files.
After the first physical screenshot, the compact Resumen was corrected to keep
vehicle artwork instead of a plate-only placeholder whenever space permits.
48/48 owner/review tests passed after that fix; flutter analyze no issues and
scoped formatting clean. Full app suite is deliberately pending visual approval.
Build: flutter build apk --release --flavor dev --dart-define=APP_ENV=dev.
Final export: ../C13_INSURANCE_OWNER_QA_20260913/PicoRadar-seguro-asistencia-dev-release.apk
SHA256: 778b9e69473bdd5180b221f65e00285309f6de4a17c087031840d2b0ae5b4ed3
Size: 101171195 bytes (96.5 MiB). Installed with adb install -r: Success.
Device: Mi A3, serial 116f2191b19a, Android 11. No clear-data or uninstall.
The installed base.apk SHA256 equals the exported APK SHA256 above.
Final format: 11 files checked, zero changed. Final analyze: no issues.
Final screenshot matrix rerun: 42/42 passed with INSURANCE_SCREENSHOTS=true.
Combined tests, visual tests, analyze and build logs are copied into the QA
folder's validacion directory; generated matrix images are in automatizadas.
The full six-file command is flutter test followed by:
- test/features/vehicle_status/data/insurance_directory_test.dart
- test/features/vehicle_status/presentation/insurance_quote_demo_test.dart
- test/features/vehicle_status/presentation/insurance_owner_screen_test.dart
- test/features/vehicle_status/presentation/insurance_owner_review_test.dart
- test/features/vehicle_status/presentation/insurance_owner_sheets_test.dart
- test/features/vehicle_status/presentation/vehicle_status_screen_test.dart
with --reporter expanded. The visual rerun uses insurance_owner_screen_test.dart
with --dart-define=INSURANCE_SCREENSHOTS=true --reporter expanded.
Review found and addressed: detached-carousel focus, document access without
policy metadata, WhatsApp scope visibility, long insurer names, enlarged-text
vehicle space, stale edits and route-aware authentication.
Final physical correction: a reminder with no due date reads Pending date rather
than Active, without modifying its stored preference or scheduling behavior.

## Physical QA and Cleanup
Final-artifact captures: 01 summary, 02 no policy, 03 vehicle selector, 04 moto,
05 directory, 06 fictional policy, 07 opaque assistance, 08 channel scopes,
10 comparison banner and 11 demo entry. Car and moto artwork remains complete;
the normal Mi A3 uses Resumen / Mi poliza rather than a vertically scrolling home.
The summary uses a smaller contained vehicle than Mi poliza. At extreme text
scale, the summary may retain only compact identity; full artwork remains in
Mi poliza. This is an intentional adaptive difference from the tall mockup.
Opening policy documents rejected adb screencap (FLAG_SECURE). No blank capture
is presented as visual evidence and protection was never disabled.
Import reached Android's picker but did not complete file selection; cancellation
returned to the locked Wallet. Positive import and credential authentication are
NOT certified. Full demo completion is automated evidence, not physical evidence.
No real calls or WhatsApp messages were sent, and no personal document was used.
QA-SEGURO-PRUEBA / QAQ013 and its policy fixture were removed via the normal
confirmed Garage deletion flow. Final UI shows four original vehicles and
BOG127 still favorite. The copied fictional PDF was removed from Downloads.
docs/CURRENT.md and docs/DESIGN_CONTRACT.md record this preview, not lot closure.

## Ten-Point Acceptance Audit
| Criterion | Expected | Evidence/status |
|---|---|---|
| Fidelity | Integrated bitmap banner, vehicle identity, compact policy actions | Fresh final-APK car/moto and two-state captures; owner approval pending |
| Fit | No front-page vertical scroll, spare space favors vehicle | Five viewports x three scales; long moto/taxi cases |
| Accessibility | 48 dp actions, full semantics, fixed plate plus scaled number | Geometry tests; no shrinking states |
| Vehicle focus | Image, plate and operations share original ID | Controller/remount and sheet race regressions |
| Truthful state | Missing record never means uninsured | Copy and loading/error tests |
| Directory | Official evidence per enabled channel, unknown inactive | C13_INSURANCE_DIRECTORY_AUDIT.md |
| Channel purpose | Scope shown before external action | Review regression; no real calls/messages |
| Wallet privacy | Authorize before private metadata; mask on lock | Tests, physical capture denial and locked picker return; positive auth/import pending |
| Demo | Dev preview only, fictitious applicant, no sending | Dual flavor/environment gate and demo tests |
| Recovery | Errors preserve prior data, retry possible | Edit/launch/copy/security tests |

## Known Risks / Debt
- Owner visual approval, full-suite closure and isolated publication/CI pending.
- Previous C15 physical scanner/import/positive-authentication debt is not closed
  by this redesign. Never disable FLAG_SECURE to obtain evidence.
- Channel verification means published official evidence on 2026-09-13, not
  live response testing, policy entitlement or perpetually current contacts.
- Demo cannot be made production-operational by a flag alone: a real recipient,
  consent contract, retention and validated C25 backend are separate work.
- Dev release has no debug-only simulation. Existing signing/size/performance
  debts remain outside scope.
- Logs and screenshots are explicit local QA artifacts, not repository exports.

## Next Steps
Request owner visual approval; complete physical Wallet import/authentication QA
with a fictitious document and owner-entered credential. Then run full suite and
isolate this lot for publication/CI without merging. No monetization is unlocked.

## Git Status at Handoff
Worktree remains intentionally dirty with extensive prior WIP. Insurance files,
test additions, generated local bitmap, catalog/audit, scoped integration edits,
planning/checkpoint and QA logs are this delivery's explicit artifacts. Existing
Android, Documents, Taxes, Fotomultas, server and other module changes are NOT
claimed as insurance changes. No commit/push/CI run occurred in this delivery;
the base HEAD is not evidence that this preview has been published.
