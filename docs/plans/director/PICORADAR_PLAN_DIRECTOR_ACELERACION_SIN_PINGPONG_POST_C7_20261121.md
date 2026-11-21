# PICORADAR — PLAN DIRECTOR DE ACELERACIÓN, CIERRE Y CONTROL DE PING-PONG

**Tipo:** documento de dirección / auditoría independiente, **NO es un prompt para ejecutar ahora**.  
**Fecha de corte:** 21/11/2026, Colombia.  
**Estado de ejecución:** **CODEX LUNA ESTÁ TRABAJANDO C7-V2** (`PICORADAR-C7-V2-IMPLEMENTACION-NACIONAL-20261121`). **NO interrumpir, reiniciar, duplicar ni cambiar su orden en curso.**  
**Próximo responsable del análisis:** **CHATGPT DIRECTOR cuando llegue el ZIP ligero C7-V2**.  
**Repositorio:** `sierraglobalcompany-rgb/PicoRadar`.  
**Origen de código comprobado:** `backup/picoradar-c6-source-20261120` → commit `bc1422c7198607850a49f4a294ed67316fed0805`, tree `2c0fd2e7a4ef8eed5b342101afb7320982d3c07c`, 1.882 blobs.  
**`main` observado:** `e9ef37511df3110ffb0fc006ef06be781df432ac`; **PR #79:** Draft, otra base, no tocar.  
**Rama de documentación de dirección:** `director/n5-modality-safe-20261118`. No editar ni hacer push a la rama de código C7 mientras Codex la use.

> **Decisión ejecutiva:** pasar de «un prompt → un pequeño entregable → otra auditoría del prompt» a **olas de producto con 3 entregables funcionales independientes**, más integración y pruebas causales. El 100 % debe representar un contrato de producto y de lanzamiento aceptado, no el número de reportes ni el resultado de una rúbrica que estaba diseñada para otra cosa.

---

## 1. Fuente, certezas y límites del análisis

Se revisaron: **(1)** el contenido íntegro de `CODEX_LUNA_PICORADAR_C7_V2_NACIONAL_FUNCIONAL_QA_LIGERO_20261121.md`; **(2)** reporte, gates, seguridad y GitHub dentro del ZIP C6; **(3)** el árbol/código C6 publicado en GitHub, incluyendo `AGENTS.md`, `docs/CURRENT.md`, `docs/SOP.md`, `docs/DESIGN_CONTRACT.md`, `RestrictionRuleController`, `RestrictionPublicationService`, `DatasetSyncService`, la navegación Flutter y el catálogo de aliados; **(4)** estado remoto de GitHub y PR #79. El ZIP C7 **todavía no existe como entrega recibida**: sus resultados no pueden presuponerse.

**Hechos acreditados:**

- C2 probó el puente HTTP local Laravel → Flutter; no certifica HTTPS público ni el dispositivo.
- C3 aportó **solo pruebas**, no código runtime nuevo; score de evidencia 37→59.
- C4 agregó 3 rutas runtime y 2 pruebas; cierre funcional de bandeja editorial/UX, 59→60,5; el intento Android falló antes de Gradle.
- C5 implementó flujos A+B; score 60,5→61; sin APK por RAM.
- C6 implementó export CSV editorial y matriz de 1.104 municipios, compiló **APK debug** (sin QA física) y creó respaldo remoto con 1.882 blobs; score permanece 61.
- C6 no modificó reglas normativas, el motor, API pública, migraciones ni contratos; la compilación APK no equivale a validación física.
- `docs/CURRENT.md` del respaldo tiene actualización **21/10/2026** y por tanto es **documento histórico**, no una medición actual de cobertura ni un reporte final de C6/C7. Debe actualizarse **una vez por entrega aprobada**, no con cada prompt.
- El baseline limita Free 1.0: sin cuenta obligatoria, sin enviar GPS continuo al servidor, sin monetización pública, campañas/pagos/premium **OFF**, navegación exacta `Inicio · Garaje · Apps · Viaje · Conducir`; **Apps al centro**.

**No está acreditado:** aceptación física, HTTPS de staging real, reglas oficiales completas para 1.104 municipios, AAB firmado de producción, Play Console, integración de código en `main`, activación comercial, ni resultado de C7.

## 2. Causa raíz: errores que debe corregir CHATGPT DIRECTOR

