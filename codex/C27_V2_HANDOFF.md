# PicoRadar C27 V2 — handoff

Fecha de ejecución: 2026-11-23 (America/Bogota)

## Git

- Checkout aislado: `C:/Users/felip/.codex/worktrees/picoradar-c27-v2/PicoRadar-C17-V2`
- Rama local: `codex/c27-v2-qa`
- Base: `ea7782b30c9d76fc53d6861dc025bb542c7416fa`
- Commit de código: `47fe1a093541a6abfe69d68af499c6811d10cf80`
- Commit documental: se crea con este handoff y la entrada superior de `docs/CURRENT.md`.
- Destino remoto autorizado: `feat/platform-integral-national-20261122`, push normal fast-forward; el resultado posterior se registra en el retorno ZIP.

## Qué cambió

Se agregaron únicamente `codex/qa/c27/seed.php` y `codex/qa/c27/README.md`. El runner es QA local y mantiene preflight, aislamiento de SQLite, contraseñas efímeras, cuatro transacciones y un único retry condicionado a rollback verificado. No se cambió código de negocio, reglas, normas, esquema, dependencias ni configuración persistente.

La causa del fallo de GEO fue reproducida: una clave de código municipal numérica en un array PHP se convirtió de string a entero y violó el tipo de `c27GeoUnit`. Se cambió ese conjunto a lista de tuplas. Se verificó rollback antes de ejecutar una única repetición de GEO; no se migró de nuevo ni se repitieron las etapas que ya habían pasado.

## Gates observados

- Fixture: OPERATORS PASS (3), GEO PASS (3 municipios, 2 jurisdicciones y asociación, sin versiones/release), APP_USERS PASS (Free, Pro, Banned; 2 logs), CAMPAIGN PASS (Draft, sponsor inactivo, catálogo OFF).
- HTTP: login 200, ruta nacional anónima 302, catálogo público 404, CSS/JS 200 con hashes idénticos a los assets locales. Preflight de consola confirmó que CLI y HTTP apuntaban a la misma SQLite, `APP_DEBUG=false`, 36 tablas y conteos esperados.
- Navegador interno: sesiones sintéticas de SuperAdmin, Editor y Commercial. Se observaron las tres filas municipales y las tres cuentas. Editor pudo abrir nacional y recibió 403 para clientes/campañas. Commercial abrió planificación DRAFT/OFF y recibió 403 para nacional/clientes.
- `C_MENU=PARTIAL`: el viewport interno visible fue 1265 px; el API disponible no permitió fijar exactamente 360 o 1280 px. No se declara interacción móvil por clic/teclado.
- `C_ROWS=PARTIAL`: los datos se verificaron en la UI autenticada. Se emitieron capturas reales dentro de la sesión, pero el API CUA disponible no entregó una ruta/operación para exportarlas al ZIP; no se usó captura del escritorio ni se retuvieron emails completos. El retorno explica esta limitación.
- Hallazgo no corregido: fecha de alta visual `2026-11-24` en clientes frente a fecha de QA Bogotá `2026-11-23` en planificación; posible diferencia UTC/local no demostrada.
- `UNKNOWN=NOT_RETESTED`; Android fuera del alcance, `LEGAL=NO_GO`, `RELEASE=NO_GO`, `MAIN_BRIDGE=HOLD`.

## Verificación exacta

- `php -l codex/qa/c27/seed.php` — PASS.
- `git diff --check` — PASS.
- Búsqueda focal de claves privadas/secretos embebidos — PASS.
- Una ejecución inicial de fixture mostró el TypeError de GEO y rollback confirmado. Se ejecutó el único retry GEO; quedó PASS. No se repitieron R11/C19–C26 suites ni npm audit.
- Vite se preparó una vez en entorno aislado; lockfile sin cambios. No se generó APK ni se usó ADB.
- El servidor C27 fue detenido; comprobación posterior: puerto 18727 sin listener.

## Archivos, riesgos y siguiente paso

Archivos de código: `codex/qa/c27/README.md`, `codex/qa/c27/seed.php`. Evidencias completas y hashes están en el retorno ZIP externo. La SQLite sintética permanece fuera del repositorio y no forma parte del ZIP.

El trabajo queda parcial por verificación responsive y por no poder exportar las capturas desde el navegador interno disponible. No se afirma que el motor de Pico y Placa haya sido probado ni que los datos sintéticos representen cobertura legal.

Siguiente responsable: ChatGPT Director para valorar el `C_MENU` y `C_ROWS` parcial y decidir si hace falta otra herramienta de navegador interno con viewport/exportación. Sin merge, despliegue o release.
