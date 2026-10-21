# PicoRadar — handoff único de estabilización

## Status
**PARTIAL. Cinco de cinco objetivos corregidos y PASS en focales y en la última regresión completa.** Gate global FAIL por11 casos adicionales; los nueve nuevos pasan en recheck serial. Chunked falla también aislado y compilador pasa aislado pero falla bajo carga. No release ni aceptación física.

## Lot
Estabilización consolidada de cinco fallos móviles, por orden del propietario de 20-10-2026. Sustituye el NEXT exclusivo del selector tardío. Un lote y un PR, sin rescate forense repetido ni features nuevas.

## Git
- Branch: `codex/picoradar-mobile-stabilization-20261020`.
- Código publicado local/remoto: `161ceb6410a16aa0e0267be41489a5426e22d752`; tree `c55e47d0d75298e2c77f1a45b11cedbec127dae7`.
- Base: `recovery/20261019-modern`, SHA `5f59a7f75f907d9fefa80103eaf230524805f464`, recuperado en PR #71. No se volvió al main antiguo.
- PR draft único: https://github.com/sierraglobalcompany-rgb/PicoRadar/pull/72 . Sin merge.
- Worktree canónico: `D:/Dev/PicoRadar`, exFAT. Original C: preservado; no se movieron sus worktrees.
- El commit documental que contiene este handoff puede ser posterior al SHA de código probado; obtener HEAD final con `git rev-parse HEAD` y cotejar PR. No se introduce un hash autorreferente en este archivo.

## Outcome y ledger único
Baseline full anterior: **3233 PASS / 11 SKIP / 12 FAIL**. Recheck anterior: **7 PASS / 5 FAIL**. Los doce no eran doce defectos persistentes acreditados.

| Caso | Reproducción actual | Causa acreditada | Corrección mínima | Evidencia posterior | Global |
|---|---|---|---|---|---|
| Selector tardío | FAIL, 7,86s | Espera nominal ~1s abandona I/O/cleanup activo | Predicado real acotado y refuerzo de sesión bloqueada/original conservado | Focal PASS; archivo 20 PASS | PASS en full-2 |
| Scanner frente/reverso | FAIL, 11,66s; después Guardando activo al salir de espera3s | Dos esperas cortas en validación y guardado | Sincroniza validación/cierre/mutex; comprueba nombres y rutas cifradas distintas | Archivo 6 PASS | PASS en full-2 |
| Viaje sin hora/ETA | FAIL, 6,57s | Reloj real contra fixture staleAfter 01-10-2026 | Fecha sintética vigente, sin tocar tests de caducidad | Focal PASS; archivo 95 PASS | PASS en full-2 |
| Round-trip cifrado | Timeout30s, 33,55s con teardown | Siete tipos y escrituras durables acumulados en un presupuesto | Siete tests independientes con timeout original; índice mixto cifrado adicional | Siete tipos e índice PASS dos veces | PASS siete tipos e índice en full-2; archivo28/28 también cubierto entre full-1 y reanudación |
| Caché SOAT | FAIL, 9,45s; teardown Error32. Más tarde No element en global | Espera silenciosa corta; close SQLite no esperado; lookup onstage falla si visor deja owner offstage | Predicado explícito, await close y lookup de owner montado incluyendo offstage | Focal final 2/2 y archivo final 100/100 PASS | PASS en full-2 después del fix; sin No element |

El helper amplía su presupuesto de pared de1–3s a30s, con evidencia de I/O aún activo; termina al satisfacer el predicado o falla explícitamente. No cambia timeout del runner ni demuestra un defecto de FakeAsync. No hay pausas incondicionales largas, skips nuevos, aserciones debilitadas ni cambios de cifrado/flush/guards/privacidad.

El índice mixto prueba lectura de siete entradas; no equivale a siete importaciones acumulativas. Se mantienen tests de importaciones concurrentes y preservación de entradas. Los timeouts variables en otros tests compuestos de almacenamiento tienen causa UNKNOWN; no se atribuyen automáticamente al entorno.

## Files / areas changed
Solo seis archivos de tests en mobile: `test_app_harness.dart`, `purchase_documents_screen_test.dart`, `wallet_two_sides_flow_test.dart`, `trip_screen_test.dart`, `private_vehicle_document_store_test.dart`, `vehicle_status_screen_test.dart`. Documentación: este handoff y puntero mínimo en `docs/CURRENT.md`.
Commits: `1755dcc` reloj; `c76562d` sincronización/teardown; `c9e38b6` cifrado por tipo; `161ceb6` owner offstage y limpieza de import innecesario.
Sin producción, paquetes, lockfiles, plataforma, servidor, esquema, pipeline ni cambios C11/B06/B07.

## Tests executed
Desde `D:/Dev/PicoRadar/mobile`, Flutter3.47.1 / Dart3.13.1. TEMP/TMP de proceso: `D:/PicoRadar_Rescue/logs/stabilization-20261020/temp`. Fuentes/temporales de proyecto en D:; SDK y caché pública instalada en C: son dependencias legítimas, no fuentes prestadas.

