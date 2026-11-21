# CODEX LUNA — PICORADAR C6 V2 · MACROBLOQUE DE IMPLEMENTACIÓN NACIONAL, APK Y RESPALDO REAL

> **PARA CODEX LUNA: EJECUTAR. NO VOLVER A AUDITAR NI PEDIR OTRO PROMPT.**
>
> Director: ChatGPT. `TASK_ID=PICORADAR-C6-EXPORT-NACIONAL-ANDROID-REMOTE-20261120` (CONSERVAR EL ID DE C6; V2 ES CORRECCIÓN ANTES DE EJECUTAR, NO UN C7).
>
> **ENTRADA ÚNICA:** este `.md` y los archivos C5 **ya disponibles localmente**. **SALIDA ÚNICA:** `PICORADAR_C6_RETORNO_UNICO.zip` con código, fuente recuperable, evidencia NUEVA y estados honestos. Si C6 original está en ejecución, NO lanzar otra instancia sobre el mismo candidato: aplicar estas correcciones a ese trabajo sin duplicarlo.

## 0. Propósito y definición de resultado

**Objetivo de producto:** acercar PicoRadar a una operación nacional real, no elevar artificialmente los porcentajes. Completar, en un único macrobloque y sin interrupciones para nuevas órdenes:

- **A (Laravel, prioridad funcional):** exportación editorial segura y completa que haga visibles las restricciones por categoría **y los municipios sin jurisdicción/regla**, sin confundir borrador, publicación, deshabilitado, expiración ni ausencia de fuentes. Tiene que existir código de producción y pruebas causales nuevas.
- **B (Android, prioridad de entrega):** un intento válido de APK `dev` desde `mobile/` con requisitos de memoria comprobados y configuración Gradle reversible. Si RAM impide construir, no bloquear A ni C.
- **C (continuidad/GitHub, prioridad de riesgo):** **un respaldo remoto source-only del código real C6 en una rama exclusiva de respaldo, sin merge**, siempre que pase la seguridad; preparar por separado la reconciliación con `main`. Si la seguridad o el acceso lo bloquean, fuente portátil íntegra dentro del ZIP y clasificación específica.
- **D (servicio/Flutter/campañas):** una comprobación de integración estrictamente nueva si el cambio de A la requiere; reutilizar los PASS anteriores y no implementar otros motores, cuentas o anuncios. **Ads/pagos/premium permanecen OFF** en Free 1.0.

**Criterio de cierre C6:** resultados individuales A/B/C verdaderos y verificables. `PARTIAL` es correcto si quedan bloqueos externos; **nunca PASS global de la app sin APK, HTTPS y autorización de release**. No terminar tras un preflight o solo documentación cuando exista entorno para implementar A.

## 1. Fuentes comprobadas y estado inalterable

Se revisaron realmente el Markdown C6 anterior y el ZIP C5 original, no solo la respuesta de Codex. ZIP C5 `D:\codex\_REPORTES\PicoRadar\C5-20261120\PICORADAR_C5_RETORNO_UNICO.zip`:

- ZIP SHA-256: `e373818ec6d92ae3cd93129f534f8756b8e8df5f20a590fa86724c9bcf021147`; 14 entradas, 13 en `MANIFEST.csv`; CRC de ZIP válido. El tar fuente `C5_SOURCE_RECOVERY.tar.gz` SHA-256 `58d3d425336c867dd53b3efb912c5058a77f8244d810f555b6b0178f4faeb9a8`. **El Director recalculó 1.880/1.880 hashes del TAR contra `SOURCE_MANIFEST.csv`: PASS, cero faltantes o extras y cero nombres inseguros/symlinks.**
- C5 HEAD local `3a75ed3d3014ee9cb3fd7a6b995eb32e1e413088`; tree `ad548cdbda48a3ba92b74e814f830c52d8830193`. C4 `b63a2b743f855b7983c516c51bd4803b0078b192`. **No inventar ancestro común** con remoto.
- C5 A+B ya PASS: 6 PHP tests/98 aserciones, 3 widget Flutter; C4 bandeja/filtro/UX, C3 roles/rollback/Drift v10→v11/offline componente, C2 puente local PASS. **No repetirlos** si el nuevo código no los afecta. Libre de cambios de fuentes nacionales oficiales nuevos en C5.
- Checkout origen protegido `HEAD=182a8821bba688b28a6e223a1e956df748f7948b`; 43 rutas WIP (18 M, 25 ??), verificadas por hash antes/después en C5. **Nunca editar, limpiar, restaurar, borrar ni hacer checkout/reset de esas rutas**. La eliminación inesperada observada de `scripts/tests/test_hostinger_installer_browser.ps1` era de un worktree candidato, no un cambio autorizado en HEAD.
- Android C5: 4,79 GiB de RAM libre, no se inició Gradle. C4 se ejecutó fuera de `mobile/` y no fue un build válido. El `mobile/android/gradle.properties` del C5 solicita `-Xmx8G` y metaspace 4G: **solo ajustar temporalmente en candidato** y revertir por hash. Flutter 3.47.1; flavor dev existente.
- GitHub contrastado en este encargo: `sierraglobalcompany-rgb/PicoRadar` público, `main=e9ef37511df3110ffb0fc006ef06be781df432ac`; PR #79 OPEN/DRAFT, cabeza `5aac8b2ef932b55e10cf4b1150d5e437d41c369c`, base `recovery/20261019-modern`. Remoto puede cambiar; **una comprobación al empezar** y no sobrescribir refs ajenas. **Diferencias C5↔main: 838 rutas, sin ancestro común; la reconciliación no es una operación automática segura.**
- Score de evidencia C5 `61/100`, NO es `61 % de aplicación terminada`. Estimación histórica de producto `58 %` y núcleo `83 %` **NO verificadas como porcentajes actuales**. Cobertura jurídica nacional `NO_MEDIBLE`, sin denominador de normas oficiales auditado. `RELEASE=NO_GO`.

### Fuentes de código C5 confirmadas por el Director

- `server/app/Http/Controllers/Admin/RestrictionRuleController.php`: `index()` filtra `q`, `department`, `vehicle_kind`, `availability`, `management=active|inactive|all`; usa `Jurisdiction::query()` y `lazy(100)`; pagina 50. `coverageSummary()` devuelve categoría, estado y listas de fuentes/fechas; `report()` ya genera CSV con `response()->streamDownload()` y `spreadsheetSafe()` ya protege fórmulas. **Reutilizarlos; no duplicar ni el CRUD ni un motor de cobertura.**
- `server/routes/web.php`: rutas `/admin/restrictions` bajo autenticación; plantilla, importación, publicación, revisión y rollback existentes. Poner export GET estática **antes de `/{version}`**.
- `server/resources/views/admin/restrictions/index.blade.php`: filtros actuales y acciones existentes; agregar enlace de export con sus filtros sin hacer una segunda pantalla.
- `Jurisdiction::geographicUnits()` existe como relación N:M; `GeographicUnit::jurisdictions()` y `parent()` también; nivel `GeographicUnitLevel::Municipality`. **Hay municipios en el catálogo sin jurisdicción editorial: exportar solo Jurisdiction no produce una matriz nacional de municipios.**
- `mobile/lib/features/pico_placa/presentation/pico_detail_screen.dart` ya muestra incertidumbre, fuentes y vigencia; `CampaignController.php` ya tiene campañas, previsualización y controles, con publicación comercial OFF. **No reescribir estos módulos por ganar líneas.**

## 2. Leyes, bloqueos y organización de agentes

L1 KISS/Ponytail, L2 antirruido, L3 antiparches, L4 diseño humano, L5 verificación independiente, L6 antiping-pong. Cumplir `AGENTS.md`: navegación **Inicio · Garaje · Apps · Viaje · Conducir** (Apps centrado), app sin cuenta, datos versionados, sin GPS continuo, seguridad/privacidad prioritarias. No APIs pagas ni GitHub Actions (no hay presupuesto). Jamás interpretar `UNKNOWN/STALE/PARTIAL/INACTIVE/NO_JURISDICTION` como `ALLOWED` o «no tiene pico y placa».

