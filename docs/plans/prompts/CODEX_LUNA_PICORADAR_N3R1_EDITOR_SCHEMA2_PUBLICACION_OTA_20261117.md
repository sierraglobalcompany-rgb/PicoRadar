# CODEX LUNA — PICORADAR N3-R1 · CIERRE REAL DEL EDITOR NACIONAL SCHEMA2 Y PUBLICACIÓN OTA

**TASK_ID:** `PICORADAR-N3R1-EDITOR-SCHEMA2-PUBLICACION-OTA-ONEBATCH-20261117`  
**TIPO:** una sola ejecución vertical de PRODUCTO, no auditoría ni preflight repetitivo.  
**SUSTITUYE TOTALMENTE:** `CODEX_LUNA_PICORADAR_N3_EDITOR_NACIONAL_OTA_HTTPS_20261117.md`. NO ejecutar ambas órdenes.  
**DIRECTOR:** ChatGPT decide contratos y acepta la entrega. **EJECUTOR:** Codex Luna, único escritor en candidato aislado.  
**OBJETIVO DE PRODUCTO:** desde el panel administrativo Laravel, crear/editar un borrador nacional de restricciones **schemaVersion=2** con días, dígitos, horas, modalidades admitidas y habilitación de consulta, validarlo/publicarlo mediante los servicios existentes; el archivo publicado debe ser consumible por **el mismo motor Flutter nacional** sin APK o motor por ciudad. **HTTPS de un dispositivo real es un gate distinto y condicionado a un servidor QA legítimo; no debe bloquear el editor ni la publicación QA aislada.**

## 0. Punto de partida: no repetir lo cerrado

- Proyecto único: `sierraglobalcompany-rgb/PicoRadar`. Trabajar desde `D:\codex\PicoRadar` solo si es la ruta real del checkout. Leer `AGENTS.md` y reglas anidadas; aplicar PingPongLaw L1–L6 (KISS, antirruido, antiparches, diseño humano, verificación, antipingpong), no instalar herramientas/skills/hooks por costumbre.
- **Último árbol verificable de producto + test R2:** `07f93bac253f9d6abf5f6535720786f571d26414`. Se recompuso de forma independiente desde el bundle RC2, parche V4-R1, parche V5-R1 normalizado *solo en copia temporal* y parche R2. Base V5: `10ab7af9d07ea6ea941ba54289c9c0455b6d1f70`. El `HEAD=182a8821...` y el índice Windows `24408f...` de los informes NO prueban que R2 esté incorporado al checkout real. Comprobar HEAD, `git status --porcelain=v1`, índice real y árbol del candidato UNA VEZ; conservar los WIP existentes, sin `reset --hard`, `git clean`, `git add -A` sobre checkout ajeno ni segundo escritor. Aplicar `PATCH_R2_tests.patch` solo si falta y solo sobre el árbol V5 exacto en índice/checkout **aislado**, verificando `07f93...`.
- **R2 YA acreditado en su ámbito:** Laravel servicios existentes → 3 snapshots sintéticos completos A+B → manifest/asset SHA exactos → HTTP loopback → `DatasetSyncService` → Drift → selector/motor, A `sí→no→sí`, B intacta, last-good, datos sintéticos preservados. `HISTORICAL_3=PASS`, `flutter analyze=PASS` según logs. **No reconstruir ni volver a ejecutar R2 salvo que el nuevo cambio afecte ese contrato.** V4-R1 `3347 PASS/11 SKIP/0 FAIL` únicamente en su árbol; V5 focales `175 PASS`, QA global V5 incompleta. La APK DEV V5 `1.0.1+2` existe pero **OTA está desactivada**; no volver a empaquetar 245 MB sin cambio móvil/configuración real.
- `GITHUB_PRODUCT=HOLD_SECURITY`, PR #79 contiene **solo documentación DRAFT**, no el árbol de producto. No hacer push/merge, publicar CDN real o cambiar firma/Android Mi A3. No usar datos personales ni producción. Datos legales LAB parciales, no autorizan declarar `ALLOWED` sin cobertura acreditada. Fuente institucional oficial puede bastar para lo expresamente publicado sin decreto PDF; este lote prueba con fuentes **sintéticas inequívocas**, no investiga 1.104 municipios.

