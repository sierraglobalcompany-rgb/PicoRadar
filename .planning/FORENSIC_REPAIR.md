# PicoRadar forensic repair and alerts

Approved plan: owner request 2026-09-19. Base 82ce6b80783118ea923ef1c8ceed0f557c31d696.
Execution branch: codex/forensic-alerts. No merge, publication or cleanup authorized by this repair.

## Checkpoint 0

- Tracked working tree clean before changes. Existing untracked capturas/, mockups/, output/ remain untouched.
- Audit: analyze clean; mobile 2959 pass, 11 skip; driving simulation explicit run 11 pass; server 493 pass / 1993 assertions with process-local SQLite extensions.
- Installed APK remains 53C7195D361F9DF984E63462EE2EB0533F14E5EF4316A7B3EBF788D4A56634C5 until a verified replacement.
- Historical 87 failures no longer reproduce. Physical scanner, authentication and alarm QA are not certified by automated tests.

## Execution and ownership

Approved multi-lot integration uses this branch, with scoped checkpoints; no unrelated refactor or restoration of historical branches.
Shared changes (router, app providers, DB schema, MainActivity, manifests) belong to the coordinator. Workers request integration edits rather than race on them.
Tests/builds run sequentially under coordinator control. Workers provide regression tests and exact commands.

## Findings and completion criteria

| ID | Area / evidence | Repair acceptance | Status |
| --- | --- | --- | --- |
| F01 | WalletBridge scan hides native failure; device reports failure | Sanitized diagnostics, retry/import, physical front/back capture | open |
| F02 | DocumentsSessionSheet persists across same-pattern route | Origin-scoped modal/viewer disposal with real shell test | open |
| F03 | Insurance editor protection differs by entry | Protected entry and epoch checks consistent | open |
| F04 | Garage deletion omits wallet authorization | Both deletion entries cancel safely on denied/revoked auth | open |
| F05 | Wallet init decodes every metadata row | Corrupt row preserved, healthy owner usable, no unsafe GC | open |
| F06 | Defense index backup not recovered | Interrupted rename recovers previous index | open |
| F07 | BuySell v4 wrong nested types become empty | Preserve invalid raw draft, block destructive overwrite | open |
| F08 | Onboarding stale async/invalid draft/partial save | No setState after dispose; useful errors; no duplicate retry | open |
| F09 | SOAT/RTM invalid dates and missing explicit owner | Reject invalid dates; no silent owner substitution | open |
| F10 | Maintenance sheet dismissal loses invalidation | Persisted record visible after delayed completion | open |
| F11 | Radius resolver confuses territorial jurisdiction | Nearby city is suggestion, never confirmed authority | open |
| F12 | Driving stale GPS and failed starts | Stale data not current; recover startup/stream failures | open |
| F13 | Services permission exceptions retain loading | Recovery and catalog selection stay available | open |
| F14 | CDA reuses disposed tile client | Repeated map/list fetches fresh tiles safely | open |
| F15 | Trip invalidates prior route before refresh | Keep explicitly previous result on same-query failure | open |
| F16 | Dev build missing APP_ENV=dev | Build config tests, demo dev only, verified APK | open |
| F17 | Compiler integration external source dependency | Synthetic fixture runs locally, production provenance intact | open |
| F18 | Pico sync empty vehicles leaves schedules | Cancel own events without touching other categories | open |
| F19 | Alert sheet captured preferences | Reactive settings, serialized saves and accurate permission | open |
| F20 | Old docs / OSRM source path / dataset freshness | Reconcile truth, canonical source, never extend expiry | open |
| A01 | Alerts center | Four categories, per vehicle settings, real scheduled state | pending |
| A02 | Rich notification | Private local plate rendering, generic public content | pending |
| A03 | Optional Android alarm | Explicit permissions, stop/snooze, expiry/reboot/revoke tests | pending |

## Cross-task contracts

- Wallet owns document lifecycle; coordinator router integration must use its origin identity contract.
- Notification preferences and native projection are new scoped C11 work. Existing document/obligation dates remain the source of truth.
- Runtime alarm and enriched features default OFF; preserve existing reminder preferences on migration.
- Ruling: keep canonical documentation/ledger in .planning rather than another temporary worktree, per consolidation requirement. Cost: changes must be staged by explicit path.

## Verification ledger

Implementation checkpoints are present; full integrated and physical gates remain open.

- F01-F05: fd2cdb1, 69eefc3, 5e35647, f4606bb. 357 document/insurance/detail tests,
  24 garage/navigation tests, 4 editor tests, 11 native wallet tests pass. Scanner's
  original physical cause is not certified yet; do not call it physically fixed.
- F06-F10/F13/F14/F16: 4c33485, 713b284, c182a0b, 1d719ef, 86d6289, b09a682,
  2bba662, 88d0a9e. Scoped passes 227 and 173; seven real config variants pass.
