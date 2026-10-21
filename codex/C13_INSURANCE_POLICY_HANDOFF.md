# C13 - Policy sheet refinement

## Status
IMPLEMENTED / INSTALLED CANDIDATE - owner visual approval and protected physical
QA still pending. This is not full-lot closure or national coverage certification.

## Git
- Branch: codex/insurance-owner-mockup
- HEAD/base: ddf60407174e3ee8d447b7eff3ca45e0fd983789
- Worktree: C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa/temp/VIAJE-R1-real-planner
- Prior extensive WIP preserved. Changes relative to HEAD include earlier lots;
  this report does not attribute that earlier work to this delivery.

## Scope
Policy sheet/editor and evidence-backed insurer service classification only.
Approved home/banner/vehicle/plate are outside the write set. No new tables,
server requests, quotation submission, monetization, GPS or favorite changes.

## Files
- mobile/lib/features/vehicle_status/domain/insurance_policy_value.dart
- mobile/lib/features/vehicle_status/presentation/insurance_owner_sheets.dart
- mobile/lib/features/vehicle_status/data/insurance_directory.dart
- mobile/assets/catalogs/insurance_directory_v1.json
- mobile/test/features/vehicle_status/domain/insurance_policy_value_test.dart
- mobile/test/features/vehicle_status/data/insurance_policy_value_store_test.dart
- mobile/test/features/vehicle_status/data/insurance_directory_test.dart
- mobile/test/features/vehicle_status/presentation/insurance_owner_sheets_test.dart
- mobile/test/features/vehicle_status/presentation/insurance_policy_editor_test.dart
- mobile/test/features/vehicle_status/presentation/insurance_owner_review_test.dart
- mobile/pubspec.yaml / pubspec.lock: SDK localization and direct intl.
- C13 lot extension, CURRENT, DESIGN_CONTRACT, directory audit and planning ledger.

## Changes and verification
- Protected policy sheet: insurer/vehicle identity, complete policy number with
  copy, date columns, optional value/reference, document access, edit and reminder.
- Editor: one insurer selector/manual exception, Spanish calendar, draft-only
  date clearing, exact original COP amount/period and collapsed private phones.
- Existing owner/session/concurrent-write checks, unknown details, documents and
  reminders preserved. Calendar and nested selector inherit protected sessions.
- Directory services/conditions are optional and backward-compatible, validated
  by the existing parser; no second catalog or duplicated personal official phones.
- Monetary model: 6 unit tests passed, independent read-only review no findings.
- SQLite close/reopen: 1 test passed, original source/date/reminder preserved.
- Final combined run: 403/403 tests pass across 11 files. The old vehicle-tap
  regression expected the intentionally removed manual insurer field; changed
  to require the single selector and assert the manual field is absent.
- 9 changed Dart files: format --output=none --set-exit-if-changed, zero changes.
- flutter analyze --no-pub: no issues. Scoped tracked git diff --check: clean.
- Independent read-only money, directory and policy/privacy reviews: no findings.
- Visual audit corrected initial doubled-text calendar clipping, missing fixture
  icon fonts and generic fixture theme before accepting regenerated screenshots.

Commands run from mobile with Flutter 3.47.1 / Dart 3.13:

```powershell
flutter test test/features/vehicle_status/data/insurance_directory_test.dart test/features/vehicle_status/domain/insurance_policy_value_test.dart test/features/vehicle_status/data/insurance_policy_value_store_test.dart test/features/vehicle_status/presentation/insurance_policy_editor_test.dart test/features/vehicle_status/presentation/insurance_owner_sheets_test.dart test/features/vehicle_status/presentation/insurance_owner_screen_test.dart test/features/vehicle_status/presentation/insurance_owner_review_test.dart test/features/vehicle_status/presentation/insurance_quote_demo_test.dart test/features/vehicle_status/presentation/vehicle_status_screen_test.dart test/core/design_system/plate_fidelity_test.dart test/features/pico_placa/presentation/pico_detail_screen_test.dart --no-pub --dart-define=INSURANCE_SCREENSHOTS=true --reporter expanded
dart format --output=none --set-exit-if-changed lib/features/vehicle_status/domain/insurance_policy_value.dart lib/features/vehicle_status/presentation/insurance_owner_sheets.dart lib/features/vehicle_status/data/insurance_directory.dart test/features/vehicle_status/domain/insurance_policy_value_test.dart test/features/vehicle_status/data/insurance_policy_value_store_test.dart test/features/vehicle_status/data/insurance_directory_test.dart test/features/vehicle_status/presentation/insurance_owner_sheets_test.dart test/features/vehicle_status/presentation/insurance_policy_editor_test.dart test/features/vehicle_status/presentation/insurance_owner_review_test.dart
flutter analyze --no-pub
flutter build apk --release --flavor dev --dart-define=APP_ENV=dev --no-pub
adb -s 116f2191b19a install -r <exported-apk>
```

Flutter executable: C:/Users/felip/.codex/tooling/flutter_3.47.1/flutter/bin/flutter.bat.
Logs at worktree root: temp-insurance-policy-accepted-tests.log,
temp-insurance-policy-final-analyze.log, temp-insurance-policy-build.log.
All final commands exit 0. Earlier rejected runs retained as history, not gates.