## 1. CAUSA REAL ya localizada por ChatGPT en el código R2 — no repetir el diagnóstico

Inspeccionar SOLAMENTE el flujo indicado y comenzar a implementar:

1. `server/app/Http/Controllers/Admin/RestrictionRuleController.php`: `store()` usa `RestrictionFormPayloadBuilder` legado y limita `max:8`; `edit()` deja **solo schema1 editable**, y `update()` **rechaza explícitamente schema2** («importa un JSON schema2»). También el filtro de índice solo reconoce `car/motorcycle`.
2. `server/app/Services/RestrictionFormPayloadBuilder.php`: acepta `car/motorcycle` y `private/taxi`, **máximo ocho coberturas**, no emite `schemaVersion=2`, no emite `coverageCompleteness` ni condiciones; rechaza horas inicio=fin, por lo que no puede representar `fullDay:true` existente.
3. `server/resources/views/admin/restrictions/form.blade.php` y `partials/rule-fields.blade.php`: los selectores/templating/round-trip todavía son legado; un borrador schema2 **no puede editarse con seguridad**. No basta con agregar opciones HTML: hay que preservar el contrato y la edición existente.
4. `server/app/Services/RestrictionContractValidator.php` ya reconoce exactamente **NUEVE pares válidos schema2**: `car/private`, `car/taxi`, `car/special`, `motorcycle/private`, `truck/private`, `truck/public_cargo`, `bus/public_passenger`, `bus/special`, `motocarro/private`. Exige `coverageCompleteness`, admite `fullDay:true` en ventana con minutos iguales y condiciones tipadas: `pillion_present`, `occupants_at_least`, `occupants_below`, `gross_weight_kg_gt`, `axles_at_least`, `inside_scope_ref`. **No admitir otros pares ni crear schema3**.
5. `RestrictionRuleVersionService::validate()` valida el borrador contra `Dataset.schema_version`; `RestrictionImportService` ya importa JSON schema2. `RestrictionPublicationService` y `DatasetReleaseValidator` publican snapshot versionado y mantienen el bloqueo `COVERAGE_COMPLETE_REQUIRES_SPATIAL_QA`. Reutilizar estos servicios y sus roles/gates (`datasets.edit`, `datasets.review`, `restriction.material_change.approve`). **No saltarse el control de `complete` para ganar PASS.**
6. Pruebas disponibles: `server/tests/Unit/RestrictionFormPayloadBuilderTest.php`, `server/tests/Feature/RestrictionRuleControllerTest.php`, `server/tests/Feature/RestrictionRouteIntegrationTest.php`, `server/tests/Feature/RestrictionMaterialApprovalWorkflowTest.php`, `server/tests/Feature/RestrictionPublicationServiceTest.php`, `server/tests/Feature/RestrictionSchemaV2LabRoundTripTest.php`, `server/tests/Feature/RestrictionNationalLabPublicationTest.php`; cliente `mobile/test/core/sync/restriction_g2_same_bytes_test.dart` (ruta verdadera). Reutilizarlas. **No abrir suites nuevas paralelas.**

## 2. IMPLEMENTACIÓN: una corrección integrada, no nueve subproyectos

### N3-1. Editor schema2 realmente utilizable por humanos