- F11/F12/F15/F17/F20 path: c542054, bae139b, 7880efe, f3a862a, 5b9d7e7.
  Scoped groups 266/24/41 pass; synthetic HTTP/Drift bridge 1 pass and Python
  compiler safety/determinism 2 pass. No production provenance weakened.
- A01-A03 implementation: e1143c6, c03357b, a750080, 9b7a5a3, e22a186.
  New controls use real shell; 15 screen/scale combinations including preview
  interactions pass. Migration/additive data tests and owner-scoped persistence pass.
- Current analyze after integration: no issues. This is not the final full-suite run.

## Cross-review corrections before acceptance

Native/Dart resynchronization must preserve snoozed/ringing events unless their
underlying setting/owner/date is removed or changed. Additional reviewed scenarios:
normal notifications survive exact-alarm permission revocation; delayed save after
leaving screen still reconciles; obligation caches cannot restore old reminder flags;
OFF before creating an obligation remains OFF; permission platform exceptions keep
recovery controls; audio replacement releases previous resources; asynchronous
playback failures and unattended alarms become visible. These are active repairs,
not deferred cleanup. Follow-up tests must pass before final build.

Follow-up checkpoints: 32342ed / cef3f32 (identity retention and mixed channels),
1fb54c6 (OFF before obligation), b432f4e (late saves/permission recovery/observed
playback), fb74477 (native resource generations, silent missed notice and status).
Native worker verification: 46 JVM tests; direct Android SDK compilation. This
does not replace integrated Gradle tests or physical sound/lifecycle checks.

## First integrated gate, 2026-09-19

- Format: 365 files, zero changes. Analyze: no issues.
- Full serial suite stopped after 1730 passes, 10 skips and 3 failures when a
  Home test awaited an unmocked new status channel with a frozen fake clock.
  This is an incomplete run, not a passing global result.
- Two Purchase Documents tests expected an off-route dialog to remain and the
  previous scanner snackbar. Keep owner-isolation/import assertions while
  adapting to retired modals and the new retry/import dialog.
- Home mocks must implement the new idle status response explicitly; preserve
  actual permission and persistence assertions, not weaken the contract.
- Read-only native cross-review found one further race: background can discard
  a status reply after its failure latch is consumed. Recover testState.failed
  on resume and exercise that sequence before final build.
- First-run evidence: artifacts/current/forensic/integration-first-run-3-failures.log.
  A fresh complete run is required after the narrow corrections.

Corrections: e2908ef mocks the Home status channel and retains permission checks;
a134d90 covers consumed error/background/resume and stronger purchase modal/import
checks. Second complete run: 3191 pass / 10 skip / 2 fail (diagnostic still expected
schema8; insurance editor test omitted the new authorization fixture). Settings now
expects schema9 with all no-PII assertions intact; 36 Settings tests pass. 2013454
replaces the editor fixture with four owner/auth-success/cancel cases, 18 tests pass.
No product protection was bypassed to fix either expectation. Second-run log:
artifacts/current/forensic/integration-second-run-2-failures.log.

Integrated Android gate: :app:testDevDebugUnitTest --offline --console=plain,
57 tests / 0 failures / 0 errors / 0 skips. Warnings concern deprecated Locale,
legacy notification priority and Gradle10 compatibility; current build succeeds.
Final full Flutter rerun is required after these test-only corrections.

## Final automated checkpoint, 2026-09-19

- Format: 365 files / zero changes. Analyze: no issues. Diff whitespace check clean.
- Full suite: 3196 pass / 10 conditional simulation skips / zero failures (5m56s).
- Explicit PICORADAR_DRIVING_SIMULATION=true regional session suite: 11 pass.
- Integrated Android: 57 pass, zero failures/errors/skips. Server: 493 pass,
  1993 assertions with SQLite enabled only for that PHP invocation.
- Logs: artifacts/current/forensic/final-*.log. The two earlier failing runs
  remain evidence of corrected test integration, not current unresolved failures.
- The status table above lists acceptance criteria, not a claim of physical
  completion. Code/test repairs are implemented; scanner reproduction, wallet
  authentication/navigation, notification privacy and alarm operation still need
  new-APK device checks. F20 editorial freshness/CDN remains external and open.
- No source cleanup, external-project edits, merge or publication performed.

## Dataset/config audit

Bundled restrictions version 2026.09.10-r4-a, inspected 2026-09-19. Manizales car
coverage staleAfter 2026-09-14T05:00Z has expired. Eight coverages expire Sept23;
Bogota taxi and Bucaramanga car/motorcycle Sept28. Day evaluation already rejects
future dates outside staleAfter. No date was extended. Build without CDN_BASE_URL
uses bundled data and no sync endpoint; no valid public endpoint was supplied or
invented in this repair. Editorial refresh/CDN activation remains a real dependency.
