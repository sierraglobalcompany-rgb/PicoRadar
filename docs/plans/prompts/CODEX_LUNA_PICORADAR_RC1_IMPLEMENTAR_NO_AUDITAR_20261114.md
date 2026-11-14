# CODEX LUNA — PICORADAR RC1 — DESARROLLO Y CIERRE FUNCIONAL, NO OTRA AUDITORÍA

**TASK_ID:** `PICORADAR-RC1-ADMIN-SCHEMA2-PUBLISHER-ANDROID-REALBUILD-20261114`  
**DIRECTOR:** ChatGPT. **EJECUTOR:** Codex Luna. **SIGUIENTE DESPUÉS DEL ZIP:** ChatGPT Director.  
**Objetivo:** salir del bucle de informes y obtener avances **funcionales** sobre el panel nacional, el publicador y una APK Android de pruebas. **NO crear V8 de auditoría, NO repetir F0/F1/F2/G2**, ni investigar de nuevo el antivirus, el SHA de Power BI, los 1.839 archivos Gitleaks o los 14 Python PASS si nada en ellos cambió.

## 0. Entradas e invariantes congeladas

1. Código BASE real restaurable del ZIP V6: `HEAD=15948a50332589ff3d1fb3157b6976809fe5a680`, `TREE=8e0b8cd1de0607e9baeeffcfac93c8f141afb67f`; repo canónico `sierraglobalcompany-rgb/PicoRadar`, 12 commits posteriores al PR71. Trabajar **solo en clon/worktree aislado** de `D:\codex\PicoRadar-RC1` o reusar el aislado previo SI el HEAD y worktree limpio coinciden y no hay otro escritor. No reemplazar por `main` antiguo. Mantener rama `feat/picoradar-v6r4-lab-candidate` o crear una rama nueva hija RC1 sin forzar bases.
2. ZIP de entrada de ESTE mensaje: `PICORADAR_RC1_SCHEMA2_ADMIN_PATCH_Y_ORDEN.zip`; contiene `PATCHES/0001-guard-legacy-form-for-schema2.patch`, `EVIDENCIA/DIFF_STAT.txt` y este prompt. Archivo `PATCHES/0001-...` corresponde a **3 rutas exactas**, elaborado por el Director sobre el HEAD indicado; no modificar otros archivos para aplicarlo. Verificar `git apply --check` antes de `git apply`; si patch ya está aplicado, reconocer y NO duplicar. Si checkout no coincide, STOP y restaurar solo desde bundle V6 validado.
3. Contratos: **un solo motor** schema2 (Flutter/Dart), fuente editable por jurisdicción y combinación válida de vehículo/servicio, metadata/leyes desde JSON por autoridad/municipio/departamento/pueblo, sincronización OTA por manifest/SHA, `UNKNOWN/STALE` cuando falten vigencia/ámbito/aprobación. La información LAB (14 autoridades, 33 DIVIPOLA, 21 pares parcial, 115 reglas) NO es producto nacional validado; no publicar LAB parcial como sustituto de datos aprobados ni inventar decretos. Comunicados oficiales sí acreditan sus campos expresos aunque falte PDF del decreto. Mantener el riesgo festivos de Dosquebradas y los seis HOLD legales anteriores sin bloquear pruebas sintéticas de software.
4. Respetar `AGENTS.md`, contrato visual y privacidad. Un solo monolito Laravel y una sola app Flutter/Drift: NO crear motor por ciudad, microservicio, cron duplicado, API diaria de circulación, ni segundo publicador. Nada Hostinger, prod, datos reales de usuarios, merge a main, modificar firma de app instalada, instalar Mi A3 ni consumir Actions de pago. No ejecutar el `.ps1` en cuarentena o reportes `.private.json`. Usuario ha indicado que Bitdefender está desactivado: no tratar eso como PASS de seguridad ni exigir otro informe/diagnóstico de antivirus para **continuar desarrollando en QA aislada**. Mantener el estado de seguridad explícito únicamente para un eventual push/producción.

## 1. BLOQUE A — CORREGIR PANEL NACIONAL SIN REDISEÑAR EL MOTOR (trabajo productivo)

A1. Aplicar el **parche ya escrito**, verificando tres archivos:
- `server/app/Http/Controllers/Admin/RestrictionRuleController.php`;
- `server/resources/views/admin/restrictions/form.blade.php`;
- `server/tests/Feature/RestrictionRouteIntegrationTest.php`.

**Causa:** el formulario humano B07 soporta subset legado schema1, mientras el importador JSON, validador y motor schema2 soportan más combinaciones (`truck`, `bus`, `motocarro`, `car:special`, etc.), condiciones y `coverageCompleteness`. Si se abre una versión schema2, el formulario legado podría reconstruirla sin esos campos. El parche impide editarla desde ese formulario, ofrece **Importar JSON schema2** y deja el payload intacto; también impide mostrar como editable una versión no-Draft. NO añadir simplemente nuevas opciones al `<select>`: eso generaría falsa compatibilidad sin implementar el contrato completo. El importador `RestrictionImportService` YA acepta schema2; reusarlo.

