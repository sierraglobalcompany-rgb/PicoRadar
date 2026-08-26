C00: DONE

Branch: feat/C00-picoradar-repo-scaffold-flavors
HEAD: 14f7b1ae1ffa8a4d9b79a8a5f9a1093b7984185b

Summary:
- ZIP autosuficiente extraido a la raiz del repo junto a .git.
- Flutter app multiplataforma creada en mobile/.
- Laravel 13 app creada en server/.
- Android flavors dev/staging/prod configurados.
- IDs: prod co.picoradar.app, staging co.picoradar.app.staging, dev co.picoradar.app.dev.
- Labels: prod PicoRadar: Pico y Placa, staging PicoRadar Staging, dev PicoRadar Dev.
- Android compileSdk 36, targetSdk 36, minSdk 24, Java 17.
- No C01 ejecutado. No merge realizado.

Validated gates:
- flutter --version: Flutter 3.47.1 stable, Dart 3.13.1.
- flutter pub get: OK.
- dart format --output=none --set-exit-if-changed .: OK.
- flutter analyze: OK, no issues found.
- flutter test: OK, all tests passed.
- flutter build apk --debug --flavor dev: OK, app-dev-debug.apk built.
- php artisan about: OK, Laravel 13.29.0, PHP 8.5.8.
- php artisan serve + curl: OK, HTTP 200.
- php artisan test: OK, 2 passed.
- secret scan: OK, no findings.

Next lots unblocked:
- Primary: C01, C02, C03.
- Also per dependency matrix: C17, C22, C25, C28.

NO MERGE REALIZADO.