| Comando / ejecución | Resultado |
|---|---|
| `flutter pub get --offline` | PASS; lockfile sin cambios |
| `dart format --output=none --set-exit-if-changed .` | PASS; 387 archivos, 0 cambios; final15,23s |
| `flutter analyze --no-pub` | PASS sin incidencias; final17s |
| Focal red cinco casos | 0 PASS / 5 FAIL;429,6s |
| Primera focal corregida | 11 PASS /1 FAIL; scanner mostró segundo corte corto, corregido |
| Cinco archivos completos seriales | 248 PASS /1 FAIL;893,4s; timeout auxiliar almacenamiento |
| Diagnóstico reemplazo con60s | PASS en ~17s; aumento retirado: no demostró necesidad |
| Archivo almacenamiento repetido con30s | 27 PASS /1 FAIL distinto;422,1s; causa UNKNOWN |
| `flutter test --no-pub --reporter=expanded --concurrency=2` full-1 | Interrumpido sin done/result;2877 PASS /10 SKIP /2 FAIL |
| Reanudación de12 casos almacenamiento pendientes | 12 PASS;98s; no repite16 terminados |
| Reanudación20 archivos pendientes/incompletos | 359 PASS /1 SKIP /2 FAIL; ambos lookup del visor |
| Cobertura completa por particiones antes del último fix | **3248 PASS /11 SKIP /4 FAIL**;3263 casos únicos, +7 respecto baseline por parametrización y nuevo índice |
| Recheck serial compilador Python | PASS,26s; no borra su timeout previo bajo carga |
| Recheck serial chunked sin Content-Length | FAIL: chunksSent17, esperaba<17; se conserva aserción |
| Focal final SOAT + visor offstage | 2 PASS;14s de test |
| Archivo final vehicle_status_screen_test | **100 PASS**,136s; sustituye archivo previo98 PASS /2 FAIL para evidencia posterior al fix |
| Recheck posterior solo nueve casos nuevos, concurrency1 | **9 PASS /0 FAIL /0 SKIP**,47s de tests; no cambia el resultado de full-2 |
| Última global full-2, mismo comando | **3241 PASS /11 SKIP /11 FAIL**, exit1,3802,46s (63,4min), SHA/tree de inicio y fin idénticos a161ceb6/c55e47d; no tercera global en esta ejecución |

Focal exacta: `flutter test --no-pub <archivo> --plain-name '<nombre del caso>' --concurrency=1 --reporter=expanded`. Archivos completos: mismo comando sin `--plain-name`. Los cinco archivos de lote y los nombres figuran en ledger; rutas completas en eventos nativos privados.
Logs/eventos/resultados únicos: `D:/PicoRadar_Rescue/logs/stabilization-20261020/`. No se publica contenido sensible de logs ni se añade parser al producto. Checkpoint privado único: `D:/PicoRadar_Rescue/manifests/PicoRadar_STABILIZATION_CHECKPOINT.md`.

Delta frente al baseline: PASS+8, FAIL-1, SKIP0, casos+7; los conjuntos de fallos cambiaron. Los cinco persistentes ahora PASS; de los otros siete casos históricos, seis PASS y revocación de preparación volvió a fallar por timeout. Diez fallos finales son distintos de los doce originales. El recuento global no equivale a once defectos independientes de producto.

La primera ejecución terminó sin proceso Dart activo y sin resumen del runner. No se declara exit0 ni se suma un recheck a sus PASS para fingir verde. La selección de pendientes usa suites/grupos/testDone del reporter JSON nativo; full-2 se lanzó independiente de la sesión del chat tras nueva corrección acreditada.

Preparación SQLite: primer intento no ejecutó casos por descarga bloqueada. Se reutilizó solo DLL pública sqlite3-3.5.2 de caché D:, SHA `2bf39f2aadafdc59a90b260f582a8fccebc5b89eb94175fdbaa9148c1e1f084d`, manteniendo comprobación estándar del hook. Sin prestar fuentes, alterar TLS o cambiar dependencias.

## Fallos residuales exactos y rechecks

No confundir11 test cases con11 causas ni convertir recheck en PASS global. Se mantienen todos en el ledger, aunque su reproducción aislada pase.

| Archivo dentro de mobile/test | Casos exactos | Full-2 / recheck |
|---|---|---|
| core/sync/dataset_sync_hardening_test.dart | `Python compiler bytes reach the engine through HTTP and Drift` | Timeout30s; PermissionError posterior; serial anterior PASS26s, repite FAIL bajo carga |
| core/sync/dataset_sync_hardening_test.dart | `caps a chunked dataset without Content-Length` | FAIL y serial FAIL;17 enviados frente a<17 |
| features/documents/data/wallet_preparation_store_test.dart | `all six preparation types roundtrip without a vehicle across restart`; `unknown preparation and invalid types cannot write documents`; `vehicle cleanup cannot affect preparation even with the same ID`; `replacement and preparation deletion clean only their own files`; `revoked authorization rolls back creation, replacement and deletion`; `encrypted preparation and document identities reject relabeling`; `preparation deletion journals cleanup failure and retries on reopen` | Siete timeout30s con errores posteriores de base ya cerrada; siete PASS serial después |
| features/documents/presentation/wallet_viewer_test.dart | `new restricted preview rejects over-two-page PDF without save` | Helper no alcanza estado observable; PASS serial después |
| features/garage/application/vehicle_associated_data_cleaner_test.dart | `deleteForVehicle cleans vehicle data without deleting other drafts` | Timeout30s y acceso posterior a temporal borrado; PASS serial después |

