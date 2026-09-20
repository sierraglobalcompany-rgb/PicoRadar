# B06 Hostinger Staging Installer - Handoff

## Status
`LOCAL_READY_FOR_PRIVATE_STAGING_REVIEW`

Hostinger remains `HOSTINGER_NOT_TOUCHED / PENDING_TARGET_SMOKE`.

## Lot
`B06 - Hostinger staging installer`

## Git
- Branch: `feat/B06-hostinger-staging-installer`
- Base: `e6406f2f7841d49ef2653f83b728c2cdfe68274f`
- Pre-concurrency checkpoint: `16514c7f8e761fa273462cf99c321573d2efbd00`
- Package source HEAD: `2095695d16fc414d7c32213d803ac42cc71b4a4b`
- Package source tree: `2a7564e1d4a394b9a7a5dc76baa31a643ff7a86e`
- Package release: `20260920T082106Z-2095695d16`
- Final documentation HEAD: recorded in the external handoff manifest after this document is committed.
- Worktree: local B06 worktree; exported evidence replaces it with `[B06_WORKTREE]`.

## Outcome
- Fixed the reproduced entrypoint race: failure to acquire the mutation lock no
  longer changes installation state or records a false migration failure.
- Added a typed lock-contention outcome and a safe retry message. Unexpected lock
  acquisition errors also leave shared state untouched.
- State is reread only after lock ownership is established.
- Concurrent finalization is idempotent and does not rerun preparation after the
  completed stage has been observed.
- The packaged browser flow now verifies prolonged contention, two-session stage
  convergence, concurrent finalization, irreversible closure, login/logout and
  private-path denial.
- Login uses the form action rendered by Laravel. The local PHP process receives a
  test-only `APP_URL` matching the isolated HTTPS origin; the DOM and package bytes
  are not rewritten, and no request reaches the real domain.
- A separate disposable scenario proves that a real migration failure while the
  request owns the lock is still recorded as `migration_failed` with retry `new`.
- Exported JUnit XML is sanitized and parsed as standard XML.
- C11 and `mobile/` remain unchanged from the B06 base.

## Files / Areas Changed
- `server/app/Installation/InstallationLockBusyException.php`
- `server/app/Installation/InstallationMutationLock.php`
- `server/deploy/hostinger/setup.php`
- `server/tests/Unit/Installation/InstallationMutationLockTest.php`
- `scripts/tests/hostinger_installer_browser_test.js`
- `scripts/tests/test_hostinger_installer_browser.ps1`
- `scripts/sanitize_junit_xml.ps1`
- This handoff and B06 evidence only

## Final Package
- File: `PicoRadar-staging-hostinger-20260920T082106Z-2095695d16.zip`
- SHA-256: `53D0CAA575E53C03F84C2C9079E0D63052F2E30F2F38A7F8B61C52BAAC66395D`
- Size: `8,891,843` bytes
- Manifest source HEAD: `2095695d16fc414d7c32213d803ac42cc71b4a4b`
- Plaintext installation token: separate local file only; excluded from Git,
  installable ZIP, evidence ZIP and this handoff.

## Tests Executed
| Command / test | Result |
|---|---|
| Original packaged contention regression before fix | RED: blocked request failed to show operation-in-progress and changed the flow |
| `InstallationMutationLockTest` | PASS: typed contention exception |
| Package verifier against final ZIP | PASS: paths, strict manifest, token separation, exclusions and hashes |
| Browser scenario `happy` against final extracted ZIP | PASS: HTTPS, Basic Auth, prolonged contention, unchanged state bytes, two sessions, migration convergence, operator, concurrent finalization, setup 404, Health, login/logout and private paths |
| Browser scenario `migration-failure` | PASS: real failure under owned lock recorded as `failed/new/migration_failed` |
| Disposable MariaDB 11.8.8 clean room | PASS: install, login, Health, links, real queue cron, overlap, failure recovery, backup/restore and rollback |
| Full Laravel suite, PHP 8.5.8 | PASS: 543 tests, 2,505 assertions, 1 platform skip |
| Installer suite, PHP 8.3.32 | PASS: 35 tests, 113 assertions, 1 platform skip |
| `composer validate --no-check-publish` | PASS |
| `vendor/bin/pint --test` | PASS |
| Sanitized JUnit parse | PASS for PHP 8.3 installer and PHP 8.5 full-suite XML |
| `git diff e6406f2 -- mobile` | EMPTY |

The first full-suite invocation lacked `pdo_sqlite`; a second had SQLite but no
synthetic `APP_KEY`. Both setup-only failures were retained in the narrative and
the final run loaded SQLite explicitly with a synthetic test key. No product or
test control was removed to obtain green results.

## Manual QA
- Extracted the exact final ZIP outside the repository for every browser and
  MariaDB scenario.
- Compared installation-state bytes before and after a request that timed out on
  the mutation lock; they were identical.
- Confirmed concurrent migration requests converged on `migrated` and concurrent
  finalization requests converged on `completed`.
- Confirmed the installer returns 404 after completion.
- Confirmed the real rendered login action stays on the isolated local origin,
  then completed login and logout.
- Confirmed package and handoff evidence contain no plaintext installation token.

## Physical Android QA
`Not required`

- Flutter, C11 and the phone were intentionally untouched.

## Data / Migration Impact
- No real database, Hostinger resource or phone data was modified.
- All database tests used disposable MariaDB or in-memory SQLite data.
- No production schema change was added by this concurrency correction.

## Security / Privacy Review
- A request without lock ownership cannot write state, `.env`, tables, operator
  records or the final marker.
- Lock contention exposes only a generic operation-in-progress message.
- Package integrity, HTTPS, CSRF, secure cookies, Basic Auth preservation and
  private application placement remain unchanged.
- The test-only local URL override exists only in the spawned PHP process.
- No token, password, private key, `.env`, database or PII is exported.

## Dependencies Added / Changed
- None.

## Known Risks / Debt
- Hostinger PHP extensions, symlink policy, filesystem permissions, proxy topology
  and cron behavior remain unverified until an owner-authorized private smoke test.
- PHP 8.4 was not re-downloaded for this delta. The unchanged prior B06 matrix had
  passed on PHP 8.4.23; this closure reran PHP 8.3.32 and PHP 8.5.8.
- The installer remains first-use only; updates and password recovery require a
  separately authorized mechanism.

## Stop Conditions Encountered
- None remain locally.

## Next Lot Unblocked
- Owner-authorized manual upload and private Hostinger staging smoke test.

## Do Not Forget
- Protect the subdomain before opening `/_setup/`.
- Keep the installation token outside uploaded and evidence ZIPs.
- Delete `_setup` in File Manager after completion.
- Configure the hPanel PHP cron every five minutes in UTC.
- No push, merge or deploy was performed.
