# PicoRadar C26 V2 — handoff

## Status
`PARTIAL`

## Lot
`C26 V2 — menú móvil y UAT nacional`

## Git
- Branch: `codex/c26-a-publish`
- HEAD funcional antes del commit documental: `9641192` (`test(C26): assert responsive container visibility`)
- Base: `feat/platform-integral-national-20261122` at `4980d9c363d17392b3b030e4d6ee4e1a97776c5d`
- Worktree: `C:\Users\felip\.codex\worktrees\c26-a-publish\PicoRadar-C17-V2`
- El SHA completo del commit documental y el resultado del push FF quedan en `GITHUB_STATE.md` del paquete único.

## Outcome
- A: navegación móvil nativa `<details>/<summary>`, enlaces protegidos por los permisos existentes y cobertura focal de roles PASS.
- B: preflight aislado PASS; la única siembra falló con `TypeError` después de migrar. No se reutilizó ni borró la SQLite; permanece retenida con esquema y cero filas sintéticas.
- C: navegador interno confirma CSS/HTTP y redirects anónimos. Sin operadores/filas, menú autenticado, navegación permitida y estados nacionales no se verificaron.

## Files / areas changed
- `server/resources/views/layouts/admin.blade.php`
- `server/tests/Feature/C26MobileNavigationTest.php`
- `docs/CURRENT.md`
- `codex/C26_V2_HANDOFF.md`

No se publica `codex/qa/c26/` porque la herramienta de siembra no superó el gate.

## Tests executed
| Command / test | Result |
|---|---|
| `php -d extension=php_pdo_sqlite.dll vendor/phpunit/phpunit/phpunit --filter C26MobileNavigationTest` | PASS — 3 tests, 37 assertions, exit 0 |
| `php -l server/tests/Feature/C26MobileNavigationTest.php` | PASS |
| `git diff --check 4980d9c..HEAD` | PASS; code delta only |
| Fixture preflight via loopback HTTP | PASS — no database created |
| Fixture apply via loopback HTTP | BLOCKED — `TypeError`; migration-only SQLite retained |
| Browser internal, 360/1280 CSS px | Login styled, CSS loaded, no horizontal overflow; protected admin routes redirect 302 to login |

No C19–C25 suites, Flutter builds, APK, ADB, Android device or phone were used.

## Manual QA
- The internal browser displayed the real login page at 360 and 1280 CSS px. The four requested admin URLs returned to login because the failed fixture left zero operators. The mobile menu and populated tables could not be reached; no target-screen screenshots are claimed.
- HTTP: `/login=200`; `/build/assets/app-BcJHtoBT.css=200` (`text/css`, 45,372 bytes); each target route returned `302` to `/login` anonymously.
- Browser console: zero errors/warnings. Login document overflow: none at either viewport.

## Physical Android QA
`Not required`
- Device: none
- Android: no build/ADB/device activity; `HOLD_OS_SYMLINK_UNCHANGED`
- Evidence: outside C26 authorization.

## Data / migration impact
- No product or real database changed. The isolated SQLite at `D:\codex\_REPORTES\PicoRadar\C26-V2-20261123\_QA_LOCAL\c26-fixture-20261123.sqlite` is retained outside the repository and ZIP. Read-only inspection: 36 migrated tables; zero rows in the relevant user/geography/jurisdiction/dataset/rule/app-user/sponsor/campaign/release tables.
- The fixture runner did not report the TypeError message. Do not reuse this database or claim national legal coverage.

## Security / privacy review
- Temporary operator secrets were process-only and were not printed, persisted in the repository, or packaged. Public campaign catalog remained OFF. No real customer data, marketing, legal publication, or external service was used.

## Dependencies added/changed
- None.

## Known risks / debt
- Fixture seed remains blocked by an unclassified `TypeError`; therefore no authenticated browser QA or required populated-state screenshots.
- Android launch, OTA QA, and municipality-by-municipality legal validation remain open. Synthetic DIVIPOLA-shaped codes are not legal findings.
- C25 manual cleanup remains pending: `%%LOCALAPPDATA%%\Temp\Picoradar-C25-QA\synthetic-users.tmp`; do not retry or bypass.

## Stop conditions encountered
- B stopped after its one new SQLite had been created/migrated and fixture application returned `TypeError`. The database was preserved. No extra fixture database or re-run was attempted.

## Next lot(s) unblocked
- Diagnose the fixture `TypeError` in a newly authorized isolated QA run, then run the single populated browser matrix and capture only sanitized target screens.
- Android requires an authorized environment that supports symlinks; legal coverage needs primary municipal sources and human review.

## Do not forget
- No merge performed. One normal fast-forward push to the authorized feature branch is recorded in the return package.