**Un integrador** dueño del índice Git, ZIP final y decisiones de unión. Hasta **dos subagentes de escritura en árboles aislados**, con archivos disjuntos:

- **Agente A:** Laravel/Blade/rutas/tests de export. Puede avanzar inmediatamente, sin Android. No modificar Flutter.
- **Agente B:** Android en raíz Flutter verificada y, solo si cabe, QA nueva estrictamente relacionada. No modificar Laravel. Suspender procesos pesados cuando A esté ejecutando pruebas si RAM es ajustada.
- **Agente C de apoyo en solo lectura (si hay capacidad):** clasificación de secretos, comparación de inventarios, cálculo de hashes, plan de respaldo GitHub. **Ningún agente C sube archivos ni modifica WIP**; el integrador ejecuta el push tras gate.

Si los subagentes o worktrees son incompatibles con la raíz restaurada sin `.git`, crear dos **copias físicas aisladas** y reconciliar con parches limitados a propiedad de archivos. Si hay poca RAM o no existen subagentes, trabajo **secuencial** sin reducir alcance. No más de una compilación pesada al mismo tiempo.

### Arranque práctico en Windows, sin perder el candidato

1. Comprobar si la raíz integrada C5 aún existe, y que sus archivos/HEAD **coincidan de verdad**. Reutilizarla en una nueva copia aislada; no editarla in situ.
2. Si no hay candidato reutilizable, **una sola restauración desde C5 ZIP** en `D:\codex\_isolated\PICORADAR-C6-V2\integrated`. Verificar SHA del TAR y los 1.880 archivos del manifiesto. La raíz real es la que contiene `mobile\pubspec.yaml`, `server\composer.json` y `AGENTS.md`; el TAR puede incluir el directorio `picoradar-c5`. No asumir `.git`, HEAD o remotos si la fuente es snapshot sin historial.
3. Excluir junctions/enlaces externos (`server/vendor`) del inventario y de limpieza automática; nunca ejecutar `robocopy /MIR` sobre checkout protegido ni `git reset --hard` allí. Inventario WIP origen antes y después: ruta, estado, bytes y SHA de **las 43 rutas**. Si una ruta cambia, abortar operaciones que pudieran agravarlo y notificar discrepancia.
4. Leer únicamente `AGENTS.md`, las 6 leyes, ficheros afectados y pruebas causales. No lanzar otra auditoría 10×10 ni suites globales.

## 3. A — IMPLEMENTAR EXPORTACIÓN EDITORIAL Y MATRIZ MUNICIPAL NACIONAL (FUNCIONALIDAD NUEVA)

**No es una exportación de reglas jurídicas oficialmente certificadas ni un mecanismo para importar/activar normas.** Dos vistas del **mismo endpoint GET** y un solo flujo/UI, sin nuevas tablas, frameworks, servicios ni paquetes:

**A1 — Vista filtrada de editor (`scope=editorial`, predeterminada).** Exportar **todos** los resultados que coincidan con los filtros C5, no solo la página 50. Una fila por `jurisdiction × coverage` vigente en la bandeja editorial; si no hay coverage, fila `UNKNOWN`. Conservar `q`, `department`, `vehicle_kind`, `availability`, `management` con idéntica semántica a `index()`, incluyendo `attention` = UNKNOWN/PARTIAL/STALE. Reutilizar funciones y parámetros de filtros existentes mediante una pequeña extracción compartida si evita divergencias; no introducir caché N+1 ni cargar todas las jurisdicciones en RAM.

**A2 — Vista nacional de control (`scope=municipalities`).** Partir de `GeographicUnit` nivel **municipality** y generar registro para cada municipio del catálogo existente (contar denominador real del runtime, NO asumir 1.104 ni 100 % legal). Un municipio sin asignación `jurisdiction_geographic_unit` debe aparecer como `NO_JURISDICTION` + `UNKNOWN`; uno asignado pero deshabilitado conserva `MANAGEMENT_INACTIVE` separado del estado legal; uno con múltiples jurisdicciones/categorías produce las filas correspondientes, sin deduplicación que pierda datos. No fabricar categoría ni evidencia donde falten; si no hay cobertura, incluir una fila `UNKNOWN`. El parámetro `scope=municipalities` **no hereda silenciosamente el filtro `management=active` del panel**; es una vista explícita de control nacional. Reutilizar las relaciones `GeographicUnit::jurisdictions`, `Jurisdiction::geographicUnits` y los helpers del controlador. Departamento y claves canónicas desde geografía, no desde la presentación humana.

