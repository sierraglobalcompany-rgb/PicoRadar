# CODEX LUNA — PICORADAR C10: CERRAR PHP Y COMPLETAR EL FLUJO EDITOR NACIONAL

**Orden del director:** EJECUTAR. **TASK_ID:** `PICORADAR-C10-PHP-NATIONAL-EDITOR-20261121`. **Objetivo:** terminar dos pendientes verificables de C9 y agregar una continuación funcional real, sin otra auditoría general.

## 0. Fuente obligatoria y punto de partida

Repositorio privado `sierraglobalcompany-rgb/PicoRadar`. Rama de trabajo **exclusiva** `feat/C10-docker-php-national-workflow-20261121`. HEAD preparado por director: **`c8d4a8d89c16af5dee1593915faf2a7525e2c7a4`**. Es descendiente exacto de C9 aprobado parcialmente, `608a7686a1db28f97df884a586166c1221499b9d` (PR #87 Draft, base C8). C9 tiene selector nacional **PASS 1.104/1.104**, Flutter **29 PASS / 1 SKIP / 0 FAIL**, OTA y consentimiento focal PASS, por lo que **NO REEJECUTAR** estas suites ni rehacer código móvil. C9 PHP: admin/CSV IMPLEMENTED_UNEXECUTED, no defectos funcionales demostrados. No fusionar `main`; PR #86/#87, `main`, checkout protegido y otros proyectos permanecen intactos.

Preflight en **un clon/worktree aislado y limpio**, nunca encima de `D:\codex\PicoRadar` con WIP. Confirmar `git rev-parse HEAD`, `git status --short`, rama y acceso Docker/Flutter. Si la rama C10 avanzó por un trabajo autorizado, **NO resetear**: identificar diferencias y conservarlas. No instalar PHP/MariaDB en Windows, no abrir puertos ni tocar servicios de otros proyectos. **NO** `docker system prune`, `docker compose down -v`, `git reset --hard`, `push --force` ni modificación de configuración global. Usar Docker único por ejecución y secretización local del proceso.

## 1. Trabajo ya hecho: NO volver a implementarlo

En C10 el director ya modificó **tres archivos** de la rama, pendientes de QA real:

- `scripts/run_picoradar_docker_qa.ps1`: variables `PICORADAR_QA_PROJECT`, `PICORADAR_QA_DB_PASSWORD`, `PICORADAR_QA_APP_KEY` aleatorias **en el proceso PowerShell**, sin `.env` temporal. `finally` restaura variables; Compose sigue con red interna, sin puertos, volúmenes persistentes ni montajes de host. Modo test fuerza `DB_CONNECTION=sqlite`, `DB_DATABASE=:memory:` y `DB_URL=`. El problema previo era interpolación de estas variables antes de arrancar contenedores; el **origen exacto de la falla anterior no está probado**, y esta alternativa debe validarse.
- `scripts/tests/test_picoradar_docker_isolation.py`: nueve comprobaciones estáticas; **9/9 PASS en la máquina del director** sobre una reproducción del cambio. Eso NO es ejecución PowerShell/Docker en Windows.
- `server/tests/Feature/C9JurisdictionOnboardingTest.php`: corrigió una aserción imposible: `setUp()` crea una jurisdicción asignada, por lo que un POST inválido debe conservar **1**, no cero. NO repetir este arreglo.

**ZIP C9:** `PICORADAR_C9V2_RETORNO_UNICO_LIGERO.zip`, SHA-256 `7f75f383774bf97201290c029a12fd140d57aecdc3a5c18a3e88b6e4a5ff46e7`. 17 entradas, manifiesto de 16 comprobado. No pedir al propietario volver a enviarlo. Informe de bloqueo exacto: `docker compose` denunció `PICORADAR_QA_APP_KEY` / `PICORADAR_QA_DB_PASSWORD` ausentes antes de build; intentos anteriores fueron 2 y no deben repetirse en su forma antigua.

## 2. Agentes separados: tareas con entrega observable

**Agente A — QA PHP/Docker, propiedad SOLO de `scripts/run_picoradar_docker_qa.ps1`, `scripts/tests/test_picoradar_docker_isolation.py` y los test PHP actualmente bloqueados si contienen fallos reales.** No reescribas Docker Compose ni Composer si no hay fallo reproducido.

1. Trabaja en worktree aislado C10. Verifica el HEAD y que Docker Desktop Linux está operativo; no toques otros proyectos.
2. Ejecuta **una vez** `python -m unittest scripts/tests/test_picoradar_docker_isolation.py` (si no se ejecutó ya sobre la versión exacta) y `pwsh -NoProfile -File scripts/run_picoradar_docker_qa.ps1 -Mode test -Filter 'C8RestrictionCurrentCoverageTest|C9JurisdictionOnboardingTest'`. Usa el launcher, sin `docker compose` con nombres genéricos.
3. Si el modo test pasa, ejecuta **una vez** `pwsh -NoProfile -File scripts/run_picoradar_docker_qa.ps1 -Mode schema` para migraciones sintéticas MariaDB. Los tests PHP antiguos usan SQLite `:memory:`; no atribuyas un PASS SQLite a MariaDB.
4. Si hay error real de aserción/runtime, corregir **solo** el defecto concreto y volver a correr **solo ese filtro** (máximo una repetición focal). Registrar exit code y cambio. Si Compose falla incluso con variables de proceso, un único diagnóstico de configuración **sin imprimir secretos**, cuando la política del host lo permita; si bloqueado por política, **STOP Docker / BLOCKED_POLICY**, no inventar PASS y no eludir el control. El resto del macrobloque continúa.
5. No volcar claves, variables completas, `.env`, contenedores, dumps, ni bases de datos en el ZIP.

**Agente B — Funcionalidad nacional: entrada directa desde jurisdicción a editor. Propiedad SOLO de** `server/resources/views/admin/jurisdictions/show.blade.php`, `server/app/Http/Controllers/Admin/RestrictionRuleController.php` (únicamente `create` y apoyo mínimo), `server/resources/views/admin/restrictions/form.blade.php`, y **nuevo** `server/tests/Feature/C10NationalEditorEntryTest.php`. No modificar las rutas existentes ni el editor/publicador subyacente.

Actualmente C9 permite crear una jurisdicción desde la matriz municipal y redirige a `admin.jurisdictions.show`, **pero desde ese detalle no hay continuación directa a preparar el borrador de restricciones**. Conectar el flujo completo:

1. En detalle de jurisdicción, mostrar un enlace **«Crear borrador de restricciones»** solo si jurisdicción `enabled` y el operador dispone de `datasets.edit`. Enlace **GET** a `admin.restrictions.create` con `jurisdiction_id` (sin POST, sin publish, sin escribir nada). Si ya existe borrador, conservar navegación existente, sin operaciones automáticas.
2. En `RestrictionRuleController::create`, validar `jurisdiction_id` de query: solo ID entero positivo y jurisdicción existente y activa; arrays, cadenas maliciosas, deshabilitados y no existentes se **ignoran conservadoramente**, sin error 500. Pasar a Blade `preselectedJurisdictionId` o `null`. No ampliar permisos ni crear registros en GET.
3. En `form.blade.php`, seleccionar esa jurisdicción por defecto en el `<select name="jurisdiction_id">`, pero respetar `old('jurisdiction_id')` **válido** cuando proviene de una validación fallida; un ID antiguo no disponible no debe activar otra jurisdicción a ciegas. Sin JavaScript nuevo, sin esquema 3.
4. **Mantener** consulta pública desactivada por defecto; al crear borrador no se activa el motor ni se publican normas. El editor conserva revisión y publicación manual independientes y las nueve categorías schema2 ya definidas.
5. Prueba focal sintética `C10NationalEditorEntryTest`: editor con `datasets.edit` ve enlace y preselección; lector sin permiso no; GET malformado no muta; `old()` válido prevalece; jurisdicción inactiva no se elige; ninguna creación/publi­cación o flag automático. Si el agente A no consigue Docker, dejar prueba **IMPLEMENTED_UNEXECUTED** y no decir PASS.

**Agente C — Comprobación de producto no invasiva:** comparar exclusivamente el efecto de los cambios B contra el flujo real matriz municipal → jurisdicción → editor, y los módulos de campañas/aliados existentes. No construir publicidad desde cero: `CampaignController`, publicador y catálogo de campañas ya existen. Mantener `CAMPAIGN_PUBLIC_CATALOG_ENABLED=false` y `PICORADAR_SPONSORED_CAMPAIGNS_ENABLED=false`; no activar publicidad, cuentas, pagos, geolocalización continua ni proveedores externos. Si detecta un fallo real y autocontenido de ese recorrido, comunicarlo al integrador con archivo/línea, **no escribir archivos propiedad de A o B**. Si no, `NO_CHANGE_REQUIRED`.

**Integrador único:** espera A/B, incorpora cambios una sola vez, revisa diff de archivos objetivo, hace una prueba PHP focal adicional **solo si los cambios de B están listos y Docker funciona**, y publica por push normal a rama C10. Si A sigue bloqueado, publica igualmente el código de B con etiqueta `PHP_UNEXECUTED`, sin release ni merge. No reabrir C2–C9 ni repetir suites Flutter 29 PASS. Puede usar la herramienta `scripts/android_16k_audit.py` sobre **artefacto local existente** solo si la ruta está documentada, sin generar APK/AAB; si no existe, `NOT_RUN` sin búsqueda extensa.

## 3. Gates y decisión de cierre

| Gate | Condición de PASS | Si no pasa |
|---|---|---|
| A0 | Git C10 descendiente correcto; checkout aislado limpio | STOP_SOURCE, sin tocar WIP |
| A1 | Docker runner usa secretos efímeros y no toca otros proyectos | BLOCKED_ENV/POLICY, documentar una vez |
| A2 | C8/C9 PHP focal ejecutado y aprobado | `IMPLEMENTED_UNEXECUTED` o FAIL real, sin falsear |
| A3 | Schema MariaDB sintético migró en Docker aislado | BLOCKED si entorno impide, no reutilizar DB |
| B1 | Enlace jurisdicción → borrador correcto y permisos seguros | CODE_PARTIAL; no publicarlo como terminado |
| B2 | Prueba PHP focal C10 ejecutada y pasó | Si Docker no funciona: `IMPLEMENTED_UNEXECUTED` |
| C | Flags Free 1.0 OFF y módulos actuales no duplicados | corregir solo defecto reproducible |
| GIT | C10 remoto SHA exacto, diferencia controlada, rama publicada | STOP_PUSH; no forzar ni tocar main |
| RELEASE | Fuentes legales verificadas, HTTPS real, QA Android físico y firma release | **NO_GO** hasta evidencia real |

**Objetivos medibles:** el selector nacional Pico ya tiene **1.104/1.104 opciones** y no se toca; las pruebas Flutter de C9 **29 PASS / 1 SKIP** se conservan como evidencia scoped. C8/C9 PHP está en **0 suites ejecutadas** por bloqueo; C10 debe intentar cerrarlas sin afirmar números si falla. La antigua puntuación **61/100** describe una rúbrica de evidencia anterior; **58 %** y **83 %** son estimaciones históricas sin fórmula vigente. NO inventar un nuevo porcentaje global por agregar documentación o escribir pruebas no ejecutadas. El catálogo geográfico no demuestra legalidad nacional.

## 4. Política de bloqueos: no perseguirnos la cola

- **No** pedir al dueño que vuelva a subir C9, no solicitar APK, TAR, capturas gigantes, ni generar múltiples archivos sueltos.
- **No** escanear todos los repositorios, no reiniciar Codex por rutina, no retomar N3/N4/N5, no repetir tests pasados.
- Si Composer, Docker, red o política bloquea PHP, registrar **causa observada vs hipótesis**, conservar evidencias mínimas, y continuar el trabajo B en paralelo. Solo una corrección causal respaldada; no entrar en un ciclo de “auditar auditoría”.
- **No** mezclar cambios en `main` ni fusionar PR #79, #86 o #87. C10 debe apuntar a base C9 y quedar Draft si se abre PR; no pasar automáticamente a merge.
- No modificar información jurídica nacional con hipótesis. Para municipios sin fuentes vigentes usar `UNKNOWN`, `STALE` o `PARTIAL`, nunca `ALLOWED` por ausencia de regla. No almacenar placas ni documentos sensibles en servidor.
- Aislamiento de otros proyectos: única identidad Docker por ejecución, sin puertos host, sin PHP/MariaDB globales, sin volúmenes de otros proyectos, sin comandos destructivos. No conservar ni subir secretos.

## 5. Entrega única obligatoria

Crear **un solo ZIP liviano** `PICORADAR_C10_RETORNO_UNICO_LIGERO.zip` (máximo 5 MB) en `D:\codex\_REPORTES\PicoRadar\C10-20261121\`, con:

- `FINAL_REPORT.md`: implementaciones **exactas**, estado A/B/C, qué sí se ejecutó, pruebas/exit codes y qué sigue.
- `GATES.csv`: fuente SHA, A1-A3, B1-B2, GIT, RELEASE. Estados separados `PASS`, `FAIL`, `BLOCKED_ENV`, `BLOCKED_POLICY`, `IMPLEMENTED_UNEXECUTED`, `NOT_RUN`.
- `CHANGED_PATHS.csv`: ruta, propietario A/B, commit y blob SHA; indicar qué cambió después de los tres archivos preparados por director.
- `QA/RESULTS.csv` y **logs focales saneados**, no capturas ni logs completos de Composer; omitir secretos, tokens, variables de entorno, bases, volcados.
- `GITHUB_STATUS.md`: HEAD remoto, árbol, parent C9, PR Draft si existe, `main` sin cambios; enlace verificable.
- `MANIFEST.csv` con SHA-256/CRC32/bytes de miembros y el ZIP SHA-256 en la respuesta.

Validar ZIP CRC y manifiesto, sin incrustar el ZIP dentro de sí mismo; retorno `TASK_ID | RESULT | GATES | HEAD | PR | RELEASE | ZIP_PATH | ZIP_SHA256 | NEXT=CHATGPT_DIRECTOR`. **No empaquetar APK, AAB, TAR, fuentes completas, capturas privadas, `.env`, bases ni credenciales**.

## 6. Decisión final

**SIGUE AHORA: CODEX LUNA — EJECUTAR C10 CON AGENTES A Y B EN PARALELO, INTEGRADOR ÚNICO.**

**DESPUÉS DEL ZIP C10 SIGUE: CHATGPT DIRECTOR — VERIFICACIÓN DIFERENCIAL Y SIGUIENTE TRABAJO FUNCIONAL DE FREE 1.0.**
