# CODEX LUNA — PICORADAR G1 V2 — DATOS NACIONALES SIN PROGRAMAR CADA CIUDAD

**TASK_ID ÚNICO:** `PICORADAR-G1-NATIONAL-DATA-FIRST-RESTRICTIONS-20261110` (MISMO de G1 V1; V2 sustituye instrucciones V1; no abrir segundo G1 si hubo ejecución previa).

**RESPONSABILIDADES:** ChatGPT es el director técnico, decide arquitectura y autoriza cambios de alcance; Codex Luna ejecuta este lote exactamente, verifica el entorno y entrega un único ZIP. **NO AUTOAPROBACIÓN.** Si G1 V1 ya fue iniciado, examinar y conservar avances, aplicar solamente la diferencia necesaria; jamás ejecutar dos clones de la misma tarea en paralelo.

**OBJETIVO DE PRODUCTO:** que una regla **de tipo ya soportado** pueda cambiarse mediante **un archivo JSON editorial revisado**, pasar por **los servicios Laravel existentes**, generar release/manifiesto y llegar a **Flutter/Drift con los mismos bytes**, SIN codificar calendarios por ciudad/mes en tests PHP, SIN borrar otras coberturas y SIN afirmar que el laboratorio es una actualización disponible para usuarios.

**ALCANCE PROHIBIDO:** no implementar todavía nuevos predicados (parrillero, ocupantes, carga, rutas/geo, permisos), no convertir esas clases a `car/private` o `car/taxi`, no agregar motor/importador/publicador, no cambiar UX ni app shell, no editar catalogo DIVIPOLA 33/1.104 ni 73/219, no crear API por ciudad ni nueva migración, no cambiar schema 1, Drift schema ni versiones de producción, no activar `coverageKnown`, `staleAfter` o `engineEnabled` artificialmente. No publicar a CDN/Hostinger, no merge, deploy ni instalar APK. **R1 y R2 ya cerrados como PASS de laboratorio; no repetición de sus tareas.**

## A. Fuentes y preflight — verificar y detener solo lo afectado

A1. Repositorio `sierraglobalcompany-rgb/PicoRadar`. Rama de código PR #71 Draft, HEAD de referencia `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a` (puede avanzar; verificar). PR #79 Draft documentación, al crear esta orden su HEAD era `b0a405fd57794ce5903d830e4102b65bca2816f3`; plan maestro §AR/§AS y ledger SRC-54/55. Usar **checkout moderno** `recovery/20261019-modern` y su historia, no `main` histórico como base operacional. Nunca fusionar PR #79 en código sin reconciliar sus archivos ni `git checkout` destructivo.

A2. Antes de admitir R1/R2 como base, verificar que su historia contiene el HEAD moderno esperado de PR71 o documentar exactamente la divergencia; no unir ramas divergentes de modo automático. R1 commit local `da9d8083bb21bd7c9863a319e07de51a5e692d09`; R2 commit local `88fc5d1307a80a9781f7b7e23e1912c3316c7531`, rama esperada `feat/PICORADAR-R2-bogota-taxi-nov2026`. **Primera acción:** comprobar `git cat-file -t <sha>`, `git show --format=%P -s <sha>`, `git merge-base --is-ancestor` y ramas remotas; R2 debe ser hijo de R1 según evidencia. Si no existe, NO recrear commits imaginarios: localizar artefactos R1/R2 de ZIP y patches, comprobar sus hashes y reconstruir en clon limpio sin tocar trabajo privado; si la reconstrucción no da fuente reproducible, marcar `BASE_UNAVAILABLE` y cerrar G1 como parcial, no fabricar PASS.