| Causa | Evidencia de la serie | Cambio obligatorio de dirección |
|---|---|---|
| R1. Un «macrobloque» equivale a una sola pieza pequeña | C6 entregó CSV; C7 prescribe una pantalla municipal nueva | Cada ola debe entregar **tres capacidades de producción independientes**, si la base y recursos lo permiten; un bloqueo no detiene las otras dos |
| R2. Auditar el prompt después de haberlo entregado | Versiones C2/V2, C3/V2, C4/V2, C5/V2, C6/V2, C7/V2 | **Un único pase de calidad antes de publicarlo** y solo corregir tras detectar un fallo material nuevo. No obligar a Codex a repetir 10×10 |
| R3. Los tests se confunden con trabajo de producto | C3: tres archivos de pruebas, 0 código runtime | Registrar por separado `NEW_RUNTIME_FEATURES`, `TESTS_NEW`, `GATES_CLOSED`, `LEGAL_VERIFIED`, `REMOTE_CODE_SHA` |
| R4. Plataforma consume el lote entero | C1/C2 hooks, C4 root incorrecto, C5 RAM, C6 Kotlin | **Track de infraestructura separado**, como trabajo del integrador. La aprobación de un motor/editor nunca depende de un APK nuevo salvo cambio de plataforma |
| R5. Backup GitHub se trató como merge | 838 rutas divergentes; C6 solo logró backup source-only | Mantener **dos gates independientes**: código recuperable remoto y convergencia segura con `main`; jamás force-push o merge a ciegas |
| R6. Confusión de metas | 58 % histórico, 61/100 evidencia; no denominador de 100 % | Congelar **contrato Free 1.0**, **cumplimiento legal territorial** y **monetización post-Free** por separado |
| R7. Enfoque en áreas ya máximas de la rúbrica | Editor 12/12, permisos 9/9 y publicación 11/11 mientras faltan motor/legal/OTA/HTTPS/Android | Dirigir código a las brechas de mayor riesgo, no subir puntos con otra vista equivalente |
| R8. Paralelismo anunciado, no demostrado | Prompts permitieron subagentes; retornos no acreditan tiempos/trabajos independientes | 2–3 tareas disjuntas, cada una con patch/commit + tests propios; integrador único y prueba de contribución; si no hay agentes, igual ejecutar secuencial sin replanificar |
| R9. La cobertura geográfica se confunde con cobertura legal | C6: 33 departamentos y 1.104 municipios, con legal `NO_MEDIBLE` | Medir por **unidad jurídica elegible**, acto oficial, categoría, vigencia y revisión; no por cantidad de filas geográficas |
| R10. Sobrecarga de evidencias/artefactos | ZIPs de 74 MB y múltiples reconstrucciones | Rama GitHub como fuente de código; **un ZIP ≤2 MiB objetivo, máximo 5 MiB**, solo informe, gates, logs focales y diff; **sin APK/TAR/bundle** |

**Responsabilidad:** el diseño de estos lotes fue del director. Los límites de RAM, seguridad y permisos explican bloqueos concretos; **no justifican reencargar tantas veces documentación, cachés o pruebas antiguas**. No convertir Codex en el responsable de decidir el alcance o rediseñar el plan.

## 3. El 58 % y el 61/100: reglas para no volver a engañarnos

**58 %** = estimación histórica de desarrollo, **sin fórmula auditada**. No es un avance actual verificado. **83 %** para «núcleo técnico nacional» también es una estimación histórica. **61/100** = rúbrica de **evidencia local**, no de porcentaje de aplicación terminada. Estos valores **no se suman ni se sustituyen mutuamente**.

### 3.1 Brechas de la rúbrica de evidencia vigente (61/100)

| Componente | Estado | Máximo | Gap |
|---|---:|---:|---:|
| Motor nacional | 7 | 14 | **7** |
| Reglas/fuentes jurídicas | 0 | 12 | **12** |
| Editor manual | 12 | 12 | 0 |
| Roles/Super Admin | 9 | 9 | 0 |
| Publicación y rollback | 11 | 11 | 0 |
| OTA/Sync | 5 | 10 | **5** |
| Drift | 7 | 7 | 0 |
| UX | 5 | 6 | **1** |
| Campañas desactivadas | 5 | 5 | 0 |
| Integración GitHub | 0 | 4 | **4** |
| HTTPS real | 0 | 5 | **5** |
| Android/QA | 0 | 5 | **5** |
| **TOTAL** | **61** | **100** | **39** |

No «regalar» puntos por extender el editor 12/12 ni por instalar una APK sin probarla. Si la rúbrica no refleja la amplitud del producto, conservarla como métrica **de evidencia**, no convertirla en objetivo de producto. Registrar el cierre de cada gate solo con prueba no reutilizada, ejecución y resultado.

### 3.2 Nueva medición de producto: no falsificar porcentajes

Crear **una sola vez** `PRODUCT_SCOPE_1_0.csv` en la rama de desarrollo a partir de Baseline, Arquitectura, flujos 01–08 y código real. Cada capacidad tendrá `ID`, `área`, `requisito fuente`, `criterio de aceptación`, `dependencias`, `prioridad release`, `actor`, `estado`, `commit`, `prueba/QA`, `bloqueo`, `peso` y `evidencia`. Estados válidos: `NOT_STARTED`, `IMPLEMENTED_UNVERIFIED`, `PASS_LOCAL`, `PASS_INTEGRATED`, `PASS_DEVICE`, `BLOCKED_EXTERNAL`, `DEFERRED_OWNER_APPROVED`, `OUT_OF_SCOPE_V1`.

