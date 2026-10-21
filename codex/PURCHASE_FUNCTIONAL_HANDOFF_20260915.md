# Preparar compra: functional execution ledger

## Workspace consolidation note (2026-09-15)

Current source is committed in 5958f42 and now lives in the repository root on
codex/workspace-consolidation. The old temp worktree is retired. The final
checkpoint limitation documented below is historical, not the current recovery
state. Evidence was relocated to artifacts/current/purchase; original installed
APK retained at artifacts/current/PicoRadar-installed-dev-release.apk.
Physical acceptance gates remain open. See docs/WORKSPACE_CONSOLIDATION.md.

Status: PARTIAL acceptance. Implementation and dev installation complete;
physical document import/scanner/positive authentication and owner acceptance
remain open. Approved six-review plan, 2026-09-15. No release/merge approval.

## Preservation
- Existing branch codex/cda-owner-map; no merge or publication authorized.
- Tracked WIP checkpoint refs/checkpoints/purchase-functional-before-20260915:
  be5cd029ebd3fa3cc301ac91628749e53a2a4eda.
- Untracked owner WIP and .planning remain in place.
- Visual cover and purchase grid are frozen; change sheets and data integration.

## Work packages
1. Parent: optional purchase context, persistent selections, six actionable sheets,
   explicit Garage picker, candidate city catalog and integration/regressions.
2. Wallet data worker: preparation owner and Drift migration with preserved files.
3. Directory worker: territorial procedure channels and all 33 tax fiche audit.
4. Document UI worker: protected preparation files with existing wallet actions.

## Acceptance gates
- Empty candidate and zero Garage vehicles can use all six reviews.
- Consultations do not set Reviewed or send identifying data automatically.
- Preparation-owned documents never borrow vehicle or driver identities.
- Existing v1/v2/v3 progress survives v4; legacy file flags are not real files.
- Focused tests/analyze/build run sequentially to avoid earlier OOM/native locks.
- Physical installation preserves user data; fictitious documents only for QA.
- Existing global baseline: 2783 passed, 10 skipped, 87 failures.

## Rulings
- National directory coverage is explicit; unresolved institutional channels use
  official directory access and are not asserted to be registering authorities.
- Scope includes shared wallet adaptation (C15) required by approved purchase flow;
  no unrelated wallet redesign or global 87-failure cleanup.
- No new runtime dependency, OCR, server, PDF contract export or automatic queries.

## Implemented behavior and scope audit

| Criterion | Implementation / evidence | Remaining gate |
|---|---|---|
| Optional vehicle | Six sheets opened on Mi A3 without candidate; SIMIT opened in browser and returned to same sheet | Passed for empty candidate; zero-Garage covered by fixtures |
| Context isolation | Independent three authority IDs; Garage pick is temporary; candidate never silently replaced by favorite | Data/widget coverage; no user Garage mutations during physical QA |
| Concrete guidance | Numbered steps and official actions; explicit Reviewed switch; browser return leaves 0 of 6 | Physically inspected; no payment or personal consultation performed |
| Directory truth | 33 tax fichas audited, 8 editorial portal referrals; 2 confirmed transfer bodies, 767 pending entries retained | Live availability is not certified |
| Actual files | Named secure visit uses existing capture/validation/viewer; files owned by preparation, not fictitious vehicle | Physical capture/import/authentication |
| Legacy truth | Historic flags displayed as pending only without an actual traffic-license copy | Covered in document widget tests |
| Owner preservation | Draft v4, distinct archive IDs; candidate change explicitly creates new owner and preserves old snapshot/files | Covered in widget/data tests |
| Accessibility | Original cover retained; five sizes, text 1/1.5/2; selectors scroll with keyboard, no free city entry | Normal Mi A3 fit physically confirmed; enlarged text automated |
| Recovery | Corrupt preference preserved, save blocked; failed links retry; stale GPS ignored; document epoch/route/session checks | Physical lifecycle |
| No unrelated expansion | No leads, payment, contract PDF, backend, favorite/GPS persistence or runtime package changes | No merge |

