# Estabilizacion de la version consolidada

Estado: pausado por solicitud del owner, 2026-09-15. Checkpoint WIP, no entrega aprobada.
Autorizacion explicita del owner: una base actual sin los
87 fallos conocidos. Base de consolidacion: ccd00bd. Rama: codex/stabilize-current-suite.

## Gates
1. Clasificar los 87 fallos reproducidos en artifacts/current/consolidation/full-tests.log.
2. Corregir causas, preservando disenos y contratos actuales. No skips nuevos,
   eliminacion de tests ni restauracion de pantallas antiguas para hacerlos pasar.
3. Probar grupos focalizados; ejecutar suite completa, analisis y build desde raiz.
4. Documentar resultado real y checkpoint. QA fisica no ejecutada no se declara aprobada.

## Grupos observados
- Composicion sync: importer tributario aprobado ausente en expectativa antigua (1).
- Arranque: fixtures no suministran path_provider para limpieza privada nueva (3).
- Launcher/Garaje/K7: rutas y textos previos, cobertura documental, overflow Servicios (8).
- Home/Pico: claves, calendario y fuentes cambiados en layouts aprobados (75).

No se continua la eliminacion externa ni se tocan otros proyectos. Pendientes
editoriales/fisicos quedan separados del gate automatizado, no marcados como terminados.

## Resultado al pausar
- Ultima regresion focalizada: 402 aprobadas / 15 fallidas, exit 1.
- Log: artifacts/current/consolidation/stabilization-regression-tests.log.
- Estos 15 NO son el resultado de una nueva suite completa: baseline global sigue
  siendo 2872 aprobadas / 11 omitidas existentes / 87 fallidas hasta repetirla.
- Arranque y composicion sync pasan tras corregir fixtures/expectativas.
- Cambios runtime limitados a altura minima de tarjeta Servicios y padding del
  selector de ciudad Pico. Resto: harness aislado de GPS nativo, fuentes reales y
  pruebas adaptadas a controles actuales sin retirar comprobaciones de seguridad.
- Pendientes focalizados: Home 8, Garaje 1, Apps 1, geometria Pico texto 2.0 4,
  matriz documental K7 1. No se introdujeron skips para ocultar estos errores.
- Formato, analisis, suite completa, build y QA del WIP pendientes.
- No APK nueva ni instalacion en esta estabilizacion. No procesos de prueba activos.

## Primeras verificaciones al retomar
1. Leer errores exactos del log. Home espera un asset generico incorrecto: comprobar
   _cityHeroVehicleAsset (actual Chevrolet) y alinear la expectativa, no el diseno.
2. Auditar Documents con vehicleId explicito inexistente: posible fallback silencioso
   al favorito. Mantener acceso personal y exigir eleccion vehicular explicita.
3. Resolver cuatro mediciones de texto 2.0 en City Pico sin recortar ni bajar fuentes.
4. Auditar callers nuevos de openExternal/callPhone antes de actualizar matriz K7;
   revisar manejo de errores en atribucion OSM de cda_map_view.dart.
5. Revisar CRLF/whitespace de fuentes de datos introducidas por ccd00bd sin alterar
   contenido original. Luego gates focalizados, globales, analisis y build secuencial.