A3. ZIP entregado R2: `PICORADAR_R2_BOGOTA_TAXI_NOV2026_Y_R1_SCOPEFIX_EVIDENCIA_UNICA.zip`, SHA-256 `213d65fcdecfc1fba12d613160e4168a8f77db5018156d2bad30f73b3d65019c`. Release aislado `r3-f5584f294412`, contenido SHA-256 `c879a27ce3fc0ef983575a069e995c95c4f9a03fe2b5f89509386dfa8090d5e5`. **Localizar y verificar rutas reales**; no dar por accesible una ruta `D:\` narrada en chat. `ACTUAL_R2_LARAVEL_RELEASE.json` y `ACTUAL_R2_MANIFEST.json` son fuente técnica base, no dataset ya desplegado.

A4. Ejecutar solo en clon/worktree aislado bajo `D:\codex\...` validado sin WIP ajeno; preservar checkout moderno `D:\Dev\PicoRadar`, worktrees y 101 rutas WIP históricas que **podrían no estar montadas**. Prohibidos `git clean`, `reset --hard`, borrado o trash, force-push, instalación/configuración global de Git, credenciales y cambios C:. Detectar `scripts/tests/test_hostinger_installer_browser.ps1` eliminado históricamente, conservar estado. Guardar PRE/POST refs, hashes, `git status --porcelain=v1 -uall`, stash, worktrees. Si no puede hacerse clon seguro, `BLOCKED_SAFE`.

A5. **LEER ANTES DE ESCRIBIR**: `AGENTS.md`, `docs/CURRENT.md`, `docs/SOP.md`, `docs/DESIGN_CONTRACT.md` si se afecta UI (no está autorizado), documentos de baseline/arquitectura que AGENTS referencia, plan §AR/§AS y ley canónica L1–L6 de PingPongLaw. Si una instrucción superior exige parar, bloquear esa acción y conservar lo demás. Confirmar PHP/Composer/SQLite/Flutter, dependencias instaladas y lockfiles; NO reinstalar ni modificar dependencias en silencio. En ausencia de toolchain, probar lo alcanzable y declarar bloqueos.

A6. Hacer **inventario focal de consumidores** antes de editar: `RestrictionImportService::read/normalize/analyze/confirm/payloadForRows`, `RestrictionRuleVersionService`, `RestrictionContractValidator`, `RestrictionPublicationService::publishVersions/rollbackCity/currentPayload`, `DatasetPublisher`/manifest, `restriction_dataset.dart`, `dataset_sync_service.dart`, `BogotaNovember2026PublicationTest.php`, tests existentes de importación y rollback. No aceptar el argumento «no se encontró consumidor» como justificación para borrar.

## B. Contrato editorial concreto — NO duplicar el importador

B1. El importador existente **ya acepta JSON/CSV/XLSX**; **no crear otro**. Para este G1, formato canónico para admisión por `RestrictionImportService::read()` es:

```json
{
  "jurisdictions": [
    {
      "id": "co-dc-bogota",
      "name": "Bogotá",
      "coverages": [
        { "vehicleKind": "car", "serviceType": "private", "rules": [] },
        { "vehicleKind": "motorcycle", "serviceType": "private", "rules": [] },
        { "vehicleKind": "car", "serviceType": "taxi", "rules": [] }
      ]
    }
  ]
}
```

**Este ejemplo solo explica la ENVOLTURA y claves: NO es un payload ejecutable.** Reemplazar cada cobertura de ejemplo por el objeto COMPLETO de R2, con sus `verifiedAt`, `staleAfter`, `sourceUrls`, reglas reales y campos existentes, **sin eliminar ni normalizar información**. El fichero editorial puede llamarse `server/database/data/restrictions/official/2026-11-bogota.json` si no hay director canónico equivalente. Su fuente es **exactamente el objeto Bogotá** del release R2, con tres coberturas, 23 días taxi y las dos reglas particulares noviembre. Conservar los metadatos de fuente tal como R2; no ampliar su vigencia ni volver a certificar jurídicamente R1/R2.

B2. **No** pasar un único objeto `{id,coverages}` directo a `analyze()` porque `read()` exige lista de filas o `{jurisdictions:[...]}`. **No** pasar el release completo de siete jurisdicciones como si fuese una actualización editorial de una sola ciudad. Extraer un objeto Bogotá y envolver en `jurisdictions` con un elemento, de manera reproducible, preservando cobertura completa. Verificar que el archivo se pueda analizar como JSON `valid=1`, `invalid=0`, `excluded=0` en base/discos de prueba; SHA reproducible para la misma entrada.

B3. `RestrictionImportService::analyze()` **ESCRIBE** archivo privado, fila de import y auditoría; `normalize()` tiene `publish=yes` predeterminado. `analyze` por sí mismo NO publica, pero **no es autorización legal ni vista read-only**. En G1 SOLO usar DB SQLite temporal, `Storage::fake`, usuario editor de prueba y fuente activa registrada en el laboratorio. El flujo es estrictamente: (1) examinar fuente y firma/coberturas, (2) analizar en laboratorio, (3) inspeccionar diffs/errores, (4) **confirmar explícitamente** filas revisadas, (5) validar versiones, (6) publicar a DISCO FALSO SOLO para E2E. Nunca auto-confirmar o auto-publicar por detectar archivo nuevo o `valid=1`. No modificar el default histórico sin evaluar todos sus consumidores; documentar el riesgo y exigir aprobación humana en futuro entorno real.

B4. Una sola fuente mantenida para ese calendario **fuera de pruebas PHP**. Si `BogotaNovember2026PublicationTest.php` contiene 23 fechas/personalizados, convertir la entrada de ejecución a lectura del JSON único; no mantener segunda tabla manual. **Oráculo independiente:** conservar únicamente afirmaciones jurídicas centinela explícitas fijadas por autoridad (ej. 03-nov, 09-nov, 16-nov festivo, 30-nov, franjas 05:30–21:00 y conteo 23) y validadores genéricos para todas las fechas del archivo. NO generar el esperado del mismo objeto que se prueba. Para futuras ciudades/rotaciones, cambian archivos de datos, no PHP. Nunca cambiar un oráculo porque falló sin contrastar con una fuente oficial.

B5. No crear un `ApprovalService`, `DatasetCompiler`, CLI alternativo, JSON espejo en Flutter ni metadatos desconocidos mezclados dentro de `coverages`; si se necesita informe editorial, generarlo **en la evidencia** como salida estructurada de revisión, sin una segunda fuente de verdad versionada. Eliminar duplicados SOLO si son creados en este lote y se demuestra ausencia de consumidores; conservar cualquier archivo histórico existente.

## C. Integridad: publicación de jurisdicción COMPLETA y rollback

C1. En PR71, `RestrictionPublicationService::publishVersions()` cambia una ciudad entera mediante `$merged[] = $selected[$key]->payload`. **La solución no es añadir ifs particulares de Bogotá.** Para actualizar una cobertura ya existente, suministrar borrador de jurisdicción completo. Verificar por clave de identidad `(vehicleKind,serviceType)` todas las coberturas actuales y conservar las no modificadas por comparación estructural canónica, incluidos **known-empty, staleAfter, fuente y reglas**.

C2. **Protección mínima reutilizable en el dueño correcto:** antes de escribir un release en publicación **normal** (`action=publish`), cotejar coberturas antiguas de cada jurisdicción seleccionada contra su nuevo payload. Si falta una identidad existente, fallar con error inequívoco `REJECT_COVERAGE_LOSS` (o equivalente estable) ANTES de escribir draft/release/manifiesto. No transformar una caída en éxito ni restaurar silenciosamente una cobertura faltante: mostrar qué falta, obligando al editor a completar su propuesta. Evitar una segunda política/tabla/servicio. Si una implementación ya protegía ese caso, mostrar test y **cero nuevo código**.

C3. Este gate **NO** debe aplicarse a `rollbackCity`/rollback histórico: restaurar una versión anterior podría cambiar legítimamente el conjunto de coberturas. Mantener permisos y verificaciones existentes. **No añadir bypass automático** a publicación normal; el futuro retiro explícito de una cobertura requerirá decisión jurídica/operativa del propietario en otro lote, sin sacrificar seguridad ahora. Probar publicación nueva (sin baseline), cambios completos, rechazo parcial, rollback previo y conflictos de revisión.

C4. La protección de identidades **no sustituye** un diff de revisión: comprobar y reportar también eliminación o modificación de IDs de reglas, fechas, prioridades, ventanas, efecto y fuentes para cada cobertura. No bloquear automáticamente todo cambio de regla (una rotación legítima debe poder cambiar dígitos y reemplazar reglas), pero exigir revisión humana posterior antes de despliegue. Un cambio con cobertura vieja intacta pero todas sus reglas inesperadamente borradas se declara `REVIEW_BLOCKED` en G1 si no está expresamente solicitado; no `PASS` por tener misma identidad.

C5. Generar un resumen estructurado legible de diferencias **antes** de `confirm/validate/publish` en prueba: ciudad, total de coberturas antes/después, identidades, reglas agregadas/eliminadas/cambiadas, `verifiedAt`, `staleAfter`, URLs, hashes canónicos de preservadas, y motivos de bloqueo. Preferir extensión pequeña de tests o salida reutilizable del servicio existente, NO construir pantalla/admin nueva, API o motor. Si el admin ya genera esa vista, consumirlo en vez de duplicar.

## D. Demostración verificable multi-ciudad y sin código por calendario

D1. Baseline laboral = **release R2 completo y verificable**, con 7 jurisdicciones/12 coberturas, no el asset R4 de septiembre como representación de reglas actuales. El asset R4 puede usarse SOLO para comprobar compatibilidad/retroceso. El dataset R2 tiene Bogotá carro particular y taxi noviembre; las otras coberturas conservan sus fechas/editorialidad antiguas. No refrescar ni «arreglar» los otros 10 `staleAfter`.

D2. Caso oficial ciudad 1 **Bogotá**: tomar `2026-11-bogota.json` desde R2, analizar, confirmar y publicar en DB/disco de prueba **sin alterar valores jurídicos**. En la primera publicación contra baseline R2 idéntico puede producir no-op previsto; **NO modificar fechas/dígitos solo para forzar un nuevo release**. Para probar rotación por datos, copiar ese fichero a temporal de test (NUNCA al directorio oficial), modificar exclusivamente un dígito/una regla en ese temporal con etiqueta `SYNTHETIC_VARIANT_ONLY`, y demostrar cambio de salida sin editar una función PHP/Dart. No presentar esa variante como calendario oficial ni subirla a fixtures de producción.

D3. Caso ciudad 2 **Popayán** (`co-cau-popayan`) u otra jurisdicción EXISTENTE del baseline: usar un JSON de test separado, `SYNTHETIC_NOT_FOR_RELEASE`. Partir de su objeto completo, cambiar UN parámetro soportado (p.ej. dígitos del carro particular), conservar intactas las otras coberturas de esa ciudad y las otras seis ciudades. **PUNTO CRÍTICO:** Popayán en R2 está editorialmente VENCIDA. Si se quiere observar `RESTRICTED`/`ALLOWED` en un día presente, el fixture temporal aislado debe indicar explícitamente fecha de verificación y `staleAfter` DE PRUEBA futura, fuente `https://example.test/synthetic-not-for-release`, y fecha congelada del test; esos cambios nunca entran al archivo oficial ni cuentan como verificación real. Alternativa aún más simple: evaluar a fecha fija histórica anterior a su vencimiento sin alterar `staleAfter` y comprobar las dos respuestas. Elegir **una** estrategia fundamentada, no modificar datasets reales para satisfacer el test. Si las normas Popayán históricas ya expiraron para la fecha elegida, la alternativa de test temporal es obligatoria.