**Fórmula posterior:** `porcentaje funcional = 100 × suma(peso de capacidades que satisfacen su aceptación requerida) / suma(pesos de capacidades incluidas en versión aprobada)`. **No calcular el número hasta fijar y verificar el denominador y sus pesos**. Un test de componente no satisface una capacidad que requiere dispositivo o servidor real. Publicar aparte `LEGAL_COVERAGE_VERIFIED`, no ocultarlo dentro del progreso funcional.

**Propuesta de pesos iniciales para aprobación, no calificación de progreso:** motor y reglas 25; aplicación y UX Free 20; servidor/editor/Super Admin 15; OTA/offline 15; Android y release 15; seguridad/privacidad y operación 10. **Total 100**. Se deben descomponer por requisito; cambiar pesos después para «subir porcentaje» queda prohibido. La monetización comercial real se mide en un **roadmap posterior** hasta que el dueño cambie expresamente el baseline Free 1.0.

### 3.3 Cobertura jurídica, denominador aparte

- Catálogo **geográfico** ≠ cobertura **normativa**; 1.104 municipios accesibles no acreditan 1.104 restricciones verificadas.
- Unidad de verificación: `municipio/DIVIPOLA + clase vehicular + tipo de servicio + régimen horario + período/vigencia + acto oficial + fuente + revisión`. Un «municipio sin restricción» es `VERIFIED_NO_RESTRICTION` solo con prueba oficial; si no existe, `UNKNOWN`.
- Medir `verified/eligible` y `unknown/eligible` solo después de definir el universo de unidades elegibles; **no inventar denominador de obligaciones de cada municipio**. Registro de procedencia, fecha de verificación, autoridad y URL oficial; revisión humana antes de publicar.
- El motor puede admitir las 1.104 ciudades **como geografía** sin afirmar pico y placa legal en todas. La app debe dar una respuesta segura `UNKNOWN` para territorios no sustentados.

### 3.4 Inventario mínimo de pantallas y capacidades que debe salir del baseline (no asumir PASS por encontrar archivos)

El árbol GitHub C6 demuestra **existencia de código**, no aceptación funcional ni física. El próximo `PRODUCT_SCOPE_1_0.csv` debe cotejar de forma trazable los flujos del Baseline contra estas áreas y sus dependencias. En esta tabla `CÓDIGO PRESENTE` **no significa `READY`**:

| Área/ruta existente en C6 | Recorrido humano que falta acreditar o reutilizar | Gate que decide cierre |
|---|---|---|
| `home/` | inicio con estado de restricción y banners seguros sin publicidad comercial | UX/estado local consistente + test visual focal |
| `garage/` | alta/edición/eliminación de vehículo sin perder preferencias o documentos ajenos | persistencia/privacidad/migración; QA móvil |
| `pico_placa/` | consulta nacional, tipos de vehículo, horarios, fuente, vigencia, incertidumbre | motor tipado + fixtures legales + UI offline |
| `core/sync/` | descarga OTA firmada/hash, revisión, no downgrade, rollback, last-good | contrato real + fallback + HTTPS en staging |
| `alerts/` | preferencias, notificación, permisos OS y expiración | test focal + QA Android física si OS sensible |
| `apps_launcher/` | **Apps al centro**, acceso a módulos incluidos en baseline, sin enlaces inertes | navegación completa y accesibilidad |
| `trip/` | viaje, ruta/peajes/restricciones, manejo de datos incompletos | pruebas de trayecto y QA de proveedor autorizado |
| `driving/` | cámaras y avisos locales, HUD/audio, permisos, background y batería | QA **física obligatoria** para GPS/OS |
| `fotomultas/` | consulta territorial y distinción de fuente/verificación | datos oficiales/versiones + UI sin falsos certificados |
| `documents/` | billetera privada, cifrado, reemplazo y apertura segura | persistencia privada + pruebas físicas de importación/restore |
| `vehicle_status/`, `maintenance/` | SOAT/RTM, recordatorios y estados sin consulta engañosa | flujo funcional, privacidad y fuentes válidas |
| `cda/`, `comparendos/`, `tramites/` | directorios, vínculos y cobertura honesta sin scraping prohibido | navegación, fuentes, caducidad y UX |
| `buy_sell/`, `peritajes/`, `defense/` | formularios/ayudas de alcance Free aprobado, sin promesas legales | criterios del baseline y protección documental |
| `server/app/Http/Controllers/Admin/`, `Restriction*` | editor, importación, revisión, rol, fuente, publicación/rollback | prueba funcional de permisos, integridad y audit log |
| `server/routes/api.php`, catálogos OTA | lectura cliente pública segura, límites, manifest versión/hash | HTTPS real, contratos API, degradación offline |
| `home_partner_catalog`, campañas/aliados | catálogo revisable y fail-closed, `OFF` en Free 1.0 | banderas OFF verificadas; monetización futuro hito |

