# LOT C15 — Private wallet + Android document scanner + biometrics

**Suggested branch:** `feat/C15-private-wallet-scanner`  
**Status at pack creation:** NOT STARTED

## GOAL

Implement the sensitive local document flow safely on Android.

## SOURCE OF TRUTH

- Flujo 03 W-001/W-002/W-003
- Arquitectura §12–13, §29

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C04
- C08

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- private_documents metadata table/migration if not already present.
- Android MethodChannel wrapper to ML Kit Document Scanner.
- Front/back flow + gallery where supported.
- Encrypt final images with AES-GCM.
- Delete plaintext temp files.
- Document viewer front/back.
- local_auth optional gate.
- No-backup storage handling Android.
- Labels stating copy is backup, not official substitute.

## OUT OF SCOPE

- iOS VisionKit implementation.
- Cloud backup.
- OCR extraction.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] No unencrypted document remains after save flow.
- [ ] Restart can decrypt/show after biometric rules.
- [ ] Cancel cleans temp.
- [ ] No analytics/ads on viewer.

## TESTS REQUIRED

- `unit crypto/storage`
- `widget flow`
- `platform bridge tests where possible`

## PHYSICAL QA

REQUIRED: camera scan, gallery, cancel, biometric allow/deny, restart.

If physical QA is required, use `codex/ANDROID_PHYSICAL_QA.md` and record evidence.

## ARTIFACTS

At minimum:
- code diff;
- tests;
- updated docs/ADR if needed;
- handoff report.

## STOP CONDITIONS

- Scanner API/device dependency unavailable on supported test device; implement graceful unsupported state.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not store image blobs in DB.
- Do not use OCR.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