D4. Demostrar un **lote de dos jurisdicciones** desde dos fuentes de datos revisables usando los servicios ya existentes: generar drafts separados por jurisdicción, validar ambos y llamar `RestrictionPublicationService::publish([versionBogota,versionPopayan], revision, actor)` una sola vez en DB/disco de laboratorio. **Para que las dos jurisdicciones cambien de verdad**, usar únicamente dentro del test la variante temporal de Bogotá (D2) y la variante sintética de Popayán (D3), ambas marcadas `SYNTHETIC_NOT_FOR_RELEASE`; la Bogotá editorial OFICIAL original se prueba por separado como `NO_OP` frente a la baseline R2 y jamás se altera para provocar un cambio. Comprobar preservación del resto de las ciudades, 7 jurisdicciones/12 coberturas si no aparecen identidades nuevas, y que ambos cambios se aplican sin `if` por nombre ni modificaciones del motor. El release resultante de las dos variantes es **LAB SYNTHETIC**, NO una nueva versión jurídica de Bogotá/Popayán. **No mover variantes sintéticas a asset/productivo ni al manifiesto real.**

D5. E2E de esos bytes: PHP `DatasetPublisher`/`ManifestPublisher` en DB/disco fake produce JSON, versión, manifest y SHA; Flutter/Drift recibe **exactamente esos bytes** a través del flujo existente (HTTP loopback mock si hace falta) y verifica PHP SHA = manifest SHA = SHA del archivo importado = SHA entrada Dart. Preparar entorno env `PICORADAR_R1_EVIDENCE_DIR`/`PICORADAR_R2_EVIDENCE_DIR` u otros que existan; **ningún E2E obligatorio omitido por una variable vacía**, de lo contrario `E2E_BLOCKED`, no PASS. Verificar last-good ante hash malo. Los datos falsos de Popayán son aceptables únicamente en laboratorio y con etiqueta explícita; no afirmar un release jurídico nacional.

