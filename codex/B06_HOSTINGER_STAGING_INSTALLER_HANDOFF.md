# B06 Hostinger Staging Installer - Handoff

## Status
`LOCAL_READY_FOR_PRIVATE_STAGING_REVIEW`

Hostinger remains `HOSTINGER_NOT_TOUCHED / PENDING_TARGET_SMOKE`.

## Lot
`B06 - Hostinger staging installer`

## Git
- Branch: `feat/B06-hostinger-staging-installer`
- Base: `e6406f2f7841d49ef2653f83b728c2cdfe68274f`
- Pre-closure checkpoint: `4616dcc36334184bfefedb9ffc6944d27ccf0a25`
- Final implementation/test HEAD: `e40b103`
- Final delivery HEAD: recorded after packaging in the evidence manifest.
- Worktree: `C:\Users\felip\.codex\worktrees\b06-hostinger-installer\PicoRadar_ Pico y Placa`

## Outcome
- Corrected the six installer defects independently reported against the original
  B06 package: dotenv interpolation, empty manifest acceptance, untrusted HTTPS
  forwarding, unsafe state recovery, Basic Auth replacement and ambiguous DB
  configuration flow.
- Produced a portable prebuilt package with `/` ZIP paths and a strict manifest.
- Completed the real setup wizard from the packaged ZIP behind local HTTPS and
  Basic Auth, using two browser sessions and disposable MariaDB 11.8.8.
- Verified operator creation, logout/login, admin panel, health contract, private
  path denial, irreversible setup closure, cron work, recovery and synthetic
  backup/restore.
- Preserved C11 and `mobile/` byte-for-byte relative to this branch.
- No Hostinger access, phone access, deployment, push or merge occurred.

## Files / Areas Changed
- `server/app/Installation/`
- `server/app/Actions/Admin/InitialOperatorCreator.php`
- `server/deploy/hostinger/`
- `server/bin/cron.php`
- `server/bootstrap/app.php`
- `scripts/build_hostinger_staging_package.ps1`
- `scripts/verify_hostinger_staging_package.ps1`
- `scripts/server_preflight.ps1`
- `scripts/tests/hostinger_installer_*`
- Installer, operator, preflight and package tests
- B06 lot documentation and staging runbook

## Acceptance Gates
| Gate | Result |
|---|---|
| `ZIP_PORTABLE` | PASS - standard Windows verification and Linux/BusyBox extraction without repair |
| `ENV_SECRET_ROUNDTRIP` | PASS - special password preserved through PDO, `.env` and Laravel bootstrap |
| `MANIFEST_FAIL_CLOSED` | PASS - empty, altered, duplicate, unsafe and incomplete manifests rejected |
| `HTTPS_AND_PRIVATE_BARRIER` | PASS - untrusted forwarding rejected; root/login/setup blocked without Basic Auth |
| `DB_EMPTY_CHECK` | PASS - database must be empty before any migration |
| `RECOVERY_AND_CONCURRENCY` | PASS - monotonic release-bound state, backup recovery and cross-session mutation lock |
| `REAL_BROWSER_INSTALL` | PASS - complete wizard from the final extracted ZIP over local HTTPS |
| `ADMIN_SMOKE` | PASS - operator login and panel access after installation |
| `CRON_REAL_JOB` | PASS - real queued job, overlap lock, failure and later recovery |
| `RESTORE_SYNTHETIC` | PASS - database and sample storage restored and read in a second disposable environment |
| `PHP_MATRIX` | PASS - focal suite on PHP 8.3.33, 8.4.23 and 8.5.8 |
| `C11_UNCHANGED` | PASS - `git diff -- mobile` is empty |

## Tests Executed
| Command / test | Result |
|---|---|
| Installer unit suite, PHP 8.3.33 | PASS - 35 tests / 113 assertions / 1 platform skip |
| Installer unit suite, PHP 8.4.23 | PASS - 35 tests / 113 assertions / 1 platform skip |
| Installer unit suite, PHP 8.5.8 | PASS - 35 tests / 113 assertions / 1 platform skip |
| Full Laravel suite, PHP 8.5.8 with isolated SQLite extensions and synthetic APP_KEY | PASS - 543 tests / 2505 assertions / 1 platform skip |
| `composer validate --no-check-publish` | PASS |
| `vendor/bin/pint --test` | PASS |
| Package structure, manifest, exclusions and SHA-256 | PASS |
| Linux/BusyBox extraction of exact ZIP | PASS - 6630 files extracted without repair |
| Clean package + disposable MariaDB 11.8.8 | PASS |
| HTTPS browser wizard + two sessions | PASS |
| Login, panel, health and private-path negatives | PASS |
| Real database queue cron + overlap + failure recovery | PASS |
| Synthetic database/storage backup and restore | PASS |
| `git diff -- mobile` | EMPTY |

The first full-suite attempt used a PHP binary without SQLite and failed only
with `could not find driver`. A direct rerun with SQLite loaded in that process
passed. No test or product control was removed to obtain green results.

## Manual QA
- Extracted the exact candidate ZIP outside the repository.
- Installed it through the browser wizard using synthetic credentials.
- Confirmed the existing synthetic Basic Auth directives remained after routing
  rules were installed.
- Confirmed setup returns 404 after completion.
- Captured sanitized installer completion and admin panel evidence.
- Confirmed package and evidence do not contain the plaintext installation token.

## Physical Android QA
`Not required`

- Flutter and the phone were intentionally untouched.

## Data / Migration Impact
- No existing database or phone data was modified.
- Local integration used disposable MariaDB data and a synthetic operator.
- Hostinger still requires a new exclusive empty database.

## Security / Privacy Review
- Laravel, `.env`, vendor state, logs and storage remain outside `public_html`.
- The token is submitted in the request body; only its Argon2id hash is packaged.
- HTTPS is checked before accepting setup credentials; proxy signals require an
  explicit trusted proxy IP.
- Session cookies are Secure, HttpOnly and SameSite Strict; CSRF and throttling
  remain enabled.
- Existing Basic Auth rules are preserved by a marked idempotent routing block.
- Setup becomes 404 after `installed.lock` and must then be deleted manually.
- No secrets, `.env`, private key, database, session or PII are in the evidence ZIP.
- Registration, Lite, ads, payments, Pro, WhatsApp, OSRM and public partner intake
  remain disabled.

## Dependencies Added / Changed
- No production package was added.
- Composer production dependencies and built assets come from existing lockfiles.
- PHP 8.3.33 and 8.4.23 runtimes were used only as local compatibility tools.

## Known Risks / Debt
- Hostinger PHP extensions, symlink policy, filesystem permissions, proxy topology
  and cron behavior remain unverified until the on-host diagnostic runs.
- The setup assistant is first-use only. Updates and password recovery require a
  separately authorized tool.
- The test environment is Windows plus Linux/BusyBox extraction; the target host
  still needs its own private staging smoke test before acceptance.

## Stop Conditions Encountered
- None remain locally.
- A Windows-only symlink negative test is skipped because creating true symlinks
  requires privileges; package validation rejects links and Linux extraction was
  verified independently.

## Next Lot Unblocked
- Owner-authorized manual upload and private Hostinger staging smoke test.
- A separate updater/rollback design only after staging acceptance.

## Do Not Forget
- Protect the subdomain before opening `/_setup/`.
- Keep the install token outside the uploaded and evidence ZIPs.
- Delete `_setup` from File Manager after completion.
- Configure the hPanel PHP cron every five minutes in UTC.
- No merge was performed.
