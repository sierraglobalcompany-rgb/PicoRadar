# PicoRadar: Pico y Placa

Monorepo KISS para PicoRadar Free 1.0, Android-first con Flutter multiplataforma y Laravel como control plane.

## Estructura

- `mobile/`: app Flutter multiplataforma.
- `server/`: Laravel 13 para control plane/API.
- `docs/baseline/`: baseline de producto y arquitectura.
- `contracts/`: contratos de API, datasets y manifest.
- `data/`: fixtures y datos piloto.
- `scripts/`: helpers del monorepo.
- `codex/`: lotes, Definition of Done y handoff.

## Tooling baseline C00

- Flutter 3.47.x stable / Dart 3.13.x.
- Android `compileSdk 37`, `targetSdk 36`, `minSdk 24`.
- Java 17.
- PHP 8.3+.
- Laravel 13.

## Mobile

```powershell
$env:JAVA_HOME='C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot'
$env:Path='C:\Users\felip\.codex\tooling\flutter_3.47.1\flutter\bin;' + $env:JAVA_HOME + '\bin;' + $env:Path
cd mobile
flutter pub get
dart run build_runner build
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug --flavor dev
flutter run --flavor dev --dart-define=APP_ENV=dev
```

## C01 App shell

Mobile now has the approved C01 shell only: `Inicio`, `Garaje`, `Apps`, `Viaje`, `Conducir`. The tabs are implemented with `go_router` branch navigation so each root preserves its local state. The temporary immersive preview route lives outside the tab shell and is opened with stack navigation, so Android back returns to the invoking tab.

Configured Android flavors:

| Flavor | Application ID | Label |
|---|---|---|
| `prod` | `co.picoradar.app` | `PicoRadar: Pico y Placa` |
| `staging` | `co.picoradar.app.staging` | `PicoRadar Staging` |
| `dev` | `co.picoradar.app.dev` | `PicoRadar Dev` |

## C03 Local Database

The local Drift database lives in `mobile/lib/core/database/` with `schemaVersion = 1`. The initial schema is intentionally small: `vehicles`, `vehicle_obligations`, `notification_preferences` and `dataset_versions`, with indexes for vehicle plates, obligation lookups/due dates and dataset keys. GPS history, trip history, dataset imports, UI repositories and SQLCipher remain out of scope.

## C04 Local Storage And Crypto

Local storage foundations live in `mobile/lib/core/storage/`. `shared_preferences` is used only through `SharedPreferencesAsync` for non-sensitive settings, `flutter_secure_storage` stores small secrets and the 32-byte file master key, and `cryptography` provides AES-256-GCM for private file bytes. These dependencies match the approved technical baseline, keep Android/iOS support in the Flutter plugin ecosystem, and avoid custom crypto or extra repository layers.

## Server

```powershell
cd server
composer install
php -r "file_exists('.env') || copy('.env.example', '.env');"
php -r "file_exists('database/database.sqlite') || touch('database/database.sqlite');"
php artisan key:generate --no-interaction
php artisan about
vendor/bin/pint --test
if (php -m | Select-String -Quiet '^pdo_sqlite$') { php artisan migrate --pretend --no-interaction } else { Write-Warning 'Local pdo_sqlite is disabled; CI installs it and runs migrate --pretend.' }
php artisan serve --host=127.0.0.1 --port=8000
php artisan test
```

Use `server/.env.example` as the local template. Do not commit `server/.env`, real API keys, signing keys, database passwords, or provider credentials.

## CI

GitHub Actions runs separate mobile and server gates on pull requests and matching pushes. Mobile pins Flutter `3.47.1`, Java 17 and Android API 36, then runs pub get, format, analyze, optional build_runner, tests with coverage and the dev debug APK build. Server pins PHP `8.5` to match the current Composer lock while staying inside the PHP `8.3+` baseline, installs dependencies with `pdo_sqlite`, runs Pint, checks migrations in pretend mode and runs Laravel tests. Dependabot opens weekly PRs for GitHub Actions, Flutter pub and Composer updates; no auto-merge is configured.

## Current Scope

C00 creates repository foundation, Flutter/Laravel scaffolds, Android flavors and smoke tests. C01 adds design tokens, Riverpod/go_router bootstrap, the five-tab app shell, root placeholders and shell/router tests. C02 adds CI quality gates and Dependabot. C03 adds the Drift/SQLite schema skeleton and migration harness only. C04 adds non-sensitive preferences, secure storage and AES-GCM file crypto foundations only. Firebase, GPS, account/cloud, the Apps 3x3 launcher and product feature screens remain out of scope until their approved lots.