**A3 — Semántica de las columnas, PROHIBIDO confundirse:** encabezados estables (pueden añadirse si se documenta):

`scope,department_code,municipality_code,municipality_key,municipality_name,jurisdiction_key,jurisdiction_name,management_state,vehicle_kind,service_type,coverage_evidence_state,editor_version,editor_version_status,published_release,publication_state,source_urls,verified_at,valid_until,stale_after,missing_reason`.

- `editor_version` = versión de regla en el editor; **no equivale** al release publicado. `published_release` = valor derivado del dataset verdaderamente publicado y comprobable; si no se puede relacionar con el registro, columna vacía y `publication_state=UNKNOWN`, jamás `PUBLISHED` por inferencia. Nunca divulgar una versión borrador como regla vigente de circulación.
- `coverage_evidence_state` = `UNKNOWN|PARTIAL|STALE|VERIFIED` del helper editorial existente, **no certificación jurídica nacional por sí sola**. Si falta fuente, caduca, o hay regla sin vigencia suficiente, conservar estado conservador. `management_state=ACTIVE|INACTIVE|NO_JURISDICTION` es administrativo, distinto de cobertura jurídica.
- `service_type` debe ser el dato **crudo** si existe; la etiqueta combinada `category` del helper NO sustituye al tipo de servicio para análisis nacional. Las listas de URL/fechas deben serializarse sin perder elementos (separador documentado) y vacíos explícitos.
- Agregar en la página de editor un enlace/selector compacto **«Exportar vista CSV» / «Matriz municipal CSV»**, conservando `scope` y filtros; no una página o API nuevas. Ruta GET estática `admin.restrictions.coverage.export`, antes de `/{version}`. `Gate::authorize('datasets.view')` **antes de transmitir bytes**. Acceso sin permiso = 403; GET no escribe, publica, audita datos personales ni cambia la versión del dataset.
- `StreamedResponse`/`fputcsv()` reutilizando el helper existente `spreadsheetSafe()` (nombre exacto en controlador), escape de fórmulas en todos los textos no confiables (`= + - @`, tab, CR/LF y espacios iniciales relevantes), saltos de línea y comillas válidas, UTF-8; no exportar PII ni secretos. Para ambos modos usar streaming por bloques/cursor, **sin `->get()` de todo el país**. Capacidad de más de una página: prueba con 55+ registros y filtros; volumen acotado por catálogo actual, no prometer infinito.

**A4 — Test causal propio** sobre base sintética, aislada: (1) 55+ registros y exportación sin truncar/paginar; (2) filtros exactos; (3) dos municipios, uno sin jurisdicción, otro vinculado inactivo; (4) varias categorías y fuente/fecha, distinción editor/publicado; (5) CSV injection incluidas celdas que empiezan con espacios; (6) rol sin permiso 403 y base sin mutación, sin solicitudes externas. Registrar conteo de municipios **del fixture vs catálogo real**. Al menos un controlador/servicio PHP runtime y ruta/vista efectivamente modificados; sintaxis/Pint y **solo test A** + tests que cambien causalmente. Si se descubre un componente equivalente ya funcional, extenderlo sobre el déficit verificable y no duplicar.

## 4. B — ANDROID DEV DESDE LA RAÍZ CORRECTA (SIN CONVERTIRLO EN OTRO CICLO)

**B1.** En candidato aislado identificar `$mobile = Join-Path $root 'mobile'`; comprobar físicamente `$mobile\pubspec.yaml` y `$mobile\android\app\build.gradle.kts` (o archivo Gradle realmente existente) antes de compilar. Reportar carpeta efectiva (`Get-Location`), Flutter/JDK, hash `pubspec.lock`, variante `dev` y memoria libre **justo antes**. No copiar un comando de una raíz antigua.

