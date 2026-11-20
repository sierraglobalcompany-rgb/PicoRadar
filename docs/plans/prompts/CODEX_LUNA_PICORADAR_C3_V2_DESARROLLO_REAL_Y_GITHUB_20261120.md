# CODEX LUNA — PICORADAR C3 V2 · IMPLEMENTACIÓN REAL DE PRODUCTO NACIONAL Y CÓDIGO RECUPERABLE

**EJECUTOR:** Codex Luna. **DIRECTOR:** ChatGPT. **Fecha de corte:** 20/11/2026, America/Bogota.  
**TASK_ID:** `PICORADAR-C3-PRODUCTO-NACIONAL-POST-C2-20261120` (**mismo C3; V2 sustituye al C3 original si todavía no se ejecutó**).  
**TRABAJO:** implementar software y verificar el resultado, no entregar una tercera auditoría ni reconstruir N4/N5.  
**ENTRADA:** SOLO este Markdown. El candidato integrado C2 existe en el equipo de Codex; no requiere otro ZIP para empezar.  
**SALIDA:** UN SOLO `PICORADAR_C3_RETORNO_UNICO.zip` con cambios nuevos, pruebas relevantes, métricas de cierre y recuperación de código. `NEXT=CHATGPT_DIRECTOR`.

## 1. Razón de esta corrección y decisión vinculante

C1 y C2 cerraron fallas del entorno, pero **no añadieron código nuevo de producto**: `FINAL_TREE=859bb8bbdff769ec3504af407f4df27593b2efea`, `CODE_FILES_CHANGED_C2=0`. C1 demostró **53 PHP/592 assertions/0 warnings**. R2: **3.365 Flutter PASS, 11 SKIP**. C2: prueba `VERTICAL_SAME_BYTES=PASS_LOCAL` con snapshot de Laravel real pero servido por HTTP loopback en el test Flutter, `ROLLBACK_LAST_GOOD=PASS_LOCAL`; `sqlite3` regenerado para Dart 3.13.1. **NO repetir estos gates sin cambios de contrato, ni elevarlos a HTTPS/offline/Drift/Android**.

El 58 % integral y 83 % del núcleo citados anteriormente son **estimaciones heredadas, no mediciones reproducibles**. **No inflar** porcentajes por prompts, ZIP, documentación, test antiguo, estado local de Git o conteo de municipios LAB. Este lote entrega `SCORECARD_BEFORE_AFTER.csv` con puntuación calculable y evidencia; ver §7.

**Éxito C3:** al menos **DOS resultados de producto** que antes no estuvieran acreditados en el árbol integrado, de estas rutas: (A) editor nacional completo con autorización real, (B) offline real con último catálogo y sin cuenta, (C) migración Drift sin pérdida, (D) publicidad/campañas OFF fail-closed. Para cada uno: código fuente o prueba causal faltante, resultado reproducible y archivos específicos. Si ya existe y pasa, elegir **siguiente hueco real** del mismo módulo y cerrarlo; no tocar código artificialmente. **No detener todo por APK, RAM, fuentes legales externas ni GitHub 403**. Si se encuentra un bug bloqueante, causa concreta + **una** corrección focal, después continuar otro frente. Resultados honestos por encima de un número inventado.

### Estado y archivos que se deben respetar