## Test ledger

- First data run: 12 wallet tests passed; new draft test initially had an invalid
  test-helper reference. Corrected using a local AppPreferences fake.
- First document run: 53 passed, 3 failed. Fixed lazy-list assertions and
  preparation session integration in the focused document follow-up.
- First integrated run: 471 passed, 7 failed. All seven timeouts came from an
  indeterminate progress indicator under a nested picker. Hidden when its route
  is not current; requests remain serialized. No assertions were weakened.
- Subsequent purchase presentation run: 46 passed.
- Final focused integration run: **621 passed**, exit 0 (2026-09-15):
  `flutter test --no-pub test/features/buy_sell test/core/database test/features/documents test/features/comparendos test/features/vehicle_status/data/purchase_tax_directory_test.dart test/features/vehicle_status/data/tax_catalog_test.dart test/features/services test/features/settings/presentation/settings_screen_test.dart --concurrency=1`
- Analyzer: exit 0, no issues after explicit mounted guard for the protection
  sheet. Final source check is rerun before build.
- Full `dart format --output=none --set-exit-if-changed .` could not traverse an
  existing missing Android transform-cache path under build/android_file_picker.
  No cleanup/destructive workaround used; source-root check recorded separately.
- Full suite: **2868 passed, 10 skipped, 88 failed**, exit 1, sequential run.
  Exact failure-name comparison identified the prior 87 failures plus one K7
  expectation that corrupt purchase preferences be deleted. The approved
  recovery contract now preserves and throws; that test was updated and rerun:
  **1 passed**. The full suite was not rerun after this correction. Do not
  describe the complete suite as green or claim a fresh 87-failure full run.
- Latest purchase run after final ID validation and new six-sheet shell tests:
  **76 passed**, exit 0:
  `flutter test --no-pub test/features/buy_sell --dart-define=PURCHASE_CAPTURE=true --concurrency=1`.
- Final `flutter analyze --no-pub`: no issues, exit 0.
- Source format: `dart format --output=none --set-exit-if-changed lib test tool`:
  **345 files, 0 changed**, exit 0. Root formatter limitation remains as above.
- `flutter build apk --flavor dev --release --no-pub`: exit 0, 100.7 MB.
- `adb -s 116f2191b19a install -r build/app/outputs/flutter-apk/app-dev-release.apk`:
  Success. Local and installed base APK SHA256 match exactly:
  `C8D5B1E2B374AC4517E410F77FD16C345F07D2B3AC20F500391F919646746C00`.
- Logs: `mobile/build/purchase-review/functional-*.log` (local evidence).
- Final scoped `git diff --check`: exit 0 after normalizing only K7 test line
  endings to its tracked LF format. Its Dart format check: 1 file, 0 changed.

## Security / data review

- Drift schema 8 preserves existing encrypted bytes, IDs and associations;
  private_documents has exactly one driver/vehicle/preparation owner.
- New preparation identity row uses encrypted metadata and existing no-backup
  storage. No file bodies in SQLite. Draft remains in its existing local
  preferences contract; this change does not claim all draft fields are encrypted.
- A document operation fixes its owner at entry. Named visit scope handles
  background, tab change, late callbacks and viewer closure, and always requests
  FLAG_SECURE. No protection is disabled for evidence.
- v4 rejects missing ownership structure and duplicate archive identities.
  Invalid drafts remain recoverable and cannot be overwritten by the UI.
- Review found immutable checklist sets on new candidates; _applyDraft now
  copies the set. A dedicated candidate-change/mark/unmark/save regression exists.

## Physical baseline captured

- Mi A3 connected as device 116f2191b19a, 360x780 dp.
- C:/Users/felip/AppData/Local/Temp/purchase-functional-before-20260915.png
- C:/Users/felip/AppData/Local/Temp/purchase-comparendos-before-20260915.png
- Baseline confirms optional preparation nonetheless only exposed Usar mi
  vehiculo without a plate, and hid SIMIT. No user data changed for these captures.

## Git and release limits

