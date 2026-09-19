# Lot Handoff

## Status
`DONE`

## Lot
`Lot B - wallet two-sided documents`

## Git
- Branch: `codex/lot-b-wallet-two-sides`
- HEAD: this handoff commit; canonical SHA is reported with the final handoff response
- Base ref: `d26ba84b1e1aeb7738e7dc965a3ad4adca16d917`
- Worktree: `C:\Users\felip\.codex\worktrees\owner-wallet\PicoRadar_ Pico y Placa`

## Outcome
- Identity card, driver license, and traffic license now use a guided front-then-back capture flow with one scanner page per step.
- The user can save only the front and add the back later.
- Existing copies expose add/replace front, add/replace back, replace PDF, and delete-whole-document actions as applicable.
- Side replacement is atomic, retains untouched encrypted sides, and journals cleanup only for replaced ciphertext.
- Stored PDFs retain validated one-page or two-page status.
- Existing scanner opening/recovery behavior remains in place and the release APK passes the ML Kit DEX registrar gate.

## Files / areas changed
- Wallet document model and encrypted store operation.
- Wallet capture/import actions and document action sheet.
- Focused wallet store, flow, and existing menu regression tests.
- No driving, Home, backend, maintenance, Tramites, or dataset files changed.

## Tests executed
| Command / test | Result |
|---|---|
| New two-sided flow and menu tests | PASS, 6 tests |
| Wallet store tests | PASS, 30 tests |
| Relevant Flutter gate: Documents, wallet/database migrations, vehicle cleanup/status, Settings, Android bridge | PASS, 472 tests |
| `dart format --output=none --set-exit-if-changed .` | PASS, 366 files, 0 changed |
| `flutter analyze --no-pub` | PASS, no issues |
| Android native wallet unit tests | PASS, 9 tests |
| Android backup/privacy verification | PASS, 60 checks |
| Wallet release fixture gate | PASS, 2 valid and 11 invalid fixtures |
| `flutter build apk --release --flavor dev --dart-define=APP_ENV=dev --no-pub` | PASS, 106,169,565-byte APK |
| Actual APK ML Kit DEX verification | PASS |

Release APK SHA-256: `1c1cc47c1d8fa0eba2c7b92dff443f9b5974e55eb960a27189737aacce5fbdff`.

## Manual QA
- Automated widget coverage verifies guided scanner front/back capture, front-only availability, side-specific menus, PDF replacement, and page-count status.
- No human visual acceptance was performed in this worker.

## Physical Android QA
`Blocked`
- Device: none attached to this worker
- Android: not applicable
- Evidence: release build and native/package gates passed; physical camera, authentication, lifecycle, and screenshot-blocking checks remain for a real device.

## Data / migration impact
- No schema change and no migration.
- Existing optional front/back/PDF encrypted references are reused.
- Side replacement writes new ciphertext before one database transaction replaces the row; failed authorization/transactions remove the new ciphertext and preserve the prior document.

## Security / privacy review
- Encryption, owner validation, authorization epoch checks, `FLAG_SECURE` ownership, 25 MB import limits, viewer plaintext cleanup, scanner temporary cleanup, and encrypted cleanup journals remain active.
- No new logging, network transfer, cloud storage, secret, or dependency was added.

## Dependencies added/changed
- None.

## Known risks / debt
- Physical Android QA remains required for camera/scanner UI, credential allow/cancel, background/restore, and screenshot blocking.
- The release APK is a local verification artifact and is not committed.

## Stop conditions encountered
- None. The physical QA limitation is recorded rather than bypassed.

## Next lot(s) unblocked
- Owner/device QA can validate the two-sided flow on hardware before integration.

## Do not forget
- No merge or push was performed.
