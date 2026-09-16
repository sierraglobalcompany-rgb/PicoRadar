# Checkpoint: Mi Pico y Placa mensual

Fecha: 2026-09-11 13:45 America/Bogota.
Estado: PAUSADO POR SOLICITUD DEL USUARIO. No continuar hasta nueva instruccion.
Repo: C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa/temp/VIAJE-R1-real-planner
Branch: codex/garage-single-favorite
HEAD: ddf60407174e3ee8d447b7eff3ca45e0fd983789

## Punto exacto
El usuario aprobo con PLEASE IMPLEMENT el plan "Mi Pico y Placa: vehiculo protagonista y calendario mensual claro" y luego pidio "crea un checkpoint y para".
Auditoria y plan completos. Implementacion nueva NO iniciada: ningun cambio de produccion, test, asset o APK en este lote.
Se leyeron skills executing-plans/TDD y se intentaba delegar pruebas. Spawn fallo antes de crear agente: full-history fork no admite agent_type explicito. No hay agente ni proceso ejecutandose. Al reanudar, omitir agent_type con fork_context=true o usar contexto no heredado.
No commit, stage, push, PR ni merge nuevos.

## Plan aprobado (autoridad para reanudar)
- Solo Mi pico y placa del vehiculo especifico; NO redisenar Inicio, Garaje, Detalle, Pico por ciudad o Conducir.
- Un scroll vertical con barra inferior fija. El usuario eligio expresamente scroll unico frente a dos vistas.
- Cabecera navy con regreso y titulo unico. Retirar marca/avatar/notificaciones de esta pantalla.
- Fondo adjunto local e ilustrativo, sin representar GPS ni variar por ciudad consultada. Asset vehiculo completo, dominante, no deformado.
- Nombre centrado arriba: apodo, marca/modelo, Mi vehiculo. Placa aprobada debajo, NO sobre carroceria, compactWidth=112 solo aqui.
- Cambiar ciudad con pin a derecha en fila separada. Consulta temporal, sin cambiar ciudad global/GPS/favorito.
- Reusar TodayRestrictionSummary sin cambiar Inicio: horario una vez, contador y reloj existente, ciudad; todos estados conservados. No onTap hacia otra copia de Pico.
- Quitar textos independientes Hoy/fecha y motivo bajo resumen. Motivo comprobable en detalle del dia.
- Mes directo, sin Proximos dias/Mes ni tarjetas horizontales personales. Flechas mes/anio; Lun Mar Mie Jue Vie Sab Dom con acentos correctos.
- 7 columnas: check verde, prohibicion roja con menos, interrogante ambar; numero/simbolo separados. Hoy borde navy. Fuera de mes casillas neutras sin interaccion.
- Leyenda Libre / Restriccion / Por verificar. Dia abre hoja fecha/estado/horarios/motivo, preserva mes/scroll/resumen de hoy al cerrar.
- Motor y vigencias intactos. No extrapolar cobertura ni interpretar revision dataset como fecha de cambio legal.
- Proxima restriccion desde manana hasta30dias; si hay dias desconocidos antes, Proxima restriccion conocida. Sin resultado, Por verificar o Sin restricciones en los proximos30dias segun cobertura real.
- Fuente y vigencia abre hoja, no ExpansionTile. Todas fuentes disponibles, ultima verificacion, vigencia normativa y revision datos separadas. Enlace solo accion expresa, fallo visible/reintento, no inventar vigencia.
- Sin nuevas dependencias/APIs/preferencias/tablas/motor. Mes cacheado, reloj minuto no consulta DB/red/GPS ni recalcula mes. Fondo con cacheWidth y fallback neutro.
- Texto ampliado reorganiza/aumenta altura, sin FittedBox/recortes/scroll horizontal. Targets48dp; calendario margen reducido en360 para siete targets completos.
- Validar360x780,390x844,412x915,430x932 texto1/1.5/2; meses4/5/6filas; estados, multipleshorarios, medianoche, vencimiento, regreso, consultas Medellin/Bogota/Manizales sin cambio global.
- Preview: analisis/tests focales/build con simulacion, instalar conservando datos, comparar capturas. ESPERAR aprobacion visual antes suite completa/publicacion/CI.
- Sin merge. Separar WIP previo y sus deudas antes de publicacion.

