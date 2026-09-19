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

Implementation not yet verified. Add exact RED/GREEN commands, checkpoints and physical evidence before closing each finding.