**Recorte del alcance:** que exista una ruta no significa que todas sus capacidades deban salir en Free 1.0. La autoridad es el Baseline y la decisión explícita de alcance, no el deseo de llenar el score. Lo que quede fuera se marca `OUT_OF_SCOPE_V1` **con aprobación**, no se elimina ni se hace pasar por terminado. Esta tabla es un índice de auditoría diferencial de aceptación, **no un pedido de volver a testear todo de inmediato**.

## 4. Tres productos distintos: qué significa «terminar»

| Producto/etapa | Terminación técnica admisible | No confundir con |
|---|---|---|
| **Free 1.0 / aplicación móvil** | Flujos principales utilizables sin cuenta; motor y OTA seguros; UX estable; datos locales preservados; QA de Android autorizada; controles de privacidad y lanzamiento satisfechos | «Todas las 1.104 alcaldías tienen norma» o publicidad comercial habilitada |
| **Control nacional / editor/servidor** | 33 departamentos/1.104 municipios administrables; estados `UNKNOWN` honestos; reglas tipadas por vehículo/servicio; fuentes verificables; flujo draft→review→approve→publish→rollback; manifest firmado/hash, difusión HTTPS real y last-good | Actos legales vigentes verificados sin fuente oficial completa |
| **Publicidad/aliados post-Free 1.0** | Contratos de catálogo, consentimiento, moderación, ubicación, expiración, separación patrocinado/oficial, fail-closed; activación solo después de aceptación comercial/privacidad | Campañas visibles o cobros activos en Free 1.0: **OFF por contrato vigente** |

**Punto de decisión del dueño, solo al final del Free 1.0:** ¿mantener el modelo Free sin anuncios y activar publicidad en v1.1, o autorizar cambio explícito del baseline? Hasta esa decisión, preparar integración sin exponer anuncios reales. **No detener desarrollo de Free por monetización.**

## 5. Estrategia de ejecución después de C7: olas completas y paralelas

### 5.0 Durante C7: cero interferencia

**NO entregar este documento a Codex como un prompt nuevo.** No pedirle cambios extra, no usar su rama de trabajo, no reiniciar Codex, no crear C8 hasta recibir la evidencia C7. El director solo puede preparar documentación en rama `director/...`, examinar GitHub en **solo lectura**, hacer análisis del baseline y planear. Al recibir C7, **una auditoría diferencial**: comprobar el commit nuevo, el delta, tests nuevos y el ZIP; conservar todos los PASS previos sin reejecutarlos.

Si C7 ya está en otra rama o tuvo cambios, **esa realidad manda sobre este plan**, no forzar nombres o SHA obsoletos.

### 5.1 Ola siguiente: **Producto nacional integrado**, NO otro prompt de 1 pantalla

**Condición inicial:** C7 entregado. Base = commit C7 remoto verificado (si no pudo publicar, commit/delta recuperado en checkout aislado desde C6); no editar `backup/picoradar-c6-source-20261120` ni `main`. Crear **un único lote nuevo** con 3 frentes que producen código funcional distinto:

**AGENTE A — Flutter: motor nacional + OTA + usuario final**  
**Código dueño:** `mobile/lib/features/pico_placa/`, `mobile/lib/core/sync/`, tests específicos; evitar `home/partners` y servidor.  
**Entregable A:** completar el recorrido *vehículo seleccionado → municipio → tipo de servicio → restricción vigente/UNKNOWN → fuente y vigencia → último catálogo válido sin red → actualización OTA comprobable*. Usar el motor existente, NO crear otro. Revisar casos reales por categoría (particular, motocicleta, taxi y otras que el contrato ya represente) y fechas; motor no debe tratar `UNKNOWN` como libre tránsito. Validar: payload v2 válido/invalidado, rollback, hash, expiración, manifest 304 y uso offline. **Implementar solo brechas verificadas frente a lo que ya hace el código**. Si una parte ya pasó, citar commit/test y no reescribirla.

**AGENTE B — Laravel: editor nacional + publicación + operación jurídica**  
**Código dueño:** `server/app/Http/Controllers/Admin/`, `server/app/Services/Restriction*`, Blade `server/resources/views/admin/restrictions/`, tests server; rutas comunes solo por integrador.  
**Entregable B:** recorrer *municipio/categoría → fuente oficial → edición de borrador → validación → aprobación por rol → preview de cambios materiales → publicación exacta → manifest/release → rollback*. Aprovechar `RestrictionRuleController` y `RestrictionPublicationService`. La bandeja municipal C7 **no se implementa otra vez**. Añadir solo la brecha crítica restante descubierta por una inspección de 1 vez (p.ej. enlazar fila `NO_JURISDICTION` con el workflow editorial existente sin crear norma automática, o control de vigencia/fuente con señal de revisión). Debe mostrar un recorrido admin nuevo y causado por diff; no solo un CSV.

