# PicoRadar: estado vigente

Actualizado: 2026-09-19. Sustituye el diario de versiones intermedias anterior,
recuperable en Git (5958f42:docs/CURRENT.md). Baseline, Arquitectura, contratos
funcionales y DESIGN_CONTRACT conservan su precedencia. Consolidar carpetas
no modifica aprobaciones del producto.

## Base de trabajo unica
- Raiz: C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa.
- Rama local: codex/forensic-alerts; base auditada 82ce6b8.
- Estado: reparacion forense y Alertas en ejecucion; sin merge ni publicacion.
- No trabajar en temp/VIAJE-R1-real-planner ni en B03/B04.
- Checkpoints y recuperacion: docs/WORKSPACE_CONSOLIDATION.md.
- GSD: .planning/.continue-here.md y .planning/HANDOFF.json.

## Version instalada conservada
APK: artifacts/current/apk/PicoRadar-dev-release-stabilized-20260915-235843.apk.
SHA256: 53C7195D361F9DF984E63462EE2EB0533F14E5EF4316A7B3EBF788D4A56634C5.
Esta es la instalacion previa a la reparacion; un build nuevo no implica aprobacion
fisica. No borrar datos del telefono ni continuar la limpieza durante este lote.

## Funcionalidad y aceptacion
La base incluye las mejoras actuales de Inicio/Garaje/Pico, Viaje/Conducir,
Documentos, CDA, Servicios, Seguro y Compra/Venta. No recuperar layouts antiguos
ni activar cambios pendientes de otras ramas como parte de la limpieza.

- Preparar compra: seis revisiones sin candidato, autoridades independientes,
  borrador v4 y documentos privados por preparacion. Portada conservada.
  Ver codex/PURCHASE_FUNCTIONAL_HANDOFF_20260915.md y
  codex/PURCHASE_LAYOUT_HANDOFF_20260915.md.
- Drift instalado: schema v8. En desarrollo: v9 agrega ajustes de alertas por
  vehiculo/categoria. Propietario documental exclusivo driver/vehicle/preparation,
  cifrado y no-backup conservados. La migracion debe verificarse antes de instalar.
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
- Importacion, escaner y autenticacion positiva documentales en Mi A3, y
  aceptacion del propietario. Tests automatizados no sustituyen estos gates.
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

## Invariantes
Sin cuenta obligatoria; Android primero; Inicio/Garaje/Apps/Viaje/Conducir con
Apps central. GPS sin historial por defecto ni envio continuo. Documentos sin
nube por defecto; no secretos en Git/APK. Demos no son patrocinio real ni leads.
Free 1.0 antes de monetizacion; sin pagos, reservas o PDF contractual nuevos.
No scraping/CAPTCHA de SIMIT/RUNT. Sin merge ni declaracion release-ready.
