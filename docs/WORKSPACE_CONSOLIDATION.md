# Consolidacion del workspace PicoRadar

## Contrato (2026-09-15)

Raiz unica: `C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa`.
Rama: `codex/workspace-consolidation`. Sin merge, push ni cambios al celular.
El traslado conserva la version instalada, no activa pendientes de otras ramas.

## Recuperacion de pendientes

| Trabajo | Referencia Git | Tratamiento |
| --- | --- | --- |
| Codigo vigente instalado, WIP y .planning | `5958f42`, `codex/checkpoint-current-before-consolidation` | Base de esta consolidacion |
| WIP anterior de la raiz (R03/SOAT) | `b86c787`, `codex/checkpoint-root-before-consolidation` | No aplicar sobre la version actual sin comparar |
| B04 comparador de importaciones | `fe0d8d4`, `codex/pending-B04-before-consolidation` | Pendiente; no integrado al runtime actual |
| Fuentes QA del worktree vigente | `af7df94`, `codex/pending-qa-sources-before-cleanup` | Recuperar solo lo necesario al reabrir QA |
| Fuentes QA auxiliares de la raiz | `6fc47b5`, `codex/pending-root-qa-before-cleanup` | Historial Git; sin otra carpeta de codigo |

B04 afecta `codex/lots/B04_CAMERA_IMPORTER_VALIDATOR.md`,
`server/app/Http/Controllers/Admin/CameraImportController.php`,
`server/routes/web.php` y
`server/resources/views/admin/camera-imports/compare.blade.php`.
Para retomarlo: inspeccionar `git show fe0d8d4`, revisar dependencias del lote,
crear una rama nueva desde la base vigente e integrar deliberadamente.
No hacer cherry-pick ciego: el controlador no existe en la base movil actual.

## Evidencia vigente

APK instalado preservado en `artifacts/current/PicoRadar-installed-dev-release.apk`.
SHA256: `C8D5B1E2B374AC4517E410F77FD16C345F07D2B3AC20F500391F919646746C00`.
Capturas y logs actuales: `artifacts/current/purchase/`.
Registro de eliminaciones comprobadas: `artifacts/current/consolidation/deletions.jsonl`.
Los artefactos locales no se publican ni son copias historicas del repositorio.

Fuentes CDA: `data/sources/cda/`; fuentes de Comparendos:
`data/sources/comparendos/`. No dependen de Descargas ni de temp.

## Pendientes funcionales que esta limpieza no cierra

- Compra/documentos: importacion fisica, escaner, autenticacion positiva y
  aceptacion del propietario; ver `codex/PURCHASE_FUNCTIONAL_HANDOFF_20260915.md`.
- Suite completa previa: 2868 pass / 10 skip / 88 fail; una asercion de recuperacion
  fue corregida y validada aisladamente. No se declara suite global verde.
- Cobertura de directorios: mantener los pendientes y sus limitaciones en
  `codex/PURCHASE_DIRECTORY_AUDIT_20260915.md` y auditorias C13/C24.
- Las ramas Git anteriores permiten retomar otros lotes sin mantener worktrees
  ni procesos abiertos. Su retirada no significa aprobacion funcional.

## Gate de eliminacion

Comparar cambios reales, preservar referencias, confirmar consumidores, verificar
fuentes/evidencia y validar desde la raiz antes de retirar copias de codigo.
No seguir enlaces; no borrar carpetas compartidas ni originales editables unicos.
Las caches regenerables pueden retirarse antes del build para liberar espacio,
una vez preservado el APK instalado y la evidencia vigente.

## Estado de ejecucion

Consolidacion del codigo y limpieza interna verificadas. Limpieza externa PARTIAL:
la herramienta bloqueo el borrado externo antes de ejecutarlo. No se reintento
por otra via. Descargas, originales de vehiculos y archivos de otros proyectos
permanecen intactos. Las copias B03/B04 de PicoRadar si se retiraron mediante Git
tras preservar sus commits y configuraciones locales.

## Resultado verificable

- Unico worktree registrado: raiz canonica. Retirados los 18 worktrees auxiliares
  existentes, incluidos B03/B04; 48 registros obsoletos depurados con referencias
  previas preservadas. Sin borrar .git ni reescribir main.
- temp contiene cero archivos. Windows retiene vacias las carpetas
  temp/VIAJE-R1-real-planner/mobile y su padre. No se termino un proceso de
  pertenencia incierta para desbloquearlas.