**AGENTE C — Ads/aliados y operación Free 1.0 (código disjunto)**  
**Código dueño:** `mobile/lib/features/home/data/home_partner_catalog.dart`, `mobile/lib/features/home/presentation/home_partner_carousel.dart`, `server/app/Http/Controllers/Api/CampaignCatalogController.php` y archivos propios de campañas; **no** modificar `mobile/lib/core/sync/` ni controlador de reglas.  
**Entregable C:** terminar **preparación** técnica de campañas: validación de catálogo y caducidad, patrocinado ≠ oficial, fail-closed si falta aprobación, no rastreo/PII innecesarios, ubicaciones prohibidas (Conducir/HUD/documentos/emergencias) y test de `OFF` bajo Free 1.0. **No activar** anuncios ni pagos. Si ya todo está implementado, no fabricar commits: ejecutar recorrido focal y seleccionar una brecha real de uso operativo (e.g. preview de moderación admin) sin ampliar esquema/API innecesariamente.

**INTEGRADOR ÚNICO — GitHub y QA de integración**  
**Código dueño:** `server/routes/*`, estados/documentos cortos, integración de commits; solo este actor hace cherry-pick/merge de **ramas hijas de la misma base**, push y PR. Resolver conflictos sobre archivo común después de fusionar parches, no permitir escritura concurrente al mismo índice. Una suite de integración **solamente sobre rutas y contratos tocados**, no todas las suites históricas. Los trabajos C no deben competir por RAM con build Gradle. **Si Flutter runtime cambia, compilar una única APK del candidato integrado en el gate de QA correspondiente** (no una por agente ni por microajuste); nunca usar APK C6 para fingir que probó cambios C8. La APK sigue únicamente en el equipo y no se adjunta al chat.

**Regla de paralelismo:** al iniciar el lote, el integrador asigna **A y B en worktrees distintos** y **C solo si hay RAM y capacidad suficiente**. Tres entregables funcionales de código, no tres análisis. Cada agente retorna `DIFF`, `tests_run`, `passed`, `blocked`, `commit` y dependencias; el integrador une todo **una vez**. Si Codex carece de subagentes efectivos, ejecuta A→B→C en worktree(s) aislados, mismo alcance y sin preguntar qué hacer. No usar paralelismo de Gradle/SDK ni caches compartidas.

**Aceptación de la ola:** 2–3 flujos end-to-end distintos, **código runtime nuevo cuando había brechas** o PASS de integración de rutas críticas antes no verificadas, commits trazables, sin pérdida de datos, controles de rol, sin anuncios activos y reporte de bloqueos externos separado. Un lote que solo crea tests e informes = `NO_PRODUCT_DELIVERY`, aunque sus tests estén verdes.

### 5.2 Ola de **gates reales de lanzamiento**, en paralelo a correcciones menores

**AGENTE PLATAFORMA:** validar la APK DEV C6 **sin volver a adjuntarla**. Usar solo su ruta local y hash; emulador ya disponible si existe o dispositivo **solo después de autorización específica** para instalación/reemplazo. Si el Mi A3 presenta conflicto de firma anterior, **no desinstalar ni borrar datos**; registrar y pedir una decisión puntual cuando corresponda. No fabricar `PHYSICAL_PASS` desde un emulador. No construir APK/AAB repetidas veces por rutina.

**AGENTE SERVIDOR/STAGING:** si el dueño autoriza staging real con URL, DNS y certificado, probar TLS real, GET manifest, SHA, descarga, aplicación cliente, 304/ETag, rollback y último bueno; registrar encabezados sensibles sanitizados. **Sin autorización/entorno:** `BLOCKED_EXTERNAL` documentado una vez; no inventar HTTPS local como gate público ni gastar un lote entero creando infra nueva. Un test TLS local se llama `LOCAL_TLS_CONTRACT`.

**AGENTE QA DE PRODUCTO:** recorrer Inicio → Garaje → Pico → Apps → Viaje → Conducir según baseline; verificar permisos, accesibilidad, almacenamiento privado, notificaciones, privacidad y no regresión de documentos, GPS/Conducir. Hacer QA **por riesgo y cambio**, no 3.365 tests por cada parche. Física obligatoria para GPS, cámara, notificaciones sensibles, lifecycle/HUD, Bluetooth, ahorro de energía y segundo plano; si no hay autorización, marcar gates sin inventar PASS.

**Cierre de ola:** `RELEASE_CANDIDATE_FREE_1_0` solo cuando el conjunto de gates de release esté realmente cerrado, no porque haya APK debug. Si faltan aprobaciones externas, seguir terminando funcionalidades sin prometer lanzamiento.

### 5.3 Ola de **convergencia GitHub con `main`** (no force, no merge ciego)

**Objetivo:** volver el producto actual auditable e integrable desde una rama descendiente de `main`, sin destruir su historia. `backup/picoradar-c6-source-20261120` y rama(s) C7+ son origen verificable del producto; `main` histórico no debe tratarse como código más nuevo por ser default.

