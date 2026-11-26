# C29 V3 — Handoff

## Status
`PARTIAL`

## Lot
`C29 V3 — fecha administrativa, export nacional sintético, interop Dart y OTA loopback`

## Git
- Branch: `codex/c29-v3`
- HEAD_CODE: `9fa14a40c50f66b9b072819ad16590110937f593`
- Base / destino autorizado: `e9bb44ae08b5edff6f698c662e6d7b064b24aaad` / `feat/platform-integral-national-20261122`
- Worktree: `D:\codex\_build\PicoRadar-C29-V3\repo`
- Commit funcional C29 empujado por fast-forward normal; `git ls-remote` confirmó la rama en `9fa14a40c50f66b9b072819ad16590110937f593`. `main` permaneció en `e9ef37511df3110ffb0fc006ef06be781df432ac`.

## Outcome
- Corregida la fecha local de alta del panel de cuentas: zona `America/Bogota` aplicada a una copia de `created_at`; encabezado explícito `Alta (Bogotá)`. UTC persistida intacta.
- B1 exportó los bytes de una publicación sintética OFF/partial mediante los servicios reales de publicación Laravel y fake disks.
- B2 importó esos bytes exactos al motor Dart y mantuvo OFF/partial/UNKNOWN.
- B3 ejecutó el servicio OTA real sobre HTTP loopback: descarga/importación positiva, luego GET del payload de ataque y rechazo por mismatch SHA antes del parse/import, con estado SQLite sin cambios.
- C1 confirmó el flujo UI de un vehículo y consulta municipal en el AVD existente, offline y con datos sintéticos. La pantalla mostró datos vencidos/por actualizar. No se infiere permiso de circulación ni vigencia normativa.
- No se modificó motor de producción, esquema, dataset, dependencias, lock, API ni certificado. No se generó APK nuevo.

## Files / areas changed
- `server/resources/views/admin/app_users/index.blade.php`
- `server/tests/Feature/C28AppUserRegistrationDateTest.php`
- `server/tests/Feature/C28NationalBridgeInteropTest.php`
- `mobile/qa/c29/national_ota_from_php_c29_test.dart` (opt-in, fuera de auto-discovery)
- `codex/C29_V3_PHP_RUNTIME.md`
- `codex/C29_V3_HANDOFF.md`
- `docs/CURRENT.md`

## Tests executed
| Command / test | Result |
|---|---|
| A0 PHP 8.5.8 + PDO SQLite `:memory:` + lock/vendor/autoload isolation | PASS |
| A1 rojo original: `test_registration_date_is_shown_in_bogota_without_mutating_utc_storage` | 1 test, 4 assertions; RED esperado: 00:30 UTC aparecía como 24/11 Bogotá |
| A1 tras corrección, mismo test | PASS, 1 test, 11 assertions; almacenamiento UTC intacto |
| `php -l` sobre tests A1/B1 | PASS |
| B1 `test_c28_off_release_exports_exact_bytes_for_dart_bridge` | PASS, 1 test, 37 assertions; export exacto auditado |
| B2 `qa/c28/national_bridge_interop_c28_test.dart` | PASS, 1 test |
| `dart format qa/c29/national_ota_from_php_c29_test.dart` | PASS, 0 cambios |
| `dart analyze qa/c29/national_ota_from_php_c29_test.dart` | PASS, sin issues |
| B3 `flutter test --no-pub qa/c29/national_ota_from_php_c29_test.dart --reporter=expanded` | PASS, 1 test; positivo y negativo por SHA |
| `git diff --cached --check` antes del commit funcional | PASS |
| Barrido de patrones de credenciales en los cuatro archivos del delta funcional | PASS, sin patrones de alta confianza |

No se ejecutaron suites completas, build, pruebas repetidas C19–C28, Vite/npm, ni pruebas de dispositivos físicos.