**B2.** Finalizar procesos pesados **iniciados por este lote** (no ajenos), dejar CPU/RAM libre, medir RAM. Umbral previamente aprobado **mínimo 6 GiB libres**. Si < 6 GiB: `ANDROID=BLOCKED_RESOURCE`, no iniciar Gradle; **continuar A y C**. No falsear memoria ni bajar el umbral para subir marcador.

**B3.** Si >= 6 GiB, copiar SHA y contenidos temporales de `mobile/android/gradle.properties`; usar máximo workers 1 y JVM proporcional (`-Xmx3G`, metaspace ≤768m) y `kotlin.incremental=false` **solo si ataca el fallo previo por caché cruzada**. Dejar flags temporales fuera del commit y restaurar SHA original en `finally`. Desde la carpeta `mobile` ejecutar **un** `flutter build apk --debug --flavor dev --no-pub` con log completo. Preflight `flutter pub get --offline` solamente si falta una dependencia cacheada; sin cambios sorpresivos de lockfile ni descargas comerciales. No ejecutar Gradle ni más de una compilación pesada simultáneas.

**B4.** Si falla y el primer error causal tiene reparación local obvia y comprobable (p.ej. incompatibilidad de caché incremental), permitir **un segundo intento como máximo**, tras modificación focal documentada; jamás loop automático, borrado indiscriminado de Gradle, eliminación de junctions ni modificación del checkout protegido. Si no, `FAIL_CAUSAL`/`BLOCKED_ENV` con línea/archivo real del primer error. Si APK existe, verificar SHA-256, nombre de package/applicationId/flavor `dev`, tamaño y `AndroidManifest`, incorporar APK al ZIP **solo si no contiene secretos**. Sin ADB, instalación ni QA físico en Mi A3 sin autorización y firma compatible. `DEVICE_QA=NOT_RUN` hasta entonces.

**B5.** No repetir 3.365 Flutter, pruebas Drift ni widgets C4/C5 si no hay cambios Flutter. No añadir pantalla cosmética para compensar un build bloqueado. QA offline física y HTTPS no quedan PASS por test de transporte simulado.

## 5. C — ACTUALIZAR GITHUB CON CÓDIGO, SIN MERGE DE HISTORIAS NI SECRETOS

El original C6 exigía resolver previamente las **838 diferencias** con `main` antes de tener cualquier respaldo remoto, lo que arriesga otro `HOLD`. **Separar DOS estados diferentes:** `REMOTE_SOURCE_BACKUP` (respaldo en GitHub) y `MAIN_INTEGRATION` (integración compatible con `main`). Un PASS del primero **NO** implica PASS del segundo.

**C1. Preflight único y seguridad:** verificar SSH/HTTPS `origin` sin revelar token; consultar `main` y PR #79 una vez. Del HEAD C6 fuente crear copia fuente **desde el árbol integrado limpio**, sin `.git` histórico, caches, vendor, `.env` real, llave, base de datos privada, datos de clientes ni symlinks a rutas exteriores. Verificar hashes de **todos** los archivos contra `SOURCE_MANIFEST_C6.csv` y restaurar una vez en directorio vacío. Detectar rutas mayores de 50/100 MiB y archivos binarios inesperados. **No usar el worktree con la eliminación incidental**.

**C2. Gate de seguridad antes de cualquier push público:** usar scanner libre instalado (gitleaks, detect-secrets, etc.) si existe. Si no existe, no fingir PASS: ejecutar barrido local reproducible con Python estándar + `git grep`/regex de patrones y entropía de candidatos, extensiones privadas, URLs con userinfo y archivos `.env*`; un segundo revisor (agente solo lectura) clasifica cada hallazgo sin imprimir sus valores. Documentar `STANDARD_SCANNER=UNAVAILABLE` y `MANUAL_REVIEW_SCOPE=...`. **Cualquier posible secreto o archivo no explicado = HOLD de push**, no bloquear A/B. Ejemplos/fixtures deben ser acreditados como tales, no blanqueados automáticamente. Nunca instalar tool de pago. No subir fichero con credencial a repositorio público.