- **Extender el formulario y su builder/endpoint EXISTENTES** para crear y actualizar borradores schema2, sin borrar la compatibilidad ni rebajar silenciosamente schema1. La selección de nueve pares debe validar la pareja, no ofrecer combinaciones cartesianas inválidas. Permitir hasta **9 coberturas diferentes por jurisdicción** en la petición/builder; una duplicada debe rechazarse. Si la limitación de ocho tiene otra razón de producto real, resolverla con evidencia en el mismo lote, no omitir la novena combinación.
- En el editor actual, exponer con entradas humanas y formato seguro: vehículo/servicio, `coverageCompleteness=partial` por defecto, fechas de revisión y vencimiento editorial, fuentes HTTPS, días 1–7, paridad **de fecha**, posición/lista de dígitos, rangos, `fullDay` (inicio=fin **solo** con flag tipado), festivos, vigencia, prioridad, efecto y fuente. **Conservar intactos** `schemaVersion`, `coverageCompleteness`, `conditions`, `municipalityCodes`, `consultationEnabled` y cualquier campo tipado válido no editado. Nunca convertir schema2 a schema1 durante un POST o PUT.
- Para las seis condiciones tipadas usar **el camino mínimo comprensible** en el mismo formulario: controles simples si ya existen; de lo contrario, sección avanzada de condiciones en JSON canónico **por regla**, validado en backend con `RestrictionContractValidator`, con error de campo comprensible y round-trip exacto. No crear un constructor visual complejo ni aceptar JSON sin validar. Si una condición existente no puede editarse sin riesgo de perderse, bloquear esa operación con mensaje preciso; nunca eliminarla o sobrescribirla silenciosamente.
- **Diferenciar bandera territorial:** `Jurisdiction.enabled` es administración, `consultationEnabled` del dataset es consulta pública. El toggling jurisdiccional debe reflejarse en la **revisión aprobada publicada**, no solo en la BD. El contrato actual **no tiene un booleano de habilitación por cobertura**: no inventar uno; por modalidad, conservar o retirar de forma segura el bloque de cobertura versionado conforme al contrato y garantizar `UNKNOWN` (nunca `ALLOWED` por ausencia). Si una deshabilitación por modalidad no es expresable sin pérdida o ambigüedad, dejarla `PARTIAL_CONTRACT_LIMIT` explícita en vez de inventar un gate falso. Conservar reversión de la versión anterior.
- Nunca publicar `coverageCompleteness=complete` sin QA espacial/exenciones certificados; dejar `partial` y estados `UNKNOWN/STALE` cuando falta evidencia. `allow` no implica por sí solo circulación libre en una cobertura incompleta. No inventar polígonos, parrillero, carga o excepciones jurídicas.
- Respetar permisos actuales: Editor puede editar y NO publicar; Reviewer puede revisar y NO editar; Admin/Super Admin dentro de permisos vigentes; la aprobación de cambios materiales sigue su gate independiente. Evitar autopublicación por error y bypass de CSRF. Guardar borrador NO debe publicar.
- La ruta JSON import existente sigue siendo alternativa para lotes complejos; **no es suficiente** como único editor manual de números/días/horarios. No abrir pantalla/panel paralelo.

**ACEPTACIÓN N3-1 (Laravel QA sintético):** usando el formulario/controller real, crear un borrador schema2, volver a abrirlo y cambiar **día + dígitos + horario + modalidad**, persistir y recuperar exactamente el mismo esquema; mantener `conditions`/`fullDay` y `municipalityCodes`/`consultationEnabled` sin pérdidas. Validar la novena combinación y el rechazo de pareja inválida. Confirmar que la edición legacy schema1 no regresa accidentalmente; que la guardia de `complete` sigue activa y que Editor no puede publicar.

### N3-2. Publicación completa e integración desde la edición real

