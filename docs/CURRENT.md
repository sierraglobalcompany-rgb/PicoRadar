# PicoRadar: estado vigente

Actualizado: 2026-09-15. Sustituye el diario de versiones intermedias anterior,
recuperable en Git (5958f42:docs/CURRENT.md). Baseline, Arquitectura, contratos
funcionales y DESIGN_CONTRACT conservan su precedencia. Consolidar carpetas
no modifica aprobaciones del producto.

## Base de trabajo unica
- Raiz: C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa.
- Rama local: codex/workspace-consolidation; base vigente 5958f42.
- Estado: raiz consolidada y compilable; limpieza externa parcial, sin merge ni publicacion.
- No trabajar en temp/VIAJE-R1-real-planner ni en B03/B04.
- Checkpoints y recuperacion: docs/WORKSPACE_CONSOLIDATION.md.
- GSD: .planning/.continue-here.md y .planning/HANDOFF.json.

## Version instalada conservada
APK: artifacts/current/PicoRadar-installed-dev-release.apk.
SHA256: C8D5B1E2B374AC4517E410F77FD16C345F07D2B3AC20F500391F919646746C00.
La limpieza no reinstala, modifica ni borra datos del telefono.
El build de comprobacion desde la raiz no implica una nueva version aprobada.

## Funcionalidad y aceptacion
La base incluye las mejoras actuales de Inicio/Garaje/Pico, Viaje/Conducir,
Documentos, CDA, Servicios, Seguro y Compra/Venta. No recuperar layouts antiguos
ni activar cambios pendientes de otras ramas como parte de la limpieza.

- Preparar compra: seis revisiones sin candidato, autoridades independientes,
  borrador v4 y documentos privados por preparacion. Portada conservada.
  Ver codex/PURCHASE_FUNCTIONAL_HANDOFF_20260915.md y
  codex/PURCHASE_LAYOUT_HANDOFF_20260915.md.
- Drift vigente: schema v8. Propietario documental exclusivo driver/vehicle/
  preparation, cifrado y no-backup. Esta limpieza no migra datos.
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
- Suite global fresca desde raiz: 2872 passed / 11 skipped / 87 failed. No hay
  nombres de fallos nuevos respecto al baseline; la expectativa K7 ya corregida
  desaparece. Los 87 fallos anteriores siguen abiertos, no es una suite verde.
- Cobertura editorial, rendimiento y QA fisica de lotes previos siguen sujetos
  a sus contratos. No abrir esos trabajos automaticamente.

## Verificacion de la consolidacion
Desde la raiz: flutter analyze --no-pub limpio; 625 tests focalizados passed;
flutter build apk --flavor dev --release --no-pub correcto (100.7 MB).
Logs: artifacts/current/consolidation. Runtime, assets y configuracion movil
identicos al checkpoint instalado. Sin dependencias nuevas.

APK reconstruido: mobile/build/app/outputs/flutter-apk/app-dev-release.apk.
SHA256: 362608E545676E67A8BC3AAA33407E7846158E356D7AD3665942EFE76C99CBFF.
No instalado durante la consolidacion. Detalles, limites de limpieza y pendientes
reabribles en docs/WORKSPACE_CONSOLIDATION.md y .planning/PENDING.md.

## Invariantes
Sin cuenta obligatoria; Android primero; Inicio/Garaje/Apps/Viaje/Conducir con
Apps central. GPS sin historial por defecto ni envio continuo. Documentos sin
nube por defecto; no secretos en Git/APK. Demos no son patrocinio real ni leads.
Free 1.0 antes de monetizacion; sin pagos, reservas o PDF contractual nuevos.
No scraping/CAPTCHA de SIMIT/RUNT. Sin merge ni declaracion release-ready.