## Manual QA
- Export B1 exacto: `restrictions.json` 936 bytes SHA-256 `AF1955879EDC63725FB8C8332CDDD627C6D8B5116A15BD0FEEFB1ECC358CFD7E`; `manifest.json` 424 bytes SHA-256 `F244CEB0CEE6C56AB3D1F7FFB72EA78190BE14AA0D38804052A107EF1F0676FA`.
- Versión `r2-7f969a248a68`; revisión 2; schema payload 2 / manifest 1; `generatedAt=2026-11-23T12:00:00Z`; `minAppVersion=1.0.0`; jurisdicción y cobertura OFF, completitud `partial`, regla retenida, URL relativa `/storage/`; sin `expiresAt` global, `staleAfter=2026-12-20T00:00:00Z`.
- B3 compara snapshot completo de las tablas version, restriction coverage y jurisdiction availability antes/después. La respuesta de ataque incrementa revisión y versión opaca, mantiene el SHA anunciado y cambia un byte servido; ambos GET devuelven 200 y el cliente falla con `SHA-256 mismatch`.

## Physical Android QA
`Not required (physical device)` — se ejecutó solo QA en AVD; no se intervino dispositivo físico.
- AVD `PicoRadar_QA_API35_Phone`, `emulator-5556`, Android 15/API 35.
- APK C28 reutilizado: 209.317.424 bytes, SHA-256 `29D896DE83AA8DCEF267733FA1FB755C5D04D55B0D818E56484BD592463F077E`; instalado `base.apk` coincide por bytes/hash; no se instaló.
- `ANDROID_FLOW=PASS_SCOPED`: vehículo sintético ABC123 → ciudad de conducción Medellín visible/seleccionada → resultado visible; UI indicó “Datos vencidos / Actualiza datos locales”. `UNKNOWN_UI=NONE`: no se encontró una ciudad disponible con estado desconocido en el selector mostrado.
- Se retiró el vehículo sintético por UI, AVD detenido (estaba apagado al inicio y volvió a estado apagado), conectividad del emulador restaurada. No cuenta/GPS/permisos. Evidencia en `android/C1-20261126-01` del ZIP.

## Data / migration impact
- Sin migraciones ni persistencia en servidor. PHPUnit, B2/B3 usaron SQLite en memoria; los JSON B1 se escribieron en fake disks y export temporal sintético separado del repo.
- La fecha se transforma solo al renderizar con copia inmutable; `created_at`/`updated_at` UTC verificados.
- El AVD usó un único vehículo falso y se limpió por UI. Ningún dato real alterado.

## Security / privacy review
- Sin secretos detectados por barrido de alta confianza en los archivos de cambio. PHP aislado con config/env de prueba, SQLite memory, correo/campañas OFF, fake disks; B3 usa solo loopback. No prueba OTA HTTPS productiva ni autenticidad criptográfica.
- Sin Mi A3, servicios pagos, Laravel remoto, Hostinger, Actions, `main`, merge o release.

## Dependencies added/changed
- Ninguna dependencia o lock de producto. `composer.lock` y `pubspec.lock` preservados. `vendor` candidato local/ignorado usado para ejecutar PHPUnit, no versionado.

## Known risks / debt
- `LEGAL=NO_GO`, `RELEASE=NO_GO`, `MAIN_BRIDGE=HOLD`. La prueba OTA acredita solo transporte HTTP local aislado, no HTTPS productivo ni distribución del APK.
- C1 observó un dataset de Medellín marcado vencido/por actualizar; no certifica su validez jurídica. La matriz de UNKNOWN UI no se alcanzó (`UNKNOWN_UI=NONE`).
- No se construyó APK porque el único cambio de producto está en Blade y las adiciones Flutter son tests opt-in. Un cambio posterior de producción móvil requiere nuevo APK y QA apropiada.

## Stop conditions encountered
- Ningún bloqueo inseguro. Alcance cerrado sin suite completa, build o pruebas físicas, conforme al prompt C29.

## Next lot(s) unblocked
- Para afirmar OTA productiva: entorno HTTPS de QA autorizado con aislamiento y prueba contra el servidor real; mantener secretos/datos fuera de evidencia.
- Validación jurídica humana de fuentes y jurisdicciones antes de cualquier decisión legal/release.
- No reejecutar las pruebas focales C29 salvo cambio causal; no repetir C19–C28.

## Do not forget
- `MAIN_BRIDGE=HOLD`; no merge hecho.