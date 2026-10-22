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

**Riesgo residual actualizado por G2B (2026-10-22):** informe local metadatos-only: 114.488 ocurrencias ignoradas en 13 worktrees y 15.510.169.892 bytes acumulados **sin deduplicar**. Categorías: 73.799 dependencias, 39.647 build/caché, 5 IDE, 2 `.env` (1.414 B), 6 SQLite (2.158.592 B), 87 `data/local` / `.local` sin SQLite (469.188.829 B), 30 `server/storage` exclusivas (1.055 B), 880 otros (486.223.072 B) y 32 falsos positivos de nombre database sin atribución final (80.120 B). **No existe correspondencia SHA fuente→respaldo demostrada para los 2 `.env` ni 6 SQLite ni los datos ignorados potencialmente únicos**; ausencia de coincidencias en manifiestos NO demuestra ausencia de otras copias. G1A/G1B no sustituyen este resguardo. Cuatro APK ignorados y un PBF de 329.060.219 B permanecen de identidad no verificada; `data/sources/osrm/source.json` versionado conserva un SHA esperado para este último, pero igual tamaño no demuestra identidad. El filtro G2B leyó por error por líneas ocho Markdown y un ZIP de respaldos (sin extracción, salida ni escritura reportada); **desviación registrada, G2B PARTIAL, no repetir ese filtro**. Además G2B reportó **una eliminación rastreada preexistente en D:** con ruta omitida; diverge del estado clean de G1C y requiere verificar qué archivo es y si intervino protección de Windows, **sin restaurarlo automáticamente**. El HEAD y tree no cambiaron. Flutter/Dart y dependencias/extensiones PHP faltan: pruebas runtime `NOT_RUN`; las sesiones globales de Codex en C: son un tema distinto, no migrado.

**G2C — control de cifrado del volumen BLOCKED (2026-10-22):** Codex reportó denegación de consulta administrativa de D:; `RECOVERY_KEY_EXTERNAL=NO_VERIFICADO`, `HASH_CHECK=NOT_RUN`, `SQLITE_CONSISTENCY=NOT_VERIFIED`. **No se copiaron** los 2 `.env`, 6 SQLite, ni candidatos locales/privados. C: y GitHub sin cambios. Una comprobación BitLocker denegada **no demuestra** que el disco carezca de protección ni que sea necesario elevar privilegios. Vía alternativa **a verificar**, sin elevar privilegios: archivo de respaldo cifrado de formato 7z (AES-256 + cabeceras/nombres cifrados), contraseña solicitada solo interactivamente y conservada por el usuario fuera de C:/D:; jamás contraseña en chat, argumentos de comando, scripts o registros. No confundir copia cifrada en D: con una copia en otro medio independiente.

**NEXT ÚNICO ACTIVO — RECUPERACIÓN:** verificar de manera focalizada si existe una herramienta ya instalada para crear y verificar **un único resguardo cifrado recuperable** de los candidatos irremplazables. **Solo si** puede pedirse la contraseña sin exposición, el usuario conserva recuperación independiente y la integridad se comprueba, copiar directamente fuentes estáticas a un nuevo archivo cifrado privado fuera del repositorio Git. No crear temporales de datos privados sin cifrar en D:. Para las seis SQLite, exigir origen sin uso/cambios y journaling coherente, o la API oficial de copia online con staging seguro; de lo contrario dejar solo esas bases `BLOCKED`, nunca declararlas protegidas tras una simple copia no consistente. No suponer redundancia de los 87 locales/30 storage/880 otros/APK/PBF por tamaño; conservar candidatos únicos o registrar excluidos solo con evidencia. Leer por separado `git status --porcelain=v1 -uall` para identificar la **eliminación rastreada preexistente en D:**, sin restaurarla, borrarla ni convertirla en cambio de código. No editar C:, git, PRs adicionales, producción, estado global Codex, ni reinstalar herramientas en esa fase. Sin procedimiento de cifrado seguro, `BLOCKED` y STOP; no solicitar privilegios administrativos ni mover secretos en claro. **La migración no incluye formateo ni limpieza de C:**; el usuario lo decidirá por separado.