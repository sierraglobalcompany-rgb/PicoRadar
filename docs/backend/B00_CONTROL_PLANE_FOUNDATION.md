# B00 Control Plane Foundation

## Scope and boundaries

B00 establishes only the Laravel control-plane foundation: operator authentication, a minimal admin shell, `/api/v1/health`, and portable operator metadata. It does not create datasets, releases, publishers, cameras, partners, ads, mobile accounts, user data, or a mobile API hot path.

The mobile application remains local-first. It never connects directly to MariaDB/MySQL, and no GPS samples, private documents, routes, or vehicle state are sent by B00.

## Runtime and database strategy

- Laravel 13 supports PHP 8.3, 8.4, and 8.5; production is recommended on PHP 8.5 with Composer 2.
- Composer resolution is pinned to the PHP 8.3.0 platform floor. This prevents a lockfile generated on PHP 8.4 or 8.5 from selecting a dependency that violates PicoRadar's minimum supported runtime. The runtime itself remains supported and tested on PHP 8.3–8.5.
- Local development and tests use SQLite. The B00 migration uses portable schema-builder columns and has a rollback.
- Hostinger production uses `DB_CONNECTION=mysql` with a MariaDB/MySQL-compatible database. No Redis, queue worker, Docker, or privileged database feature is required.
- CI runs Laravel gates on PHP 8.3, 8.4, and 8.5 with SQLite, plus a dedicated MariaDB 11 migration/final-rollback compatibility job on PHP 8.5. This keeps the main matrix fast while proving the production database path.

## Hostinger deployment readiness

1. Point the domain document root to `server/public` (or use an equivalent Hostinger configuration that never exposes `.env`, `vendor`, `storage`, or application source).
2. Select PHP 8.5 (PHP 8.3–8.5 are supported) and make Composer 2 available through SSH.
3. Create the MariaDB database/user with ordinary schema privileges, then create a production `.env` outside version control. Set `APP_ENV=production`, `APP_DEBUG=false`, an HTTPS `APP_URL`, `DB_CONNECTION=mysql`, and the `DB_*` values. Set `SESSION_SECURE_COOKIE=true` for HTTPS.
4. Ensure the web-service user can write `storage` and `bootstrap/cache`.
5. Run `php artisan key:generate`, `php artisan migrate --force`, `php artisan config:cache`, `php artisan route:cache`, and `php artisan view:cache`.
6. Create the first operator only through an SSH session: `php artisan picoradar:admin:create`. The command asks for the password without echoing or logging it; do not put a password in command arguments or source control.
7. Enforce HTTPS at Hostinger. A future scheduler can call `php artisan schedule:run`; B00 creates no scheduled jobs or workers.

## Operator policy

There is no public registration. Operators use Laravel sessions with CSRF protection, login rate limiting, session-ID regeneration after login, native password hashing, an active-account check at login and on each protected request, and the roles `super_admin`, `admin`, `editor`, `reviewer`, and `commercial`.

B01 remains blocked until B00 receives external audit approval.