## Physical Android QA
Mi A3 116f2191b19a connected. Pre-capture rejected by FLAG_SECURE; a zero-byte
output is explicitly marked invalid, not a visual before-image. No protection
bypass. New sheet screenshots must be automated, fictional and clearly labeled.
No real user-policy edits, phone calls or messages performed for QA.
Install -r returned Success; app started and existing vehicle data remained.
Inspected physical home, empty registration editor, Spanish calendar and insurer
selector. Cancelled calendar, selector and editor without saving. No runtime
configuration/density/text-scale/clock/GPS changes. UI automation temporary XML
removed after use. Empty registration does not prove positive wallet auth.

## APK and evidence
Directory: ../C13_POLICY_REFINEMENT_QA_20260914/
APK: PicoRadar-poliza-calendario-contactos-dev-release.apk
SHA256: 375935564b33535288220ac7f6226fd39c4b38fc61020fcff70e72cebd241090
Export and installed /data/app/.../base.apk hashes match.
Size: 103318671 bytes; previous approved artifact 101171171 bytes;
delta +2147500 bytes (about 2.05 MiB). This is total candidate delta, not an
isolated benchmark attributing every byte to localization.
Release does not expose debug-only simulation. Commercial demo still requires
both dev flavor and APP_ENV=dev; no production activation or quotation sending.
60 automated fictional screenshots in automatizadas/: 5 viewports x 3 scales x
4 surfaces. Current filenames include WIDTHxHEIGHT. Prior rejected images were
not exported. LEEME.md distinguishes physical/automated/protected evidence.
Approved home, plate and banner file hashes match the pre-edit checkpoint.

## Data/security
Original COP minor units and period are the only source values in existing
details JSON; equivalents are display-only. No migration/codegen required.
Existing wallet authentication, session epochs, encryption, screen protection
and internal viewer remain mandatory for protected access.

## Dependencies
flutter_localizations from the installed Flutter SDK and intl 0.20.3 (already
transitive, now direct). BSD-3-Clause licenses; Flutter multiplatform APIs,
no native plugin/permission/calendar dependency. Scope localization to insurance.
The total measured build-size delta is recorded above.

## Directory audit
Version 2026-09-14.1, schema 1; all 16 existing reference entities reviewed.
60 contacts: 54 enabled and 6 disabled; all earlier disabled observations retained.
39/64 entity-service combinations have an evidence-backed route, 25 pending.
Matrix statuses: 38 verified, 1 conflicting with verified alternative, 25 pending.
General assistance does not imply towing/designated driver/roadside repair.
HDI WhatsApp limited to its published purposes. Renewal-only AXA observations
remain disabled for assistance. Each enabled service route has source/review date.
SFC identity cross-check is not a full audit of every supervised insurer's current
automotive offering. Additional Liberty identity noted, offering evidence pending;
not silently aliased to HDI or claimed nonexistent. Detailed sources and limits:
codex/C13_INSURANCE_DIRECTORY_AUDIT.md.

## Ten-point acceptance audit
| Criterion | Observed / evidence | Status |
| --- | --- | --- |
| Approved home unchanged | Three checkpoint hashes + physical home | Passed |
| Readable policy hierarchy | Fictional policy screenshots, text scales | Passed automated; owner approval pending |
| Calendar and accessibility | Spanish physical picker; 15 viewport/scale fixtures | Passed |
| Exact optional value | Unit, repeat-toggle, invalid-input, SQLite tests | Passed |
| One insurer selector | No duplicate manual field; exception and cancellation tests | Passed |
| Automatic service contacts | Explicit services/conditions, 16-entity audit, unknown fallback | Passed within declared evidence scope |
| Draft and owner integrity | Cancel, error, concurrency, vehicle-switch tests | Passed |
| Private document/session handling | Nested-route tests and static review, FLAG_SECURE unchanged | Automated passed; positive physical auth pending |
| No accidental transmission | Existing demo/contact launch regressions, no real calls | Passed |
| Delivery/recovery | Build/install/hash, preserved WIP and data, error/retry tests | Passed candidate; not full-lot closure |

## Risks/debt
- National exhaustiveness and the 25 missing service routes are NOT certified.
  Missing or contradictory evidence does not enable unverified channels.
- Physical positive authentication/import debt from earlier work remains open.
- Approval, full-suite/CI and publication not claimed. No merge performed.
- No other lot is declared completed or unblocked by this refinement.

## Next
Owner review of the protected policy sheet and controls on device. Then full
Flutter suite, required physical auth/import checks and isolated publication/CI
per lot. No next lot automatically unblocked, no merge authorized.

## Git status
Branch/base unchanged. Extensive tracked/untracked WIP remains, including prior
server, Android, Documents, tax, maps and other features. No staging/commits,
deletion of user changes, push or merge. This scoped report, QA artifacts and
logs are explicit uncommitted handoff artifacts; git status is not clean.
Only the Files list above and this refinement's docs/logs belong to this turn;
the complete diff from historical HEAD must not be used as its isolated patch.
