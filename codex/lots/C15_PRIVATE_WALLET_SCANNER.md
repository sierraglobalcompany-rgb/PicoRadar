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

## Owner Extension: 2026-09-13 (Implementation In Progress)

- Driver-first Documents design; a permanent Principal profile and at most one
  additional local profile. Driver documents do not require a vehicle.
- Optional whole-wallet system authentication. Leaving the visit or background
  revokes access, including vehicle copies entered through SOAT/Tecnomecanica.
- Internal secure viewer replaces external opening. No sharing/export or OCR.
- Drift v7 stores encrypted metadata and ownership; ciphertext stays outside
  SQLite in Android no-backup storage. Legacy migration must be idempotent and
  preserve IDs, references and unresolved records. Explicit deletion must also
  remove legacy copies, with recoverable cleanup on failure.
- Front/back for identity, driving and traffic licenses; other existing PDFs
  retain their pages. New imports are limited to 25 MB and require signature
  plus decoder validation and an explicit preview before committing.

### Dependency Decision

`local_auth` 3.0.2 is the official Flutter plugin already contemplated by the
baseline. It delegates credential UI to Android; an app-owned PIN or a custom
biometric implementation was rejected. Android integration uses
FlutterFragmentActivity and USE_BIOMETRIC. The plugin has a BSD-3-Clause license;
iOS support exists in the plugin but the complete native wallet remains pending.

ML Kit Document Scanner 16.0.0 is the baseline Android scanner, using basic mode,
without OCR. The standard file picker remains available when scanner components
are unavailable. The Google SDK is governed by its published SDK terms, not the
Flutter plugin license. Its optional first-use download must not be described as
fully offline first use. No app camera permission is introduced.

PDF rendering uses Android PdfRenderer inside a non-exported isolated service,
not an additional PDF runtime package. Pages are rendered on demand with bounded
bitmap size. The bridge fails explicitly on unsupported platforms; no external
viewer fallback is allowed for private copies.

APK size impact, physical authentication/scanner/secure-window evidence and
owner visual approval remain gates, not completed claims in this extension.

## Approved purchase-preparation ownership extension (2026-09-15)

Explicit owner plan adds preparation-owned documents; it does not complete the
remaining physical C15 acceptance. Drift v8 introduces WalletPreparations and an
exclusive preparation foreign key on PrivateDocuments, retaining IDs, encrypted
metadata and existing files during v7 migration. Driver and vehicle ownership
remain unchanged. Draft v4 keeps the preparation ID stable and archives an old
candidate instead of reassigning its private files to another candidate.

PurchaseDocumentsScreen is an explicitly named secure visit. It reuses the
wallet session, encryption, scanner/import confirmation, protected internal
viewer and cleanup. Unprotected tutorials and official portal links remain
accessible without authentication. No runtime package, external private-file
viewer, OCR or cloud storage was added. See
`codex/PURCHASE_FUNCTIONAL_HANDOFF_20260915.md` for tests and physical limits.