- Con base **SQLite QA efímera**, reutilizar workflow de revisión/aprobación, `RestrictionRuleVersionService`, `RestrictionPublicationService`, `DatasetReleaseValidator`, `DatasetPublisher` y `ManifestPublisher` sin implementar otra API. Tras cambios por formulario de A, publicar junto a B y cualquier jurisdicción previamente aprobada **en el snapshot íntegro**, con `schemaVersion=2` en reglas y schema propio del manifiesto sin confundirlos. No usar ni modificar DB real.
- Tres revisiones sintéticas: A (`1,2` lunes), A editada (`3,4` martes, horario distinto), A consulta deshabilitada; B permanece idéntica; reversión de A reactivada en revisión posterior **solo si el procedimiento existente la requiere**. El número de revisiones no es un fin en sí mismo: agregar solo lo necesario para demostrar transición y preservación. Guardar evidencia de `publicationRevision`, sha256 bytes del asset, SHA/manifiesto, fuente sintética, aprobación, rechazo no-autorizado y rollback/last-good. Municipio nuevo fuera de las 73 editoriales se identifica con su DIVIPOLA/departamento reales en catálogo geográfico, **sin afirmar norma oficial**.
- **Prueba diferenciadora obligatoria**: los bytes producidos por una EDICIÓN REAL del controller/builder deben alcanzar el publicador. Reutilizar R2 para importación/Drift, sin repetir toda la prueba `Laravel→HTTP→Drift` si el formato publicado sigue intacto; si hay cambio de contrato, ejecutar el caso R2 afectado una vez contra árbol final. No probar solo `RestrictionPublicationService::publish` como si eso acreditara el nuevo editor.

**ACEPTACIÓN N3-2:** modificación desde formulario → borrador schema2 → revisión y aprobación → publicación asset/manifiesto A+B íntegro; nueva consulta refleja el cambio, otra jurisdicción intacta, origen y SHA correctos, `UNKNOWN/STALE` si falta cobertura. Si no hay infraestructura para cliente, el gate servidor termina `PASS_SCOPED_SERVER` y se conserva R2 como `PASS_SCOPED_HTTP_LOCAL`, no `OTA_HTTPS_PASS`.

### N3-3. HTTPS OTA QA: aprovechar solo un origen seguro disponible

- Determinar UNA sola vez si existe **HTTPS QA legítimo y accesible con certificado válido**, mismo origen de manifest y CDN como exige `datasetSyncServiceProvider`. Sin origen disponible, escribir `OTA_HTTPS_QA=NOT_RUN_ENV`, registrar dependencia exacta, **continuar la entrega N3-1/N3-2 y no hacer 5 intentos de túneles, Docker ni certificados improvisados**.
- Si existe, comprobar en QA manifest/asset íntegros, ETag/304 si se aplica, SHA incorrecto rechazado, last-good y, si se puede sin intervenir teléfono, consumidor/Drift con configuración de producto no simulada. HTTP loopback R2 **no** equivale a HTTPS productivo. **Ni siquiera HTTPS en simulación acredita Android físico**.
- APK nueva solo si cambió código móvil o se configura un endpoint real que justifique build. La APK V5 offline se reutiliza como evidencia previa, no adjuntarla de nuevo. **NO instalar, borrar o actualizar Mi A3** sin gates de firma, migración, datos y autorización específicos.

## 3. VERIFICACIÓN SOLO DEL DELTA Y SALIDA ÚNICA

