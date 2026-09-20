# B06 Hostinger Staging Installer - Handoff

## Status
`DONE_LOCAL_PENDING_MANUAL_INSTALLATION`

## Lot
`B06 - Hostinger staging installer`

## Git
- Branch: `feat/B06-hostinger-staging-installer`
- Implementation checkpoint: `8c7f352f86d9e0ac17bcbbb90fb61965ae1b6219`
- Base: `e6406f2f7841d49ef2653f83b728c2cdfe68274f`
- Worktree: `C:\Users\felip\.codex\worktrees\b06-hostinger-installer\PicoRadar_ Pico y Placa`
- Final delivery HEAD: recorded in `PicoRadar-PRUEBAS_Y_PROCEDENCIA.json`

## Outcome
- Guided, one-time web installer for a private Hostinger staging environment.
- Prebuilt public/private package requiring no SSH, Composer or Node on Hostinger.
- Atomic environment creation, empty-database gate, migrations and one initial
  `super_admin` through a shared domain action.
- Package integrity verification, partial-state recovery and irreversible setup
  lock.
- Private bounded cron runner and prebuilt-package preflight.
- No deployment was performed.

## Files / areas changed
- `server/app/Installation/`
- `server/app/Actions/Admin/InitialOperatorCreator.php`
- `server/deploy/hostinger/`
- `server/bin/cron.php`
- `server/bootstrap/app.php`
- `scripts/build_hostinger_staging_package.ps1`
- `scripts/verify_hostinger_staging_package.ps1`
- `scripts/server_preflight.ps1`
- `scripts/tests/hostinger_installer_clean_room.php`
- `scripts/tests/test_hostinger_installer_mariadb.ps1`
- Installer, operator, preflight and package tests
- B06 lot documentation and staging runbook

## Tests executed
| Command / test | Result |
|---|---|
| Baseline Laravel suite | PASS - 503 tests / 2373 assertions |
| B06 focal suite on PHP 8.3.33 | PASS - 27 tests / 100 assertions |
| B06 focal suite on PHP 8.4.23 | PASS - 27 tests / 100 assertions |
| B06 focal suite on PHP 8.5.8 | PASS - 27 tests / 100 assertions |
| Updated Laravel suite | PASS - 530 tests / 2473 assertions |
| Installer/operator regression | PASS - 24 tests / 92 assertions |
| `composer validate` | PASS |
| `pint --test` | PASS |
| route cache / clear | PASS |
| preflight tests | PASS |
| package structure, manifest, exclusions and SHA-256 | PASS |
| clean package + disposable MariaDB 11.8.8 | PASS |
| real HTTP Login and `/api/v1/health` | PASS |
| cron, public/private links and migration rollback | PASS |
| `git diff -- mobile` | EMPTY |

## Manual QA
- Extracted the generated ZIP outside the repository.
- Completed installation using synthetic credentials and an empty disposable DB.
- Verified that package and test logs expose no database or operator password.
- Verified setup package does not contain plaintext install token or `.env`.

## Physical Android QA
`Not required`
- Flutter and the phone were intentionally untouched.

## Data / migration impact
- No existing database or phone data was modified.
- Local integration used a disposable MariaDB directory and synthetic operator.
- Hostinger installation still requires a new exclusive empty database.

## Security / privacy review
- Laravel, `.env`, vendor state, logs and storage remain outside `public_html`.
- Token is submitted in the body; only its hash is packaged.
- Secure/HttpOnly/SameSite Strict session, CSRF and attempt limiting are enabled.
- Setup becomes 404 after `installed.lock` and must then be deleted manually.
- No registration, ads, payment, WhatsApp, OSRM or partner intake was activated.

## Dependencies added/changed
- No production package was added.
- Composer production dependencies are bundled from the existing lockfile.
- PHP 8.3.33 official NTS runtime was used only as local compatibility tooling.

## Known risks / debt
- Hostinger capabilities remain unaccredited until the on-host diagnostic runs.
- Hostinger must support symbolic links; the installer blocks before migration if
  it does not.
- Updates and password recovery need separately authorized utilities; this setup
  assistant is intentionally first-use only.

## Stop conditions encountered
- None remain locally. Windows junction detection required path-resolution
  validation; both links now resolve to their exact private targets.

## Next lot(s) unblocked
- Manually protected Hostinger staging installation, after owner authorization.
- Separate future updater/rollback design after staging acceptance.

## Do not forget
- Protect the subdomain before opening `/_setup/`.
- Keep the install token outside the uploaded ZIP.
- Delete `_setup` from File Manager after completion.
- Configure the hPanel PHP cron every five minutes in UTC.
- No merge was performed.
