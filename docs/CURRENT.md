# PicoRadar: estado vigente

Actualizado: 2026-09-19. Sustituye el diario de versiones intermedias anterior,
recuperable en Git (5958f42:docs/CURRENT.md). Baseline, Arquitectura, contratos
funcionales y DESIGN_CONTRACT conservan su precedencia. Consolidar carpetas
no modifica aprobaciones del producto.

## Base de trabajo unica
- Raiz: C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa.
- Rama local: codex/owner-improvements-integration; base d26ba84.
- HEAD de codigo integrado: 9c256a5.
- Estado: mejoras del propietario integradas, gates automaticos aprobados y APK
  nueva instalada. Aceptacion fisica documental en curso; sin merge ni publicacion.
- No trabajar en temp/VIAJE-R1-real-planner ni en B03/B04.
- Checkpoints y recuperacion: docs/WORKSPACE_CONSOLIDATION.md.
- GSD: .planning/.continue-here.md y .planning/HANDOFF.json.

## Version instalada
APK: artifacts/current/apk/PicoRadar-dev-release-owner-improvements-20260919.apk.
SHA256: 703CF65F0852DBEC237B4FA399083BB44BB263E252F1DBFF686676CEB53E0116.
Build dev release con APP_ENV=dev. Instalacion -r correcta en Mi A3 API30 el
2026-09-19 a las 15:30:15 (Bogota), sin borrar datos. El usuario ya habia
confirmado que el escaner ML Kit abre. La captura guiada frente/reverso esta
implementada y cubierta por pruebas; su ciclo fisico final con tarjeta ficticia
sigue pendiente de confirmacion.
No continuar la limpieza durante este lote.

## Mejoras del propietario integradas
- Conducir: Atrás confirma el cierre de una sesion activa y vuelve a Inicio;
  GPS abre diagnostico y recuperacion, Voz es alternable y persistente, y el
  velocimetro usa escala visual de 160 km/h sin ocultar velocidades superiores.
- Documentos: Cedula, Licencia de conduccion y Licencia de transito admiten
  frente y reverso, guardado de solo frente y reemplazo atomico por lado o PDF.
- Apps/Mas: se conserva el origen al volver. Talleres incorpora selector de
  vehiculo, proximos/vencidos, historial, costos, busqueda GPS/ciudad y
  recordatorios honestos por fecha o kilometraje actualizado.
- Inicio: carrusel manual superior de cuatro campanas locales, borde a borde en
  telefonos y sin mostrar la lamina siguiente. La navegacion vive dentro de la
  imagen mediante flechas y cuatro indicadores; no hay contador visible ni el
  antiguo banner inferior. Tres campanas son demos y la cuarta invita a ser
  aliado. El formulario real permanece cerrado hasta cumplir HTTPS, privacidad
  versionada y bandeja administrativa.
- Tramites y cobertura: catalogos versionados con estado y evidencia. No se
  presenta como nacional lo pendiente o vencido.

## Funcionalidad y aceptacion
La base incluye las mejoras actuales de Inicio/Garaje/Pico, Viaje/Conducir,
Documentos, CDA, Servicios, Seguro y Compra/Venta. No recuperar layouts antiguos
ni activar cambios pendientes de otras ramas como parte de la limpieza.

- Preparar compra: seis revisiones sin candidato, autoridades independientes,
  borrador v4 y documentos privados por preparacion. Portada conservada.
  Ver codex/PURCHASE_FUNCTIONAL_HANDOFF_20260915.md y
  codex/PURCHASE_LAYOUT_HANDOFF_20260915.md.
- Drift de la APK instalada: schema v9, agrega ajustes de alertas por
  vehiculo/categoria. Propietario documental exclusivo driver/vehicle/preparation,
  cifrado y no-backup conservados. Migracion aditiva 8 a 9 y conservacion de datos
  cubiertas en la suite; la app instalada abre con los vehiculos existentes.
- Documentos: reglas y pendientes en codex/C15_DOCUMENTS_OWNER_HANDOFF.md y
  codex/C15_DOCUMENTS_COMPACT_HANDOFF.md; sin fallback externo inseguro.
- Seguro: canales con evidencia y limites; ver
  codex/C13_INSURANCE_POLICY_HANDOFF.md y codex/C13_INSURANCE_DIRECTORY_AUDIT.md.
- CDA: universo operativo aprobado de 866; historico RUNT de 964 conservado.
  Geocodificacion aproximada no equivale a sede confirmada fisicamente.
  Ver codex/C24_CDA_OWNER_HANDOFF.md y codex/C24_CDA_GEODATA_AUDIT.md.
