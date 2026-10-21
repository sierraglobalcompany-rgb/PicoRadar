# PicoRadar: handoff único de recuperación V2

## Estado

**PARTIAL.** Fuentes modernas publicadas y respaldos comprobados. Clon remoto independiente, APK y servidor reconstruidos. Suite móvil fallida; instalación B06/B07 bloqueada por enlaces en exFAT, navegador por archivo denegado y CI por facturación. Paquete y verificación integral PASS desde GitHub, incluida limpieza final. No se declara DONE.

## Git y trabajo

- Canónico: `D:/Dev/PicoRadar`, exFAT; branch `recovery/20261019-modern`.
- Fuente moderna: `ffe0cbd194310e004b20abd97fcd10e685c7df88` (B07 administrativo).
- Original C: `codex/forensic-alerts`, `d26ba84b1e1aeb7738e7dc965a3ad4adca16d917`, preservado.
- Base remota del PR: main histórico `e9ef37511df3110ffb0fc006ef06be781df432ac`. No se seleccionó como runtime moderno.
- PR draft sin merge: https://github.com/sierraglobalcompany-rgb/PicoRadar/pull/71.
- Primer read-back remoto: `21be9d97156191bdf19253d9bc52fa699502d644`, tree `fe79831e1c7e8c7d8f1f0f82f250e8b40dcffa80`; clon independiente y pruebas parten de ese corte. Las revisiones posteriores incluyen documentación y el fixes de limpieza `db333f9` y procedencia detached `bcdb1e7`, validados por separado.
- Comparador pendiente recuperado sin integrar: `recovery/20261019-pending-b04`, HEAD `fe0d8d46bf7c6abb223d246e7af43fbe1648439c`.
- El SHA de la entrega se obtiene con `git rev-parse HEAD` o el commit del PR; no se usa un hash autorreferencial dentro del documento.

## Cambios

Se recuperó la historia moderna owner → C11 → coherencia → B06 → B07 sin cambiar código runtime. README, AGENTS, CURRENT, DESIGN_CONTRACT, SOP, README servidor y entrada GSD orientan a la rama moderna y reconstrucción portable. Matriz: `PicoRadar_FORENSE_10_PASADAS.md`.

GitHub Actions y lockfiles se conservan; no se añadieron dependencias, parsers, migraciones ni activaciones comerciales. Correcciones acotadas de código de herramientas: `scripts/build_hostinger_staging_package.ps1`, `scripts/verify_hostinger_staging_package.ps1`, `scripts/package_scratch_cleanup.ps1` y su fixture de regresión. Sustituye la limpieza recursiva fallida de PowerShell por .NET con reintentos IO acotados, validación del temporal propio y ancestros, y conservación del error original. Además, `bcdb1e7` registra la rama como `HEAD` en clones detached, evitando un Trim sobre null en la procedencia; `07c8962` aplica la misma limpieza acotada al verificador, con fixture propio y conservación del error primario. No cambia comandos ni layout del paquete. B04 comparador permanece pendiente y separado; versiones anteriores y QA histórica no se aplican sobre el runtime.

## Alcance y áreas

Rescate V2 transversal autorizado; no es un lote funcional nuevo. Áreas documentales: `README.md`, `AGENTS.md`, `docs/CURRENT.md`, `docs/DESIGN_CONTRACT.md`, `docs/SOP.md`, `server/README.md`, `.planning/.continue-here.md`, matriz y este único handoff. Herramientas modificadas: builder, helper de limpieza y fixture descritos arriba. Sin paquetes nuevos, cambios de esquema ni migraciones nuevas; se probaron las migraciones recuperadas en bases sintéticas.

QA manual: inspección de fuentes, contratos, diffs y continuidad remota. QA física Android **BLOCKED/pendiente**: dispositivo y versión no evaluados, sin conexión a Mi A3. Stop conditions registradas: archivo denegado en Windows, CI por facturación y fallos de pruebas; no se desactivaron controles ni se ocultaron resultados.

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
| Tests Android nativos | PASS: 57 tests en seis suites XML, cero fallos/errores/omisiones; :app:testDevDebugUnitTest con las mismas opciones de proceso |
| Laravel/Pint/migraciones/assets | PASS local en PHP 8.5.8: 108 paquetes Composer desde lockfile, npm ci/build, Pint; PHPUnit 602 tests / 2.778 aserciones / cero fallos / una omisión por symlink en Windows; migraciones SQLite nuevas, rutas, contrato B06/B07 y cobertura nacional. PHP 8.3/8.4 no ejecutados por CI bloqueada |
| B06/B07 paquete desde clon remoto | Dos intentos stock FAIL tras Composer 77 paquetes, npm y Vite correctos. Diagnóstico: Remove-Item node_modules en línea112, DirectoryNotEmpty HRESULT80070091, ocultado por finally252. La limpieza corregida db333f9 pasó en el builder real, pero el tercer intento falló después del ZIP por procedencia detached (Trim sobre null, línea225), 1.579s. Cuarto intento desde GitHub bcdb1e7 PASS, 1.860s; ZIP 8.976.004 bytes. Verificación de contenido/hashes/token PASS pero proceso exit1 por cleanup93, 878s; fix 07c8962 y repetición integral PASS, exit0 en 1.604s, incluyendo limpieza final. MariaDB exit1, 894s: base creada, instalación detenida por enlaces públicos que requieren NTFS en Windows/exFAT; no acredita instalación ni checks posteriores |
| Limpieza temporal corregida | Fixture Windows de límites/handles PASS y residuo real PASS en 67s. Junction raíz/intermedia NOT_RUN/SKIP porque TEMP es exFAT; no se creó otro filesystem. Revisión independiente del fix sin bloqueos adicionales |
| B06/B07 navegador | BLOCKED_FILE_UNAVAILABLE por denegación local del PS1; no ejecutado |
| CI de `21be9d9`, `2d925dd` y tooling `db333f9`/`bcdb1e7`/`07c8962` | CI_INFRA_BLOCKED_GITHUB_BILLING; cinco jobs por corte fallaron sin iniciar steps por pagos/límite de gasto; anotaciones remotas comprobadas |
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