D6. Probar `timeWindows:[]` como todo el día **calendario** únicamente donde el contrato actual lo admite, y `startMinute==endMinute` como RECHAZO. No implementar una nueva semántica 06:00→06:00 ni jornadas especiales en G1; no confundir «24 h de día calendario» con ventana móvil de 24 horas.

D7. Documento final con matriz mínima de capacidades del motor **ya existentes frente a pendientes**, en una página: carro/moto/taxi, día/semana, festivos, paridad, horarios y ventana toda la jornada; carga/bus/especial/motocarro, acompañante/ocupantes, peso/ejes, zona/sentido, 06→06 y permisos. Estados `ALREADY_SUPPORTED`, `NEEDS_TYPED_CONDITION`, `NEEDS_GEO`, `LEGAL_NOT_VERIFIED`. **No es el entregable principal.** No extenderlo en este lote, no investigar 1.104 localidades ni volver a procesar 31/55 propuestas.

## E. Criterios de salida precisos, sin pruebas rituales

| Gate | Evidencia ejecutada que debe existir | Resultado permitido |
|---|---|---|
| E01 | SHA/ancestralidad Git R1→R2, ZIP R2 correcto, PRE/POST worktrees/WIP | PASS / BLOCKED_SAFE |
| E02 | JSON editorial Bogotá en formato `jurisdictions:[...]`, una ciudad y 3 coberturas exactas | PASS / FAIL |
| E03 | Análisis Laravel desde JSON real en DB fake, `valid=1`, **sin auto-confirm ni auto-publish** | PASS / FAIL |
| E04 | Una sola fuente editable fuera de tests y oráculos centinela independientes | PASS / FAIL |
| E05 | Publicación normal de ciudad parcial rechazada antes de release; rollback histórico conserva su comportamiento | PASS / FAIL |
| E06 | Diff estructural muestra reglas y coberturas; nada stale refrescado sin fuente | PASS / FAIL |
| E07 | Dos ciudades (Bogotá real + Popayán variante sintética) en un lote, sin ramas por ciudad | PASS / FAIL |
| E08 | R2 oficial no-op si idéntico; variante temporal modifica salida por dato y no por código | PASS / FAIL |
| E09 | PHP release + manifest + Flutter/Drift mismos bytes y SHA; 0 SKIP de E2E obligatorio | PASS / BLOCKED_E2E |
| E10 | Flutter last-good ante corrupción; estados de datos vencidos/UNKNOWN sin falsos ALLOWED | PASS / FAIL |
| E11 | Suite focal PHP import/version/publication/rollback; Flutter importer/sync/engine, sin tests históricos no afectados | PASS / FAIL |
| E12 | Formato, PHP Pint, `git diff --check`, hashes de archivos, branch limpia y un ZIP único | PASS / FAIL |