- Mas de 39.37 GiB de eliminaciones confirmadas por archivo/directorio en el
  registro local. El conteo es conservador: excluye las eliminaciones parciales
  realizadas por Git antes de errores de ruta larga/bloqueo. Disco libre observado
  despues: aproximadamente 46 GiB; esa cifra tambien depende de otros procesos.
- Retirados APK reemplazados, caches de builds anteriores, paquetes temporales,
  exports CDA manuales sustituidos por la fuente actual y checkpoints intermedios
  de .planning. Los contratos normativos y fuentes actuales se conservan.
- El enlace node_modules del antiguo worktree apuntaba al runtime compartido de
  Codex. Se retiro solo el enlace; el destino compartido existe y no se limpio.
- Ningun proceso de otros ERP, navegador personal ni servicio compartido cerrado.
  No se modificaron datos del celular, configuracion global ni SDKs.

## APK y pruebas desde la raiz

APK reconstruido: mobile/build/app/outputs/flutter-apk/app-dev-release.apk.
SHA256: 362608E545676E67A8BC3AAA33407E7846158E356D7AD3665942EFE76C99CBFF.
Paquete co.picoradar.app.dev, version 1.0.0 (1), minSdk 24, targetSdk 36;
coinciden con el APK instalado preservado. El hash nuevo es diferente al APK
instalado; no se afirma identidad binaria ni se reinstalo. La comparacion Git
de mobile/lib, assets, android y pubspec contra 5958f42 no muestra diferencias.

| Gate | Resultado |
| --- | --- |
| flutter analyze --no-pub | PASS, sin issues |
| flutter test --no-pub test/features/buy_sell test/core/database test/features/documents test/features/comparendos test/features/vehicle_status/data/purchase_tax_directory_test.dart test/features/vehicle_status/data/tax_catalog_test.dart test/features/services test/features/settings/presentation/settings_screen_test.dart --concurrency=1 | 625 PASS |
| flutter test --no-pub --concurrency=1 | 2872 PASS, 11 SKIP, 87 FAIL conocidos |
| Comparacion de nombres de fallos | 0 nuevos; retirada la asercion K7 ya corregida antes de esta consolidacion |
| dart format --output=none --set-exit-if-changed lib test tool | 345 archivos, 0 cambios |
| flutter build apk --flavor dev --release --no-pub | PASS, 100.7 MB |
| Python unittest comparendos_import_test.py | 4 PASS con Python incluido en Codex |
| PowerShell parser y rechazo de raiz fuera del alcance de limpieza | PASS |
| git diff --check | PASS |

Python313 global no tiene pdfplumber y el primer intento de esas pruebas fallo
por dependencia ausente. Se uso el Python ya incluido en Codex, sin instalar ni
modificar paquetes globales. Logs y comparacion exacta en artifacts/current/consolidation.

## Elementos pendientes de clasificacion/eliminacion

- Externos en Descargas y Documentos: duplicados detectados por hash y paquetes
  C01/C02 con commits existentes; eliminacion bloqueada, siguen en su lugar.
- Tres carpetas PicoRadar_Vehiculos_3D del Escritorio: contienen fuentes originales
  y normalizadas. No afirmar que una exportacion WebP sustituye al original PNG.
  Ninguna fue borrada; falta correspondencia completa fuente/asset aprobado.
- capturas/, mockups/ y output/ heredados: fuentes de diseno y propuestas cuyo
  estado de aprobacion no es uniforme. Conservados sin atribuirlos a esta tarea.
  Los cinco mockups owner identificados en la conversacion estan tambien en
  docs/design/reference; no se borro el original externo.
- .local contiene solo configuraciones/datos unicos necesarios para pendientes,
  incluidos borradores server y una copia QA del dispositivo. No es codigo activo
  ni un backup completo. No publicar ni activar configuraciones al retomar sin
  revisar rutas/secretos. Su eliminacion requiere resolver su uso pendiente.
- C:/codex, C:/codexD, Documentos/Codex y espacios compartidos: no se hallo una
  unidad eliminable con pertenencia exclusiva comprobada a PicoRadar en el
  inventario revisado. Menciones en logs de ERP-BDM NO autorizan borrado.

## Herramientas de auditoria

Superpowers executing-plans y verification-before-completion; GSD workspace y
pause-work para refs y handoff; Graphify query contrastado con rg/Git. El grafo
local es historico y su paquete 0.9.37 difiere de la skill 0.9.55: no se actualizo
tooling compartido ni se uso el grafo como prueba suficiente de orfandad.
