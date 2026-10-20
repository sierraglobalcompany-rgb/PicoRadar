# PicoRadar: handoff único de recuperación V2

## Estado

**PARTIAL — Gate C en curso.** Fuente recuperada y respaldos comprobados. Clon remoto independiente creado y comprobado; ejecución de suites aún abierta y CI bloqueado por infraestructura. No se declara DONE.

## Git y trabajo

- Canónico: `D:/Dev/PicoRadar`, exFAT; branch `recovery/20261019-modern`.
- Fuente moderna: `ffe0cbd194310e004b20abd97fcd10e685c7df88` (B07 administrativo).
- Original C: `codex/forensic-alerts`, `d26ba84b1e1aeb7738e7dc965a3ad4adca16d917`, preservado.
- Base remota del PR: main histórico `e9ef37511df3110ffb0fc006ef06be781df432ac`. No se seleccionó como runtime moderno.
- PR draft sin merge: https://github.com/sierraglobalcompany-rgb/PicoRadar/pull/71.
- Primer read-back remoto: `21be9d97156191bdf19253d9bc52fa699502d644`, tree `fe79831e1c7e8c7d8f1f0f82f250e8b40dcffa80`; clon independiente y pruebas parten de ese corte. Las revisiones posteriores son documentales.
- Comparador pendiente recuperado sin integrar: `recovery/20261019-pending-b04`, HEAD `fe0d8d46bf7c6abb223d246e7af43fbe1648439c`.
- El SHA de la entrega se obtiene con `git rev-parse HEAD` o el commit del PR; no se usa un hash autorreferencial dentro del documento.

## Cambios

Se recuperó la historia moderna owner → C11 → coherencia → B06 → B07 sin cambiar código runtime. README, AGENTS, CURRENT, DESIGN_CONTRACT, SOP, README servidor y entrada GSD orientan a la rama moderna y reconstrucción portable. Matriz: `PicoRadar_FORENSE_10_PASADAS.md`.

Los pipelines y lockfiles se conservan; no se añadieron dependencias, parsers, migraciones ni activaciones comerciales. B04 comparador permanece pendiente y separado. Versiones anteriores y QA histórica no se aplican sobre el runtime.

## Preservación

- 13 worktrees con estados comparados antes/después.
- 1.723 archivos no regenerables: 1.406.579.578 bytes verificados por SHA-256.
- Almacén Git completo: 792/792 archivos coincidentes, incluyendo índices, refs, reflogs y objetos; bundle complementario verificado.
- 93 entregables externos y 3 archivos privados B06 respaldados.
- Índice privado: `D:/PicoRadar_Rescue/manifests/`; snapshots y bundles fuera de Git. No copiar sesiones, bases, tokens ni manifiestos privados al chat/PR.
- C: intacto; D: no constituye por sí solo respaldo físico independiente.

## Tests y evidencia

| Comprobación | Resultado observado |
| --- | --- |
| Hashes ZIP V2 | 5/5 coinciden |
| Snapshot WIP / Git common-dir | PASS, cifras anteriores |
| Selección por ancestry y diffs | PASS; B07 contiene ancestros modernos |
| `git diff --check` documental | PASS antes del commit inicial |
| Escaneo historia publicable | Gitleaks 8.30.1: rango ampliado main..ae93533, 207 commits / 71,38 MB; tres alertas revisadas: URL pública Power BI y dos apariciones del identificador público ledgerKey del dataset. Cero alertas pendientes en ese alcance; sin valores reproducidos. Cambios documentales preparados escaneados aparte |
| Clon exclusivo GitHub | PASS: SHA/tree anteriores, inicialmente limpio, sin alternates |
| `flutter pub get` | PASS, lockfile conservado |
| `dart format --output=none --set-exit-if-changed .` | PASS |
| `flutter analyze --no-pub` | PASS, sin issues |
| Codegen | CODEGEN_NOT_REQUIRED según SOP-07; entradas y generados rastreados conservados |
| Suite móvil completa | FAIL: 3.233 PASS / 11 SKIP / 12 FAIL, concurrency=2; repetición selectiva serial: 7 PASS / 5 FAIL, sin modificar código ni aserciones |
| Simulación | PASS, 11 tests con PICORADAR_DRIVING_SIMULATION=true |
| APK dev APP_ENV=dev | PASS desde clon remoto, opciones explícitas Kotlin incremental=false / in-process; comando reproducible en README |
| Tests Android nativos | PASS, :app:testDevDebugUnitTest con las mismas opciones de proceso |
| Laravel/Pint/migraciones/assets | PASS: 108 paquetes Composer desde lockfile, npm ci/build, Pint; PHPUnit 602 tests / 2.778 aserciones / cero fallos / una omisión por symlink en Windows; migraciones SQLite nuevas, rutas, contrato B06/B07 y cobertura nacional |
| B06/B07 paquete desde clon remoto | IN_PROGRESS: builder existente, dependencias de producción desde lockfile; verificación e instalación MariaDB locales aún sin resultado final |
| B06/B07 navegador | BLOCKED_FILE_UNAVAILABLE por denegación local del PS1; no ejecutado |
| CI de `21be9d9` | CI_INFRA_BLOCKED_GITHUB_BILLING; cinco jobs fallaron sin iniciar steps por pagos/límite de gasto |
| Revisión de continuidad independiente | PASS de reanudación desde GitHub, exclusivamente lecturas remotas; no certifica reconstrucción. Contradicciones documentales de codegen/SOP/antecedentes visuales corregidas |