A2. Ejecutar `git diff --check`, `php -l` en controlador y test; PHP formatter focal si disponible. Ejecutar **solo** el test nuevo `RestrictionRouteIntegrationTest::test_schema2_draft_cannot_be_downgraded_by_legacy_form` y, si es necesario, el test legado `test_editor_creates_a_city_draft_with_human_fields_instead_of_json`. Siempre en DB sintética MariaDB QA (o SQLite TEST aislado si es fiable), con `APP_KEY` sintética y `database.default/host/port/database` comprobados ANTES de migrar. Si `vendor/` falta, usar Composer locked y caché gratuita; NO alterar lockfiles. Una falla RED permite una corrección causal mínima y reejecución del mismo test, NO 33 pruebas F2 otra vez.

A3. Usar un fixture schema2 sintético con **una combinación no legado** (`truck:public_cargo` o `bus:public_passenger`), `coverageCompleteness=partial`, `conditions` permitidas, fechas con offset y `sourceUrls` HTTPS, para validar **por el flujo existente** `JSON -> analizar -> confirmar -> borrador` y que ninguna ruta de panel elimina condiciones al guardar. Si el test de importación schema2 ya está en los logs aprobados del mismo HEAD, citarlo, NO repetir; si falta evidencia, una sola prueba focal. Para cobertura sin restricción real, NO convertir `enabled=false` ni ausencia de datos en libre circulación.

**Salida A:** `ADMIN_SCHEMA2_PROTECTED_PASS` si los dos tipos de borrador funcionan sin pérdida de contrato, o error real con archivo/línea, no paquete de diagnóstico interminable.

## 2. BLOQUE B — ADMINISTRACIÓN/PUBLICACIÓN: CERRAR TRES PRUEBAS REALMENTE PENDIENTES

B1. F2 33/279 PHPUnit y G2 bridge Laravel bytes→Flutter **YA PASARON** para base V6R4; NO reejecutarlos. Lo único no demostrado en V5 es:
- `Tests\Feature\RestrictionPublicationServiceTest::test_selective_publication_and_city_rollback_preserve_other_cities`
- `Tests\Feature\RestrictionPublicationServiceTest::test_normal_publication_rejects_coverage_loss_before_writing_release`
- `Tests\Feature\RestrictionMaterialApprovalWorkflowTest::test_active_admin_approval_is_bound_to_exact_city_sha_sources_and_revision_then_published_separately`

B2. Ejecutar **exactamente estos tres** en una sola selección focal de PHPUnit; listar primero los tests para evitar falso PASS por filtro vacío. MariaDB efímera loopback, destino validado por cliente y Laravel resuelto, `DB_URL` vacío, APP_KEY sintética, `explicit_defaults_for_timestamp=ON`, SQL estricto; apagar y verificar puerto cerrado. Si ya hay evidencias de esos tres con el mismo SHA, reutilizarlas, no reejecutar.

B3. Si tres PASS, dar por validado el **núcleo de aprobación editorial, no pérdida de coberturas, publicación/rollback selectivo** en QA. Siguientes fases de datos: snapshot completo relativo a la BASE aprobada, signed/hashed manifest según código vigente, staging aislado con origen controlado, rollback y consumo Drift. NO tratar un laboratorio de 14 jurisdicciones como si tuviese todos los municipios de Colombia. No inventar URLs externas ni créditos de fuente.

**Salida B:** `ADMIN_PUBLICATION_PASS_3_FOCAL` o `BLOCKED_QA_DB` con causa concreta. No continuar con más debates legales si las pruebas son sintéticas.

## 3. BLOQUE C — APK: DESBLOQUEAR EL BUILD REAL, NO SUPONER QUE 3,37 GiB DE PAGEFILE LO IMPIDEN PARA SIEMPRE

C1. Preflight de Windows **una vez**: memoria física disponible, memoria comprometida y límite de commit, espacio de disco, JDK 17, Flutter 3.47.9/Dart compatible, SDK API y Gradle cache; obtener cifras REALES del sistema ACTUAL. `mobile/android/gradle.properties` establece máximos generosos `-Xmx8G -XX:MaxMetaspaceSize=4G`. Una cifra histórica de **pagefile libre=3,37 GiB** NO es medición equivalente del total de memoria disponible; no omitir build únicamente por ese dato viejo.

C2. Si la medición demuestra margen suficiente, compilar una **APK DEBUG DEV** usando el comando ya verificado en `README.md` (`flutter build apk --debug --flavor dev --dart-define=APP_ENV=dev ...`, Kotlin incremental false/in-process y no Gradle daemon según opción disponible). Reusar lockfiles, toolchain y caches sin internet si es posible. No hacer `flutter upgrade`, Gradle/Android plugin upgrade, bajar `targetSdk`, cambiar la firma/certificado o usar credenciales reales.