- Directorios: cobertura y pendientes en
  codex/PURCHASE_DIRECTORY_AUDIT_20260915.md; no inventar canales.
- Conducir: .planning/CONDUCIR_OWNER_CONSOLIDATED.md y
  artifacts/current/driving/INFORME_OWNER_CONSOLIDADO.md. El ultimo perfil
  documentado no alcanzo el objetivo de 95%; no cerrado por esta limpieza.
- Viaje: piloto OSRM local detenido. Entradas en data/local/osrm y procedencia
  en data/sources/osrm/source.json. No cambiar contratos de proveedor.

## Pendientes en reposo
- Completar en Mi A3 el ciclo fisico frente/reverso con tarjeta ficticia,
  autenticacion, guardado y reapertura. La apertura del escaner fue confirmada;
  tests no sustituyen este gate fisico.
- B04 comparador: fe0d8d4, codex/pending-B04-before-consolidation. No incorporado.
- Auditoria fresca de 82ce6b8: 2959 pruebas moviles pasan, 11 omitidas; analisis
  limpio. Las 87 fallas historicas ya no se reproducen. Simulacion Conducir:
  11 pasan al habilitarla. Servidor: 493 pasan / 1993 assertions con SQLite
  habilitado solo en el proceso de pruebas. Esto no certifica cambios posteriores.
- Cobertura editorial, rendimiento y QA fisica de lotes previos siguen sujetos
  a sus contratos. No abrir esos trabajos automaticamente.

## Verificacion historica de la consolidacion
Desde la raiz: flutter analyze --no-pub limpio; 625 tests focalizados passed;
flutter build apk --flavor dev --release --no-pub correcto (100.7 MB).
Logs: artifacts/current/consolidation. Runtime, assets y configuracion movil
identicos al checkpoint instalado. Sin dependencias nuevas.

APK reconstruido: mobile/build/app/outputs/flutter-apk/app-dev-release.apk.
SHA256: 362608E545676E67A8BC3AAA33407E7846158E356D7AD3665942EFE76C99CBFF.
No instalado durante la consolidacion. Detalles, limites de limpieza y pendientes
reabribles en docs/WORKSPACE_CONSOLIDATION.md y .planning/PENDING.md.

## Reparacion activa
Plan, hallazgos y gates en .planning/FORENSIC_REPAIR.md. Ampliacion de Alertas
documentada en docs/ADR_ALERTS_ANDROID.md. Las reparaciones llevan checkpoints
por alcance. No se cierran escaneo, autenticacion ni alarmas por pruebas unitarias.
La APK dev nueva debe incluir APP_ENV=dev para mostrar Seguro demostrativo;
produccion mantiene la promocion oculta. No alterar vigencia editorial de datasets.

Verificacion final de la integracion: formato limpio (381 archivos), analisis
limpio, 3238 pruebas moviles pasan y 10 quedan omitidas por condiciones de
plataforma/simulacion. Las pruebas Android nativas pasan (224 tareas Gradle).
Servidor: 503 pruebas y 2373 assertions pasan con SQLite habilitado solo para el
proceso. El validador nacional pasa. Los 87 fallos historicos no se reproducen.
Handoff principal: codex/OWNER_IMPROVEMENTS_INTEGRATION_HANDOFF.md.

Cobertura vigente declarada: Pico y placa contiene 73 municipios (6 verificados,
36 condicionales, 2 vencidos y 29 pendientes); solo cinco paquetes afirmativos
existentes estan habilitados en motor. Fotomultas contiene 360 registros, 67 sin
velocidad y 13 departamentos/unidades territoriales. Peajes contiene 184
estaciones y no publica tarifas no comprobadas. Tramites contiene 769 autoridades
y 1003 filas fuente; solo Bogota y Medellin tienen enlaces directos verificados,
con 767 entradas pendientes. Estos conteos no equivalen a cobertura nacional
completa ni a operacion actual confirmada.

## Invariantes
Sin cuenta obligatoria; Android primero; Inicio/Garaje/Apps/Viaje/Conducir con
Apps central. GPS sin historial por defecto ni envio continuo. Documentos sin
nube por defecto; no secretos en Git/APK. Demos no son patrocinio real ni leads.
Free 1.0 antes de monetizacion; sin pagos, reservas o PDF contractual nuevos.
No scraping/CAPTCHA de SIMIT/RUNT. Sin merge ni declaracion release-ready.
