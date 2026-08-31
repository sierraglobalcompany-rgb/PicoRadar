# B03 Camera Registry + Verification Control Plane

B03 is an operator-only control plane. It stores provenance and reviewed camera records; it does not expose a public camera API, import mass sources, publish a dataset, write a manifest, or create B04/B05 assets.

## Operator Runbook

Manual intake follows: create/verify a source, create a camera draft, submit it, review it on the detail page, verify it, then activate it. A correction is always reopen for correction, edit the resulting draft, submit, verify, and activate. Do not edit verified, active, or inactive master data in place.

For a temporary removal, use active to inactive and provide a reason. For a final removal, use active/inactive to retired and provide a reason. Retired is terminal. A speed camera may remain active while its speed limit is absent or unverified, but it is not overspeed eligible until a reviewed speed limit is present.

The duplicates view is read-only. It first bounds the search by jurisdiction and latitude/longitude box, then measures exact Haversine distance. Operators review candidates manually; B03 never auto-merges, deletes, or retires a record.

`CAMERA_REVERIFY_AFTER_DAYS` defaults to 180. Reverification is a computed queue signal only; it does not change lifecycle state or publish data.

## Integrity and readiness

Run `php artisan picoradar:cameras:quality --json` for informational aggregate quality. It includes reverification due, inactive/unverified source references, integrity-violation count and a bounded duplicate-candidate metric. The duplicate metric is explicitly not a global total if the per-seed cap is reached. Run `php artisan picoradar:cameras:integrity --json --fail-on-error` to find impossible state, provenance, geography, timestamp, fingerprint, and speed invariants. Run `php artisan picoradar:cameras:readiness --json --fail-on-error` to identify active records that cannot satisfy the future dataset contract. Both are read-only and accept `--jurisdiction=<key>`.

The registry, verification and retirement operations use one database transaction for state mutation, history and audit. Their internal failure hook is constructor-only and test-only: no HTTP request or configuration enables it. The B03 test suite injects a failure after mutation for verify, activate and retire and proves that all of the associated rows roll back.

## Incident recovery

If a source becomes invalid, first make dependent active cameras inactive, repair/reverify the source, and reopen affected cameras for correction. For coordinates or speed-limit errors, reopen the camera, correct the draft, and repeat review. For a duplicate, compare source and external identifier, then use the normal correction or retirement process with an audit reason. If a jurisdiction is disabled, active cameras fail readiness and must not be treated as ready until jurisdiction governance is corrected. If integrity fails, do not publish anything; correct the identified record through the lifecycle and rerun the command.

## Handoff

B04 receives stable `camera_id`, source registry and external-id uniqueness, manual registry workflow, duplicate detector, integrity/quality services, verified history, and jurisdiction/municipality checks. B05 may consume only contract-ready records. Neither batch starts in B03.

## Database indexes

The camera table indexes status; jurisdiction/status; municipality/status; source/status; type/status; speed-verification/status; and jurisdiction/latitude/longitude. The last index supports the database bounding-box candidate query without spatial extensions and is portable across SQLite and MariaDB.

The B03 scale test creates 5,000 synthetic distant cameras plus a nearby candidate, asserts that duplicate lookup uses the latitude/longitude bounding query, and executes the chunked integrity/readiness commands. It does not use real camera data or network access.