- Candidato integrado C2: tree **`859bb8bbdff769ec3504af407f4df27593b2efea`**, HEAD inicial reportado **`37ca71e1a1ebfbb14d908f3ab128c109ff401bc2`**, `pubspec.lock` SHA-256 **`e86ada9d658800b3c47bcfb1f8743d3ff14ce75fac1b81bc040b16ccfb03a41b`**; las **61 rutas staged** corresponden a cambios anteriores, no son C3. Comprobar `git write-tree` y `git diff --name-status` **una vez**, no confundir HEAD con árbol integrado; si el candidato ya tiene nuevos cambios reales de otro lote, detener la modificación concurrente y documentar la nueva base.
- Fuente **protegida, lectura solamente:** `D:\codex\_isolated\PicoRadar-V6R4-Close-Runtime-QA-20261113`; HEAD reportado `182a8821bba688b28a6e223a1e956df748f7948b`, 43 rutas WIP (18 tracked y 25 untracked). PROHIBIDO `clean`, `reset`, `stash`, `checkout`, `commit`, editor o pruebas que escriban allí. Inventario y hashes de contenido al principio y al final una vez; no reutilizar huella ajena como actual.
- El candidato puede depender de `git alternates` apuntando a esa fuente protegida: **no eliminar ni mover sus objetos**. Los subagentes no pueden partir simplemente del HEAD anterior, porque perderían el árbol staged. Antes de paralelizar, cada copia debe tener **exactamente** el árbol integrado de C2; si no se puede verificar, proceder secuencialmente.
- No se da por existente `D:\codex\PicoRadar` sin comparar su árbol. Utilizar el **candidato validado** identificado realmente. Reportes fuera del checkout protegido: `D:\codex\_REPORTES\PicoRadar\C3-20261120\`.
- Leer `AGENTS.md` y los contratos superiores pertinentes antes de cambiar cada flujo, **solo una vez por flujo**. Leyes: KISS/ponytail, antirruido, antiparches, diseño humano, verificación independiente causal, anti-ping-pong. Barra inferior obligatoria `Inicio · Garaje · Apps · Viaje · Conducir` (Apps al centro), servicio sin cuenta, evaluación local, GPS continuo no enviado, sin publicidad/pagos/marketing activados en Free 1.0.

## 2. Prioridad de ingeniería y asignación sin colisiones

**Plan con límite de recursos:** un integrador exclusivo controla el índice Git, commits, pruebas finales y ZIP. **Hasta dos subagentes**, solamente si están disponibles y cada uno trabaja en copia aislada idéntica a `BASE_TREE`:

- **A: Laravel** — editor manual nacional, roles Super Admin/operador, publicación/versionado/rollback. Solo `server/`; no tocar bases productivas ni mover el índice compartido.
- **B: Flutter** — modo offline, Drift migraciones, experiencia de incertidumbre y superficies patrocinadas OFF. Solo `mobile/`; no ejecutar Gradle en paralelo con otro proceso Dart pesado.

Con memoria libre insuficiente (C2 reportó 4,64 GiB), **no lanzar dos procesos pesados**. Puede haber un subagente de **lectura liviana** mientras el ejecutor modifica/testea un módulo; de otro modo trabajar A y B en secuencia. La ausencia de subagentes **no** es blocker del producto. Los agentes entregan parches y resultados al integrador, quien integra cada diff una vez. Prohibido dos agentes escribiendo sobre mismo índice, `.dart_tool`, Gradle, `.env` o la fuente protegida.

## 3. Frente A — cerrar FLUJO MANUAL NACIONAL + SUPER ADMIN (prioridad 1)

**No crear un segundo editor, un segundo publicador ni un nuevo modelo legal.** El repositorio base ya tiene `server/app/Http/Controllers/Admin/DatasetController.php`, `server/app/Services/DatasetPublisher.php` (publish/rollback), rutas de datasets y servicios de auditoría; en el candidato C2 figuran `RestrictionFormPayloadBuilder`, `DatasetReleaseValidator`, `server/resources/views/admin/restrictions/form.blade.php` y `partials/coverage-fields.blade.php`. Verificar las rutas y nombres efectivos en el **candidato** (no inferir que GitHub `main` contiene N4/N5).

**A0 (inspección máxima 1 vez):** localizar `DatasetController`, `DatasetPublisher`, validador, formularios, rutas, permisos reales y tests focales; marcar en `GAP_MATRIX.csv` cada paso ya probado o ausente. No reescribir lo que pasó.

**A1 (primer resultado funcional):** completar de punta a punta en **Laravel local** el recorrido **editor crea/edita regla tipada `schemaVersion=2` → vista previa con categoría y horarios → validación de norma/vigencia → aprobador autorizado publica release inmutable SHA-256/manifiesto → rollback al último release bueno**. Reutilizar infraestructura, sin desplegar. Si falta solo un enlace/UI, implementar solo eso; si ya todo existe, convertir en **una prueba HTTP/feature causal nueva** con autorización y publicación que demuestre el camino humano. El resultado debe sobrevivir una recarga; no basta inspección estática de clases ni un test unitario aislado.

**A2 (segundo resultado/seguridad):** separar acción del editor y acción del aprobador/Super Admin mediante middleware/policy/rol que **ya exista**. Si no existe separación, añadir autorización mínima reutilizando `User`/operadores, sin crear otro login. Aserciones mínimas: editor puede guardar borrador, editor NO puede publicar/rollback, aprobador sí puede publicar y rollback, visitante no accede, intento denegado no cambia puntero/publicación ni manifest. No confundir `auth` con autorización por rol. Verificar CSRF/guards que apliquen sin modificar políticas globales ajenas.

**A3 (motor nacional):** guardar tipos y modalidades realmente soportados (particular/moto/taxi/servicio público **según contrato existente**), horario, excepciones, expiración con zona, fuente, categoría y alcance. Usar un único parser/validador; datos inválidos o fuera de cobertura no se publican. `UNKNOWN`, `PARTIAL`, `STALE` y `NO_RESTRICTION_EXPLICIT_VERIFIED` deben estar semánticamente separados, sin equiparar UNKNOWN a ALLOWED. Si una modalidad no está implementada, reportar `NOT_SUPPORTED` y no inventar decreto. El selector geográfico nacional (municipios/departamentos) **no cuenta como cobertura jurídica**.

**A4 (seguridad diferencial):** hallazgo C2 de `.env.example` y `.env.staging.example` es `SUSPICIOUS_UNCONFIRMED`, NO compromiso confirmado. Inspeccionar **solo los cambios y el alcance real a enviar**, clasificar valores privadamente como `EMPTY/PLACEHOLDER`, `ACTIVE_SECRET_CONFIRMED` o `UNRESOLVED` sin mostrar ni empaquetar valores. Las nuevas variables flags de campañas/cuentas se mantienen OFF. Confirmación de secreto activo implica `HOLD_SECURITY` y solicitud de rotación humana, sin publicarlo. Hallazgo benigno no habilita por sí mismo subir todos los archivos. **Prohibido falsos positivos por nombres** como APP_KEY.

**A5 (cobertura legal honesta):** matriz C2 17 filas (3 PARTIAL, 14 UNKNOWN), 14 hashes LAB verificados, sin cobertura legal completa acreditada. Codex solo puede elevar una jurisdicción×clase×periodo a `VERIFIED_OFFICIAL` si consigue fuente oficial verificable + decreto/acto + fecha de consulta + vigencia + horarios + excepciones + modalidad exacta. Si no hay red/fuente: registrar `UNKNOWN` y **seguir cerrando editor/roles**. No hacer scraping de CAPTCHA ni elevar LAB a producción. Si se verifica alguna, crear archivo versionado por ciudad y test acotado; sin fuente, no inventar. Informar numerador/denominador únicamente cuando ambos estén acreditados.

## 4. Frente B — cerrar OFFLINE Y PERSISTENCIA DE USUARIO (prioridad 2)

Usar `mobile/lib/core/sync/dataset_sync_service.dart`, `published_catalog_store.dart`, providers y Drift `AppDatabase` **existentes en el candidato**. GitHub `main` puede tener schema Drift antiguo; **usar schema y migraciones reales del candidato integrado**, no forzar versión 5 ni 10 desde memoria. No duplicar motor ni base.

**B0:** inspección focal una vez de tests/implementación ya escrita para identificar un hueco. No repetir 3.365 tests globales ni C2 puente loopback si contratos no cambiaron.

**B1 (primer resultado funcional):** probar **offline auténtico**, no simulado con una respuesta HTTP local: sincronizar dataset válido de schemaVersion=2, apagar acceso a transporte, destruir y recrear contenedor/provider de servicio (y conexión BD cuando aplique), cargar el último snapshot persistido y evaluar categoría cubierta **sin cuenta**, con `UNKNOWN/STALE` visibles cuando falte vigencia. Comprobar que hash/dataset corrupto no invalida el último bueno. Si la persistencia falla, implementar corrección KISS en tienda existente; **una sola prueba causal** de entrada/salida y datos.

**B2 (segundo resultado funcional):** ejecutar una prueba de migración Drift **desde un fixture real de versión previa soportada hacia el schema actual**. Debe conservar placas/vehículos, preferencias y versión de dataset; no borrar BD para que pase. Si fixture no existe, crear **fixture mínimo real a partir del esquema anterior versionado** si se puede demostrar su estructura sin adivinar; si no, `NOT_RUN_FIXTURE` con causa exacta y pasar a B3. No reemplazar datos personales por datos reales: fixtures sintéticos.

**B3 (publicidad y aliados):** conservar campañas/aliados, si hay infraestructura, **OFF en Free 1.0**. Si `CAMPAIGN_PUBLIC_CATALOG_ENABLED` o equivalente falta/false, URL no HTTPS, manifest inválido, no existe consentimiento/publicación o falla la red, no cargar contenido patrocinado y no representar patrocinio como oficial. Una prueba fail-closed enfocada. No SDK nuevo, no suscripciones, no anuncios live, no pagos, no tracking GPS; superficie opcional reutilizando vista actual sin desplazar `Apps` del centro. **Poder activar campañas en futuro no es permiso de activarlas ahora.**

**B4 (UX):** si el motor retorna UNKNOWN/STALE, mostrar incertidumbre sin prometer libre circulación. Si ya se cumple, probarlo una vez con widget focal y priorizar B1/B2. No ampliar la app con screens o frameworks nuevos.

## 5. Integración + GITHUB DEL CÓDIGO (no solo de documentos)

**G0:** conservar `BASE_TREE` integrado exacto al principio. El integrador incorpora parches disjuntos A/B sin mezclar trabajo externo. No `git add .`, no reset/clean/stash. Calcular `FINAL_TREE` con `git write-tree` tras stage explícito de **solo las rutas modificadas/añadidas C3**; diferenciar **61 rutas anteriores** de nuevas C3 con `git diff --binary BASE_TREE FINAL_TREE > C3_DELTA.patch`. Validar patch portable una vez en árbol descartable si posible. `C3_CHANGED_FILES` y pruebas solo de C3; si cero modificaciones, explicar individualmente qué funcionalidad ya estaba implementada con prueba causal, o fallas que realmente impidieron cambios. No informar “avance de producto nuevo” por meras comprobaciones.

**G1:** el repositorio público `sierraglobalcompany-rgb/PicoRadar` tiene `main` y PR documental #79 **borrador/no fusionado** al corte. La rama documental `director/n5-modality-safe-20261118` contiene órdenes, no acredita el candidato N4/N5 integrado. Por tanto **verificar el remoto y la base** antes de `push`; no publicar un parche C3 solo contra `main` desactualizado. Objetivo: rama de código **NO productiva** `codex/c3-national-product-20261120` o equivalente única, basada en el historial correcto y que incluya N4/N5+C3, si se satisfacen todos los controles de seguridad y GitHub permite escribir. Cerrar `HOLD_SECURITY` solo con evidencia de escaneo diferencial **de todo el contenido que se intentará subir**, revisión de credenciales y permisos. No tocar `main`, no auto-merge PR #79, no usar Actions de pago, no publicar servidor ni release, no subir WIP protegido o datos sensibles. **Si el gate falla, NO push**, pasar a G2 y seguir terminando código local.

**G2 (recovery garantizado):** **UN SOLO ZIP** debe transportar el **C3_DELTA.patch** más **los dos parches de restauración N4/N5/R2** (`R2V2_BASE` SHA-256 `04b23709133b1b6fb02e6bea7c9b735305d8670c223b8df319602a3862a1b19b`, 61 rutas; `R2V2_FINAL_DELTA` SHA-256 `79d8426aef6e7ae25199e3f3c73ce762d3eabdf47ddc424304195d2988ac5ebf`, 9 rutas) **si no están garantizados y accesibles permanentemente por GitHub/copia local**. Verificar que el ZIP permite reconstruir el **árbol final exacto** desde una base conocida, con commits/base trees y hashes; si no es reconstruible, reportar `RECOVERY_NOT_SELF_CONTAINED`, no decir backup completo. No adjuntar `.env`, secretos, BD con datos personales, APK falsa ni archivos de la fuente WIP ajena. Puede llevar los parches anteriores como miembros del mismo ZIP (no ZIP anidado). Si no existe base histórica recuperable, incluir fuente sanitizada portable del candidato y manifiesto sin datos privados, sin duplicar gigabytes de dependencias.

**G3:** medir WIP protegido al inicio y fin por `git status`/HEAD/índice **y SHA-256 de contenido** para cada ruta pertinente (máximo las 43 existentes); si alguna ruta desapareció o cambió por agente externo, reportar `SOURCE_WIP_CHANGED_UNEXPLAINED` y no atribuirlo a Codex sin evidencia. No leer ni publicar valores sensibles. `SOURCE_WIP_BYTES=PASS` solo con ambas huellas comparables y iguales.

**G4 (release):** APK DEV únicamente después de cerrar A/B, **una** medida de RAM libre al final. Si >= 6 GiB y SDK/Gradle presentes, intento de build DEV único, hash de APK, firma debug; si <6 GiB, `APK=BLOCKED_RESOURCE`, **pero código nuevo queda implementado y respaldado**. NO ADB, teléfono, certificados productivos, FTP, Hostinger, compras, publicación o despliegue externo sin autorización. HTTPS OTA, migraciones reales y firma/dispositivo son gates independientes: no convertir `PASS_LOCAL` en release. `RELEASE=NO_GO` hasta cierre real.

## 6. Gates C3 — sin falsas aprobaciones

| Gate | PASS mínimo | Si falta |
|---|---|---|
| `C3_EDITOR_FLOW` | HTTP/UI local de borrador→vista previa→validación→publicación SHA→rollback, evidencia de roles | `PARTIAL_CODE`, `FAIL_BUG` o `NOT_RUN_ENV` |
| `C3_AUTHZ` | Tests autorizados/denegados; sin mutación bajo rol insuficiente | `FAIL_BUG` o `NOT_RUN` |
| `C3_MOTOR_NATIONAL` | Contrato tipado vigente por categoría, tiempos/fuentes, UNKNOWN no ALLOWED | `PARTIAL_SCOPED` |
| `C3_OFFLINE` | Snapshot persistido se evalúa sin red ni cuenta después de reinicio | `FAIL_BUG` o `NOT_RUN` |
| `C3_DRIFT` | Migración desde fixture real preserva vehículos/preferencias | `NOT_RUN_FIXTURE` o `FAIL_BUG` |
| `C3_ADS_OFF` | Campañas OFF/fail-closed y distinción patrocinado | `PARTIAL_CODE` o `FAIL_BUG` |
| `C3_LEGAL` | Sólo actos oficiales verificables; cobertura pendiente UNKNOWN | `PARTIAL_LEGAL` |
| `C3_GITHUB_CODE` | Rama no productiva contiene código completo N4/N5+C3 y commit verificable, sin gate de seguridad pendiente | `HOLD_SECURITY/NOT_PUSHED` |
| `C3_RECOVERY` | ZIP portable reconstruye árbol exacto desde base acreditada | `PARTIAL_RECOVERY` |
| `C3_APK` | APK real con hash/firma DEV comprobados | `BLOCKED_RESOURCE/ENV` |
| `C3_RELEASE` | HTTPS, QA física, firma, datos legales y aprobaciones reales | `NO_GO` |

**Si fallan dos gates independientes:** corregir como máximo dos causas reproducidas que afecten al resultado de producto; continuar el otro frente. Prohibido dar 10 vueltas a SDK/SQLite (ya PASS), reauditar C2 o repetir suites globales. Si cambian contratos, ejecutar **una vez** tests afectados y puente cruzado, no toda la historia.

## 7. MEDICIÓN REAL DEL AVANCE — evitar otra vez “58 %” sin fundamento

Generar `SCORECARD_BEFORE_AFTER.csv` con columnas `item,weight,status_before,status_after,score_before,score_after,evidence,change_files,reason`; no basta una lista de deseos. Pesos **explícitos y suman 100**, distintos del 58 % histórico: 

| Componente | Peso |
|---|---:|
| Motor tipado generalizable | 14 |
| Cobertura jurídica oficial por categoría y vigencia (no selector) | 12 |
| Editor manual nacional operativo | 12 |
| Autorización y Super Admin | 9 |
| Publicación, manifiesto y rollback Laravel | 11 |
| OTA último válido y offline sin cuenta | 10 |
| Migración Drift sin pérdida | 7 |
| UX/vehículos y estados de incertidumbre | 6 |
| Superficies de campañas OFF/fail-closed | 5 |
| Código recuperable en GitHub con seguridad | 4 |
| HTTPS/OTA real de entorno autorizado | 5 |
| APK/QA Android físico | 5 |
| **TOTAL** | **100** |

**Escala:** `0` = no demostrado, `0.5` = parcialmente demostrado con ejecución real del alcance, `1` = criterio final completo con evidencia; `score=weight×escala`. No se asigna 0.5 por intención, README, código no ejecutado o historial no verificable. `status_before` debe derivarse de evidencia R2/C1/C2 existente, sin repetir pruebas; `status_after` de nuevos cambios/gates C3, o del mismo valor si nada nuevo ocurrió. **El nuevo score no es equivalente ni se suma al 58 histórico**; presentar ambos por separado y explicar las diferencias. Reportar `Δ puntos = score_after - score_before`, con solo beneficios causados en C3. Jurídico nacional: medición aparte por jurisdicción×tipo×periodo con denominador validado; si no existe, escribir `NO_MEDIBLE`, no 0 % ni 100 % ficticios.

**Meta de ejecución**: al menos dos resultados de producto con criterio de cierre; no declarar fracaso total por RAM/HTTPS ajenos a A/B. No preasignar puntos ni garantizar porcentajes futuros. Si ya están listos, completar otro hueco objetivamente relevante o producir entrega real de código a GitHub bajo gate de seguridad; si nada es implementable, devolver causas exactas con evidencia, no inventar logros.

## 8. Entrega de evidencias — exactamente UN ZIP

`D:\codex\_REPORTES\PicoRadar\C3-20261120\PICORADAR_C3_RETORNO_UNICO.zip` contiene **solo**:

- `FINAL_REPORT.md`: antes/después de archivos, flujo del usuario que sí funciona, huecos cerrados y restantes, gates, HEAD/TREE fuente y candidato, `RELEASE=NO_GO`, `NEXT=CHATGPT_DIRECTOR`.
- `GATES.csv` con PASS/FAIL/PARTIAL/NOT_RUN y evidencia verificable; `GAP_MATRIX.csv` para A/B.
- `C3_DELTA.patch` con cambios **nuevos C3**, `R2V2_BASE.patch` y `R2V2_FINAL_DELTA.patch` cuando sean necesarios para recuperación; `RECONSTRUCTION.md` (base acreditada, orden, SHA-256, tree final, pasos exactos sin publicar secretos).
- `QA/` logs causales **nuevos** (PHP y/o Flutter, outputs, assertions, command, stderr y resultado), no miles de tests antiguos.
- `SCORECARD_BEFORE_AFTER.csv` calculado, más `NATIONAL_COVERAGE_DELTA.csv` con URL oficial y ventana si hay avances jurídicos.
- `GITHUB_CODE_STATUS.md`: enlaces/commits SHA verificables si hubo push, o bloqueo preciso y recuperación. `SECURITY_GATE.md` sin valores secretos.
- `SOURCE_WIP_FINGERPRINTS.csv` con comparación inicial/final (si se puede). APK solo si construida realmente y con hash/firma.
- `MANIFEST.csv` con ruta, bytes, SHA-256 y CRC32 de **todos los miembros salvo sí mismo**. Cerrar ZIP, verificar CRC+hash de cada entrada, y calcular SHA-256 del ZIP final; no modificar ZIP después.

No crear ZIP anidados ni múltiples links. Mensaje final de Codex: `TASK_ID | BASE_TREE | FINAL_TREE | NEW_C3_FILES | C3_GATES | SCORE_BEFORE→AFTER | GITHUB_CODE_STATUS | APK | ZIP_SHA256 | RELEASE=NO_GO | NEXT=CHATGPT_DIRECTOR`.

## 9. Auditoría diferencial del PROMPT (NO reejecutar 20 pasadas en Codex)

| Verdugo — riesgo de C3 original | Juez — corrección V2 |
|---|---|
| V01. Repetir QA ya aceptado | J01. Heredar R2/C1/C2 salvo cambio causal |
| V02. Confundir reporte con avance | J02. Exigir dos resultados de producto |
| V03. Atribuir 58 % a progreso verificable | J03. Scorecard nuevo y método explícito |
| V04. Worktree desde HEAD pierde 61 staged | J04. Verificar árbol materializado integrado |
| V05. Dos agentes chocan por RAM/índice | J05. Dueño único, copies aisladas o secuencia |
| V06. Editor/publicador duplicados | J06. Reutilizar DatasetController/Publisher |
| V07. `auth` se confunde con autorización | J07. Tests editor denegado/aprobador permitido |
| V08. UNKNOWN equivale a libre circulación | J08. Fuente y vigencia por categoría; fail-closed |
| V09. OTA local se presenta como offline/HTTPS | J09. Gates separados y tests específicos |
| V10. Drift fixture inventado o datos borrados | J10. Fixture histórico real y preservación |
| V11. Publicidad activa antes de Free 1.0 | J11. OFF/fail-closed sin SDK comercial |
| V12. Aplicación GitHub main carece de N4/N5 | J12. Rama de código completa, no sólo docs |
| V13. Dos parches perdidos otra vez | J13. ZIP de recuperación con BASE+DELTA+C3 |
| V14. Falso positivo de secretos por `.env.example` | J14. Clasificación diferencial privada |
| V15. Candidato depende de `git alternates` | J15. No tocar almacén fuente; recovery reproducible |
| V16. 43 WIP reportados sin digest de bytes | J16. Huella real inicio/fin, o NOT_VERIFIED |
| V17. APK bloquea funciones | J17. Gradle sólo al final y con RAM necesaria |
| V18. 17 filas LAB se convierten en legal nacional | J18. Legal `NO_MEDIBLE` sin fuentes acreditadas |
| V19. Test sintético se convierte en release | J19. HTTPS, teléfono y aprobación separados |
| V20. Retorno disperso obliga a otro ping-pong | J20. ZIP único, manifiesto y próxima acción clara |

## 10. REGLA FINAL

Codex es **ejecutor de código**: debe implementar los huecos demostrados, no escribir otra auditoría extensiva ni otro prompt. Un fallo de SDK/Gradle no impide cerrar editor o persistencia. Si un componente ya cumple, pasar al siguiente hueco de producto sin introducir cambios artificiales. **GitHub sólo está actualizado para el código cuando la rama de código se comprueba y su SHA coincide**, no cuando se suben Markdown. No gastar el lote en informes sobre informes. Guardar reversibilidad y seguridad en todo momento.

# 🔴🔴🔴 QUIÉN SIGUE: CODEX LUNA — EJECUTAR C3 V2, IMPLEMENTAR Y ENTREGAR UN SOLO ZIP 🔴🔴🔴

**TRAS EL ZIP, SIGUE CHATGPT DIRECTOR PARA INTEGRAR Y MEDIR RESULTADOS NUEVOS.**
