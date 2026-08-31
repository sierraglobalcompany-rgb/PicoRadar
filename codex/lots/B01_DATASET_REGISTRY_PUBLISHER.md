# LOT B01 — Dataset Registry + Publisher

Implements the Laravel-only dataset control plane: registry, verified sources, private JSON drafts, validated immutable releases, static manifest distribution, rollback, audit trail, and B00-role authorization. Flutter is unchanged and remains local-first.

State machine: `draft → validated → published → retired`; `retired` is terminal. Published assets are deterministic, content-addressed by SHA-256 of exact distributed bytes, and never overwritten. A shared cache lock serializes DB mutation plus post-commit static manifest regeneration; a failed rebuild is recovered through `picoradar:datasets:manifest`.

CI retains the B00 PHP 8.3/8.4/8.5 SQLite matrix and MariaDB 11 job. External runner unavailability remains an infrastructure debt, not a pass.