C3. Si la opción actual de `-Xmx8G` impide arrancar, en un clon QA se permite **una sola variante acotada**, sin commit/product change: respaldar `mobile/android/gradle.properties`, fijar temporalmente un heap de desarrollo basado en RAM/commit comprobados (p.ej. 3–4 GiB y metaspace 1 GiB si hay margen REAL), Gradle `--no-daemon`, máximo dos workers, Kotlin in-process, ejecutar un único build debug, después restaurar ese archivo y verificar diff. No borrar caché global ni disminuir valores a ciegas. Si falla por memoria, registrar exit/stack resumido y `ANDROID_BLOCKED_REAL_MEMORY`, sin intentos infinitos.

C4. Si `APK PASS`, guardar `app-dev-debug.apk`, bytes y SHA, arrancarla primero en emulador/dispositivo de QA alterno SI está disponible. No desinstalar PicoRadar actual ni intervenir Mi A3 sin autorización. Hacer smoke: abre shell, Garaje y persistencia, Inicio/consulta ciudad, `UNKNOWN/STALE` seguro, simulación OTA QA, mapa/cámaras básicos y sin crash. Solo afirmar “build debug local” y “smoke de emulador” si realmente hay evidencia. No declarar release firmado de Play Store.

**Salida C:** `APK_DEV_DEBUG_PASS` con APK y SHA, o `ANDROID_BLOCKED_MEASURED` con memoria real y mínima salida accionable.

## 4. BLOQUE D — DATOS NACIONALES Y GITHUB SIN VOLVER A INVENTARIAR

D1. Confirmar catálogo de datos habilitables **YA EXISTENTE** (autoridades y municipios con/sin cobertura) y que reglas nuevas entran por importación JSON schema2 sin APK. Si falta un **conmutador editorial por autoridad/par** en el flujo que realmente usa el cliente, registrar el archivo/contrato preciso; implementar solo la menor pieza necesaria y test focal, NO reescribir motor. Continuar introduciendo **solo fuentes institucionales verificadas**; fuente oficial web suficiente para campos expresos. Cualquier contenido no certificado queda partial/UNKNOWN, no “permitido circular”. La expansión nacional es una operación de carga editorial, no 1.104 ramas de código.

D2. GitHub: priorizar que el código V6R4 + cambios RC1 quede recuperable remotamente, en **rama LAB sin merge**, únicamente tras comprobar que los cambios nuevos y su historia no divulgan secretos. Nueve coincidencias Gitleaks V6 estaban clasificadas como benignas, una URL PowerBI histórica del PR71 se mantiene `UNKNOWN`; no copiarla a nuevos informes ni abrirla. Si no hay evidencia suficiente para publicar la historia, mantener `GITHUB_HOLD_SECURITY`, entregar bundle restaurable como parte del ZIP y **seguir A/B/C**: la incertidumbre de un enlace histórico NO bloquea el desarrollo local de APK/panel. No preparar PR/merge a main ni tocar producción. Si se verifica con fuente institucional igualdad exacta en memoria y el resto del control está aprobado, un solo `push` normal de rama LAB y comprobación SHA; no `force` ni acciones pagas.

D3. Documentar brechas **funcionales** de lanzamiento, no repetir un inventario general: publicación/staging protegido, QA Android física, firma de producción, fuentes oficiales por cobertura y permisos de despliegue. Conservar los PASS previos en una línea con su SHA; no volver a enumerar 10 + 10 auditorías ni pedir otra fase para revisar el propio prompt.

## 5. Entrega en UN ZIP y continuidad

Generar SOLO `D:\codex\_REPORTES\PicoRadar\RC1-ADMIN-PUBLISHER-APK-20261114\delivery\PICORADAR_RC1_AVANCE_FUNCIONAL_EVIDENCIA_UNICA.zip` con:

- `FINAL_REPORT.md`: qué código cambió, tres resultados A/B/C, el estado GitHub D y los *únicos* bloqueos reales al lanzamiento; SHA inicial/final, modificaciones, autorizaciones no usadas, `NEXT_ACTOR=CHATGPT_DIRECTOR`.
- `LOGS/`: tests PHP **focales** y su exit real, app build solo si se ejecutó, smoke solo si existe.
- `GIT/full-final.bundle` restaurable: incluir commits del HEAD final con historial necesario para continuar; validar clon limpio, HEAD/TREE y `git status --porcelain`.
- `APK/app-dev-debug.apk` **solo si el build pasó**; SHA-256 registrado. No APK de mentiras.
- `MANIFEST.csv` con tamaños+SHA+CRC; validar CRC/miembros al cerrar. No reportes Gitleaks privados, enlaces opacos, llaves QA ni archivos personales.

**Un solo ZIP final, NO 10 archivos regados.** Una sola respuesta corta: `TASK_ID | ADMIN_SCHEMA2=... | ADMIN_3=... | APK=... | GITHUB=... | HEAD=... | TREE=... | ZIP_SHA256=... | PRODUCT_RELEASE=NO_GO | NEXT_ACTOR=CHATGPT_DIRECTOR`.

**Regla de fin del bloque:** ENTREGAR AVANCE DE PRODUCTO. No responder solo con una lista de riesgos, una auditoría más o una nueva propuesta de V8. Corregir de forma mínima hasta producir el resultado de A, B y C dentro de los límites indicados.