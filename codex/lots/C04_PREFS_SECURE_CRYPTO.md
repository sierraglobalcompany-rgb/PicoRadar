# LOT C04 — Preferences + secure storage + crypto foundations

**Suggested branch:** `feat/C04-prefs-secure-crypto`  
**Status at pack creation:** NOT STARTED

## GOAL

Provide safe local settings and encrypted-file primitives before Billetera.

## SOURCE OF TRUTH

- Arquitectura §12
- Cierre Global §21

Always also obey `AGENTS.md` and the Baseline precedence.

## DEPENDENCIES

- C03

Do not start if required dependencies are not DONE unless the user explicitly authorizes a stub/mocked path described here.

## IN SCOPE

- SharedPreferencesAsync wrapper for non-sensitive settings.
- flutter_secure_storage wrapper for small secrets/master key.
- AES-256-GCM service using cryptography package.
- Encrypted file envelope format with version/nonce/ciphertext/tag.
- Tests for encrypt/decrypt/tamper/failure.
- Logging redaction helpers.

## OUT OF SCOPE

- Document scanner.
- Biometric UI.
- Cloud backup.

## IMPLEMENTATION RULES

- Follow KISS.
- Do not change frozen product decisions.
- Do not add unrelated refactors.
- New dependency requires written rationale.
- Preserve privacy/local-first rules.
- Update tests with behavior.

## ACCEPTANCE CRITERIA

- [ ] Tampered ciphertext fails closed.
- [ ] Keys are not written to prefs/logs.
- [ ] Plaintext temp handling API is explicit.

## TESTS REQUIRED

- `unit crypto tests`
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

- Platform secure storage cannot initialize on Android baseline.

Plus all global Stop Conditions in `AGENTS.md`.

## DO NOT

- Do not invent custom crypto.
- Do not store master key in SQLite/shared prefs.

## HANDOFF

Complete `codex/templates/HANDOFF_TEMPLATE.md`.  
Do **not** merge without explicit human approval.
