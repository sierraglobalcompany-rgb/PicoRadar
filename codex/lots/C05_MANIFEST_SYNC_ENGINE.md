# LOT C05 — HTTP/config + manifest and atomic dataset sync engine

**Suggested branch:** `feat/C05-manifest-sync-engine`  
**Status at pack creation:** NOT STARTED

## GOAL

Implement the scalable versioned-data pipeline used by rules/cameras/tolls/directories.

## SOURCE OF TRUTH

- Arquitectura §14, §17–20
- contracts/MANIFEST_CONTRACT.md

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C03
- C04

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- Add Dio baseline.
- Environment config for API/CDN base URLs.
- Manifest DTO/parser.
- ETag support if practical.
- Compare dataset versions.
- Download to temp, SHA-256 verify, decompress, schema validate hook.
- Transactional import interface.
- Update dataset_versions only after commit.
- Rollback/retain old data on failure.
- Jitter/TTL policy abstraction.
- Fixture HTTP tests.

## OUT OF SCOPE

- Specific restriction/camera import schemas.
- FCM.
- Workmanager scheduling.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] Corrupt/hash-failing dataset never replaces current.
- [ ] Interrupted sync preserves old dataset.
- [ ] No network call blocks first UI frame.

## TESTS REQUIRED

- `unit/integration sync tests`
- `flutter analyze`
- `flutter test`

## PHYSICAL QA

Not required.

If physical QA is required, use `codex/ANDROID_PHYSICAL_QA.md` and record evidence.

## ARTIFACTS

At minimum:
- code diff;
- tests;
- updated docs/ADR if needed;
- handoff report.

## STOP CONDITIONS

- Manifest contract must change incompatibly; create ADR before continuing.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not sync every app open unconditionally.
- Do not write directly into production tables without transaction.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