- Branch codex/cda-owner-map, HEAD ddf60407174e3ee8d447b7eff3ca45e0fd983789.
- Existing large tracked/untracked WIP remains; it is not attributed to this
  functional change. No feature commit, push or merge has been made.
- This is an explicitly approved C12 purchase extension with a bounded C15
  shared-storage change. It does not close historic C15 scanner/authentication
  debt, global failures, public-release gates or visual acceptance.
- Full directory evidence and changed directory files:
  codex/PURCHASE_DIRECTORY_AUDIT_20260915.md.

## Files / areas changed

- Purchase: `buy_sell_draft.dart`, `buy_sell_screen.dart`, new
  `purchase_review_sheets.dart` and `purchase_documents_screen.dart`.
- Shared wallet: `wallet_models.dart`, `wallet_store.dart`, `wallet_access_gate.dart`,
  `wallet_actions.dart`, `app_database.dart` and generated Drift companion.
- Directories: `territorial_catalog.dart`, `comparendos_authorities_v1.json`,
  `tax_calendars_v1.json` and source/coverage audit.
- Tests: purchase draft/presentation/files, database migration, wallet/session,
  territorial/tax contracts, schema assertions and K7 corrupt-draft recovery.
- Documents: CURRENT, DESIGN_CONTRACT, bounded C15 extension and this handoff.
- Runtime dependencies: none added for this extension.

## Physical Android QA

Mi A3, 360x780 dp. Installation preserved data. All six review sheets opened
with the candidate empty. No review was marked, no user vehicle/favorite changed,
no personal identity submitted, no calls or payments made.

Observed on the installed build:
- Cover includes all six tiles, Notes, Copy and Save above navigation without
  scrolling. Header, colors and grid retained from approved visual candidate.
- SIMIT opens without plate and Back restores the same Comparendos sheet.
- Tax entity selector opens without plate; selection cancelled during QA.
- Transfer selector reports 2 confirmed bodies and marks remaining entries
  pending. Historical source names include malformed spacing; this is visible
  source-data debt, not a claim of 769 habilitated registration offices.
- Appraisal GPS action opened Google Maps; no exact coordinates were logged.
  Catalog-city picker also opened. This does not certify Maps result ordering.
- Payment/delivery instructions and document guidance inspected.
- Preparation document folder opened as 0 local copies and exposed import/scan.
  Android file selector opened for a fictitious two-page PDF. Automated taps
  did not select it; owner assistance requested. Successful physical import,
  preview/save and positive authentication remain unverified. No FLAG_SECURE
  bypass or personal files used.
- Device left at the Android file selector for owner assistance. Only the
  newly pushed `Download/picoradar-purchase-QA-20260915.pdf` is intended for
  this test; it is a 1086-byte fictional fixture, not an imported private copy.
  Remove that exact QA file after acceptance; do not remove user Downloads.

Permitted physical screenshots consolidated in `artifacts/current/purchase/`:
- `purchase-functional-after-20260915.png` (overview)
- `purchase-comparendos-after-20260915.png`
- `purchase-taxes-after-20260915.png`, `purchase-tax-picker-20260915.png`
- `purchase-transfer-after-20260915.png`, `purchase-transit-picker-20260915.png`
- `purchase-appraisal-after-20260915.png`, `purchase-city-picker-20260915.png`
- `purchase-payment-after-20260915.png`, `purchase-documents-guide-20260915.png`

Automated fixture captures in `artifacts/current/purchase/` are explicitly
test evidence, not photographs of protected physical document screens.

## Stop conditions / handoff limits

- Final temporary-index Git checkpoint operation was blocked by the tool before
  execution. No bypass attempted; initial checkpoint remains. Source changes
  are saved in the preserved dirty worktree, not a new commit.
- Final `git status --short` remains a large inherited tracked/untracked WIP,
  including unrelated server/CDA/Insurance changes. It was inspected, not
  staged wholesale or attributed to this purchase extension.
- This build is a dev acceptance candidate. Next gate is owner review plus
  physical fictitious-file import/scanner/authentication. No next lot or public
  release is declared unblocked by incomplete physical checks.
