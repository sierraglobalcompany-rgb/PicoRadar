# PicoRadar: estado vigente

Actualizado: 2026-10-21. Estado único para continuidad. Baseline, Arquitectura y contratos conservan su precedencia. Recuperar no cambia aprobaciones del producto.

## Punto de entrada

- Rama moderna: recovery/20261019-modern, repositorio sierraglobalcompany-rgb/PicoRadar. Confirmar HEAD remoto.
- Fuente: B07 administrativo ffe0cbd194310e004b20abd97fcd10e685c7df88.
- Cadena comprobada: original d26ba84 → integración owner 13190d0 → C11 2e8f2ed → coherencia e6406f2 → B06 c9dbaf1 → B07 ffe0cbd.
- Checkout principal actual (reporte MIG-G1C): `D:/codex/PicoRadar` sobre NTFS, limpio en `recovery/20261019-modern` @ `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a` (tree `04a01f15475dd25fbcd40597120e6e44722b0504`). Clone/HEAD/tree/fsck fueron declarados PASS por Codex y los SHA remotos coinciden. Los viejos `D:/Dev/PicoRadar` y `D:/Verification/PicoRadar` son copias heredadas, no fuente canónica.
- Originales C: preservados. No retomarlos como checkout activo ni restaurar desde el main histórico e9ef375.
- Fuente de verdad para estado y NEXT: **este `docs/CURRENT.md`** (en este PR #74 Draft). `PicoRadar_RECOVERY_HANDOFF.md` y `PicoRadar_STABILIZATION_HANDOFF.md` conservan evidencia **histórica**, con rutas exFAT, fallos y NEXT anteriores; NO son instrucciones operativas actuales. El PR #72 ya está MERGED. Hasta integrar #74, el checkout principal en D: permanece en la documentación antigua de la rama moderna; `AGENTS.override.md` local fuera de Git señala esta diferencia.
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

**B04 (2026-10-21, independiente de la migración):** `B04_CSV_KISS` sigue en [`PR #75`](https://github.com/sierraglobalcompany-rgb/PicoRadar/pull/75), rama `feat/B04-csv-safe-parser` @ `f9abb8f7e6a768966d1e735ed8779466d51aa3ee`, Draft sin merge. Contrato en [`codex/lots/B04_CSV_CAMERA_IMPORT.md`](../codex/lots/B04_CSV_CAMERA_IMPORT.md) de PR #74 (también Draft). Codex reportó QA real local: Laravel 220 PASS/1 SKIP (436 avisos Dotenv), MariaDB 103 PASS, concurrencia M1–M7 y responsive 2.000 filas; no hay capturas exportadas ni mockup aprobado del administrador. CI #193 falló sin pasos/logs accesibles: **NO CI VERDE**. Pendiente propio de B04, **no NEXT de recuperación**: obtener CI observable cuando esté disponible y revisión humana; sin merge/deploy. No repetir el desarrollo ni integrar el viejo B04 divergente.

**Recuperación operativa C: → D: (G0/G1A/G1B/G1C; cierre G1 parcial, 2026-10-22):** inventario G0: 12 worktrees enlazados a C:; WIP G1A: 720 archivos / 451.590.665 bytes con manifiesto SHA-256 verificado; G1B: bundle de 196 ramas y 13 HEAD comprobado en bare autónomo; cierre posterior: cinco commits únicos de reflog guardados en bundle privado adicional y refs de recuperación. G1C: clon limpio GitHub en `D:/codex/PicoRadar` NTFS, rama moderna y SHA/tree citados arriba, fsck PASS. Son resultados de informes locales de Codex, **no pruebas de aplicación nuevas**. D: (USB) no equivale a un segundo respaldo externo independiente; el usuario administrará C: por separado, **no corresponde formatear ni limpiar C: en este proyecto**.

**Riesgo residual real:** 114.488 rutas ignoradas distribuidas en los worktrees históricos, mayoritariamente dependencias/cachés; el cierre detectó **por nombre solamente** dos posibles `.env`, seis posibles bases locales y 1.111 archivos `otros` (sin clasificación de utilidad ni contenido). Permanecen en C: y **NO** están acreditados como recuperables por G1A/G1B; no deducir por su nombre que son secretos ni que deben copiarse. El proyecto fuente/lockfiles está en D:, pero en el clon nuevo Flutter/Dart, `server/vendor`, `server/node_modules`, `.dart_tool` y extensiones PHP `pdo_sqlite`, `sqlite3`, `gd` faltan: runtime/QA `NOT_RUN`. GitHub CLI `gh` requiere autorización propia para recuperar el PBF OSRM opcional. El estado global/sesiones de Codex en C: es independiente y **NO MIGRADO**. Ninguna rama Draft está integrada.

**NEXT ÚNICO ACTIVO — RECUPERACIÓN (sin aplicar cambios):** inspección dirigida y **solo metadatos** de las dos posibles configuraciones `.env`, seis posibles bases locales y 1.111 elementos `otros` ignorados de C: para atribuirlos a PicoRadar, determinar si hay datos irremplazables y confirmar si ya cuentan con copia segura en D:. **No leer/exportar secretos ni DB, no copiarlos en claro, no mover estado global de Codex, no instalar SDK ni repetir QA general** en esa misma tarea. Entregar únicamente clasificación `NECESARIO / REGENERABLE / PRIVADO_REQUIERE_CIFRADO / DESCONOCIDO`, ruta de respaldo *si ya existe* y bloqueos. **Después de esa evidencia**, definir resguardo cifrado indispensable (si lo hubiera) y preparación dirigida de toolchain. Un nuevo worktree no es necesario para este control; conservar `D:/codex/PicoRadar` limpio.