**C3. RESPALDO DE CÓDIGO (sin mezcla, rama distinta):** después de gate limpio, crear en una **copia limpia nueva** un historial Git de **un único commit raíz** (source-only, sin historia sintética antigua), rama `backup/picoradar-c6-source-20261120` **solo para recuperación**, y hacer **un push no forzado** al repo público. Comprobar que esa rama no exista previamente (si existe, usar sufijo corto del hash de árbol, sin sobrescribir) y `git ls-remote`/fetch remoto posterior; guardar URL, SHA commit y tree remoto y comparar el inventario de código 1:1. Esta rama **no tiene que compartir ancestro con `main`, porque jamás se hará merge de ella**. Etiquetar en README de recuperación `BACKUP_ONLY_NOT_MERGE_READY`, sin nuevo servicio de despliegue ni release. Prohibido `push --force`, `--allow-unrelated-histories`, PR a `main` y tocar PR #79. Si el usuario no concedió acceso/escritura o hay 403, registrar bloqueo exacto y **devolver ZIP autónomo**; no insistir con múltiples pushes.

**C4. INTEGRACIÓN REAL (NO CONFUNDIR CON BACKUP):** en una rama **separada** descendiente de `origin/main`, registrar lista de 838 diferencias C5↔main y diferencias C6, compatibilidad de código, ficheros exclusivos y decisiones de conflicto; NO reemplazar masivamente el árbol de main. Pueden prepararse commits de módulos aislados **solo si** encajan, pasan pruebas propias y seguridad, sin utilizar historial sintético; de otro modo `MAIN_INTEGRATION=HOLD_COMPATIBILITY`. Este paso es posterior al respaldo fuente y nunca debe impedir que A/B avancen. Si un módulo seguro pequeño es integrable durante este macrobloque, subirlo a rama separada no productiva con su prueba; **no crear PR de merge si quedan 838 diferencias sin resolver**.

**C5. Recuperación obligatoria incluso con GitHub PASS:** `SOURCE_RECOVERY_C6.tar.gz` source-only en ZIP único, `SOURCE_MANIFEST_C6.csv` con SHA/tamaño, inventario de archivos omitidos y restauración desde carpeta vacía **100 % verificada**. Guardar la diferencia nueva `CODE_DIFF_C5_TO_C6.patch` o manifiesto de cambios con hash, no solo informes.

## 6. D — NO REPETIR LO QUE YA PASÓ; CERRAR EL PRODUCTO POR GATES

- La consulta nacional, motor tipado, permisos Super Admin, importación, publicación/rollback, Drift/offline de componente, campañas y patrocinadores locales existen. **No reconstruirlos**; no crear servicios comerciales ni activar publicidad. El objetivo de anuncios Free 1.0 es OFF y fail-closed.
- No introducir reglas nacionales ni fuentes jurídicas inventadas. `GeographicUnit` cubre catálogo geográfico, **no cumplimiento legal**. Publicar normativas requiere fuente oficial y vigencia por municipio/categoría. Un CSV `UNKNOWN` es una tarea editorial, no autorización de circulación.
- Sin nuevo origen HTTPS configurado, no simular `HTTPS_REAL_PASS`. Sin QA física, no declarar `ANDROID_DEVICE_PASS`. Sin APK no declarar lanzamiento listo. `RELEASE=NO_GO` y `GITHUB_PRODUCT_HOLD` hasta puertas de seguridad/producción.
- **Si** el nuevo CSV expone datos publicados a Flutter, crear únicamente la prueba causal necesaria. No transferir CSV editorial ni borradores a clientes públicos; los clientes consumen solo releases publicados y validados. Si solo es descarga administrativa, no reejecutar puente C2.
- Integrador: consolidar A+B+C, resolver conflictos sin perder código, ejecutar `git diff --check`, cambios PHP mínimos y las pruebas nuevas, proteger archivo eliminado incidental, contabilizar rutas runtime nuevas y verificar no regresiones causales. No correr auditoría 10×10 ni suites completas.

## 7. Priorización de salida, aunque un frente falle

