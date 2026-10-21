# F07 / F08 scoped forensic repair handoff

## Status

DONE for scoped implementation and focused verification. Global integration,
Android build and physical QA remain with the coordinator. No release claim.

## Lot and sources

Approved .planning/FORENSIC_REPAIR.md: F07 and F08 only. C06/C07 and C25 context.
Read AGENTS.md, baseline 11/12 through word/document.xml, relevant flows 01/03/08,
CURRENT, DESIGN_CONTRACT, SOP, purchase functional handoff and Superpowers TDD.

## Git

- Branch: codex/forensic-alerts.
- F07: 713b2847f82075cfff92e9730a87d77a7cef99ca.
- F08: c182a0b6b54eeaff47a41603e7155759d3220354.
- Shared HEAD observed before this handoff: 2bba662a64cb56a889b9d3cc63d42f52304fc9e5.
- Plan checkpoint: 91b804c; approved forensic base: 82ce6b8; base branch: main.
- Worktree: C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa.
- Explicit-path staging and commit --only used; no merge, push or force-push.

## Outcome and files

- mobile/lib/features/buy_sell/data/buy_sell_draft.dart: v4 requires map-shaped
  active and archived sections; rejects invalid city confirmation types. Saving
  validates the existing source first, preserving corrupt raw content.
- mobile/test/features/buy_sell/data/purchase_context_test.dart: 51 regression
  cases covering null/list/scalar nested values, raw preservation and blocked saves.
- mobile/lib/features/onboarding/presentation/onboarding_vehicle_screen.dart:
  mounted guards, recoverable load errors, validated drafts, serialized autosave,
  controlled storage errors, duplicate-submit guard and partial-save recovery.
  Successful vehicle identity is retained in state and persisted into the draft;
  retry updates that vehicle, including after reopening a recoverable draft.
- mobile/lib/features/garage/data/vehicle_repository.dart: duplicate normalized
  plate checks in Drift transactions for creation and editing; useful domain error.
- mobile/test/features/onboarding/presentation/onboarding_recovery_test.dart:
  disposal, corruption, read/write failures, duplicate plates, partial saves,
  reopening and delayed autosave cleanup using real in-memory Drift.

## Tests executed

Working directory for all commands below: mobile.
flutter = C:/Users/felip/.codex/tooling/flutter_3.47.1/flutter/bin/flutter.bat.
dart = C:/Users/felip/.codex/tooling/flutter_3.47.1/flutter/bin/dart.bat.
Every Flutter/Dart invocation used Local\PicoRadarFlutterGate with WaitOne and
try/finally ReleaseMutex. No overlapping Flutter processes were started here.

| Command / test | Result |
|---|---|
| flutter test test/features/buy_sell/data/purchase_context_test.dart --reporter compact | RED: 51 new failures, 5 existing passes before F07 implementation |
| flutter test --no-pub test/features/onboarding/presentation/onboarding_recovery_test.dart --reporter expanded | RED: 17 failures before F08 implementation; disposal, parsing, storage and duplicate errors reproduced |
| flutter test --no-pub test/features/buy_sell/data/purchase_context_test.dart test/features/onboarding/presentation/onboarding_recovery_test.dart --reporter expanded | GREEN: 73 passed |
| flutter test --no-pub test/features/buy_sell test/features/onboarding test/features/garage/data/vehicle_repository_test.dart --reporter expanded --concurrency=1 | GREEN: 227 passed, including four additional recovery cases |
| dart format --output=none --set-exit-if-changed [the five Dart paths above] | PASS: 0 changed |
| flutter analyze --no-pub [the five Dart paths above] | PASS: no issues |
| git diff --check -- [the five Dart paths above] | PASS |
| dart format --output=none --set-exit-if-changed . | Exit 1: 19 files outside this scope needed formatting; output=none did not edit them |
| flutter analyze --no-pub | Exit 1: 11 findings, two in the new test corrected before focused analyze; nine findings outside this scope |
| flutter test --no-pub --concurrency=1 --reporter expanded | INTERRUPTED at owner request; only our session stopped, PID 25340 confirmed absent. Global suite belongs to coordinator |

An initial onboarding test attempt could not compile due to concurrent maintenance
WIP using ProviderContainer.disposed. The new test then used its own minimal
preferences fake instead of importing the full app harness; the RED run above
reproduced actual onboarding failures. Maintenance was not edited here.

The focused run emitted an existing missed-tap warning in the BuySell test
"failed restoration blocks saving over the original source"; no test failed.

## Global observations for coordinator

The interrupted global run was against a changing shared working tree, not an
immutable integration checkpoint. Five failures were observed, not repaired here:

1. core/database/wallet_preparation_migration_test.dart: v6 preserves data and
   enforces three exclusive owners (expected schema 8, actual 9).
2. Same file/test for v7 (expected 8, actual 9).
3. Same file/test for v8 (expected 8, actual 9).
4. core/sync/dataset_sync_hardening_test.dart: Python compiler bytes reach the
   engine through HTTP and Drift; eligibleForUnqualifiedOperationalCount missing
   or not boolean.
5. features/buy_sell/presentation/purchase_documents_screen_test.dart: stale root
   confirmation cannot delete after another visit unlocks. This test passed in
   the earlier 227-test focused run; document/navigation files changed concurrently.

Logs: C:/Users/felip/AppData/Local/Temp/PicoRadar-F07-F08-format.log,
PicoRadar-F07-F08-analyze.log and PicoRadar-F07-F08-full-test.log in the same folder.

## Manual / physical Android QA

- No device operations, installation, edits or deletions performed.
- Manual visual acceptance and physical lock/background/restore not certified.
- No platform integration changed by these commits; final Android build deferred
  to coordinator. CODEGEN_NOT_REQUIRED for F07/F08.

## Data, security and dependencies

- No schema migration, package, shared provider/router/DB edit or network behavior.
- Local corrupt drafts remain intact; no new PII logs or upload.
- BuySell legacy v1-v3 restoration retained and existing migration tests pass.
- Garage presentation, document features and other agents' changes untouched.

## Known risks / debt

- SQLite and preferences are separate stores. If the process dies after vehicle
  commit but before its recovery ID reaches preferences, a reopened old draft
  cannot automatically identify that partial save. The plate uniqueness check
  prevents duplication and directs the user to edit the saved vehicle in Garage.
- Corrupt onboarding drafts remain blocked with retry/back; no destructive reset
  or new repair UI was introduced.
- Global analyze/format/test results remain coordinator integration gates. No
  complete green global suite is claimed.

## Stop conditions and next work

No baseline/privacy conflict. Global test process stopped per owner instruction.
Coordinator can integrate F07/F08 and run the final suite/build after all workers.
No additional lot was started.

## Git status

All five implementation/test paths clean after the two scoped commits. Shared
working tree remains dirty with other agents' work (51 status entries observed
before writing this handoff); nothing reverted, removed or staged from those paths.
