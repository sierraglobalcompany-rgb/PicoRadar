# C28 V2 — handoff local

## Estado

`PARTIAL`. Base: `dba24e009ea8ba260fc6d0492027169dad5dd85d`. Código: `1f6e08c69a4bf0f341db6a495e91f721b7c4bb33`. Rama local: `codex/c27-v2-qa`; remoto autorizado por el lote: `feat/platform-integral-national-20261122`. El SHA final documental y el resultado remoto están en el informe único C28, después del commit documental/push.

## Android-only

Se usó una copia externa de `git archive HEAD mobile` en `D:\codex\_build\PicoRadar-C28-V2\android-only-20261123-01\mobile`. Al prepararla se excluyeron únicamente `windows/` y `linux/` para que Flutter 3.50.0 no intente sus symlinks de escritorio; el SDK local solo crea esos enlaces cuando los targets existen. Los 1.203 archivos restantes compararon por blob Git sin diferencia. El checkout conserva sus targets versionados.

Entorno usado por proceso:

```powershell
$env:FLUTTER_ROOT='D:\codex\_tools\flutter'
$env:PUB_CACHE='D:\codex\_tool-cache\flutter-d5-20261022\pub-cache'
$env:ANDROID_HOME='C:\Users\felip\AppData\Local\Android\sdk'
$env:ANDROID_SDK_ROOT='C:\Users\felip\AppData\Local\Android\sdk'
$env:JAVA_HOME='C:\Program Files\Eclipse Adoptium\jdk-21.0.12.8-hotspot'
```

Comandos del gate que pasó:

```powershell
flutter pub get --offline --enforce-lockfile
flutter build apk --debug --flavor dev --no-pub
```

Lock SHA-256 conservado: `9D68CE85ABA7E40C4E484D34B0F449E3BFFB98BE3D9F0118B7775ECC1E5F4834`. APK C28: `D:\codex\_REPORTES\PicoRadar\C28-V2-20261123\apk\app-dev-debug.apk`, 209.317.424 bytes, SHA-256 `29D896DE83AA8DCEF267733FA1FB755C5D04D55B0D818E56484BD592463F077E`. Paquete `co.picoradar.app.dev`, versionCode 2/versionName 1.0.1, certificado debug SHA-256 `5435a892a30b3e5387e9ef6272f3b1c073ff1a9fe19741f1d5060200f680b78e`. El registrant se define en `classes17.dex` y tiene `registerWith`; los 12 plugins Android con build nativo coinciden con metadatos/DEX. No reutilizar el APK C21.

El AVD existente `PicoRadar_QA_API35_Phone` se inició explícitamente como `emulator-5556`, se verificó Android 15/API 35 y se instaló con `adb -s emulator-5556 install -r`. El paquete previo era el APK C21 exacto con el mismo certificado/versionCode; `firstInstallTime` se mantuvo. QA observó Inicio → Garaje → Inicio durante la prueba; no se creó vehículo. El AVD C28 se cerró con `adb -s emulator-5556 emu kill`. No usar ADB contra el Mi A3.

## Fecha de alta administrativa — bloqueada

Fuente propuesta para la corrección y prueba focal: `deferred-tests/php/C28AppUserRegistrationDateTest.php` dentro del ZIP C28. Ejecutar cuando exista `server/vendor/autoload.php` y PHP tenga `pdo_sqlite`:

```powershell
cd server
php artisan test tests/Feature/C28AppUserRegistrationDateTest.php --filter=test_registration_date_is_shown_in_bogota_without_mutating_utc_storage
```

La invocación C28 no llegó a PHPUnit (0 pruebas, 0 aserciones). No se cambió la vista ni UTC persistido, exportación CSV/API, vencimientos, sesión o Pro. La prueba pasó `php -l`, pero el cambio de presentación debe esperar una reproducción focal.

## Contrato PHP → Dart — PHP bloqueado, test opt-in listo

`deferred-tests/php/C28NationalBridgeInteropTest.php` contiene el flujo sintético de aprobación/publicación con discos fake. La ruta de salida se pasa solo por proceso en `PICORADAR_C28_BRIDGE_EXPORT_DIR`, como directorio hijo nuevo de `D:\codex\_REPORTES\PicoRadar\C28-V2-20261123`; no se creó porque falta Laravel `vendor/autoload.php` y `pdo_sqlite`. `php -l` pasó; no se ejecutó publicación ni se fabricó JSON.

El test versionado `mobile/qa/c28/national_bridge_interop_c28_test.dart` queda fuera de `mobile/test` y requiere esos bytes reales. En esta ejecución está marcado `C28_DART=NOT_RUN_ENV`. `dart format --output=none --set-exit-if-changed qa/c28/national_bridge_interop_c28_test.dart` y `dart analyze qa/c28/national_bridge_interop_c28_test.dart` pasaron en la copia preparada. No ejecutar el test con bytes de sustitución. Comando pendiente desde `mobile/` después de C_PHP=PASS:

```powershell
$env:PICORADAR_C28_BRIDGE_EXPORT_DIR='D:\codex\_REPORTES\PicoRadar\C28-V2-20261123\bridge-<id-nuevo>'
flutter test --no-pub qa/c28/national_bridge_interop_c28_test.dart
```

Este contrato no certifica OTA HTTP, firma/rollback transaccional, publicación normativa ni cobertura legal. No se cambió el motor, dataset distribuido ni producción.

## Límites y siguiente paso

- `A_PUB=PASS`, `A_BUILD=PASS`, `A_REGISTRANT_DEX=PASS`, `A_RUNTIME=PASS_HOME_INTERACTIVE`, `APK=NEW_VERIFIED`.
- `B_DATE=BLOCKED`; `C_PHP=BLOCKED`; `C_DART=NOT_RUN_ENV`; `C_BRIDGE=NOT_VERIFIED`; `OTA_E2E=NOT_RUN`.
- `LEGAL=NO_GO`, `RELEASE=NO_GO`, `MAIN_BRIDGE=HOLD`. No PR, Actions, merge, publicación ni Mi A3.
- Siguiente paso: ejecutar B/C focales en entorno PHP con `vendor` y `pdo_sqlite`; ejecutar Dart solo con los bytes exactos exportados por Laravel. No recompilar mientras producción móvil no cambie.