1. Capturar SHA final de código C7+ y SHA de `main`, **solo lectura**. Congelar un manifiesto de rutas *de producto y pruebas*, excluyendo secretos, cachés, APK y reportes.
2. Crear `integration/free-1-from-main-<fecha>` **desde main**, en worktree aislado. Montar el árbol producto validado mediante aplicación determinista de snapshot/diff *con lista blanca por ruta* (`mobile/`, `server/`, scripts/infra necesarios); inspeccionar rutas borradas y dependencias. **No** resolver manualmente 838 rutas una por una ni arrastrar cambios históricos incompatibles sin revisión.
3. Exigir `git diff --check`, comprobación de archivos eliminados intencionalmente, revisión de secretos de historia/delta y contratos de build; comparar el árbol funcional resultante con rama fuente mediante hashes. Nada de `git replace`, `force push` a `main` ni cambiar su branch default.
4. Subir rama temporal y PR **DRAFT contra `main`** con diffstat y matriz de compatibilidad. **No merge sin aprobación explícita del dueño.** Si revisar todo el cambio sigue siendo inmanejable, usar PRs por carpetas coherentes con base estable; el código de producto fuente sigue disponible en la rama C7+ mientras tanto.
5. No declarar GitHub integrado hasta que un humano pueda revisar el PR, se hayan aprobado gates y se haya autorizado merge. El respaldo remoto ya existe; el bloqueo de integración no debe volver a impedir desarrollo Flutter/Laravel independiente.

### 5.4 Ola de **normativa y cobertura nacional escalable**

Paralelo al producto Free, con editor y doble revisión, sin alterar reglas automáticamente:

- Definir una cola única de `UNKNOWN`, `STALE`, `PARTIAL`, fechas de revisión y prioridades por cobertura de usuarios. Partir de los pilotos Medellín, Bogotá y Cali en C7, sin volver a buscarlos de cero. Verificar **acto íntegro de autoridad competente**, vigencia, suspensiones, exclusiones y tipos vehiculares; las notas de prensa sirven solo como pistas.
- Registro legal por jurisdicción: autoridad, número y fecha acto, URL oficial, fecha de consulta, hora/zona, perímetro, clase/servicio, dígitos/días, excepciones, vigencia, evidencia y aprobador. **No guardar una placa real ni fotos**.
- Convertir a `DRAFT` tipado solo lo que el acto íntegro soporte. Ejecutar comparaciones en entorno aislado; segundo aprobador publica manualmente por el backend; manifest/version/hash; cliente OTA lo valida sin esperar respuesta del servidor por cada GPS.
- Mostrar conteo de municipio/categoría realmente verificados y desconocidos; no declarar «cobertura total Colombia» por tener geografía completa. Revalidar cambios normativos con fecha de vigencia.
- Extensión futura camiones, parrillero y ocupación mínima entra **solo** si el esquema vigente las representa o hay decisión aprobada de contrato: no crear un motor diferente por municipio.

### 5.5 Ola de **monetización** después de Free 1.0

Con autorización expresa: revisión de privacidad/consentimiento, aprobación de patrocinadores, expiración de catálogo, disclosure patrocinado, no anuncios durante Conducir/emergencia/documentos, límites de frecuencia, pruebas fail-closed y monitoreo. La plataforma de campañas se desarrolla/prepara sin habilitar Ads/Pagos/Premium al público antes del hito aprobado. No usar publicidad para retrasar el cierre de Free.

## 6. Matriz de responsabilidades y no-colisiones

| Agente | Propiedad principal | Puede cambiar | No puede cambiar | Entrega |
|---|---|---|---|---|
| A Flutter/motor | Pico y OTA | `mobile/lib/features/pico_placa/**`, `mobile/lib/core/sync/**`, tests focales | campañas, rutas PHP, Git root | diff, tests, recorrido motor |
| B Laravel/legal | reglas, admin, publicación | `server/app/**Restriction**`, admin Blade, tests propios | mobile, scripts Git, APK | diff, flujo editor + publicación |
| C campañas | catálogo y moderación | `mobile/lib/features/home/*partner*`, campañas backend propias | motor/OTA, privacidad global, activar ads | diff, fail-closed + flag OFF |
| Integrador | contratos compartidos y repositorio | routes, integración, PR, tracker una vez | WIP protegido, main sin autorización | commit, gates, ZIP único |
| QA plataforma | dispositivos/TLS | scripts de test y reportes | secretos, datos usuario, borrar app | PASS físico/HTTPS o BLOCKED causa |
| Dirección ChatGPT | análisis y prioridades | plan documental `director/...` | checkout de Codex, rama C7 activa, secretos | aceptar/rechazar diferencial y siguiente macro |

**Si dos frentes requieren la misma ruta, solo el integrador la modifica al final**, guiado por los cambios acotados de cada frente. No ordenar que tres subagentes compitan escribiendo sobre el mismo repositorio.

## 7. Contrato de una instrucción nueva para Codex: UNA OLA, UNA ENTREGA

Una vez C7 esté validado, el siguiente prompt ejecutable debe contener:

