# C25 V2 — handoff local

## Status
`PARTIAL`

## Lot
`C25 — HTTP admin, security and visual QA`

## Git
- Branch: `codex/c25-integrator`
- Code HEAD: `4891534cdbb5b5d49a2e5d295110d89ea0034fdc`
- Base: `c154d38383a68aa092a687fb0b5cd71dbaced66b`
- Target branch: `feat/platform-integral-national-20261122`
- Worktree: `C:\Users\felip\.codex\worktrees\c22-integrator\PicoRadar-C17-V2`
- The final documentation commit and remote result are recorded in `GITHUB_STATE.md` in the C25 return ZIP.

## Outcome
- A authenticated HTTP/ACL matrix passed with isolated synthetic SQLite and PHP `cli-server`; anonymous, SuperAdmin, Commercial and public catalog OFF cases matched expected statuses.
- B visual QA was performed in the ChatGPT in-app browser. Five routes were inspected at 360 and 1280 CSS px. No document overflow or browser-console errors. Three sanitized captures were retained.
- C npm security advisories were patched with lock-only updates; the single requested `npm ci`, Vite build and final audit passed.
- Overall remains partial: the synthetic DB intentionally has zero municipalities and zero app-user accounts, so those row states were not certified. Android remains held; no APK or device operation.

## Files / areas changed
- `server/package-lock.json`: patch/minor transitive version updates only; `server/package.json` unchanged.
- `docs/CURRENT.md`: one C25 state entry.
- `codex/C25_HANDOFF.md`: this handoff.
- No product source, legal rules, database schema, app data, permissions, certificates, secrets or external service settings changed.

## Tests executed
| Command / test | Result |
|---|---|
| PHP CLI/SAPI preflight, PHP 8.5.8 with `pdo_sqlite` | PASS |
| Synthetic HTTP auth/ACL matrix: 13 route/action cases | PASS |
| Initial `npm audit --json` | 5 advisories, expected nonzero exit |
| Lock-only npm update | PASS |
| `npm ci --no-audit --no-fund` (once) | PASS |
| `npm run build` (once) | PASS |
| Final `npm audit --json` | PASS, zero advisories |
| In-app-browser visual sweep: 5 routes × 2 viewport widths | PASS_FOCAL; empty data limits row validation |

## Manual QA
- Routes: admin summary, national operations, municipal matrix, app users, campaign planning.
- Viewports: 360 and 1280 CSS px. No page-level horizontal overflow; tables expose horizontal scrolling at narrow width. Browser console errors: 0.
- Captures: `01-360px-national-operations.jpg`, `02-1280px-campaign-planning.jpg`, `03-360px-campaign-planning.jpg` in the return ZIP.
- Synthetic data: 0 municipalities and 0 app-user accounts. Municipal OFF and actual account rows remain unverified. Campaign planning explicitly showed `PUBLICIDAD OFF / SOLO SIMULACIÓN`.

## Physical Android QA
`Not required; Android gate held`
- Device: none touched.
- Evidence: `HOLD_OS_SYMLINK_UNCHANGED`; `APK_NEW=NO`.

## Data / migration impact
- No product data or migrations changed. HTTP checks used an isolated temporary synthetic SQLite database.

## Security / privacy review
- Initial npm audit: 5 package advisories (3 high, 2 critical); final audit: zero. Final package lock SHA-256: `57945438E08009CFD6B67BFF40AF90D68E1E3D287A5DF6A86B5B5F3B2D306362`.
- Synthetic credentials/cookies were not retained in evidence. The QA server was stopped after capture; no service or business mutation was performed.

## Dependencies added/changed
- No dependency manifest change. `server/package-lock.json` only.

## Known risks / debt
- No municipal rows or app-user rows existed in the synthetic database; their individual UI states are not established.
- Android symlink gate remains unresolved; no APK was created.
- `LEGAL=NO_GO`, `RELEASE=NO_GO`, `MAIN_BRIDGE=HOLD`.

## Stop conditions encountered
- Android remained held at the unchanged OS symlink gate. No unsafe workaround was attempted.

## Next lot(s) unblocked
- Director review of the C25 evidence package. Do not infer release approval from the npm gate.

## Do not forget
- No merge performed. Only the explicitly authorized target branch may be updated, using a normal fast-forward push.
