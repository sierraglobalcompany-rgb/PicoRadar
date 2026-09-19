# PicoRadar: estado vigente

Actualizado: 2026-09-19. Sustituye el diario de versiones intermedias anterior,
recuperable en Git (5958f42:docs/CURRENT.md). Baseline, Arquitectura, contratos
funcionales y DESIGN_CONTRACT conservan su precedencia. Consolidar carpetas
no modifica aprobaciones del producto.

## Base de trabajo unica
- Raiz: C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa.
- Rama local: codex/forensic-alerts; base auditada 82ce6b8.
- Estado: reparacion y Alertas implementadas, gates automaticos aprobados y APK
  nueva instalada. Aceptacion fisica en curso; sin merge ni publicacion.
- No trabajar en temp/VIAJE-R1-real-planner ni en B03/B04.
- Checkpoints y recuperacion: docs/WORKSPACE_CONSOLIDATION.md.
- GSD: .planning/.continue-here.md y .planning/HANDOFF.json.

## Version instalada
APK: artifacts/current/apk/PicoRadar-dev-release-scanner-fix-20260919.apk.
SHA256: A7ABC8D881E814DA68544DBD5472709F6A32F3A0C6C42070B2A957CBE66D21CD.
Build dev release con APP_ENV=dev, checkpoint ee7a734. Instalacion -r correcta en
Mi A3 API30 el 2026-09-19 a las 12:38:37 (Bogota); hash de base.apk identico.
Sin borrado de datos. Centro de Alertas y banner de Seguro capturados fisicamente.
El usuario confirmo que el escaner ya abre. Se corrigio la eliminacion por R8 del
constructor de CommonComponentRegistrar; un gate inspecciona ahora el DEX real.
Guardar/reabrir frente y reverso, autenticacion y alarmas siguen en comprobacion.
No continuar la limpieza durante este lote.

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
- Importacion, guardado/reapertura de captura y autenticacion positiva en Mi A3.
  Apertura del escaner confirmada por el usuario el 2026-09-19; no equivale a
  validar todo el ciclo documental. Tests no sustituyen esos gates.
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

Verificacion final automatica: 3196 pruebas moviles pasan, 10 omisiones
condicionales de simulacion; las 11 pruebas de esa suite pasan con su bandera.
Formato limpio (365 archivos), analisis limpio, 57 pruebas Android nativas y
493 de servidor (1993 assertions) pasan. Siete configuraciones reales de Seguro
verificadas; tres pruebas Python de fixtures/rutas pasan. Los 87 fallos historicos
no son deuda vigente. Handoff: codex/FORENSIC_ALERTS_HANDOFF.md.

## Invariantes
Sin cuenta obligatoria; Android primero; Inicio/Garaje/Apps/Viaje/Conducir con
Apps central. GPS sin historial por defecto ni envio continuo. Documentos sin
nube por defecto; no secretos en Git/APK. Demos no son patrocinio real ni leads.
Free 1.0 antes de monetizacion; sin pagos, reservas o PDF contractual nuevos.
No scraping/CAPTCHA de SIMIT/RUNT. Sin merge ni declaracion release-ready.
