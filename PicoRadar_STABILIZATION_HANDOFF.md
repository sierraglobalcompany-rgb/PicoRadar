# PicoRadar — handoff único de estabilización V4

Actualizado: 2026-10-21. Registro vigente del lote; sustituye los resultados anteriores de estabilización que figuran en este archivo.

## Estado

**FULL_MOBILE_QA_PASS (local).** Los cinco problemas móviles originales de PR #72 permanecen corregidos. La regresión completa pasó en el SHA de código registrado abajo: 3.253 PASS / 11 SKIP / 0 FAIL / 0 errores, exit 0. Los 11 skips son los existentes; no se añadieron skips en este lote.

No significa CI verde, aceptación física, release ni aprobación para merge. GitHub Actions no se ejecutó por cuota agotada. El visor/cleaner no requirieron cambio de producto; el caso del cleaner no reprodujo en las tandas controladas y queda INTERMITTENT_NOT_PROVEN.

## Rama, PR y evidencia Git

- Repositorio: sierraglobalcompany-rgb/PicoRadar.
- Rama: codex/picoradar-mobile-stabilization-20261020.
- PR draft: https://github.com/sierraglobalcompany-rgb/PicoRadar/pull/72
- Base: recovery/20261019-modern, SHA 5f59a7f75f907d9fefa80103eaf230524805f464.
- SHA de código probado: e5aeda06787eeec2e90fb6a7aa239a95516d6227.
- Tree probado: 2093c608196ae70eee9b5ea5dbafd7024d0c383f.
- La regresión global registró iguales SHA y tree antes/después.
- La documentación de cierre se agregará en un commit posterior, sin cambios móviles. Consultar HEAD remoto del PR para el SHA de publicación final.
- Canónico: D:/Dev/PicoRadar sobre exFAT. Originales C: preservados. Clon independiente: D:/Verification/PicoRadar.
- No merge, force-push, cambio de main, Hostinger ni teléfono.

## Cambios y ledger de causas

| Familia | Evidencia y cambio mínimo | Estado |
|---|---|---|
| Cinco objetivos originales | Selector tardío, scanner frente/reverso, Viaje sin hora/ETA, round-trip cifrado y caché SOAT: permanecen con sus aserciones de comportamiento y pasan en la suite completa final. | 5/5 PASS |
| A — descarga chunked | Se quitó solo la métrica del servidor chunksSent, que mide escritura/flush del servidor y no consumo del cliente. La prueba unitaria del stream confirma BoundedStreamException, cancelación del productor, menos de 17 bloques entregados y archivo parcial de máximo 48 bytes. El E2E HTTP sin Content-Length confirma sin versión instalada, sin llamada al importador y temporales limpios al resolver sync(). | PASS |
| B — compilador Python | Medición del fallo anterior mostró el timeout de 30 s bajo carga antes de que Process.run y el test terminasen; se observó acceso al JSON temporal durante el teardown. Dos procesos medidos bajo prueba terminaron con exit 0 en aprox. 2,5–2,7 s cada uno. Se conserva Process.run, las dos compilaciones deterministas y el contrato HTTP/Drift; timeout de 90 s aplicado solo a este test de integración. | PASS bajo la regresión |
| C — preparación / SQLite | Los seis tests que no verifican reinicio usan NativeDatabase.memory(); los tres tests que comprueban identidad estable, persistencia/reapertura y journal de limpieza mantienen SQLite en archivo, creado antes de escribir. Sin cambio de producto, cifrado, IDs, migración ni aserciones. | Archivo 9/9 PASS |
| D — visor PDF | El rechazo del PDF de más de dos páginas reutiliza pumpUntilRealIo y mantiene verificaciones de error, cierre, cero render/pageCounts/guardado, sesión y limpieza, archivo original intacto. | Archivo 31/31 PASS |
| Cleaner | Se conservaron doble eliminación e invariantes de no borrar datos/documentos/borradores ajenos. No reprodujo el fallo en las dos tandas agrupadas ni en la suite global; no se fabricó una corrección. | INTERMITTENT_NOT_PROVEN |

Commits de este cierre de cuatro causas: 4f21a15 (chunked y cancelación), 0be1dd3 (timeout acotado del compilador), bf55cde (SQLite de test), e5aeda0 (espera real del visor). La historia previa del mismo PR conserva los cinco objetivos originales.