1. Ejecutar tests PHP del **builder/controlador/roles/publicación** alterados, con datos sintéticos y `php artisan test --filter=...` focales aplicables. Si cambió el contrato de serialización, pruebas de paridad PHP/Dart afectadas. Correr una sola suite Laravel final si `AGENTS.md` lo exige para cierre, sin repetir históricos ajenos. Usar formatter PHP únicamente en archivos editados, no refactor del repositorio.
2. Si **NO cambió Dart**, NO repetir 3347 pruebas Flutter ni reconstruir la APK. Si sí cambió código Dart: `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test` UNA vez sobre árbol final conforme a `AGENTS.md`, más focales causales; documentar errores de entorno reales sin declarar PASS. Si solo cambió PHP/Blade, QA server, revisión de HTML sensible y verificación de seguridad/CSRF; no construir Android por protocolo.
3. Atribuir toda afirmación a árbol SHA, test/comando y exit; distinguir `PASS_SCOPED` del release. Los bloqueos de red/CDN/dispositivo impiden **solo esos gates**, no el desarrollo independiente. **No redactar otra auditoría 10×10 ni generar nuevo plan maestro.**
4. Un **ÚNICO ZIP** en `D:\codex\_REPORTES\PicoRadar\<TASK_ID>\delivery\` con `FINAL_REPORT.md`, `GATES.csv`, `EVIDENCE_MATRIX.csv`, logs focales compactos, manifiesto SHA256/tamaño/CRC32, `RECOVERY.patch` aplicado sobre BASE_TREE explícito y comprobado en clon aislado, commit/tree/índice y estado WIP, capturas/síntesis del formulario si se prueban sin PII, y evidencia sintética mínima. APK solo si hay build nuevo realmente necesario. **No enviar archivos sueltos** ni incluir bundle de 85 MB, APK V5 de 245 MB, secretos, matrícula/fotos/cédulas ni bases privadas. Comprobar CRC ZIP, hashes y reproducibilidad del patch antes de entregar.
5. GitHub producto sigue `HOLD_SECURITY`: **NO push/merge/force push**. Guardar el código resultante de forma reproducible en parche ZIP; el Director actualizará documentación en PR79 después de recibirlo. No modificar worktree ajeno, registro de vehículos, ni fuentes legales vigentes por pruebas sintéticas.

## 4. SALIDA EXACTA Y RESPONSABLE

```text
TASK_ID=PICORADAR-N3R1-EDITOR-SCHEMA2-PUBLICACION-OTA-ONEBATCH-20261117
BASE_TREE=<SHA real identificado>
FINAL_TREE=<SHA reproducible>
FORM_SCHEMA2_CREATE_EDIT=PASS|PARTIAL|FAIL
NINE_PAIRS_AND_FULLDAY=PASS|PARTIAL|FAIL
CONDITIONS_ROUNDTRIP=PASS|PARTIAL|FAIL
JURISDICTION_TOGGLE=PASS|PARTIAL|FAIL
MODALITY_DISABLE=PASS|PARTIAL_CONTRACT_LIMIT|FAIL
ROLES_EDITOR_REVIEW_PUBLISH=PASS|PARTIAL|FAIL
ADMIN_TO_FULL_PUBLICATION=PASS_SCOPED_SERVER|FAIL|NOT_RUN_ENV
PUBLISHED_MANIFEST_SHA=PASS|FAIL|NOT_RUN_ENV
OTA_HTTP_R2=CARRIED_PASS_SCOPED
OTA_HTTPS_QA=PASS|FAIL|NOT_RUN_ENV
OTA_ANDROID=NOT_RUN_SAFE|PASS|FAIL
MOBILE_FULL_QA=REUSED_PRIOR_TREE|PASS|FAIL|NOT_RUN_ENV
APK_NEW=YES|NO
GITHUB_PRODUCT=HOLD_SECURITY
PRODUCT_RELEASE=NO_GO
ZIP_PATH=<ruta única>
ZIP_SHA256=<hash>
NEXT_ACTOR=CHATGPT_DIRECTOR
```

**Éxito operativo sin falsas exigencias:** un editor schema2 real, cambios manuales publicados con preservación de otras jurisdicciones y evidencia de controles. Si falta HTTPS QA, entregar esos resultados con la dependencia exacta y **NO** transformar la falta de infraestructura en una nueva ronda de análisis. Si hay limitación de modalidad no expresable en el contrato actual, señalarla sin eliminar seguridad ni abrir schema3 por impulso. Codex ejecuta una sola orden integral, no pide al usuario decidir fallos mecánicos.

**FUERA DE N3-R1, PERO SIGUE SIENDO NECESARIO PARA LLEGAR AL 100%:** registro opcional de usuarios, consentimiento y privacidad local de placas/documentos; Super Admin de clientes/filtros/CSV y correos permitidos; actualización OTA de CDA/SOAT/aseguradoras, aliados/campañas/publicidad sujeta al alcance Free 1.0; HTTPS y Android físicos, seguridad GitHub y firma release. La geografía de 1.104 códigos no demuestra cobertura normativa de 1.104 municipios. No construir motor separado por ciudad.

# SIGUE CODEX LUNA — EJECUTAR N3-R1; DESPUÉS DEL ZIP SIGUE CHATGPT DIRECTOR