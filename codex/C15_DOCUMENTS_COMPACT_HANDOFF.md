# C15 Documents Compact Front Page

Status: PARTIAL (implementation and preview complete; owner visual approval and
the earlier C15 physical-security gates remain open).

## Scope and baseline

- Worktree: `temp/VIAJE-R1-real-planner`.
- Branch: `codex/documents-owner-vault`.
- Base HEAD: `ddf60407174e3ee8d447b7eff3ca45e0fd983789`.
- Extensive earlier C15 and unrelated WIP is preserved. This HEAD alone does not
  reproduce the installed application. No commit, publication or merge yet.
- Checkpoint: `.planning/DOCUMENTS_COMPACT_CHECKPOINT.md`.
- This change is presentation-only: compact driver rows, driver management,
  adaptive no-scroll front page and vehicle carousel. No changes to storage,
  migration, authentication, scanner, cipher or favorite selection.

## Files in this adjustment

- `mobile/lib/features/documents/presentation/documents_screen.dart`
- `mobile/lib/features/documents/presentation/documents_widgets.dart`
- `mobile/lib/features/documents/presentation/documents_driver_sheet.dart`
- `mobile/test/features/documents/presentation/documents_screen_test.dart`
- `mobile/test/features/documents/presentation/documents_owner_screen_test.dart`
- `mobile/test/features/documents/presentation/documents_compact_widgets_test.dart`

## Behavior

The header exposes driver management and protection. There is no shared driver
selection: each row identifies its owner and uses that owner's document query.
The two cards share at most two personal owner providers. Management exposes
add/rename/delete profiles and document replacement/deletion without a long press.

The front page has no vertical scroll. Text and controls are measured first;
remaining height belongs to the full vehicle image. If both sections cannot fit,
Conductor/Vehiculos internal views preserve the carousel. Copy updates do not
change the composition. Privacy and recovery information remain available in
protected sheets, where scrolling is intentionally retained.

Owner clarification during implementation: keep the approved plate as a fixed
horizontal 96 dp graphic; when text is enlarged, show its complete number also in
14 sp scalable text. The shared plate renderer is unchanged, with no micro variant
or FittedBox added. Standard fixture plates measure 96 x 46 dp at all tested text
scales. Personal card titles/rows, state strings and vehicle names still scale.

Review also identified two coordination regressions to protect explicitly: preserve
the mounted content/action context behind the wallet lock, and invalidate owner
queries after successful writes even if the management sheet has been dismissed.

## Evidence and gates

New evidence directory: `../C15_DOCUMENTS_COMPACT_QA_20260913/`.
`physical-before.png` was checked visually: Documents top, not the Taxes screen
that happened to be open initially. `physical-before-bottom.png` records its
previous scroll-dependent lower content. Prior evidence is not overwritten.

Final candidate: 434 focused tests PASS, including 69 owner/screen and 50 compact
widget tests. All six touched Dart files pass scoped format with zero changes.
`flutter analyze --no-pub`: no issues. `git diff --check` on Documents: PASS.
Intermediate geometry failures are retained in `development-logs/`, not presented
as approved evidence. The final run is `focused-tests.log`; analysis and build
have separate logs. Automated images were regenerated from the final candidate.

Exact focused test command (from mobile):

```text
flutter test --no-pub --concurrency=1 --timeout=45s test/features/documents test/core/database/wallet_migration_test.dart test/core/database/app_database_test.dart test/features/garage/application/vehicle_associated_data_cleaner_test.dart test/features/vehicle_status/application/vehicle_wallet_document_provider_test.dart test/features/vehicle_status/data/private_vehicle_document_store_test.dart test/features/vehicle_status/presentation/vehicle_status_screen_test.dart test/features/settings/presentation/settings_screen_test.dart android/bridge_tests/wallet_platform_test.dart
```

Build: `flutter build apk --release --flavor dev --dart-define=APP_ENV=dev`, PASS.
APK: `../C15_DOCUMENTS_COMPACT_QA_20260913/PicoRadar-C15-documentos-compactos-dev-release.apk`.
Size: 98,870,407 bytes (Flutter reports 94.3 MB).
SHA256: `0e93d52dab025b49df910e008a17b5a35360db69e9c7a3d3b958dc7fb6b7edc3`.
Installed successfully with `adb -s 116f2191b19a install -r` after checkpoint.

## Physical Android QA

Required layout preview: passed inspection on Mi A3, Android 11, 720x1560 pixels,
360 dp width, without changing the device scale or clock. This is not final owner
approval or completion of the old scanner/authentication gates.

- `physical-one-driver.png`: complete front page with the same vehicle as before.
- `physical-two-drivers.png`: second fictitious profile, both row pairs accessible.
- Personal cards measure approximately 126 dp / 174 dp for one / two drivers.
  The additional 48 dp comes from the vehicle area, not an outer scroll.
- Standard plate remains 96x46 dp; row and header touch bounds are at least 48 dp.
- Vertical swipe leaves the front page in place; horizontal carousel still works.
- All four existing vehicles remain. Closing management, vehicle and privacy
  sheets preserves the focused vehicle (fourth of four in the comparison).
- Added only `QA_COMPACTO`, checked its second-driver row and its named management
  sheet, then deleted only that fictitious profile. Principal and vehicles remain.
- Checked the add-source sheet, seven vehicle document rows and privacy sheet.
  No scan, import, real private document or authentication-success claim is made.
- Additional images: `physical-driver-management.png`,
  `physical-second-driver-documents.png`, `physical-vehicle-documents.png`,
  `physical-privacy.png`. Every listed screenshot was opened and inspected.

## Data, security and dependencies

No data/schema/migration/dependency changes in this adjustment. Fixed the two
reviewed context/invalidation regressions using existing session-aware content
and providers. No private document was added, opened or exposed for screenshots;
FLAG_SECURE and device protection were not disabled. The fixed graphic plate and
separate scalable number were explicitly confirmed by the owner during this turn.

## Git and next step

Base is the existing WIP on `codex/documents-owner-vault`, not a clean checkout of
HEAD. Final HEAD remains `ddf60407174e3ee8d447b7eff3ca45e0fd983789`. Git remains
dirty with extensive pre-existing modified/untracked C15 and unrelated work;
this is intentional preservation, not a clean or published lot. This adjustment's
files are listed above. Development logs were moved outside the source worktree.
No stage-all, reset, commit, push or merge. No other lot is unblocked/closed by
this preview. Next step: owner visual approval, followed by the outstanding C15
physical gates, full-suite closure and isolated publication when authorized.

## Open acceptance and debt

- Owner visual approval is required before full closure/publication.
- Earlier physical scanner availability, import return and positive device-auth
  checks remain open in `C15_DOCUMENTS_OWNER_HANDOFF.md`; this layout does not
  resolve them.
- Use only fictitious driver/document fixtures for QA. Do not disable secure
  screenshots or inspect personal files to manufacture evidence.
- Release is not the debug simulation variant.
- No other lot or existing performance/APK-size debt is closed by this change.