`G1_DATA_FIRST_PASS_SCOPED` = E01–E12 verificables PASS, incluyendo archivos de datos externos a test, flujo normal del importador y guard antipérdida. Si hay riesgo/entorno no verificado: `G1_PARTIAL_WITH_EVIDENCE` o `G1_BLOCKED_SAFE` con la causa específica. **`PRODUCT_RELEASE=NO` en los tres casos.** No usar cantidad de tests como métrica de cobertura nacional.

**Limitación del lote:** aunque G1 pase, no se afirma que el editor tenga una interfaz productiva con aprobación legal implementada, ni APK disponible ni soporte para todos los municipios. El próximo lote G2 debe atacar predicados tipados reales; no otro mes con test PHP nuevo.

## F. Reglas de ejecución y cambios mínimos

F1. **Prioridad de archivos:** verificar y REUTILIZAR `RestrictionImportService.php`, `RestrictionPublicationService.php`, `RestrictionRuleVersionService.php`, `RestrictionContractValidator.php`, `DatasetPublisher.php`, `ManifestPublisher.php`, `BogotaNovember2026PublicationTest.php`, tests de validación/rollback, `restriction_dataset.dart` y `DatasetSyncService`. Los únicos archivos nuevos de producto esperables son el JSON editorial de Bogotá y tests focales indispensables. Si el guard antipérdida falta, modificar como máximo su dueño `RestrictionPublicationService.php` y tests afectados; **no editar 10 servicios por estilo**. Un helper pequeño dentro de una clase actual es preferible a un nuevo servicio cuando solo tiene ese consumidor.

