# C33 V2 — handoff final

Fecha de ejecución: 2026-11-26 (America/Bogota); el identificador del lote sigue la fecha UTC 2026-11-27 del prompt. Estado general: PARTIAL; MAIN_BRIDGE=HOLD, LEGAL=NO_GO, RELEASE=NO_GO.

## Identidad y alcance

- Integrador: D:\codex\_build\PicoRadar-C33-V2\repo, rama codex/c33-v2, base 04a64f5ef5a344e39f2fc28790feb6baadecf5ad. HEAD_CODE=e698a02 antes del commit documental; el SHA completo y HEAD_FINAL quedan en el retorno único.
- Candidatos separados: A codex/c33-a, commit funcional bf5b2985554db85b32bbadd7cc331ad64335fa18; B codex/c33-b, commits 73fa5e7c0d3628868750b53fa13ba29a25fe8485, c8d8a9f y 621b102a527887fe34baf91dd849f46dcd9a9ca6. Integración local lineal de A/B y guard final: 3a23b03, 51fd732, a68c801, e698a02. No hubo merge, PR, merge a main, despliegue ni release. El estado final del remoto autorizado se consigna en GITHUB_STATE.md del retorno.
- C31 fuente permaneció en 71c61ca1a591fdbe571ec771e95c769969951547; integrador C32 preservado en 04a64f5ef5a344e39f2fc28790feb6baadecf5ad. Sin cambios en checkouts originales.
- Cambios de código limitados a operador QA local y herramientas QA MariaDB/panel. No hubo cambios en server/, mobile/lib/, normas, API, motor, dependencias, esquema o configuración global.

## A — OTA viva de C31

| Gate | Estado | Evidencia |
|---|---|---|
| Recuperación del operador | PASS | PID y listener ausentes comprobados; marker archivado byte por byte, 353 bytes, SHA-256 bbf90d7f938125ac2b1637a1568d3095b2ea275a80f0873a8f37bb6442b0e910; slot y DB no alterados. |
| GET manifest | PASS | HTTP 200, 424 bytes, SHA-256 103bf15d43ee2d54ffd06a3b0a8685bfcd43f74f57c82162c8aa6454ed6fddc8. |
| GET payload | PASS | HTTP 200, 941 bytes, SHA-256 a2cd478f2204a51ae1d80a045d70c56a55c54b5cd66b64881590da379e6b620a. |
| TLS | PASS | Certificado local validado para serverAuth, SAN 127.0.0.1, cadena y vigencia; sin trust global ni bypass. |
| Dart live | PARTIAL | El caso real alcanzó upstream, relay, sync y UNKNOWN; el test focal de allowlist pasó. El comando completo flutter test terminó con un caso negativo cuyo fixture esperaba conservar %6d; Dart normalizó ese URI como m. No se atribuye al cliente ni se modificó código móvil. |
| UNKNOWN / relay | PASS | OFF/partial permanece UNKNOWN; cuatro GET relay 200 con hashes esperados; campaña sigue 404/OFF, cero upstream. |
| Cleanup / Stop | PASS | Limpieza temporal del test confirmada. Stop normal; puerto 8892 cerrado y hashes de DB, manifest y payload sin cambio. |

Resultado de A: evidencia de bytes vivos y relay, con suite Dart global parcial por canonicalización del fixture. No se produjo APK ni OTA de aplicación.

## B — catálogo MariaDB y panel local

| Gate | Estado | Evidencia |
|---|---|---|
| Fuente | PASS | MariaDB 11.8.8 aislada, DB C32 de QA, 36 tablas InnoDB; origen sin usuarios de app ni escritores inesperados. Conteos de catálogo antes/después coinciden. |
| Fix del bootstrap | PASS | El root host se detecta con SELECT por named pipe antes del DDL; destino independiente arrancó correctamente. Sin ejecutar migraciones adicionales contra el origen. |
| Backup | PASS_SCOPED | CATALOG_DB_ONLY, 304.811 bytes, SHA-256 DCF90E8B16992B51B4BC65BDC8E7CEDAA2EB52AB7CE4DE83238C9DE308105B76, 36 tablas. El SQL y manifest quedan solo en private B; no se incluyen en Git/ZIP. |
| Restore | PASS_SCOPED | Importación una vez a otra DB y datadir; 36/36 tablas/filas conciliadas y catálogo C32 intacto. No se migró ni sembró después. |
| Panel | PASS_SCOPED | HTTP local autenticado; /up, admin, nacional 1.104 municipios y SIN RELEASE ACTUAL, filtro Medellín, municipios, app-users y campaigns 200; catálogo de campañas 404/OFF. CSS/JS Vite auténticos, hashes exactos. No se certifica visualmente por HTTP. |
| Guard de reinicio | PASS_SCOPED | En el worktree B ligado al marker: Stop→Start→Status (HTTP_UP=200)→Stop. Errores de consulta de proceso/listener son fatales; un puerto sin coincidencias se trata como libre solo tras enumerar listeners satisfactoriamente. Parser y diff-check pasan. |
| Source preserved / Stop | PASS | Fuente y destino DB_STATUS=STOPPED; panel STOPPED; sin listeners 8892/8893/64595/57305. Fuente: 156 eventos de auditoría y cero usuarios. Destino: 1 SuperAdmin sintético y 157 eventos; el GET /admin/app-users añade un evento de lectura. |

Destino final DB_TARGET_FINAL=NOT_CERTIFIED: QA privado de catálogo, no backup de aplicación completa, no servidor definitivo, no legalidad ni publicación.

## Verificación, Git y privacidad

- Parser PowerShell para scripts cambiados y php -l para router/bootstrap: PASS. Guard focal: 13 assertions estrictas PASS. git diff --check: PASS. El ciclo de vida final del panel se ejecutó después del último cambio. No se repitieron las suites históricas C28–C32.
- La corrida Flutter completa de A tuvo el resultado parcial descrito arriba; no se presenta como PASS global.
- Remoto autorizado al preflight: feat/platform-integral-national-20261122 en 04a64f5ef5a344e39f2fc28790feb6baadecf5ad; main=e9ef37511df3110ffb0fc006ef06be781df432ac. Los workflows de push filtran main; el push de la rama autorizada no dispara esos workflows. El HEAD remoto final se anota en GITHUB_STATE.md y el retorno tras push fast-forward normal.
- APP_KEY, password, option files, SQL dump, cookies, sesiones, HTML/logs crudos, vendor y APK quedaron fuera del repo/ZIP. No se usaron dispositivos, ADB, servicios externos ni producción.

## Próximo bloqueo real

C34 debe decidir y aprobar un origen HTTPS de release autorizado para consumo Android, además de instalador/actualizador final y QA física en una etapa distinta. A necesita resolver la expectativa del fixture URI para que la suite global Dart termine verde sin debilitar la allowlist. Antes de release se requiere revisión humana de fuentes/normas; LEGAL=NO_GO, RELEASE=NO_GO y MAIN_BRIDGE=HOLD permanecen.