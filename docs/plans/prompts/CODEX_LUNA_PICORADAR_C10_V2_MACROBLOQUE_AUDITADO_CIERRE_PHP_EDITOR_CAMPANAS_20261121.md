# CODEX LUNA — PICORADAR C10-V2: CIERRE PHP + EDITOR NACIONAL + SEGMENTACIÓN COMERCIAL SEGURA

**EJECUTAR ESTE DOCUMENTO EN SUSTITUCIÓN DEL C10 ORIGINAL.**  
`TASK_ID=PICORADAR-C10-V2-PHP-EDITOR-CAMPAIGN-20261121` · `NEXT_ACTOR=CODEX_LUNA` · `PRODUCT_RELEASE=NO_GO`.

## 0. Contrato de ejecución: un macrobloque, no auditoría circular

Director ChatGPT define el trabajo; Codex Luna implementa mediante **tres agentes de archivos disjuntos y un integrador único**. No es una solicitud de otra auditoría general. Conservar las evidencias anteriores cuando sus SHA/rutas no cambiaron; ejecutar **solo pruebas nuevas o previamente bloqueadas**. No detener B y C porque Docker falle. No realizar trabajos en segundo plano ni anunciar PASS sin pruebas efectivamente ejecutadas.

**Origen confirmado en GitHub el 2026-11-21:** repositorio `sierraglobalcompany-rgb/PicoRadar`, rama `feat/C10-docker-php-national-workflow-20261121`, **HEAD exacto `c8d4a8d89c16af5dee1593915faf2a7525e2c7a4`**; desciende de C9 `608a7686a1db28f97df884a586166c1221499b9d` (PR #87 abierto Draft, base C8). Si remoto avanzó tras esta orden: conservar el trabajo, inspeccionar únicamente el delta posterior y nunca resetearlo. Checkout del propietario y 43 rutas WIP protegidas: **intocables**. No tocar `main` (`e9ef37511df3110ffb0fc006ef06be781df432ac` al preparar esta orden), PR #79/#86/#87 ni proyectos ajenos. No merge automático, force-push ni release.

**Evidencia conservada (no reejecutar por rutina):** C9 selector Pico nacional **1.104/1.104 municipios = 100 % de opciones geográficas**, no 100 % de leyes; Flutter focal **29 PASS, 1 SKIP, 0 FAIL**; fechas OTA, consentimiento de aliados: PASS focal; Android ELF sintético 7/7; controles Docker previos 9/9 estáticos, **no Docker real**. C8/C9 PHP: pruebas escritas, cero ejecuciones por `BLOCKED_ENV`; no declarar PASS. Motor nacional, editor manual nacional, servidor OTA, Super Admin y catálogo comercial ya existen: **no reescribir, no crear versión 2/3 de su arquitectura, no introducir cuarto JSON territorial, no habilitar monetización**. Legal: ausencia/fuente vencida/territorio ambiguo = UNKNOWN/STALE/PARTIAL según contrato; jamás ALLOWED por falta de regla.

## 1. Preflight de 4 verificaciones, una sola vez

1. Trabajar en **clon/worktree NUEVO y aislado**, limpio y asociado a C10; nunca trabajar sobre el WIP protegido. Confirmar repo, rama, `git rev-parse HEAD`, `git status --porcelain`, `git remote -v` **sin mostrar credenciales**. No clonar desde una rama histórica si existe C10. Si el remoto no coincide, mantener ambas referencias; no `reset --hard`.
2. Comprobar `docker compose version`, `docker info` resumido y disponibilidad de `pwsh`, sin mostrar variables privadas. **No arrancar, parar, limpiar o inspeccionar contenedores de otros proyectos.** Prohibido `docker system prune`, `docker volume prune`, `docker compose down -v`, puertos fijos, MariaDB global, PHP global, cambiar Docker Desktop global, tocar `php.ini` del host.
3. Confirmar que la rama ya contiene las tres correcciones del director: `scripts/run_picoradar_docker_qa.ps1` (secretos en variables del proceso y restauración; SQLite `:memory:` en modo test); `scripts/tests/test_picoradar_docker_isolation.py` (9 pruebas estáticas); y en `C9JurisdictionOnboardingTest.php` la aserción **1 jurisdicción** tras POST inválido (su `setUp()` crea una jurisdicción). **No implementar de nuevo**.
4. Asignar agentes a **worktrees separados con HEAD base común**; el integrador es el único que incorpora commits. Cada agente hace `git status` limpio y commits propios antes de Docker: el ejecutor **rechaza worktrees con cambios sin guardar**. No pedir reenvío del ZIP C9 ni recuperar paquetes enormes.

## 2. Agente A — desbloquear QA PHP con aislamiento real (primera prioridad)

**Propiedad EXCLUSIVA:** `scripts/run_picoradar_docker_qa.ps1`, `scripts/tests/test_picoradar_docker_isolation.py`, y **solo los test PHP C8/C9 que presenten fallos reales**: `server/tests/Feature/C8RestrictionCurrentCoverageTest.php`, `server/tests/Feature/C9JurisdictionOnboardingTest.php`. No editar archivos de B o C; no reescribir Dockerfile/Compose/Composer sin fallo causal reproducido.

**Orden concreta:**

A1. Si el código coincide con los hashes preparados y los 9 tests Python ya quedaron aprobados en esa misma versión, no repetirlos. Si cambiaste A, ejecuta `python -m unittest scripts/tests/test_picoradar_docker_isolation.py` **una sola vez**. Los 9 checks son **estáticos**, no certifican que Docker arranque.

A2. Desde worktree **limpio**, ejecutar **una sola vez** el launcher existente con `-Mode test -Filter 'C8RestrictionCurrentCoverageTest|C9JurisdictionOnboardingTest'`. El código del runner actual pasa `DB_CONNECTION=sqlite`, `DB_DATABASE=:memory:` y `DB_URL=` solo al contenedor de tests, porque `phpunit.xml` no debe asumir que sobreescribirá las variables inyectadas por Compose. Registrar comando exacto, exit code, número de tests y aserciones reales, o mensaje de error **saneado**. No ejecutar las 29 pruebas Flutter de C9.

A3. **Solo si A2 puede ejecutar PHPUnit y Docker es seguro**, ejecutar una vez `-Mode schema` sobre **MariaDB sintética**: imagen aislada, identificador Compose único, red `internal: true`, datadir `tmpfs`, sin puertos ni volúmenes de otros proyectos. `schema PASS` implica únicamente migraciones de ese contenedor, no pruebas sobre MariaDB de producción.

A4. Si fallo antes del build: discriminar `BLOCKED_POLICY`, `BLOCKED_DOCKER_SERVICE`, `BLOCKED_COMPOSE_INTERPOLATION` o `BLOCKED_NETWORK_OR_DEPENDENCIES`. Si procede **un único** diagnóstico acotado y permitido (p. ej. `docker compose ... config --quiet` bajo las **mismas variables de proceso** y proyecto único, SIN imprimir configuración expandida ni secretos); si una política de seguridad lo veta, **NO eludirla**. No repetir una prueba fallida tres o cuatro veces; máximo una corrección causal + una repetición focal. Si el bloqueo persiste, A declara `BLOCKED_*` y B/C continúan.

A5. Si PHPUnit llega a ejecutarse y falla por código, atribuir `FAIL_TEST` con aserción/línea. Corregir solo la causa probada. **No falsear exit 0** ni sustituir SQLite por MariaDB del host. Docker con imágenes sin red o Composer bloqueado ≠ código PHP defectuoso.

## 3. Agente B — completar recorrido municipio → jurisdicción → borrador nacional

**Propiedad EXCLUSIVA:** `server/resources/views/admin/jurisdictions/show.blade.php`, `server/app/Http/Controllers/Admin/RestrictionRuleController.php` (**solo método `create()` y el mínimo apoyo necesario**), `server/resources/views/admin/restrictions/form.blade.php` y test **nuevo** `server/tests/Feature/C10NationalEditorEntryTest.php`. No tocar servicio de publicación, reglas del motor, rutas ni migraciones. C9 ya implementó matriz municipal y CTA para crear jurisdicción; **no repetir C9**.

**Defecto de base verificado en C10:** `RestrictionRuleController::create()` no procesa `?jurisdiction_id`, el `<select>` solo usa `old('jurisdiction_id')`, y `$formJurisdiction` se calcula como **primera jurisdicción** si `old` no existe. Una preselección visual mal hecha daría **código DIVIPOLA del municipio equivocado** en `municipality-code`. Además, un `<select>` sin opción vacía selecciona implícitamente la primera ciudad, y al cambiar de ciudad el JS existente actualiza el código pero **no desmarca una casilla de consulta ya activada**. Corregir este conjunto en una sola implementación, no con parches inconexos.

B1. En `admin.jurisdictions.show` añadir enlace GET **«Crear borrador de restricciones»** a `route('admin.restrictions.create', ['jurisdiction_id' => $jurisdiction->id])`. Mostrarlo **solo si** `jurisdiction.enabled === true` **y** el usuario tiene `datasets.edit`. Para inactivos, lector o comercial, NO mostrarlo. No auto-POST, auto-publish, ni cambiar `Jurisdiction.enabled`.

B2. En `RestrictionRuleController::create()` (autoriza `datasets.edit` y requiere `Dataset(key=restrictions)`), obtener candidatos existentes **enabled=true**, con `primaryGeographicUnit` eager-loaded como hoy. Leer query `jurisdiction_id` como escalar entero positivo y longitud razonable; arrays/objetos, `-1`, `0`, enorme, ID inexistente o inactivo => **sin preselección**, no 500. Verificar pertenencia a la colección de candidatos; pasar a vista `preselectedJurisdictionId` o `null`. No ejecutar acciones de escritura en GET.

B3. Resolver UNA única jurisdicción seleccionada en Blade: `old('jurisdiction_id')` **solo si coincide con un candidato activo**, en segundo lugar la preselección GET válida, y si ninguno aplica, **NADA**. El `<select name="jurisdiction_id" required>` debe comenzar con `<option value="">Selecciona municipio y jurisdicción</option>` seleccionado cuando no hay candidato válido, de modo que el navegador no elija silenciosamente la primera ciudad. Para un formulario de edición existente (`$version`), preservar exactamente su jurisdicción. Una vez seleccionado el ID, usar **el mismo objeto** para el `selected` de la opción, `$formJurisdiction`, DIVIPOLA readonly y texto de gestión. No usar `first()` como fallback en alta, ni permitir que `old()` de otro ID inactivo cambie el DIVIPOLA.

B4. En alta **mantener siempre el input hidden `consultation_enabled=0` y renderizar el checkbox `consultation-enabled` desmarcado**, pero **disabled** mientras no haya jurisdicción/DIVIPOLA válido; así la selección manual posterior puede habilitar el control sin recargar la página. En el `change` JS **ya existente** del selector, sincronizar el readonly `municipality-code` (vacío si selección vacía), **desmarcar** el checkbox **y activar/desactivar solo su disponibilidad** según el código de 5 dígitos; jamás marcarlo automáticamente. Un checkbox marcado para una ciudad no puede trasladarse a otra. Conservar la rehidratación legítima de `old('consultation_enabled')` al volver de un POST fallido para la **misma ciudad**, y el comportamiento existente al editar `$version`. No confundir habilitar el control con habilitar la consulta en el servidor. **No añadir librería JS ni reescribir el wizard**.

B5. Conservar el contrato schema2: nueve categorías existentes, cobertura nueva `partial`, `consultation_enabled` por defecto `0`, borrador separado de revisión/manual publication y motor nacional sin cambios. El enlace y GET **no crean datos ni acreditan normas**. No activar anuncios, cuentas o pagos.

B6. Crear `C10NationalEditorEntryTest.php` con fixtures sintéticos mínimos: `RefreshDatabase`, `withoutVite()`, país/departamento, **dos jurisdicciones activas con DIVIPOLA diferentes**, una inactiva, usuarios Editor/Reviewer/Commercial y **Dataset `restrictions` con `schema_version=2`**, sin el cual `create()` da 404 legítimo. Tests focales: roles y enlace; GET preseleccionado muestra **option seleccionada + código DIVIPOLA de ese mismo ID**; `old()` **válido** prevalece; `old()` inactivo/ausente no se usa; query inválida no selecciona ciudad alguna y deja checkbox deshabilitado; cambio de ciudad desmarca consulta y habilita/deshabilita el control según DIVIPOLA (widget/browser local si disponible, en caso contrario reportar el JS como `UNEXECUTED`, sin fingir validación dinámica); GET no muta tablas `jurisdictions`, `restriction_rule_versions`, `datasets` ni `restriction_publications`; POST sigue requiriendo autorización y no publica automáticamente. Un ensayo PHP por filtro de clase basta. Si Docker falla, `IMPLEMENTED_UNEXECUTED` y logs mínimos.

## 4. Agente C — avance comercial real, pequeño y SIN activar anuncios

**Propiedad EXCLUSIVA:** `mobile/lib/features/home/presentation/home_screen.dart` y **opcionalmente solo** un helper puro nuevo `mobile/lib/features/home/domain/campaign_territory_mapper.dart` + su test focal `mobile/test/features/home/domain/campaign_territory_mapper_test.dart`; no modificar archivos A/B, servidor, banners publicitarios, repositorio de campañas ni permisos.

**Brecha de código verificada:** `_campaignTerritory()` en `home_screen.dart` usa `picoJurisdictionCatalogProvider.records` (el catálogo histórico de **73**), mientras C9 habilitó la **selección geográfica nacional de 1.104**. Para una nueva jurisdicción publicada por OTA no incluida en esos 73, el contexto publicitario actualmente cae a `municipalityKey` sin `municipalityCode`/`departmentCode`. `RestrictionJurisdiction` ya incluye `municipalityCodes` en `restriction_store.dart`; **reutilizarlo, sin descargar otro catálogo**.

C1. Preparar mapeo determinista para `CampaignTerritoryContext`: si hay `selectedJurisdiction` con **exactamente un DIVIPOLA válido de cinco dígitos** en `municipalityCodes`, usar ese código y sus dos primeros dígitos como departamento; mantener `municipalityKey=jurisdiction.id`. Si contiene varios códigos distintos, inválidos, o un código ambiguo, **no inventar municipio**: contexto solo con key, sin segmentación geográfica más específica. Si la metadata OTA no contiene códigos, **conservar el fallback histórico de 73** únicamente cuando su ID corresponde exactamente a la jurisdicción. Si no hay jurisdicción, contexto vacío. No usar coordenadas de GPS ni inferir municipio por nombre.

C2. Modificar llamada de `home_screen.dart` para pasar el `RestrictionJurisdiction` completo, no solo `id`. **No** cambiar `CAMPAIGN_PUBLIC_CATALOG_ENABLED=false`, `PICORADAR_SPONSORED_CAMPAIGNS_ENABLED=false`, endpoints, reglas comerciales, ni disparar solicitudes nuevas. Mantener fallback de catálogo cuando esté cargando/falle; no bloquear Home.

C3. Test focal de función pura para nuevo id con código único, histórico de 73 sin metadata OTA, multi-municipio/ambiguo, inválido y null; **si no hay SDK Flutter/Dart**, dejar código `IMPLEMENTED_UNEXECUTED` sin fabricar PASS. Evitar testificar todo `home_screen_test.dart` (miles de líneas) sin cambio relacionado. Si C implica más de 3 archivos o requiere rehacer campañas, **detener ese alcance** y entregar evidencia `DEFERRED_SCOPED` para no frenar A/B. Su función es completar datos de segmentación, **no vender anuncios aún**.

## 5. Integración: secuencia que evita ping-pong

I1. Los agentes trabajan paralelos en worktrees/ramas locales distintos, no hacen push a la misma rama. Al integrador le entregan **commits y resumen de archivos**, no ZIPs separados. **Integrar primero B y C, luego los arreglos demostrados de A**, con cherry-pick limpio, sin rebase/reset de la rama del dueño. Conflicto => escoger la modificación mínima preservando la línea C9; no reescribir histórico.

I2. Importante: el runner Docker **rechaza `git status` sucio** y construye mediante `COPY . .`. Por ello el integrador debe **commitear** B y C antes de ejecutar los tests focales sobre el árbol final. A puede probar C8/C9 desde una copia C10 limpia inicial; **no puede declarar aprobado el nuevo test B** hasta que el integrador haya creado un checkout limpio de los commits de B.

I3. Si Docker ya corre, ejecutar **una sola vez** nueva prueba C10 `-Mode test -Filter 'C10NationalEditorEntryTest'` sobre el árbol final, más los C8/C9 que A no haya ejecutado todavía; **no repetir** los mismos tests en A e integrador. Solo repetir filtro con defecto realmente corregido. Para C ejecutar únicamente su nuevo test Dart cuando exista; **NO** repetir C9 29 PASS ni OTA/consentimiento/selector con blobs idénticos. Si Docker sigue bloqueado, integrador **continúa publicando B/C implementados**, estados `PHP_UNEXECUTED`, sin release.

I4. Confirmar flags comerciales OFF, seguridad conservadora, sin alteraciones de manifiesto OTA ni reglas nacionales salvo alcance autorizado. Diff y permisos mínimos; no auditoría general. Publicar por push normal en C10, verificar HEAD remoto, tree y blobs. Si se abre PR, **uno solo Draft C10 → C9**; no abrir múltiples PR ni tocar #87/#86/#79 ni `main`. No autorizar merge a C9/main por estar `NO_GO`.

I5. Al encontrar bloqueo ambiental, detener solo ese frente tras el diagnóstico acotado; **no transformar `BLOCKED_ENV` en `PASS`** por un resultado estático. No remover staging ajeno si la política de limpieza lo prohíbe. No pedir intervención del propietario salvo que realmente sea indispensable para ejecutar HTTPS/dispositivo final (fuera de C10).

## 6. Gates cuantificables y criterio de aceptación

| Gate | Condición real | Estado si no se probó |
|---|---|---|
| SOURCE | SHA C10 de partida y worktrees limpios, sin WIP del dueño alterado | `BLOCKED_SOURCE` |
| PHP_C8_C9 | Filtros C8/C9 ejecutados con aserciones PASS en Docker aislado SQLite; reportar conteos reales | `IMPLEMENTED_UNEXECUTED` / `BLOCKED_ENV` |
| MARIADB_SCHEMA | `migrate`/`migrate:status` reales en MariaDB efímera sin puertos host | `BLOCKED_ENV` |
| EDITOR_FLOW | Municipio → jurisdicción → formulario con selección coherente y consulta OFF | `IMPLEMENTED_UNEXECUTED` si falta prueba PHP |
| EDITOR_TEST | Test C10 real ejecutado, preselección + DIVIPOLA + permisos + no mutación | `IMPLEMENTED_UNEXECUTED` |
| COMMERCIAL_TERRITORY | Nuevo código OTA único mapea, multi-municipio no falsifica segmentación, campañas OFF | `IMPLEMENTED_UNEXECUTED` / `DEFERRED_SCOPED` |
| COMMERCE_OFF | `CAMPAIGN_PUBLIC_CATALOG_ENABLED=false`; pagos/cuentas/marketing OFF | `PASS_SCOPED` o `FAIL` según código |
| GITHUB | Push normal C10, SHA remoto y diff comprobados, PR Draft solo si útil | `BLOCKED_PUSH` |
| RELEASE | Leyes vigentes verificadas, HTTPS real, APK/AAB firmada y QA físico Android | **`NO_GO`** mientras falte cualquiera |

**Porcentajes honestos**: selector geográfico Pico **1.104/1.104 = 100 % del catálogo de opciones**, no 100 % jurídico. C9 Flutter **29 PASS/1 SKIP** de casos ejecutados; C8/C9 PHP **0 pruebas ejecutadas**, no significa 0 % de código PHP. Rúbrica anterior **61/100 de evidencia** y estimaciones históricas **58 % integral, 83 % núcleo** no son medición fresca ni deben incrementarse por redactar prompts o tests sin correr. Informar porcentajes locales solo con denominador y pruebas. No publicar ni habilitar nuevas reglas nacionales basándose únicamente en DIVIPOLA.

## 7. Un único retorno verificable

Producir **SOLO** `D:\codex\_REPORTES\PicoRadar\C10-V2-20261121\PICORADAR_C10V2_RETORNO_UNICO_LIGERO.zip` (ideal <2 MB, máximo 5 MB), con `FINAL_REPORT.md` (por agente, resultados, causas y NEXT), `GATES.csv`, `CHANGED_PATHS.csv` (SHA blob y commit), `QA/RESULTS.csv` (comandos, exit code, ejecutadas, PASS/FAIL/SKIP), mínimos logs saneados, `GITHUB_STATUS.md` (HEAD/tree/parent PR Draft y main intacto), `MANIFEST.csv` con SHA-256, bytes y CRC de cada entrada. CRC y hashes comprobados; el SHA externo del ZIP se indica en la respuesta, sin incluirse dentro del propio ZIP. No generar evidencias regadas ni anexar código fuente completo.

**PROHIBICIONES:** APK/AAB/TAR/dumps `.sql`/`.env`/contraseñas/tokens/fotos/placas, capturas privadas, logs de Composer gigantes, `docker compose down -v`, `docker system prune`, force push, despliegue Hostinger, anuncios/marketing ON, validaciones legales inferidas, nueva arquitectura o repetición de pruebas aceptadas.

**Respuesta exacta breve:** `TASK=PICORADAR_C10_V2 | RESULT=... | PHP=... | EDITOR=... | COMMERCIAL=... | DOCKER=... | GITHUB_HEAD=... | PR=... | RELEASE=NO_GO | ZIP_PATH=... | ZIP_SHA256=... | NEXT=CHATGPT_DIRECTOR`.

## 8. Auditoría ya realizada por el director — 10 pasadas VERDUGO + 10 JUEZ (NO repetir)

Estas pasadas contrastan **el prompt C10 anterior** con archivos reales del HEAD C10. No son 20 tests de aplicación ni autorización para reencontrar los mismos fallos.

| Pasada | Papel | Comprobación y resolución |
|---|---|---|
| V1 | Verdugo | C10 viejo prefijaba `jurisdiction_id` pero el Controller GET ignora ese query: instrucción explícita B2 |
| V2 | Verdugo | `$formJurisdiction` cae al primer elemento aunque otro esté seleccionado: fuente de DIVIPOLA equivocada; B3 |
| V3 | Verdugo | `<select>` HTML sin opción vacía autoselecciona el primer municipio: placeholder requerido; B3 |
| V4 | Verdugo | Cambiar ciudad no desmarca `consultation-enabled`: riesgo de reutilizar consentimiento por otra jurisdicción; B4 |
| V5 | Verdugo | Nuevo test GET puede 404 si no existe `Dataset(restrictions)`: fixture obligatorio; B6 |
| V6 | Verdugo | Prueba Docker en checkout sucio no arranca; agentes deben commitear y usar worktrees limpios; I2 |
| V7 | Verdugo | Duplicar tests PHP en agente A e integrador desperdicia tiempo; reparto de filtros y no repetir; I3 |
| V8 | Verdugo | Docker falló antes de build; no se conoce origen causal definitivo; diagnóstico único y `BLOCKED`; A4 |
| V9 | Verdugo | C10 anterior tenía agente C solo lector sin desarrollo; ahora microentregable comercial real; C1-C3 |
| V10 | Verdugo | Home usa 73 fichas para territorio publicitario y pierde DIVIPOLA de nueva jurisdicción nacional; C1 |
| J1 | Juez | `AppServiceProvider` autoriza `datasets.edit` para Editor/Admin/SuperAdmin; reutilizar Gate, no inventar permisos |
| J2 | Juez | La rama C10 existe y es descendiente de C9; conservar HEAD y PR #87 Draft, sin merge |
| J3 | Juez | PHP 8.3 Laravel 13, tests `phpunit.xml` con SQLite `:memory:`; mantener modo Docker diferenciado |
| J4 | Juez | El runner ya fuerza SQLite por `-e`; no volver a arreglarlo sin defecto probado |
| J5 | Juez | C9 selector 1.104/1.104 y Flutter 29 PASS 1 SKIP no requieren retesteo si sus blobs no cambiaron |
| J6 | Juez | Jurisdicción `enabled` es gestión; `consultationEnabled` es disponibilidad de consulta versionada; no confundir |
| J7 | Juez | Probar que GET no escribe, borrador no publica y falta de ley no significa ALLOWED |
| J8 | Juez | Mapa comercial con DIVIPOLA único es determinista; varios municipios deben degradar a solo key |
| J9 | Juez | Cada agente posee archivos disjuntos; integrador único y logs ligeros evitan conflictos |
| J10 | Juez | Gates distinguen código implementado, tests ejecutados, entorno y release; no falsos positivos |

## 9. Decisión de cierre

**SIGUE AHORA: CODEX LUNA — EJECUTAR C10-V2 CON AGENTES A/B/C EN PARALELO Y UN SOLO INTEGRADOR. NO EJECUTAR EL PROMPT C10 ANTERIOR.**

**DESPUÉS DEL ZIP ÚNICO C10-V2 SIGUE CHATGPT DIRECTOR PARA ACEPTAR SOLO LOS CAMBIOS NUEVOS Y ACERCAR EL PRODUCTO FREE 1.0 A SU CIERRE.**
