# Pendientes vigentes en reposo

Esta lista no inicia trabajos ni los declara terminados. Cerrar una carpeta o
proceso solo cambia la organizacion local. Autoridad actual: docs/CURRENT.md.

| Pendiente | Evidencia / recuperacion | Condicion para retomar |
| --- | --- | --- |
| Compra y billetera: importacion fisica, escaner, autenticacion positiva | codex/PURCHASE_FUNCTIONAL_HANDOFF_20260915.md; quick/purchase-functional-20260915/STATE.md | Usuario disponible, documentos ficticios, sin desactivar FLAG_SECURE |
| Reparacion forense y Alertas en ejecucion | FORENSIC_REPAIR.md; base 82ce6b8, 2959 pass / 11 skip, sin los 87 fallos historicos | Verificar nuevos cambios y gates fisicos; no confundir baseline verde con reparacion fisica |
| Rendimiento Conducir | CONDUCIR_OWNER_CONSOLIDATED.md; artifacts/current/driving; artifacts/current/performance | Repetir perfil fisico y comparar objetivo, no inferirlo de tests |
| Canales de seguros y autoridades pendientes | codex/PURCHASE_DIRECTORY_AUDIT_20260915.md y auditorias C13/C24 | Fuente oficial por entidad; no inventar canales |
| B04 comparador | fe0d8d4, codex/pending-B04-before-consolidation | Comparar dependencias con raiz antes de integrar |
| WIP R03 anterior de raiz | b86c787 | Comparar; no sustituir UI vigente por version anterior |
| Herramientas QA auxiliares | af7df94, codex/pending-qa-sources-before-cleanup; 6fc47b5, codex/pending-root-qa-before-cleanup | Recuperar solo archivos necesarios, corregir rutas y revisar datos privados |
| Clasificacion final de originales/mockups externos | docs/WORKSPACE_CONSOLIDATION.md | No borrar originales unicos por antiguedad o nombre |

Los checkpoints intermedios retirados de .planning estan en 5958f42. No son un
estado vigente de ejecucion ni deben recrearse como carpetas historicas.
Configuraciones locales y datos privados pendientes: .local/pending-server,
.local/pending-qa y .local/device-qa. Excluidos de Git; nunca publicarlos.