## Bloqueos, QA y deuda

Comandos ejecutados en el clon remoto, con versiones y preparación descritas en README:

```powershell
# mobile
Set-Location (git rev-parse --show-toplevel)
Push-Location mobile
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze --no-pub
flutter test --no-pub --reporter=expanded --concurrency=2
flutter test --no-pub --dart-define=PICORADAR_DRIVING_SIMULATION=true test/features/driving/application/driving_regional_session_test.dart --reporter=expanded
flutter build apk --debug --flavor dev --dart-define=APP_ENV=dev --no-pub --no-android-gradle-daemon --android-project-arg=kotlin.incremental=false --android-project-arg=kotlin.compiler.execution.strategy=in-process --verbose
# mobile/android
Push-Location android
./gradlew.bat :app:testDevDebugUnitTest -Pkotlin.incremental=false -Pkotlin.compiler.execution.strategy=in-process --no-daemon --console=plain
Pop-Location
Pop-Location
# server; variables sintéticas de proceso según README
Push-Location server
composer validate --no-check-publish
composer install --no-interaction --prefer-dist --no-progress
npm ci --no-audit --no-fund
npm run build
php vendor/bin/pint --test
php vendor/bin/phpunit --colors=never --log-junit D:/PicoRadar_Rescue/logs/cold-server-junit.xml
php artisan migrate --env=testing --no-interaction
php artisan route:list --json
Pop-Location
# raíz
pwsh -NoProfile -File scripts/tests/test_admin_content_package_contract.ps1
python scripts/validate_national_coverage.py
```

APK reconstruido: 210.851.084 bytes; SHA-256 `ce882ee133f10ac26a74f3373487d4354ae3b679753f0a36def82b28cd10e673`. Artefacto privado de prueba, no instalado ni publicado como release.

Windows deniega recrear `scripts/tests/test_hostinger_installer_browser.ps1` en D:. `git restore --source=HEAD -- <archivo>` devolvió `Permission denied`. El archivo apareció inicialmente en el clon independiente y luego dejó de estar presente también allí. Permanece intacto en Git y no se incluye su eliminación en ningún commit. SHA-256 del contenido remoto: `a0b9b1d43b60402e6635b710212085168d16e8c230badee641c736d3f3656f2d`. Causa no confirmada; no se desactiva seguridad ni se evade el bloqueo. Ambos checkouts pueden mostrar su ausencia.

Pruebas móviles: se observaron esperas propias de fixtures de aproximadamente un segundo y timeouts generales de 30 segundos durante operaciones de archivo, además de un error de teardown por archivo abierto. Hipótesis pendiente de aislar: carga de E/S durante la instalación concurrente. No se debilitaron aserciones, omitieron pruebas ni cambiaron privacidad/runtime. La suite completa falló; una repetición selectiva no la convierte en PASS.

Repetición de los doce casos, `--no-pub --concurrency=1 --reporter=expanded`, mismos timeouts y temporales en D:, terminó con 7 PASS / 5 FAIL. Persisten: selector tardío en `purchase_documents_screen_test.dart`; escaneo frente/reverso en `wallet_two_sides_flow_test.dart`; enlaces/resultados sin hora en `trip_screen_test.dart`; round-trip cifrado en `private_vehicle_document_store_test.dart` (timeout de 30 s); limpieza de caché SOAT en `vehicle_status_screen_test.dart`. Los otros siete casos pasaron. La repetición serial no resolvió cinco fallos; causa raíz funcional/E/S aún no certificada. Logs y selección exacta privados: `D:/PicoRadar_Rescue/logs/cold-mobile-failure-recheck.log` y `tools/recheck_mobile_failures.ps1`.

Android: el primer build falló por caché incremental Kotlin entre C: y D:. Los flags explícitos del README permitieron compilar APK y ejecutar tests nativos sin mover fuentes, borrar cachés ni modificar herramientas globales. Se conserva D: exFAT.

Firma release debug y su TODO son deuda histórica explícita; no se autoriza publicar una release con esa configuración.

QA física scanner, autenticación, notificaciones, Conducir y rendimiento heredada: **pendiente, no ejecutada**, por instrucción de no tocar Mi A3. Sin merge ni Hostinger. Word3D/World3D y originales artísticos históricos no localizados dentro de la cobertura; assets runtime sí versionados. Chats antiguos no exportados no accesibles.

## NEXT

Completar Gate C desde `recovery/20261019-modern`: partir del SHA del PR, clonar según README y registrar los gates todavía abiertos de la tabla. En esta máquina, consultar opcionalmente el ledger privado para no duplicar el paquete en ejecución; los documentos remotos son suficientes para un clon distinto. No iniciar una función nueva ni atribuir PASS a un gate pendiente.