1. **P0:** cero cambios a 43 WIP y recuperación C6 exacta.
2. **P1:** A1+A2 exportación editorial + matriz nacional con tests y UX. Este es el trabajo nuevo que sí suma funcionalidad.
3. **P2:** C3 rama respaldo GitHub de código real si seguridad pasa (distinta de integración main).
4. **P3:** B Android válido; si la RAM no permite, estado `BLOCKED_RESOURCE` y terminar P1/P2.
5. **P4:** integración segura incremental con `main` y preparación de gates HTTPS/dispositivo cuando existan recursos/autoridad. No condicionar P1 a P4.

Estados aceptados: `PASS_SCOPED`, `FAIL_CAUSAL`, `BLOCKED_RESOURCE`, `BLOCKED_AUTH`, `HOLD_SECURITY`, `HOLD_COMPATIBILITY`, `NOT_RUN_EXTERNAL`, `PASS_REUSED`. Un diagnóstico de bloqueo **debe incluir lo implementado por los otros agentes**, no interrumpir el macrobloque.

## 8. Medición real: NO CONFUNDIR 58, 61 Y 100

- **61/100** = puntuación de verificación del scorecard C5, NO porcentaje de producto. No cambiar pesos o criterios para inflarla. Si A queda verificado pero el rubro editor ya está al máximo, registrar `NEW_FEATURE_PASS=1` **sin regalar puntos**.
- **58 %** = estimación histórica de terminación integral que nunca tuvo denominador reproducible. **Etiquetar `HISTORICAL_UNVERIFIED`**, no reemplazar por 61 % ni incrementar por prompts o documentación.
- **83 %** = estimación histórica del núcleo técnico, igualmente sin métrica nueva. **No atribuir 100 % a motor nacional** por disponer del catálogo geográfico.
- `PRODUCT_DELIVERY_MATRIX.csv`: por cada módulo [motor, legal nacional, editor, servidor, superadmin, campañas, Flutter, offline/OTA, Android, HTTPS, GitHub backup, integración principal], registrar `implemented`, `local_tested`, `end_to_end_tested`, `deployed`, `official_coverage_verified`, evidencia/hash y bloqueo. Añadir `delta_runtime_files`, `new_user_flows`, `new_app_binary`, `remote_code_sha` y fecha. **Solo otorgar porcentaje de desarrollo nuevo cuando haya definición reproducible**; mientras tanto `PRODUCT_DEV_PERCENT=NO_MEDIBLE`.
- `LEGAL_COVERAGE`: numerador/denominador por municipio **y** tipo/categoría a partir de normas oficiales verificadas. Si no existen, `NO_MEDIBLE`; no usar municipios del selector como fuente de ley.

## 9. Auditoría diferencial del PROMPT C6: 10 VERDUGO + 10 JUEZ (EL DIRECTOR YA LA HIZO)

| Verdugo | Defecto detectado | Corrección aplicada |
|---|---|---|
| V1 | C6 exportaba solo jurisdicciones y omitía municipios sin gestión | `scope=municipalities` desde GeographicUnit |
| V2 | Confundía estado editorial y regla publicada | columnas separadas de versión y publicación |
| V3 | `current_version` ambiguo | `editor_version` y `published_release` sin inferencia |
| V4 | `category` traducida no preserva serviceType crudo | conservar `vehicle_kind` y `service_type` |
| V5 | Exportar página 1 aparentaba totalidad nacional | streaming y prueba 55+ registros |
| V6 | CSV con fórmulas/PII o GET mutador | helper seguro, Gate y prueba de no mutación |
| V7 | C6 supeditaba backup a 838 diferencias main | backup-only separada sin merge |
| V8 | Push de historial sintético o archivo privado | commit raíz nuevo, scanner/revisión independiente |
| V9 | Nuevo fallo Android por carpeta o JVM 8G | preflight real mobile, RAM y gradle reversible |
| V10 | Otro PARTIAL sin ninguna fuente de código recuperable | restauración completa TAR+hash, ZIP uno |