1. `TASK_ID`, fuente Git/commit exacta, owner del índice y prohibiciones.
2. Tres entregables funcionales autónomos A/B/C, **cada uno con punto de partida, archivo objetivo comprobado, comportamiento de usuario, criterio de aceptación, datos fixtures y prueba causal**.
3. Gráfico de dependencia simple: **A || B || C → integrador → integración focal → push/PR Draft → ZIP**; gates Android/HTTPS en carril separado condicionado por entorno, no bloquean A/B/C.
4. Un presupuesto de reintentos: uno causal después de corregir el error; si la causa es externa, `BLOCKED_EXTERNAL` y continuar otros frentes. Cero limpieza global, cero reauditorías 10×10, cero regeneración de todos los tests, cero rebuild por rutina.
5. Matriz de cierre por entregable: `NOT_STARTED`, `IMPLEMENTED_UNVERIFIED`, `PASS_NEW_RUNTIME`, `PASS_INTEGRATED`, `BLOCKED_EXTERNAL`, `FAIL`. **No asumir PASS por haber escrito el test.**
6. Prohibición de declarar `RELEASE=GO` sin gates físico/HTTPS/privacidad, sin normas inventadas, sin publicidad encendida.
7. En caso de `PARTIAL`, una explicación de **qué código sí quedó implementado** y qué siguiente acción exacta desbloquea lo pendiente; no pedir al director que rediseñe el mismo lote completo.
8. **Un único ZIP ligero**, objetivo ≤2 MiB / máximo 5 MiB: `FINAL_REPORT.md` corto, `GATES.csv`, `PRODUCT_SCOPE_1_0.csv` deltas, `CODE_DIFF.csv`, `QA/` focal, `LEGAL_DELTA.csv` si aplica, `MANIFEST.csv`, SHA-256. **Sin APK, TAR, bundle, adjuntos binarios grandes, logs duplicados, placas/datos sensibles.** Código vive en GitHub y se cita con SHA. Nunca pedir al usuario la APK C6.
9. `NEXT=CHATGPT_DIRECTOR`; si `GITHUB_HOLD`, incluir patch textual pequeño además de commit local y causa exacta.
10. Cambiar objetivos solo con evidencia causal o decisión del dueño; **no generar C8-V2 sin ejecutar primero C8**, salvo error inequívoco del prompt detectado **antes** de entregarlo.

## 8. Política de pruebas: reutilizar sin crear falsos verdes

- **REUSED**: los tests ya pasados en código sin cambio y contrato sin cambio, con SHA del commit/test y fecha. **NO_RUN_NEEDED** si no hay cambios relacionados.
- **RUN_CHANGED_ONLY**: nueva función, archivos afectados y contratos directos; Laravel test de feature/permission, Flutter widgets/engine y `flutter analyze` focal o completo según impacto. Si cambia esquema, test migración; si cambia publisher, test hash/rollback.
- **RELEASE_GATE**: una vez por candidato de release, suites globales, tests en dispositivos/HTTPS/performance y licencias/privacidad, no por microajuste.
- **PASS** solo con código, comando, exit 0 y evidencia. Simulación de red ≠ HTTPS real; emulador ≠ físico; build debug ≠ release; prensa ≠ acto jurídico; `UNKNOWN` ≠ circulación autorizada.
- Fallo: corregir una causa y ejecutar una vez de nuevo el test focal. Si no se puede, registrar `BLOCKED_EXTERNAL` / `FAIL` y avanzar en otras áreas.

## 9. Riesgos críticos que un macro no debe ocultar

| Riesgo | Severidad | Decisión/directriz |
|---|---|---|
| `main` y backup con historias divergentes (838 rutas, sin ancestro común) | Alta | convergencia en rama desde main, diff determinista/revisión de borrados, PR Draft, sin force |
| Catálogo territorial completo pero normas incompletas | Alta | `UNKNOWN` seguro y trazabilidad por acto oficial; nunca reclamar 100 % legal por número de municipios |
| Cambios de reglas/conductores sin límites claros | Alta | fuente, fecha, categoría, servicio, perímetro, vigencia, validación y aprobación humana |
| 43 rutas WIP protegidas en Windows | Alta | checkout solo lectura; agentes en worktrees aislados; comparación de hashes al final del lote |
| Dispositivo sin autorización / firma incompatible con DEV anterior | Alta | no `adb install`, no desinstalar ni borrar datos sin autorización expresa |
| HTTPS real sin staging aprobado | Alta | dejar `BLOCKED_EXTERNAL`; no desactivar validación TLS |
| Publicidad frente al contrato Free 1.0 | Alta | integración preparatoria OFF, activación únicamente tras aprobación explícita |
| Repetir builds Gradle por RAM/caché compartida | Media | APK C6 hash conocido, no reconstruir sin cambio de plataforma, no adjuntarla |
| Documentos de estado obsoletos (`docs/CURRENT.md` octubre) | Media | actualizar una sola vez por release/commit aceptado; no reescribir en cada prompt |
| Score de evidencia saturado en editor mientras falta legal/motor | Media | mantener 61/100 separado de porcentaje producto y priorizar gaps pendientes |

