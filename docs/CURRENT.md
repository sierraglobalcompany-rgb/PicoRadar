# PicoRadar: estado vigente

Actualizado: 2026-10-20. Estado único para continuidad. Baseline, Arquitectura y contratos conservan su precedencia. Recuperar no cambia aprobaciones del producto.

## Punto de entrada

- Rama moderna: `recovery/20261019-modern`, repositorio `sierraglobalcompany-rgb/PicoRadar`. Confirmar HEAD remoto.
- Fuente: B07 administrativo `ffe0cbd194310e004b20abd97fcd10e685c7df88`.
- Cadena comprobada: original `d26ba84` → integración owner `13190d0` → C11 `2e8f2ed` → coherencia `e6406f2` → B06 `c9dbaf1` → B07 `ffe0cbd`.
- Canónico: `D:/Dev/PicoRadar` sobre exFAT. Clon independiente: `D:/Verification/PicoRadar`.
- Originales C: preservados. No retomarlos como checkout activo ni restaurar desde el main histórico `e9ef375`.
- Gates, SHA, PR y NEXT: `PicoRadar_RECOVERY_HANDOFF.md`. Las pruebas históricas no certifican el HEAD recuperado.
- Rescate **PARTIAL**: fuente moderna publicada, APK dev, servidor e instalable B07 reconstruidos desde GitHub; verificador del paquete PASS con exit0; suite móvil aún fallida, instalador MariaDB bloqueado por enlaces públicos en Windows/exFAT, CI bloqueada por facturación y test de navegador bloqueado por archivo denegado en Windows. No equivale a release ni QA física aprobadas.

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
- Comparador B04 `fe0d8d4` sigue fuera del runtime moderno y esta recuperado en GitHub como `recovery/20261019-pending-b04`. Variantes y fuentes QA históricas se preservan sin aplicarlas ciegamente.
- Planes GSD previos y `docs/WORKSPACE_CONSOLIDATION.md` son antecedentes; sus paths e instrucciones de limpieza no gobiernan el rescate.
- Handoffs funcionales: `codex/`; autoridad visual: `docs/DESIGN_CONTRACT.md`; operación: `docs/SOP.md` y guía B07.

Cobertura declarada al cierre de coherencia, sujeta a la fecha de cada fuente: Pico 73 municipios (6 verificados, 36 condicionales, 2 vencidos, 29 pendientes); fotomultas 360 registros; peajes 184 estaciones; trámites 769 autoridades. No equivale a operación nacional completa ni vigencia actual confirmada.

## Continuación exacta

Seguir el campo NEXT del handoff de recuperación. Cerrar primero sus gaps de reconstrucción; no abrir funcionalidades ni QA física automáticamente. Todo lote futuro debe leer su contrato.
