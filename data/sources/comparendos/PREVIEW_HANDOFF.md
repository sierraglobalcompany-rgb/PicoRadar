# C14 Comparendos: vista previa instalada

## Estado
PARTIAL. Presentacion y selectores implementados; candidato release instalado.
Aprobacion visual del propietario, investigacion nacional exhaustiva, suite global
y publicacion pendientes. No se declara cerrado el plan integral.

## Git y alcance
- Branch: codex/comparendos-owner-directory.
- HEAD: ddf60407174e3ee8d447b7eff3ca45e0fd983789.
- Base de trabajo: codex/fotomultas-owner-map con WIP previo, no solo HEAD.
- Worktree: C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa/temp/VIAJE-R1-real-planner.
- Unico cambio funcional propio: Apps > Comparendos (C14).
- Sin commits, push, PR ni merge. Se preservaron .planning y los cambios anteriores.
- Estado Git completo al entregar: GIT_STATUS.txt en esta carpeta; WIP previo y
  archivos nuevos sin stage, explicitamente conservados para aislar la publicacion.

## Resultado
- Identidad con asset seleccionado completo, placa aprobada104dp, matricula municipal,
  copiar, selector local de vehiculo y prioridad de contexto explicito.
- SIMIT principal y selector nacional por municipio, departamento o autoridad.
- Seleccion territorial temporal independiente de matricula, favorito y GPS.
- Fichas historicas sin enlaces inventados ni competencias inferidas de su sede.
- Guardado de anotacion manual por vehiculo y dia de Bogota, errores/reintento y
  bloqueo de doble pulsacion. No se obtiene ningun resultado oficial.
- Un scroll vertical de contenido; navegacion inferior original fija.

## Archivos propios
- mobile/lib/features/comparendos/presentation/comparendos_screen.dart
- mobile/lib/features/comparendos/presentation/comparendos_widgets.dart
- mobile/lib/features/comparendos/presentation/comparendos_selectors.dart
- mobile/lib/features/comparendos/data/territorial_catalog.dart
- mobile/assets/catalogs/comparendos_authorities_v1.json
- mobile/test/features/comparendos/data/territorial_catalog_test.dart
- mobile/test/features/comparendos/presentation/ (cuatro archivos)
- mobile/tool/comparendos_import.py, comparendos_import_test.py,
  comparendos_verifications.json
- .planning/COMPARENDOS_OWNER_CHECKPOINT.md

La pantalla y su test ya tenian cambios anteriores: no publicar su diff completo
contra HEAD como si todo perteneciera a esta entrega. Ver checkpoint y WIP.

## Comandos y resultados
Ejecutables Flutter/Dart: C:/Users/felip/.codex/tooling/flutter_3.47.1/flutter/bin.
Comandos desde mobile salvo indicacion distinta.

| Comando | Resultado |
| --- | --- |
| flutter test test/features/comparendos --no-pub --reporter expanded | 132 PASS, 2026-09-13 |
| flutter analyze --no-pub | Sin incidencias, app completa |
| dart format --output=none --set-exit-if-changed lib/features/comparendos test/features/comparendos | 9 archivos, cero cambios |
| python mobile/tool/comparendos_import_test.py (raiz, runtime auditado) | 4 PASS, subauditoria de importacion |
| git diff --check (raiz) | PASS |
| flutter build apk --release --flavor dev --dart-define=APP_ENV=dev --no-pub | PASS, 89s |
| adb -s 116f2191b19a install -r APK | Success |
| adb shell sha256sum ruta_instalada/base.apk | Coincide con la APK entregada |

Build aviso no bloqueante: herramientas SDK XMLv3 frente a XMLv4. No se alteraron
versiones de herramientas por este lote. Iconos reducidos por tree-shaking.