## 10. Auditoría propia: 10 pasadas de VERDUGO + 10 de JUEZ (hechas por el director, NO encargar a Codex)

**VERDUGO** (error → acción):

| Paso | Error de la dirección | Acción exigida |
|---|---|---|
| V1 | 6–7 prompts para resultados pequeños | 3 funcionalidades por ola y revisión una vez |
| V2 | 58 % repetido sin metodología | matriz ponderada del release con denominador fijo |
| V3 | 61/100 confundido con desarrollo | métricas y denominadores separados |
| V4 | Reauditoría continua de prompts | un único gate de calidad previo, no «V2» por rutina |
| V5 | Bloqueos Android desvían código admin/móvil | track plataforma independiente |
| V6 | 838 rutas detienen backup de todo el código | backup remoto ya acreditado; integración main separada |
| V7 | Se solicita legal nacional sin acto completo | fuentes oficiales y doble aprobación, `UNKNOWN` protegido |
| V8 | Ads «terminadas» por estar apagadas | preparación técnica ≠ monetización operativa, fases distintas |
| V9 | Dos agentes nominales pero un solo archivo de resultado | partición de ownership, 3 entregables y commits separados |
| V10 | ZIP enorme recargado al chat | repositorio remoto + un ZIP ligero sin APK |

**JUEZ** (contraste → decisión):

| Paso | Cuestión adversarial | Decisión |
|---|---|---|
| J1 | ¿Hay que repetir todas las pruebas para fiarnos? | No; causalidad del diff y release gate una sola vez |
| J2 | ¿Es suficiente la APK C6? | Es build PASS, no device/release PASS |
| J3 | ¿El editor ya completo en 12/12 está listo legalmente? | No; rúbrica de evidencia y cobertura jurídica son ejes distintos |
| J4 | ¿Podemos activar ads para «terminar»? | No sin cambiar baseline/privacidad explícitamente |
| J5 | ¿Basta con respaldar código en GitHub? | Continuidad sí; `main` e integración productiva no |
| J6 | ¿Es más rápido editar `main` directamente? | No: 838 diferencias + seguridad, alto riesgo |
| J7 | ¿Tres agentes siempre son más rápidos? | Solo en archivos disjuntos/recursos suficientes; de otro modo secuencial |
| J8 | ¿Se puede fijar un porcentaje ahora? | No sin contrato/denominador; sí se puede medir nuevas funciones |
| J9 | ¿C7 debe interrumpirse para este plan? | No, no tocar ejecución en curso ni aplicar plan sobre rama C7 |
| J10 | ¿Podemos prometer el 100 % legal nacional? | No; sistema nacional y estado honesto de evidencia son objetivos verificables; cobertura legal depende de fuentes/vigencias |

## 11. Próxima decisión inmediata — SIN intervenir Codex

**AHORA:** Codex Luna termina **C7-V2**. El director no manda C8 ni C7-V3. **Cuando llegue el ZIP C7**, ChatGPT DIRECTOR realizará exactamente: (1) inspección del ZIP/manifest; (2) verificación GitHub del SHA remoto y diff sobre C6; (3) aceptación de la nueva pantalla y fuentes legales solo si hay pruebas nuevas; (4) actualización **una sola vez** de `PRODUCT_SCOPE_1_0.csv` y status; (5) generación del próximo **único prompt** con 3 frentes de implementación definidos en §5.1. Cero reauditoría de suites ya aprobadas.

**Si C7 queda PARTIAL por Android/HTTPS externo:** no repetir C7; sus cambios A/B pasan al siguiente lote como base aceptada, y se continúa A/B/C del macrobloque de producto. Los gates externos se mantienen como checklist pendiente para el release. **Si C7 fracasa por fallo real de código:** una corrección focal causal y solo ese test.

### Señal de control para dirección en cada retorno

`NEW_RUNTIME_FEATURES | NEW_RUNTIME_FILES | TESTS_NEW_PASS | REGRESSIONS_REUSED | REMOTE_BRANCH_SHA | LEGAL_OFFICIAL_VERIFIED_COUNT | ANDROID_PHYSICAL | HTTPS_REAL | PRODUCT_SCOPE_DONE_WEIGHT | PRODUCT_SCOPE_TOTAL_WEIGHT | EVIDENCE_SCORE | NEXT`.

No aceptar un «+0,5 %» de puntuación como sustituto de funcionalidades nuevas. No diseñar «una auditoría de la auditoría» antes de cerrar el lote.

---

# 🔴🔴🔴 QUIÉN SIGUE: CODEX LUNA CONTINÚA C7-V2; DESPUÉS CHATGPT DIRECTOR REVISA SU ZIP 🔴🔴🔴

**ESTE DOCUMENTO ES EL PLAN DE DIRECCIÓN; NO ES UNA ORDEN PARA INTERRUMPIR NI REINICIAR CODEX, NO ES UN NUEVO PROMPT C8.**