| Juez | Decisión y justificación | Criterio de aceptación |
|---|---|---|
| J1 | Priorizar export nacional; llena brecha operativa | editor CSV y municipio UNKNOWN en runtime |
| J2 | Mantener CSV solo administrativo | borradores nunca visibles al cliente |
| J3 | Aprovechar Jurisdiction/GeographicUnit existentes | sin tabla nueva ni framework |
| J4 | Reusar `coverageSummary` y `spreadsheetSafe` | sin motor/funciones duplicadas |
| J5 | Proteger permisos `datasets.view` | 403 y cero mutaciones |
| J6 | Reusar QA C2–C5 aprobada | solo pruebas nuevas afectadas |
| J7 | Android condicionado a RAM y causa real | log comando desde mobile, APK o bloqueo causal |
| J8 | Backup-only no es merge | URL SHA remoto; main/PR79 intactos |
| J9 | Seguridad tiene veto real sobre publicación | HOLD si hallazgos sin resolver, sin datos filtrados |
| J10 | Un solo integrador y ZIP | cambios y evidencias recuperables sin ping-pong |

Codex **NO reejecutará** estas 20 pasadas. Debe programar y evidenciar resultados, no crear otros prompts.

## 10. ÚNICO ZIP DE RETORNO

Ruta sugerida `D:\codex\_REPORTES\PicoRadar\C6-V2-20261120\PICORADAR_C6_RETORNO_UNICO.zip`. Archivos internos (no adjuntarlos aparte):

- `FINAL_REPORT.md`: resumen diferencias desde C5, archivos runtime modificados, resultados A1/A2/B/C reales, fecha, SHA de HEAD/tree si hay Git, ruta real Android, memoria libre, estado APK, GitHub y `NEXT=CHATGPT_DIRECTOR`.
- `FEATURES_BEFORE_AFTER.csv`, `PRODUCT_DELIVERY_MATRIX.csv`, `SCORECARD_C5_C6.csv` **misma rúbrica 61/100**, `LEGAL_COVERAGE_STATUS.csv` con evidencia/rastreo, nunca municipios inventados.
- `QA/php_new_export.log`, `QA/flutter_or_android_build.log` solo si se ejecutaron; logs de nueva función y comandos, CSV de ejemplo **sintético y anonimizado** con municipios con/sin jurisdicción y resultados comprobados. `APK_DEV.apk` con SHA solamente si realmente existe, es DEV y fue inspeccionada.
- `GITHUB_CODE_STATUS.md`: `REMOTE_SOURCE_BACKUP=PASS/HOLD`, `MAIN_INTEGRATION=PASS/HOLD`, URL rama, commit/tree remoto si existe, firma de seguridad (sin exponer valores), divergencia 838 y motivo exacto de hold.
- `SECURITY_GATE.md` y lista de hallazgos **sin secretos**; `WIP_BEFORE_AFTER.csv` por ruta, bytes y hash, `SOURCE_MANIFEST_C6.csv`, `SOURCE_RECOVERY_C6.tar.gz`, `RECONSTRUCTION.md` (extracción vacía y 100 % hashes verificables), `CODE_DIFF_C5_TO_C6.patch` o listado con hashes.
- `GATES.csv`: separar tests locales, cobertura nacional, GitHub backup, integración main, APK, dispositivo, HTTPS, comercial ads OFF, release NO_GO.
- `MANIFEST.csv` con **cada miembro del ZIP excepto el propio manifiesto**, tamaño, SHA-256 y CRC32; validar CRC central/sha. **Un solo ZIP**, sin ZIP anidado, credenciales, WIP protegido ni falsas evidencias.

**Respuesta final de Codex al usuario:** `TASK_ID`, `RESULT`, nuevos archivos de producción, tests y aserciones nuevas, C5→C6, `ANDROID`, `APK_SHA256` si existe, `REMOTE_SOURCE_BACKUP`, `MAIN_INTEGRATION`, `WIP=43/43`, `RELEASE=NO_GO`, ruta ZIP y SHA-256, `NEXT=CHATGPT_DIRECTOR`. Si un frente falla, cerrar y documentar los otros. No pedir nueva orden para continuar trabajo permitido.

# 🔴🔴🔴 SIGUE: CODEX LUNA — EJECUTAR C6 V2 Y DEVOLVER UN ÚNICO ZIP 🔴🔴🔴

**DESPUÉS DEL ZIP CONTINÚA: CHATGPT DIRECTOR.**
