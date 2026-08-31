# LOT B01 — Dataset Registry + Publisher

Implements the Laravel-only dataset control plane: registry, verified sources, private JSON drafts, validated immutable releases, static manifest distribution, rollback, audit trail, and B00-role authorization. Flutter is unchanged and remains local-first.

State machine: `draft → validated → published`; non-current published releases can be explicitly retired. Published assets are deterministic, content-addressed by SHA-256 of exact distributed bytes, and never overwritten.

CI retains the B00 PHP 8.3/8.4/8.5 SQLite matrix and MariaDB 11 job. External runner unavailability remains an infrastructure debt, not a pass.