Archivos móviles dentro del PR: mobile/test/core/sync/dataset_sync_hardening_test.dart; mobile/test/features/buy_sell/presentation/purchase_documents_screen_test.dart; mobile/test/features/documents/data/wallet_preparation_store_test.dart; mobile/test/features/documents/presentation/wallet_two_sides_flow_test.dart; mobile/test/features/documents/presentation/wallet_viewer_test.dart; mobile/test/features/trip/presentation/trip_screen_test.dart; mobile/test/features/vehicle_status/data/private_vehicle_document_store_test.dart; mobile/test/features/vehicle_status/presentation/vehicle_status_screen_test.dart; mobile/test/test_app_harness.dart. Sin cambios de runtime, UI, paquetes, lockfiles, plataforma, server, esquema, datasets o pipeline.

## QA local ejecutada

Toolchain observada: Flutter 3.47.1 / Dart 3.13.1. Comandos desde D:/Dev/PicoRadar/mobile. TEMP/TMP y logs detallados apuntaron a D:/PicoRadar_Rescue/logs/stabilization-20261021-v4; los logs son privados y no están en Git.

| Comando / cobertura | Resultado |
|---|---|
| dart format --output=none --set-exit-if-changed . | PASS; 387 archivos inspeccionados, 0 cambios |
| flutter analyze --no-pub | PASS; sin incidencias |
| Cinco casos smoke originales | PASS 5/5 |
| dataset_sync_hardening_test.dart, wallet_preparation_store_test.dart, wallet_viewer_test.dart y vehicle_associated_data_cleaner_test.dart agrupados, concurrency=2, pasada 1 | PASS 64/64; 0 fallos, errores o skips |
| Mismos cuatro archivos, mismo comando, pasada 2 | PASS 64/64; 0 fallos, errores o skips |
| Archivo sync completo | PASS 15/15 |
| Archivo preparación completo | PASS 9/9 |
| Archivo visor completo | PASS 31/31 |
| Regresión completa congelada en SHA e5aeda0, flutter test --no-pub --concurrency=2 --reporter=expanded | PASS; 3.253 PASS / 11 SKIP / 0 FAIL / 0 errores; exit 0; 1.596,68 s (26 min 36,7 s); 3.264 resultados totales |
| git diff --check y revisión acotada de secretos | PASS; sin hallazgos, resultado redactado en logs privados |

CI remota: REMOTE_CI_BLOCKED_QUOTA; no se consultaron ni relanzaron workflows y no se alteró CI. No se repitió una suite ya aprobada para código sin cambios. No APK/build de server: este lote no cambia runtime. No QA física, instalación en dispositivo, Hostinger ni Mi A3.

## Seguridad, datos y estado del checkout

- No se introdujeron secretos, datos personales ni archivos privados en el cambio publicado.
- Se preservan cifrado, guardas de sesión, limpieza, escritura durable, límites de descarga y validaciones.
- C: permanece intacto; D: sigue exFAT. Respaldos e inventario privados permanecen en D:/PicoRadar_Rescue.
- La regresión final registró al inicio y al cierre un único cambio preexistente y ajeno al lote: D scripts/tests/test_hostinger_installer_browser.ps1. Se conservó sin stage, restore ni publicación.
- Después del commit documental, verificar git status; el estado esperado conserva únicamente esa eliminación local.
- Sin migraciones, datos reales, cambios de dependencias ni impacto en esquema.

## NEXT

Tarea única: revisión humana del PR draft #72 antes de habilitar el siguiente lote funcional.

Punto de partida: rama codex/picoradar-mobile-stabilization-20261020, código probado e5aeda06787eeec2e90fb6a7aa239a95516d6227, base recovery/20261019-modern. Alcance: revisar el diff y evidencia local de este lote; el propietario decide si solicita cambios o aprueba y hace merge manual. Codex no hará merge. Criterio de aceptación: decisión humana registrada en PR #72 y, si se aprueba, el PR integrado sin cambiar la base moderna ni omitir la revisión. Después seleccionar un solo lote funcional según docs/CURRENT.md y su contrato; este prompt no inventa ni inicia esa funcionalidad.

QA física y CI siguen pendientes por sus límites respectivos. No desplegar ni probar en teléfono como parte de esta tarea.
