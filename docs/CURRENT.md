# PicoRadar: estado vigente

Actualizado: 2026-10-21. Estado único para continuidad. Baseline, Arquitectura y contratos conservan su precedencia. Recuperar no cambia aprobaciones del producto.

## Punto de entrada

- Rama moderna: recovery/20261019-modern, repositorio sierraglobalcompany-rgb/PicoRadar. Confirmar HEAD remoto.
- Fuente: B07 administrativo ffe0cbd194310e004b20abd97fcd10e685c7df88.
- Cadena comprobada: original d26ba84 → integración owner 13190d0 → C11 2e8f2ed → coherencia e6406f2 → B06 c9dbaf1 → B07 ffe0cbd.
- Canónico: D:/Dev/PicoRadar sobre exFAT. Clon independiente: D:/Verification/PicoRadar.
- Originales C: preservados. No retomarlos como checkout activo ni restaurar desde el main histórico e9ef375.
- Gates, SHA, PR y NEXT: PicoRadar_RECOVERY_HANDOFF.md para el rescate y PicoRadar_STABILIZATION_HANDOFF.md para PR #72 y estabilización actual.
- El rescate de fuentes moderno sigue PARTIAL en los gates que constan en su handoff. La estabilización móvil PR #72 alcanzó FULL_MOBILE_QA_PASS local en SHA de código e5aeda06787eeec2e90fb6a7aa239a95516d6227: 3.253 PASS / 11 SKIP / 0 FAIL, exit 0. CI remota sigue bloqueada por cuota. Esto no equivale a aceptación física ni release.

## Producto conservado

| Área | Implementación / aceptación pendiente |
| --- | --- |
| Shell | Inicio · Garaje · Apps · Viaje · Conducir; Apps central; sin cuenta obligatoria |
| Inicio/C11 | Carrusel manual superior de cuatro campañas, borde a borde, flechas ligeras e indicadores; vehículo adaptable; sin banner inferior antiguo |
| Campañas B07 | Catálogo opcional versionado, validación, territorio/vigencia y fallback C11; publicidad comercial no activada |
| Garaje/documentos | Frente/reverso y reemplazo por lado/PDF; cifrado privado local; ciclo físico final pendiente |
| Mantenimiento | Historial, costos y búsqueda; recordatorios por vehículo con opt-in, OFF por defecto; callback serializado y ligado al vehículo original |
| Viaje/Conducir | Motores/datasets conservados; OSRM externo opcional; QA física y objetivo de rendimiento pendientes |
| B06 | Instalador local de primera instalación, locks, manifiesto y regresiones; hosting real no intervenido |
| B07 | Reglas por ciudad, importación JSON/CSV/XLSX, publicación/restauración selectiva, campañas, operadores y auditoría; sin despliegue |
| Cobertura | Datasets con vigencias y límites editoriales; el rescate no completa cobertura nacional |

Drift conserva schema v9 y pruebas de migración. El rescate no agrega tablas ni cambia datos del usuario; conserva las migraciones B07 existentes.

## Decisiones y pendientes

- Free 1.0 antes de monetizar. Lite/Completo/Pro siguen siendo planificación; ads, pagos, nube y WhatsApp OFF.
- Sin GPS continuo al servidor ni historial por defecto; documentos sin nube por defecto; sin scraping/CAPTCHA bypass de SIMIT/RUNT.
- Patrocinado no equivale a oficial/acreditado. Defensa no promete anulación de multas.
- Sin merge, despliegue ni acceso a Hostinger o Mi A3 durante el rescate.
- Instalación C11 histórica del 2026-09-19 y apertura confirmada del scanner no acreditan captura, autenticación, guardado y reapertura completos.
- Comparador B04 fe0d8d4 sigue fuera del runtime moderno y esta recuperado en GitHub como recovery/20261019-pending-b04. Variantes y fuentes QA históricas se preservan sin aplicarlas ciegamente.
- Planes GSD previos y docs/WORKSPACE_CONSOLIDATION.md son antecedentes; sus paths e instrucciones de limpieza no gobiernan el rescate.
- Handoffs funcionales: codex/; autoridad visual: docs/DESIGN_CONTRACT.md; operación: docs/SOP.md y guía B07.

Cobertura declarada al cierre de coherencia, sujeta a la fecha de cada fuente: Pico 73 municipios (6 verificados, 36 condicionales, 2 vencidos, 29 pendientes); fotomultas 360 registros; peajes 184 estaciones; trámites 769 autoridades. No equivale a operación nacional completa ni vigencia actual confirmada.

## Continuación exacta

**Integración completada (2026-10-21):** PR #72 fusionado mediante merge normal en `recovery/20261019-modern`, commit `9d7c1b3b863a72a43ef0e2820f3e51b5392c80bd`. Los diez commits se conservaron. El código que obtuvo `FULL_MOBILE_QA_PASS_LOCAL` es `e5aeda06787eeec2e90fb6a7aa239a95516d6227`: **3.253 PASS / 11 SKIP / 0 FAIL**, exit 0. El commit documental de PR #72 `99cbf0ce2d210d5c374c8a29b47f604a5bc30f7c` es ancestro del merge. No repetir esta suite para fuentes móviles idénticas.

**Estado de ramas:** PR #72 MERGED; PR #71 sigue abierto en borrador contra `main` histórico, que NO se fusionó ni se modificó. No declarar CI verde, QA física o publicación: Actions sigue bloqueado por cuota; instalación MariaDB B06/B07 y prueba de navegador tienen los bloqueos históricos del handoff de recuperación; QA Android física permanece pendiente.

**NEXT activo (2026-10-21):** `B04_CSV_KISS` está **especificado, no implementado**. Contrato y seguridad P0/P1 completos en [`codex/lots/B04_CSV_CAMERA_IMPORT.md`](../codex/lots/B04_CSV_CAMERA_IMPORT.md); CSV ficticio versionado en `server/tests/Fixtures/camera_csv_import_sample.csv`. Primero realizar preflight **no destructivo** del checkout local/WIP y confirmar HEAD/PR remoto; luego Codex puede desarrollar **un solo lote Laravel** en una rama desde recovery moderna, PR Draft hacia `recovery/20261019-modern`, QA local antes de considerar PASS. No usar `main` ni cherry-pick del B04 divergente. Prohibidos merge/deploy/Hostinger/teléfono/acciones de pago. El trabajo no está implementado ni publicado por esta actualización documental.

**QA y portabilidad:** GitHub ya conserva código/lockfiles/fixtures y hay evidencia **histórica** de clon limpio y build, no certificación clean-room actual de todos los flujos. CI moderna sin steps por bloqueo reportado, MariaDB B06/B07 y navegador Windows bloqueados; datos/secretos/firmas no deben subirse a Git. PR #71 sigue Draft hacia `main` histórico. Audio/Conducir #56 se reserva para un lote posterior. C11/Flutter inalterados.