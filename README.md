# PicoRadar: Pico y Placa

PicoRadar es un monorepo KISS para la app Free 1.0 de pico y placa: Android-first con Flutter multiplataforma, datos locales versionados y Laravel como control plane fuera del hot path de GPS.

## Estructura

- `mobile/`: app Flutter.
- `server/`: Laravel 13 para control plane/API.
- `docs/baseline/`: documentos fuente de producto y arquitectura.
- `docs/CURRENT.md`: estado vivo, roadmap de recuperacion y matriz de fidelidad.
- `docs/DESIGN_CONTRACT.md`: contrato visual vigente para Flutter.
- `docs/SOP.md`: procedimientos de cambio, diseno, datos y QA.
- `contracts/`: contratos de API, datasets y manifest.
- `data/`: fixtures y datos piloto.
- `scripts/`: helpers del monorepo.
- `codex/lots/`: definicion historica de lotes aprobados.

## Mobile

```powershell
$env:JAVA_HOME='C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot'
$env:Path='C:\Users\felip\.codex\tooling\flutter_3.47.1\flutter\bin;' + $env:JAVA_HOME + '\bin;' + $env:Path
cd mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug --flavor dev
flutter run --flavor dev --dart-define=APP_ENV=dev
```

## Android flavors

| Flavor | Application ID | Label |
|---|---|---|
| `prod` | `co.picoradar.app` | `PicoRadar: Pico y Placa` |
| `staging` | `co.picoradar.app.staging` | `PicoRadar Staging` |
| `dev` | `co.picoradar.app.dev` | `PicoRadar Dev` |

## Server

```powershell
cd server
composer install
php -r "file_exists('.env') || copy('.env.example', '.env');"
php -r "file_exists('database/database.sqlite') || touch('database/database.sqlite');"
php artisan key:generate --no-interaction
php artisan about
vendor/bin/pint --test
php artisan migrate --pretend --no-interaction
php artisan test
```

No se deben commitear `.env`, secretos reales, claves de firma, passwords de base de datos ni credenciales de proveedores.
