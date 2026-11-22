# PicoRadar: estado vigente

Actualizado: 2026-11-22, America/Bogota. El estado operativo actual está arriba; el material previo se conserva como historial. Baseline, Arquitectura y contratos conservan su precedencia. Esta actualización no cambia aprobaciones del producto.

## Estado operativo — cierre C14 V2 2026-11-22

- Rama candidata: `feat/platform-integral-national-20261122`, basada en `b9309761b1f2dc9ca56505e84e3960d9686bee8b`. HEAD de código C14: `a764f9e56caed1aed49db4a572ca51799c9fea15` (tree `8c1128a1fe7d52898b3cb87dfa883a75f6faafdd`).
- Resultado de código: A/B/C `DONE_CODE`. A extiende el importador existente con propuestas territoriales DIVIPOLA revisables; analizar no crea jurisdicciones y confirmar resuelve/reutiliza o crea una jurisdicción deshabilitada con borrador parcial/off. B añade importación administrativa CSV/XLSX de proveedores mediante staging privado, revisión/selección y confirmación idempotente sólo a fichas `draft`; agrega una migración aditiva de lote y filas. C revalida en publicación la fuente exacta aprobada y vigente antes de cambiar release/puntero/manifiesto.
- Commits funcionales integrados: C `2fda6f7010120bc2098ea7232303b877daddc811`; A `debd65eafd24a370e5da122ec75c8c7598605a81`; refuerzo A `3415696970666cdbba521da4389126fdf95cd36b`; B `a764f9e56caed1aed49db4a572ca51799c9fea15`.
- QA local C14: `php -l` exit 0 en las 17 rutas cambiadas con extensión `.php`; `git diff --check b930976..HEAD` exit 0. Se escribieron 15 pruebas focales C14; 0 ejecutadas. PHPUnit `NOT_RUN_ENV` porque no existen `server/vendor/autoload.php` ni `server/vendor/bin/phpunit`. Flutter no aplica a este delta y no se ejecutó. Migración no aplicada; sin DB real, APK, dispositivo, publicación ni QA funcional acreditada.
- GitHub: push normal aceptado y `git ls-remote` confirma la rama autorizada en `a764f9e56caed1aed49db4a572ca51799c9fea15`. No se creó PR ni se tocó `main`, PR #88 o hosting. Checkout original preservado en `da9d8083bb21bd7c9863a319e07de51a5e692d09`, con la eliminación preexistente `scripts/tests/test_hostinger_installer_browser.ps1` como único estado reportado.
- Seguridad/decisión: datos de pruebas son sintéticos; no se afirma cobertura legal ni vigencia de fuentes nacionales. `LEGAL=NO_GO`, `RELEASE=NO_GO`, `MAIN_BRIDGE=HOLD`. Siguiente cuello de botella: ejecutar las 15 pruebas focales en entorno Laravel aislado cuando estén disponibles las dependencias fijadas; después validar fuentes y reglas con revisión jurídica humana. El SHA-256 acredita integridad, no firma criptográfica.

## Estado operativo — cierre C13 V2 2026-11-22

- Rama candidata: `feat/platform-integral-national-20261122`, basada en el HEAD remoto verificado de C12 `d4ef642db312cf6b8a5ee2e01634e2be8e13c849`; C12 conserva su base histórica `bc2c90743437a017a989adf9f00d38b1ca9459e7`.
- HEAD de código integrado antes de este commit documental: `7313a4c62231ba2c500ec0db87fb36a32b591c84`.
- Resultado: `DONE_CODE`. H1 `DONE_CODE`: toggle `consultationEnabled` por cobertura schema2 y par vehículo/servicio conectado desde edición/importación/revisión/publicación hasta parser, almacenamiento y evaluación Flutter; OFF produce `UNKNOWN`, preserva reglas y completitud. H2 `DONE_CODE`: `service_providers` tiene preview/diff, borrador, validación, publicación/rollback por el flujo único de releases y consumo Flutter SHA-256, último bueno y búsqueda offline; ficha aprobada no equivale a distribución. H3 `DONE_CODE`: suspensión temporal vencida permite una sesión OTP nueva; tokens revocados siguen revocados, ban permanente y entitlement Pro conservados.
- QA local: `php -l` PASS en 34 archivos PHP y `git -c core.whitespace=cr-at-eol diff --check` PASS. 22 casos focales nuevos/específicos escritos para C13; `TESTS_EXECUTED=0`. PHPUnit `NOT_RUN_ENV` por ausencia de `server/vendor/autoload.php` y ejecutable PHPUnit; Flutter/Dart `NOT_RUN_ENV` porque no están instalados. Sin migraciones, datos reales, APK ni QA física.
- Seguridad/producto: datasets y pruebas usan fixtures sintéticas; no se inspeccionó ni modificó una base real. SHA-256 acredita integridad, no firma criptográfica. Anuncios, pagos, servicios comerciales y GPS remoto permanecen fuera de este lote. Legal nacional `NO_GO`; falta validación jurídica/QA de fuentes reales. `RELEASE=NO_GO` y `MAIN_BRIDGE=HOLD`.
- GitHub/entorno: el cambio vive solo en `feat/platform-integral-national-20261122`; `main`, PR #88, Hostinger, Mi A3, otros dispositivos y datos reales quedan intactos. El push de esta rama es el único destino remoto permitido por C13; no crear PR ni hacer merge.
- Siguiente prioridad: ejecutar la batería focal cuando estén disponibles dependencias ya bloqueantes y obtener validación legal/runtime real antes de considerar cualquier release; no inferir cobertura jurídica nacional del catálogo técnico.

## Punto de entrada histórico — 2026-10-21

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

**NEXT:** elegir y delimitar un único lote nuevo desde el HEAD moderno, no desde `main`. `integration/VIAJE-R1-real-planner` (#55) y `codex/app-performance-kiss` (#64) son ancestros de la rama moderna y no deben reintegrarse. `fix/DRIVE-speed-audio-reliability` (#56) y `recovery/20261019-pending-b04` son divergentes: auditar cambios contra la implementación moderna, sin cherry-pick o merge ciego. Priorizar revisión del contrato funcional y evidencia antes de autorizar cualquier cambio. Conservar KISS, ley antirruido, antiparches y fidelidad UX/UI Pro; sin Hostinger, teléfono, release ni merges no previstos.
