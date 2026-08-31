# B01 Dataset Registry + Publisher

B01 adds the Control Plane master data for `datasets`, `sources`, immutable `dataset_releases`, and append-only `audit_logs`. Draft JSON uses the private Laravel disk: it has no public route or URL.

The release state machine is `draft → validated → published → retired`; `retired` is terminal. Historical release fields are protected in the model, not only in the UI. Publishing preserves the validated bytes in `datasets/{key}/{version}/{key}-{version}.json`, calculates SHA-256 from those exact bytes, locks dataset then release rows, and updates the dataset pointer. A retry of the same published release is idempotent. Any different pre-existing asset at the deterministic path aborts; no published asset is overwritten.

The generated static manifest follows the mobile v1 contract: `schemaVersion`, `generatedAt`, `minAppVersion`, `datasets`, and Free 1.0 features. `MOBILE_DEFAULT_MANIFEST_URL` and `SERVER_PUBLIC_MANIFEST_URL` are both exactly `/v1/manifest.json`. Laravel `storage:link` preserves `public/storage → storage/app/public` for `/storage/datasets/...` and creates `public/v1 → storage/app/public/manifest/v1` for the static manifest. PHP and MariaDB are not in the sync hot path. `ads`, `cloud`, and `paidDocuments` remain false.

Editors create datasets, edit sources, and upload drafts. Reviewers validate, publish, rollback, and retire; admins and super admins can do both roles. Commercial operators are denied. Validation snapshots active verified sources in release metadata. Audit metadata contains identifiers and hashes only: never raw JSON, credentials, sessions, or secrets.

Database and filesystem are not a distributed transaction. A shared Laravel atomic cache lock serializes publish, rollback, retirement, dataset enable/disable, and manual manifest rebuilds. The state transition and audit log commit together inside MariaDB; only after that commit does the lock holder regenerate the manifest with temp → checked move. If regeneration fails, the previous manifest remains intact, the committed DB state is recoverable, and the request reports failure. `php artisan picoradar:datasets:manifest` reconstructs the manifest from MariaDB and fails closed for an inconsistent pointer. `CACHE_STORE=file` is appropriate for the intended Hostinger single-app deployment; multi-instance deployment must use a shared lock store.

Hostinger readiness adds: writable published storage, `php artisan storage:link` (which creates both static links), a configured `DATASET_PUBLIC_BASE_URL`, upload limit, and backups of MariaDB plus published assets and manifest as one recovery set. No deployment is performed by B01.

Known mobile configuration debt: `mobile/.env.example` historically names `FEATURE_MANIFEST_URL` while `AppConfig` reads `MANIFEST_URL`. B01 deliberately does not modify Flutter; serving the mobile default `/v1/manifest.json` avoids blocking this lot. Resolve the env-name mismatch in a dedicated mobile configuration cleanup lot.

The B00 remote CI infrastructure debt remains. The existing PHP 8.3/8.4/8.5 SQLite matrix and MariaDB 11 job are retained; MariaDB executes B01 publisher and constraint tests once GitHub runners recover.