El clon independiente pasó de `21be9d9` a `db333f9`, `bcdb1e7` y `07c8962cfe6d5a231295483c459f8531259e4526` únicamente mediante fetch GitHub para probar los fixes de empaquetado. `mobile`, `server`, `data` y `contracts` son idénticos entre estos cortes. Las pruebas runtime anteriores no se presentan como ejecutadas sobre scripts nuevos; la validación del builder corregido se registra aparte.


Paquete independiente: SHA-256 `a2fd5de971153a7f2f904813376fd9f01358f95d5b01b98015c583df8e0721c0`, producido desde `bcdb1e7`. Se reconstruyó el instalable completo B07 mediante el builder B06 compartido; no se generó otro ZIP con el prefijo B06 por defecto. Contrato de selección B06/B07 PASS. Token separado y logs privados en D:, fuera de Git. Comandos ejecutados desde la raíz del clon independiente, con PHP y TEMP de proceso del README:

```powershell
pwsh -NoProfile -File scripts/build_admin_content_package.ps1 -OutputDirectory ..\..\PicoRadar_Rescue\deliverables\admin-content-detached -PhpPath C:\xampphp\php\php.exe -AppUrl https://picoradar.example.test
pwsh -NoProfile -File scripts/verify_hostinger_staging_package.ps1 -ArtifactDirectory ..\..\PicoRadar_Rescue\deliverables\admin-content-detached -ZipPattern PicoRadar-admin-contenidos-*.zip
pwsh -NoProfile -File scripts/tests/test_hostinger_installer_mariadb.ps1 -ArtifactDirectory ..\..\PicoRadar_Rescue\deliverables\admin-content-detached -ZipPattern PicoRadar-admin-contenidos-*.zip
```

No repetir el builder sobre una carpeta de salida existente. Para otra reconstrucción, elegir un destino nuevo y adaptar los tres comandos. El harness MariaDB verifica enlaces públicos obligatorios después de inicializar el esquema, operador y datos base; en Windows exFAT no los pudo crear. Login web, health de paquete, cron, backup/restore y rollback posteriores **NOT_RUN**. Resolverlo cambiando filesystem o alterando el contrato del instalador queda fuera del rescate autorizado; se conserva D: exFAT y la evidencia sintética privada.
Firma release debug y su TODO son deuda histórica explícita; no se autoriza publicar una release con esa configuración.

QA física scanner, autenticación, notificaciones, Conducir y rendimiento heredada: **pendiente, no ejecutada**, por instrucción de no tocar Mi A3. Sin merge ni Hostinger. Word3D/World3D y originales artísticos históricos no localizados dentro de la cobertura; assets runtime sí versionados. Chats antiguos no exportados no accesibles.

## Git status de entrega

C: conserva `d26ba84` y los mismos tres directorios sin seguimiento (`capturas/`, `mockups/`, `output/`); los trece worktrees se contrastaron sin cambios de HEAD/estado. Tras commitear la documentación, ambos checkouts D: conservan una única excepción conocida:

```text
 D scripts/tests/test_hostinger_installer_browser.ps1
```

Esa eliminación no se incluyó en el índice ni se publicó. Por ello no se declara worktree limpio; el contenido sigue en GitHub. Respaldo recuperable privado: `D:/PicoRadar_Rescue`, índices en `manifests/`, logs en `logs/`. No depende de este chat para reconstruir la fuente segura publicada; las variantes privadas preservadas requieren acceso al respaldo.

## NEXT

Una tarea: aislar y corregir el fallo de selector tardío de documentos. Crear `codex/fix-document-late-picker` desde `07c8962cfe6d5a231295483c459f8531259e4526`, usando un clon GitHub y las instrucciones finales del PR #71. Ese corte fija el tooling y conserva el runtime probado de `21be9d9`; los commits documentales posteriores no cambian esa base. Alcance: `mobile/test/features/buy_sell/presentation/purchase_documents_screen_test.dart` y el flujo estrictamente necesario; conservar revocación de visita, cifrado y limpieza privada. Reproducir primero con `flutter test --no-pub test/features/buy_sell/presentation/purchase_documents_screen_test.dart --plain-name "late picker result cannot preview or save after leaving its visit" --concurrency=1 --reporter=expanded` desde `mobile`. Aceptación: causa raíz documentada, caso y archivo completos PASS, formato/análisis PASS y suite móvil completa ejecutada con diferencias respecto de 3.233 PASS / 11 SKIP / 12 FAIL originales y, por separado, del recheck selectivo 7 PASS / 5 FAIL; no ocultar fallos ni aumentar timeouts sin evidencia. PR separado, sin merge, Hostinger ni Mi A3. Los demás gates bloqueados permanecen explícitos en esta entrega.