Reproducción mínima por caso: usar el comando focal anterior y estos nombres, sin ampliar presupuestos ni quitar flush/aserciones. El recheck posterior se ejecutó una sola vez, agrupando los nueve casos por regex exacta de nombres y tres archivos, serial. El compilador y chunked no se repitieron otra vez; ya tenían evidencia aislada.

## Manual QA / Physical Android QA
No ejecutada. Sin teléfono, Mi A3, instalación APK ni Hostinger. QA física pendiente para aceptación de capacidades OS; tests locales no la sustituyen. No hay claim de release.
Pruebas acreditadas sin cambios no repetidas: runtime21be9d9 APK dev y57 nativos PASS; Laravel602 tests/2778 aserciones/0FAIL/1SKIP; B07 buildbcdb1e7/verificador07c8962 PASS.

## Data / migration impact y dependencias
Ninguno. Sin cambios de esquema, migración, datasets, librerías o plataforma. Datos de tests sintéticos, raíces temporales propias.

## Security / privacy review
Guards de sesión/epoch, owner, limpieza, cifrado y escritura durable preservados. Sin secretos, GPS/documentos privados reales, cambios de permisos o desactivación de controles. Gitleaks staged y diff --check PASS; escaneo final del rango nuevo (cuatro commits de código) y staged documental PASS, cero hallazgos. Revisión independiente previa sin bloqueos materiales; hallazgo posterior offstage respaldado por traza y pruebas.
Publicación mediante Git Database API oficial con cuenta propietaria: trees y commits idénticos local/remoto; expected SHA y force=false. HTTPS Git local bloqueado por conectividad; no se cambió cuenta global ni se reescribió historia.

## Known risks / debt y stop conditions
- **REMOTE_CI_BLOCKED_QUOTA**, confirmado por propietario; sin reruns/consultas Actions ni cambios de YAML/cuota.
- **Chunked reproducible:** aserción servidor chunksSent<17 falla también aislada. Es distinto de demostrar que el consumidor exceda su límite. No debilitar la aserción ni inferir corrección del límite solo por una excepción genérica. Se necesita investigar evidencia causal fuera de los cinco originales.
- **Compilador:** timeout30s primero; PermissionError posterior al leer JSON temporal. Recheck aislado PASS. Carrera con teardown plausible, causa exacta UNKNOWN. No cambiar ACL/timeouts por hipótesis.
- **BLOCKED_FILESYSTEM:** única NTFS C: con109–163MB observados; datadir sintético superior ya157.750.948 bytes sin app/subdirectorios/margen. Requiere ubicación existente aislada con enlaces y espacio suficiente (margen recomendado>=1GiB). Sin mover proyecto, reformatear D: ni VHDX. No se rehízo paquete B07.
- **BLOCKED_SECURITY_CONTROL:** `scripts/tests/test_hostinger_installer_browser.ps1` ausente desde antes; padre legible/ACL consultable, atribución exacta UNKNOWN. No se forzó restore, eludió control ni publicó borrado. JS existente necesita HTTPS/DB/fixtures del harness; browser NOT_RUN.
- `git status` conserva únicamente al cerrar la excepción esperada ` D scripts/tests/test_hostinger_installer_browser.ps1`; documentos se publican explícitamente. No afirmar checkout limpio.

## Next lot(s) unblocked / NEXT
Full-2 y recheck serial posterior ya recogidos. No iniciar otra investigación dentro de este cierre. Ningún bloque funcional nuevo queda desbloqueado mientras falle el gate móvil. Siguiente tarea única posterior a este cierre: estabilizar el gate móvil residual de sincronización, preparación y limpieza en la misma rama/PR desde161ceb6 o su descendiente documental: acreditar el límite chunked sin depender del ritmo del servidor, esclarecer timeout del compilador y las operaciones que sobreviven al timeout y acceden a una base cerrada. Incluir los nueve casos nuevos según recheck; no repetir los cinco ya resueltos. Alcance tests/harness mínimo, sin modificar datasets, privacidad, CI o producto. Aceptación: causas demostradas, checks focales correspondientes PASS sin debilitar contrato y regresión global PASS; actualizar este único ledger. El resultado final añade el grupo de preparación/visor/limpieza al gate pendiente; no abrir un PR por error.

## Do not forget
C: preservado; D: sigue exFAT; no merge, force-push, Hostinger, teléfono, instalación, features nuevas ni rescate repetido. No crear ZIP ni manual duplicado.