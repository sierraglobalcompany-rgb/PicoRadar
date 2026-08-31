# B01 Dataset Registry + Publisher

B01 adds the Control Plane master data for `datasets`, `sources`, immutable `dataset_releases`, and append-only `audit_logs`. Draft JSON uses the private Laravel disk: it has no public route or URL.

The release state machine is `draft → validated → published`; a previously published, non-current release can explicitly become `retired`. Publishing preserves the validated bytes in `datasets/{key}/{version}/{key}-{version}.json`, calculates SHA-256 from those exact bytes, locks and updates the dataset pointer, and rebuilds `manifest/v1/manifest.json`. A retry of the same published release only repairs the manifest. Any different pre-existing asset at the deterministic path aborts; no published asset is overwritten.

The generated static manifest follows the mobile v1 contract: `schemaVersion`, `generatedAt`, `minAppVersion`, `datasets`, and Free 1.0 features. `DATASET_PUBLIC_BASE_URL` makes asset URLs CDN-ready while Hostinger can serve the public Laravel disk via `php artisan storage:link`. `ads`, `cloud`, and `paidDocuments` remain false.

Editors create datasets, edit sources, and upload drafts. Reviewers validate, publish, rollback, and retire; admins and super admins can do both roles. Commercial operators are denied. Validation snapshots active verified sources in release metadata. Audit metadata contains identifiers and hashes only: never raw JSON, credentials, sessions, or secrets.

Database and filesystem are not a distributed transaction. If a failure happens after a versioned asset is written, the possible outcome is a harmless immutable orphan rather than an overwrite or pointer corruption. `php artisan picoradar:datasets:manifest` reconstructs the manifest from MariaDB and fails closed for inconsistent pointers.

Hostinger readiness adds: writable published storage, `storage:link`, a configured `DATASET_PUBLIC_BASE_URL`, upload limit, and backups of MariaDB plus published assets and manifest as one recovery set. No deployment is performed by B01.

The B00 remote CI infrastructure debt remains. The existing PHP 8.3/8.4/8.5 SQLite matrix and MariaDB 11 job are retained; MariaDB executes B01 publisher and constraint tests once GitHub runners recover.