## Evidencia y referencias
Mockup:
C:/Users/felip/AppData/Local/Temp/codex-clipboard-5083e241-f093-47fe-b838-a3a48f0cfe9b.png
Fondo:
C:/Users/felip/AppData/Local/Temp/codex-clipboard-f79fb5d9-617f-47e8-9e9e-7cb51fa83b65.png
Capturas fisicas NUEVAS de auditoria (no resultado implementado):
- temp/PICO_MONTH_AUDIT_TOP_20260911.png
- temp/PICO_MONTH_AUDIT_MONTH_20260911.png
- temp/PICO_MONTH_AUDIT_SOURCE_20260911.png
TOP fue inicialmente una captura accidental de Inicio por uso concurrente del telefono; luego se RECAPTURO correctamente Mi Pico BOG127. Archivo actual validado visualmente.
Usuario dejo telefono libre tras pregunta; ultima pantalla observada calendario/fuente personal BOG127. No se modificaron datos/ciudades/favorito.
Mi A3 116f2191b19a conectado. APK anterior dev debug SIMULATION sigue instalada; este lote no hizo build/install.
Ultimo hash verificado en lote Detalle (no revalidado ahora): 531483824A5752607D2F78EB85F658556D22DE786F09BAF101FB8E78C90E8617.

## Auditoria concreta / rutas de trabajo
mobile/lib/features/pico_placa/presentation/pico_detail_screen.dart:
- _PersonalPicoViewState tiene cobertura cacheada por ciudad/tipo/dia/expiry y evaluaciones diarias. bogotaDateProvider alimenta fecha; resumen escucha bogotaNowProvider.
- _PersonalPicoHeader aun muestra marca/avatar/alertas y titulo por separado.
- _PersonalHero actual imagen108dp lateral + identidad; placa96dp.
- _PersonalCalendar modo inicial nextDays; eliminar modo/rama personal, no tocar _WeekSchedule de ciudad.
- _MonthCalendar existente GridView shrinkWrap NeverScrollable; conservar cache y navegacion. _MonthWeekdayHeader usa L M X J V S D.
- _MonthDayCell dibuja puntos7/9dp sin simbolos; no hay leyenda.
- _PersonalSourceDetails es ExpansionTile con primerlink https solamente.
- _nextRestriction retorna primera fecha restringida desde1a30, sin conservar huecos desconocidos.
- _showMonthDayDetail existente muestra base generica; incorporar motivo comprobable existente.
mobile/lib/features/pico_placa/presentation/today_restriction_summary.dart: compartido aprobado; no redisenar.
mobile/lib/features/garage/presentation/vehicle_plate_badge.dart: ya admite compactWidth=96 por defecto; pasar112 localmente.
mobile/test/features/pico_placa/presentation/pico_detail_screen_test.dart:
- primeras pruebas esperan Proximos dias/Mes, motivo exterior, identidad lateral y fuente expandible: actualizar SOLO expectativas personales al nuevo contrato.
- preservar cobertura city/clock/expiry/navigation. Helpers _pumpCityPico, _WeeklyRestrictionStore; fuentes reales tests en plate_test_fonts.dart.
- medir posiciones y targets, no solo presencia.
Graphify graphify-out/GRAPH_REPORT.md historico regex137Dart/5122nodos; consultado y contrastado con codigo. No se actualizo ni se considero prueba semantica.

## Estado anterior que NO se debe perder
Worktree mixto con cambios previos de rendimiento, Inicio/placas, Mi Pico, Garaje favorito y Detalle. git status completo medido en HANDOFF.json; NO commitear todo como nuevo redisenio.
Inicio aprobado visualmente. Detalle tambien aprobado cuando usuario dijo "que te falta, veo todo bien"; sus docs aun dicen pendiente, actualizar al cerrar ese lote aparte.
Version personal anterior NO aceptada para este nuevo mockup. No usar sus tests/capturas como validacion nueva.
Rendimiento, auditoria de peso, cierres tecnicos/suite/PRs previos siguen separados.

## Reanudacion
1. Esperar permiso para continuar; ahora parar.
2. Releer este checkpoint, AGENTS/baselines/contrato y git status sin revertir WIP.
3. Escribir test monthly-first y observar fallo real antes de produccion; no se ha escrito aun.
4. Implementar widgets personales, asset local y fuente; actualizar pruebas bajo disjoint ownership si hay agentes.
5. Ejecutar gates focales secuencialmente; QA fisica, preview con simulacion, pedir aprobacion visual. No publicar ni cerrar prematuramente.

Flutter: C:/Users/felip/.codex/tooling/flutter_3.47.1/flutter/bin/flutter.bat
Paquete: co.picoradar.app.dev. No borrar datos ni desinstalar.
