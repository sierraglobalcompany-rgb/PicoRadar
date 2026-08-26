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
- Android `compileSdk 36`, `targetSdk 36`, `minSdk 24`.
- Java 17.
- PHP 8.3+.
- Laravel 13.

## Mobile

```powershell
$env:JAVA_HOME='C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot'
$env:Path='C:\Users\felip\.codex\tooling\flutter_3.47.1\flutter\bin;' + $env:JAVA_HOME + '\bin;' + $env:Path
cd mobile
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --flavor dev
flutter run --flavor dev --dart-define=APP_ENV=dev
```

Configured Android flavors:

| Flavor | Application ID | Label |
|---|---|---|
| `prod` | `co.picoradar.app` | `PicoRadar: Pico y Placa` |
| `staging` | `co.picoradar.app.staging` | `PicoRadar Staging` |
| `dev` | `co.picoradar.app.dev` | `PicoRadar Dev` |

## Server

```powershell
cd server
composer install
php artisan about
php artisan serve --host=127.0.0.1 --port=8000
php artisan test
```

Use `server/.env.example` as the local template. Do not commit `server/.env`, real API keys, signing keys, database passwords, or provider credentials.

## C00 Scope

C00 only creates repository foundation, Flutter/Laravel scaffolds, Android flavors and smoke tests. Product navigation, Drift, Riverpod, go_router, Firebase, GPS, routes, datasets and feature screens start in later lots.