F2. **Rendimiento:** para este lote sin cambios de schema ni motor, no reconstruir asset Flutter, no ejecutar suite nacional de 3.000+ pruebas sin delta afectado. Ejecutar QA focal de PHP + Flutter datos/sync/import, y regresión cercana si se modifica un consumidor común. No hacer benchmarking, UI new, geo, instalaciones de dispositivo ni nuevas dependencias.

F3. No introducir timestamp variable dentro del archivo editorial para hacerlo pasar: fecha legal vs `verifiedAt` de revisión vs `staleAfter` editorial son distintos. JSON oficial inmutable con evidencia y SHA; release de laboratorio `generatedAt` puede cambiar y por tanto el hash del **release completo** puede cambiar entre dos ejecuciones, no declararlo bug si el payload funcional es igual. Comparar semántica canónica, incluidos invariantes legales, antes de inferir determinismo.

F4. Si se detecta una necesidad real de eliminar una clase entera de vehículo por derogatoria, **NO añadir flag bypass en G1**; registrar `REQUIRES_EXPLICIT_REMOVAL_WORKFLOW` con evidencia y pedir decisión posterior. El guard antipérdida no inventa que una regla derogada sigue activa para siempre; solo evita publicaciones silenciosas bajo una orden que no autorizó retiros. Rollback tiene semántica y permiso separados.

F5. Si son seguras identidad GitHub, permisos y costos remotos, se puede crear rama/PR **Draft** con un único commit limpio que incluya R1/R2/G1 sin mergear, preservando autorías y ancestría. Antes: listar archivos y confirmar que no se dispare CI pagada o escriba fuera del repo. **Si esos controles no se pueden probar, NO push**; guardar commit local verificable, patch COMPLETO y bundle reproducible en ZIP. No alterar PR71 ni PR79, no rebase/force, no tocar main/prod. No llamar `GITHUB_INTEGRATED` a un commit solo local.

F6. Terminar con una sola entrega; solucionar errores menores locales de ruta/quoting una vez, no delegar decisiones de arquitectura a mensajes de ida/vuelta. Ante incompatibilidad material con contratos, STOP en acción afectada y reportar bloqueador; conservar lo ya verificado. Código cambia SOLO lo necesario para objetivo, no mejoras cosméticas.