## APK
Archivo: PicoRadar-comparendos-dev-release.apk, en esta carpeta.
Tamano: 96,980,800 bytes (92.49 MiB; Flutter informa 92.5 MB).
SHA256: b3bf3c20bb26a3b40c1119ca828675eefe29f9458a3aa83986f66e653e927c6e.
Mismo hash comprobado en base.apk instalado. Variante dev RELEASE optimizada;
no contiene la simulacion que actualmente es exclusiva de debug.

## QA fisica
Required, comprobaciones de vista previa realizadas; aprobacion visual PENDIENTE.
Mi A3 116f2191b19a, Android11, 720x1560px/densidad320, escala del usuario sin cambios.
- Antes/Despues: before.png, after-same-vehicle.png, after-top.png, after-bottom.png.
- Selector de vehiculo: vehicle-selector.png (cuatro vehiculos conservados).
- Ciudad y teclado real: city-selector.png, city-search.png.
- Temporal independiente: temporary-bogota.png, motorcycle-bogota.png.
- Portales reales: medellin-portal-ready.png y simit-portal-ready.png.
- Retorno conservando consulta y scroll: return-from-portal.png.
- Reentrada conserva contexto global Medellin: final-default-context.png.
- No se introdujeron datos personales en formularios; no se marco consulta de hoy
  sobre vehiculos reales. Fallos, guardado y medianoche cubiertos por fixtures.
- Se abrio accidentalmente Impuestos al regresar a Apps, sin realizar acciones;
  se volvio a Comparendos y se verifico/corrigio la captura final. Todas las
  capturas listadas aqui corresponden al modulo o al portal explicitamente indicado.

Capturas automatizadas (otros tamanos, escalas1/1.5/2, moto/taxi/nombres largos):
C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa/temp/COMPARENDOS_OWNER/automated.
La geometria mide los glifos pintados, no ancho de layout holgado del FittedBox
preexistente de navegacion. No se modifico la barra compartida para pasar tests.

## Comparacion visual
Se conserva la jerarquia del mockup: identidad, SIMIT, territorial, anotacion.
Diferencias deliberadas: iconografia textual de SIMIT sin imitar logo oficial;
placa aprobada con emblema; assets reales guardados; fuente completa en ficha;
territorio sin tarjeta anidada; scroll cuando el contenido lo requiere.
La moto real conserva un registro antiguo de nueve caracteres: el renderer
aprobado lo muestra en dos lineas para conservarlo integro. La matricula normal
de seis caracteres permanece horizontal. No se modificaron esos datos.
La fidelidad no esta aprobada por haber pasado los tests.

## Directorio: limite importante
Ver CATALOG_HANDOFF.md y mobile/tool/comparendos_verifications.json.
Se conciliaron 1003 filas historicas (FCM398+308, RUNT297) en 769 registros de
referencia, NO en 769 autoridades actuales unicas certificadas.
7 registros investigados individualmente: 2 destinos de consulta directa
(Medellin, Manizales), 5 entradas institucionales comprobadas. 762 registros
pendientes de investigacion individual; 93 ubicaciones de sede sin codigo resuelto.
La busqueda nacional existe, pero el catalogo nacional plenamente verificado NO
esta terminado. Posibles alias/sedes/sucesiones siguen separados hasta obtener
evidencia; ausencia de enlace no implica ausencia de autoridad.

## Seguridad, datos y dependencias
Sin migracion, tabla, paquete runtime, permisos, backend ni consultas GPS nuevas.
URLs HTTPS acreditadas, sin placa/documento agregado, aperturas solo por toque.
Sin scraping, CAPTCHA automatizado, deudas, pagos propios ni documentos privados.
El asset incluye referencias publicas, no columnas de contacto/personal de PDFs.

## Siguiente paso
Revision visual del propietario. Continuar investigacion individual del directorio
antes de declararlo nacional completo. Despues de aprobacion: suite global,
contrato/CURRENT, aislamiento de patch respecto al WIP previo y CI del lote.
No se cierran deudas anteriores de rendimiento, APK, Fotomultas u otros modulos.