## G. ZIP único, autocontenido y verificable

**Ruta:** `D:\codex\_REPORTES\PicoRadar\...` después de comprobarla. **Un único ZIP**, con estos miembros (sin secrets, PII, `.env`, tokens, llaves ni historiales GPS):

- `FINAL_REPORT.md`: E01–E12, estado/alcance, bloqueos, fuentes oficiales usadas, autor y NEXT.
- `SOURCE_BOGOTA_EDITORIAL.json`: copia exacta del JSON nuevo aprobado, hash y ruta repo; `SECOND_CITY_SYNTHETIC_ONLY.json` solo como evidencia de laboratorio, fuera de datos oficiales.
- `BEFORE_AFTER_COVERAGES.json`: ciudad + identidad + hashes canónicos + reglas añadidas/retiradas + `verifiedAt/staleAfter` + informe de rechazos.
- `LARAVEL_REAL_LAB_RELEASE.json` + `LARAVEL_REAL_LAB_MANIFEST.json`: bytes exactos con SHA, **rotulados LAB SYNTHETIC** si incluyen variación de Popayán; incluir también el SHA del R2 original sin etiquetarlo producción.
- `FLUTTER_SAME_BYTES.md` y logs PHP/Flutter (comandos con exit codes, cero skips obligatorios), `SOURCE_ORACLES.md`, `CAPABILITY_MATRIX.md` conciso.
- `GIT_STATUS_PRE_POST.txt`, `GIT_REFS.txt`, `GIT_DIFF.patch` que incluya íntegramente **todos** los cambios y nuevos archivos mediante bundle/copia, `CHANGED_FILES_SHA256.csv`, `BLOCKERS.md` si corresponde.
- `MANIFEST.json` sobre todos los miembros excepto sí mismo y su SHA; `MANIFEST.sha256` con SHA final del manifiesto. Ejecutar verificación de CRC, 0 entradas traversal, hash/tamaños, extracción independiente y escaneo acotado de secretos. SHA-256 del ZIP se calcula **después** de cerrar el ZIP y se declara fuera de él, sin hash circular.

**Respuesta de Codex fuera del ZIP (máximo 10 líneas):** `TASK_ID`, `RESULT`, `BASE_R2_SHA`, `EDITORIAL_JSON`, `PRESERVATION`, `SECOND_CITY_SYNTHETIC`, `PHP_FLUTTER_SAME_BYTES`, `QA_PASS_FAIL_SKIP`, `LOCAL_COMMIT`, `REMOTE_PUSH`, `RELEASE=NO`, `ZIP_PATH`, `ZIP_SHA256`, `NEXT=CHATGPT_DIRECTOR`.

## H. Horizonte nacional, fuera de este lote

**G2:** soportar condiciones nuevas TIPADAS del mismo motor y validador (parrillero/acomp., ocupantes, carga peso/ejes, horario por corredores, motocarro y otras clases), basadas en actos oficiales representativos, estados `UNKNOWN` ante variable no comprobable, sin DSL ejecutable. **G3:** geografía DANE nacional (33/1104 existentes, centros poblados y coordenadas/segmentos verificados) sin duplicar y sin confundir centroide con ubicación en vía. **G4:** incorporar lotes multi-ciudad oficiales mediante G1 y ampliar modalidades, medir reglas vigentes que funcionan en Flutter, no ciudades en hojas de cálculo. **G5:** app distribuible, CI, firma APK, Mi A3, sincronización/rollback y GO humano. Cada lote futuro debe entregar capacidad o reglas reales; G1 no habilita medidas legales que requieren predicados aún inexistentes.

**FIN — G1 V2. UN MOTOR, UN IMPORTADOR, UN PUBLICADOR, UN JSON EDITORIAL POR CAMBIO, UN LOTE, UN ZIP. NO AUTO-PUBLICAR. SIGUE CHATGPT DIRECTOR DESPUÉS DEL ZIP.**
