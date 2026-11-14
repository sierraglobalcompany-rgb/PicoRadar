# CODEX LUNA — PICORADAR M1F · ACEPTACIÓN REPRODUCIBLE Y PRESERVACIÓN LOCAL DEL PARCHE M1E · KISS + PONYTAIL

**TASK_ID** `PICORADAR-M1F-ACCEPT-M1E-PATCH-PROVENANCE-KISS-20261108-DIRECTOR`.

**DIRECTOR TÉCNICO:** ChatGPT decide arquitectura, permisos, elegibilidad, normas, alcance y siguiente fase. **CODEX LUNA:** solo ejecutor. **RESULTADO M1E YA CERRADO:** `PASS_CANDIDATE_LOCAL` con pruebas reportadas 32 tests/86 aserciones, NO release, NO CI, NO Flutter, NO commit de código. **OBJETO DE ESTA TAREA:** convertir ese parche en candidato local reproducible, seguro y trazable, no volver a auditar el proyecto ni crear un nuevo publicador. **ZIP de salida único obligatorio.**

**NO INICIAR SI M1F YA ESTÁ EN EJECUCIÓN:** si ya existe este TASK_ID con gates validados, continuar donde quedó. No iniciar M1F V2, M1G ni repetir M1C/M1D/M1E.

## 0. Hechos que la dirección ya resolvió

1. ZIP real M1E: `PICORADAR_M1E_CALENDAR_OVERLAP_20261108.zip`, SHA-256 `7affcdfe60bc313bf416a4b4625057a3f506d4a7934c3eeb5da903dda38a2291`. El director comprobó **12 CRC**, 10 hashes/tamaños y manifiesto SHA-256 `82bf548ab31f5482c8a6d133a96fcc7c0884c558d0122c5de61323a0e9bd4ae6`. No repetir validación del ZIP en cada gate: una sola vez si cambian bytes, ruta, SHA o no hay evidencia material previa.
2. M1E patch `PATCH_CANDIDATE.diff` SHA-256 `68d6a60026609ac38140a9f924d68289af5f8d2882ba8f58a59775d89de75a04`. Exactamente tres archivos autorizados: `server/app/Services/RestrictionContractValidator.php`, `server/tests/Unit/RestrictionContractValidatorTest.php`, `server/tests/Feature/RestrictionPublicationServiceTest.php`. El único código de producción cambiado es el validador. NO copiar ni regenerar código que ya sea idéntico.
3. H4 local candidato reportado `HEAD=1b5badd9aafb7746ae9a904f0b1ba4903e83bf9c` y `TREE=dc2f2fdc5521af4cb4ad16969d76248b1e021688`. Código H4 no aparece en el GitHub remoto PR71. En el clon candidato los tres archivos están modificados SIN commit. La **base y sus padres deben verificarse realmente**, no atribuirles procedencia desde nombre de carpetas.
4. Original usuario `D:\codex\PicoRadar` reportó rama `recovery/20261019-modern`, HEAD `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`, tree `04a01f15475dd25fbcd40597120e6e44722b0504`, estado `D scripts/tests/test_hostinger_installer_browser.ps1` preexistente. ***Original READ-ONLY:*** NO checkout, reset, stash, clean, restore, rebase, branch switching, ediciones, git gc, borrado o actualizaciones de índices en esa ruta. No inspeccionar 101 WIP históricos fuera del alcance; su estado sigue `NOT_VERIFIED`.
5. ZIP candidato `BOGOTA_NOV_CANDIDATE.json`: schema2, 10 jurisdicciones, validación de contrato PASS. **Esto NO valida frescura**: Bogotá particular `staleAfter 2026-12-01T05:00Z`; moto `2026-09-23T05:00Z` vencido; taxi `2026-11-01T05:00Z` vencido a 2026-11-08. Medellín carro/moto `2026-11-10T05:00Z` (**2026-11-10 00:00 COT**). En 19 coberturas del JSON, 7 vencidas y 3 sin campo `staleAfter` (revisar contrato alternativo `nextReviewAt`, no inferir libres). Ninguna ciudad se declara READY. `PUBLISH_ALLOWED=NO`.
6. Gobierno ya establecido: Flutter/Riverpod/go_router/Drift local-first; Laravel único productor/revisor/publicador/rollback. Agente de fuentes solo lee y propone. `AGENTS.md`, baselines DOCX, `docs/CURRENT.md`, `docs/DESIGN_CONTRACT.md`, `docs/SOP.md`, seis leyes originales PingPongLaw prevalecen; leer solo los apartados pertinentes antes de escribir.
7. `PR #79` documental Draft y `PR #71` Draft. `main`, remotos, producción, Hostinger, Mi A3, ADB, firma, Android, PII, datasets activos y WIP 101 no están autorizados. NO GitHub writes de CodeX. `RELEASE=NOT_APPROVED`.

## 1. ALCANCE POSITIVO Y PROHIBICIONES DURAS

**Éxito M1F:** verificación local demostrable en el H4 real de exactamente las 3 rutas M1E, patch aplicado/ya presente, pruebas PHP verificables en suite focal con logs crudos y exit code, compatibilidad temporal con el parser Flutter H4 evaluada por lectura/test si toolchain existe, matriz explícita de datos vencidos. Crear opcionalmente **un único commit local** en rama aislada bajo la ley de trabajo si todas las condiciones de admisión pasan y no toca ningún remoto. Cero cambios de normas, UI, motor Flutter, schema, DB, composer.lock, scripts, assets, data de Bogotá u otras ciudades.

**Prohibido:** `push`, `merge`, publicar PR de código, `deploy`, `force`, `reset --hard`, `clean -fd[x]`, `stash` del usuario, `git add .`, rebase no autorizado, editar JSON de restricciones, extender `staleAfter`, añadir nueva dependencia, crear writer Python/Laravel paralelo, quitar reglas taxi, tocar pruebas Hostinger, manipular teléfono, instalador, CI remoto, QA físico, crear tarea M1G por cuenta propia, o marcar `ALLOWED`/`NO_MEASURE` en material no verificado. **No pedir aprobación por detalles mecánicos previstos**; solo STOP si falta una precondición real, documentando causa en ZIP.

**Rutas permitidas** (únicas con delta de código; no inventar archivos de infraestructura):
- `server/app/Services/RestrictionContractValidator.php`
- `server/tests/Unit/RestrictionContractValidatorTest.php`
- `server/tests/Feature/RestrictionPublicationServiceTest.php`

**Rutas de INFORMES**: `D:\codex\_REPORTES\PicoRadar\PICORADAR-M1F-ACCEPTANCE-20261108\` fuera de Git. Cualquier carpeta temporal aislada y creada por Codex va fuera del original. No guardar bundles de 100 MB ni vendor en ZIP. No modificar workspace `D:\codex\PicoRadar`.

## 2. G0 — PROCEDENCIA ÚNICA Y RECUPERACIÓN SIN PINGPONG

1. Usar preferentemente candidato **existente** `D:\codex\_CANDIDATOS\PicoRadar-M1E-Calendar-Overlap-20261108`; antes de tocarlo recoger `git status --short`, `git rev-parse HEAD`, `git rev-parse HEAD^{tree}`, `git branch --show-current`, `git remote -v`, `git diff --name-only`, `git diff --check`, SHA de tres archivos y diff. Comparar con hashes/sha del informe. Verificar que ninguno de esos paths tenga contenido nuevo del usuario distinto de M1E. **No descartar cambios sin autorización**.
2. Verificar en candidato `git cat-file -t 1b5badd9...` y procedencia histórica (padres/log/compare de solo lectura con `0d3a6a2...` si está presente). H4 no existe en remoto PR71; **no inferir que sea remoto ni prometer un PR integrable sin upstream**.
3. Si candidato H4 está correcto y sus 3 archivos forman exactamente el parche M1E esperado: **REUSAR**, sin `git apply` ni copiar. Si ausente, buscar **una sola vez** el ZIP M1E en adjuntos/ruta explícita, validar SHA externo, CRC y SHA del diff, y preparar clon nuevo desde H4 solo si base existe. No usar `main` histórico para reemplazar H4. Si no hay bytes/base, `BLOCKED_H4_OR_PATCH_INPUT` con demostración y sin nuevos ciclos.
4. Verificar en original *solo* HEAD/tree/estado y no editarlo. Si cambió, registrar diferencia como `ORIGINAL_OBSERVED_CHANGE` sin manipularlo. No confundir `WIP_NOT_VERIFIED` con cambios o pérdidas reales.
5. Leer instrucciones y precedencia exactas `AGENTS.md`, leyes PingPongLaw originales, baseline/contrato funcional que afecte a la validación; no modificarlo. Si falta DOCX binaria, dejar `NOT_READ` y limitar edición a comportamiento compatible existente, no inventar aprobación.

**G0 criterio:** `BASE_H4_CONFIRMED`, tres rutas exactas, parche no duplicado y originales preservados. Si no PASS, G1–G5 de ejecución se marcan `NOT_RUN`, paquete final explica causa sin repetir preflight.

## 3. G1 — CAUSA RAÍZ REPRODUCIBLE Y CRITERIO DE SEGURIDAD

1. Identificar en H4 real `legalValidFrom`/`legalValidUntil(Exclusive)`, `rotationPeriodStart/EndExclusive`, `validFrom`/`validUntil` de calendario y prioridades; estudiar cómo `RestrictionContractValidator` calcula `dateRangesOverlap` y `conflictFingerprint`. Contrastar con parser/motor **H4**, no sustituir por versión remota PR71 antigua.
2. Exigir evidencia RED previa a corrección atribuible al estado sin parche; si M1E incluyó test/fuente, recuperar log real de este mismo H4 o reproducir con un script temporal reversible sin modificar rama original. Un error de comando o namespace PowerShell se distingue de un defecto PHP. Ningún cambio que mejore solo un test sintético y empeore la jurisdicción entera.
3. Verificar GREEN de ciudad H4 completa y de dos reglas taxi 1/7 octubre, más rechazo a calendarios verdaderamente simultáneos, parciales, adyacentes, extremos inclusivos, legales abiertos, bounds ausentes/invertidos, offset y medianoche; el test de madrugada debe ser consistente con `validUntil` real del motor (no presupone que prolonga una regla más allá de su fecha). Si hay ambigüedad genuina, **fail closed** y reportar `DESIGN_DECISION_REQUIRED` sin inventar semántica.
4. Confirmar que `validFrom`/`validUntil` con `legalValidFrom` poseen semántica de calendario. Si parser H4 discrepa, STOP antes de integrar el patch; NO editar Flutter bajo este TASK_ID.

**G1 criterio:** misma causa demostrada y sin falsos permisos o pérdida de rechazo a solapes reales. No crear un plan general de doble calendario.

## 4. G2 — ACEPTACIÓN LOCAL DE CÓDIGO, SIN PUSH

1. Si el diff M1E sigue siendo exactamente los tres paths previstos, sin cambios de datos ni contratos, NO EDITAR POR INERCIA. Verificar que las ~438 líneas añadidas corresponden esencialmente a fixtures/test y que el cambio del validador es mínimo. `git diff --check` y comparar con SHA esperado `68d6a600...` si todo el archivo corresponde al original M1E. Si cambia por corrección justificada dentro de las tres rutas, generar diff nuevo y explicar cada hunk.
2. Ejecutar en candidato aislado sin infraestructura real ni DB productiva. `php -l` para los 3; `vendor/bin/pint --test` para los 3 si existe; PHPUnit/Pest según configuración existente, archivos `server/tests/Unit/RestrictionContractValidatorTest.php` y `server/tests/Feature/RestrictionPublicationServiceTest.php`. Guardar **stdout/stderr crudo, comando completo, versión PHP, binario PHPUnit, cwd y exit code**, no solo CSV agregado. Si dependencias ya están instaladas, reusar; NO instalar global ni romper vendor del usuario. No repetir suites masivas sin delta.
3. Ejecutar prueba de validación de **diez jurisdicciones** sobre el mismo `BOGOTA_NOV_CANDIDATE.json` que trae ZIP M1E, verificar hash `33b4eec352c1799e7f32af56cd89438dea3ca2e8bcbcbbe1f42a549ad3d0eb33` antes de usarlo. Guardar evidencia de la salida y `PUBLISH_ALLOWED=NO`. Evitar DB/storage real: `Storage::fake`, SQLite :memory:.
4. Calcular y reportar tabla `jurisdiction, category, staleAfter, nextReviewAt, estado a 2026-11-08T16:42Z` sin inventar `NO_MEASURE`: especial Bogotá car private Dec1 (vigencia técnica a esa fecha), moto Sept23 vencida, taxi Nov1 vencida; Medellín Nov10 próximo vencimiento. Para campos nulos, `MISSING_OR_ALTERNATE_CONTRACT` y buscar consumidor existente; **no modificar TTL**.
5. Se permite un único commit **local** en rama exclusiva del clon H4 si: (i) G0–G2 PASS, (ii) diff solo 3 rutas, (iii) códigos previos del usuario intactos, (iv) leyes de repo permiten commit local, (v) tests y diffs sin fallos. Rama ejemplo `fix/m1e-calendar-overlap-acceptance-local`; en ningún caso push. Preparar `git show --stat`, SHA del commit y `git diff BASE..HEAD` en ZIP. Si algún gate no pasa, NO crear commit y entregar patch reversible; resultado `PARTIAL`, sin solicitar nueva orden previa.

**Ningún cumplimiento de tests PHP implica CI verde, móvil aprobado, datos frescos, publicación ni release.**

## 5. G3 — CONSUMIDOR FLUTTER Y RIESGO DE FALSOS VERDES

**No implementar sync M3 aquí.** Únicamente demostrar por lectura de rutas concretas que el parser H4 consume `legalValidFrom`, fechas de calendario y zona `America/Bogota`, o dejar `CONSUMER_NOT_VERIFIED` si los bytes no existen. Si el toolchain Flutter ya está disponible localmente sin instalaciones globales, ejecutar solo el test existente relevante a restricciones y fechas (si existe), con comando, exit code y log. Si no existe `flutter`/Dart/cache, `NOT_RUN` sin bloquear el gate PHP ni inventar PASS móvil.

Verificar que un dato taxi/moto vencido o `nextReviewAt` pasado no se traduce a permiso afirmativo por un gate PHP aprobado. Si el consumidor H4 tiene manejo conocido `UNKNOWN/STALE`, reportar **código y prueba reales**. Si no se puede verificar, `FAIL_CLOSED_NOT_TESTED`, no marcar `ALLOWED`.

## 6. G4 — RESUMEN DE RIESGOS Y GATE DE SALIDA

La salida es exactamente una:
- `M1F_CODE_ACCEPTED_LOCAL`: H4 y procedencia verificables, fix 3 paths, tests PHP reales PASS, sin cambios secundarios, rama local/commit local autorizado o patch ya conservado, matriz de frescura con límites; **NO release**.
- `M1F_NO_CODE_NEEDED`: misma corrección ya presente en rama aislada y todas las pruebas ya vigentes/verificables bajo el mismo SHA, sin segundo commit; cumplir evidencia.
- `M1F_PARTIAL_BOUNDARY`: cambio PHP PASS pero Flutter o comprobación de H4 incompleta; justificar y dejar pendiente exacto, NO PASS total.
- `M1F_BLOCKED_CAUSAL`: razón concreta `BASE/CONTRACT/TEST_RUNTIME/DIFF_SCOPE`, nada destructivo; no improvisar arquitectura.

**No devolver un prompt nuevo.** Si surge un error menor de entorno: máximo una corrección de invocación (ej. escaping PS), 2 intentos relevantes documentados, después resultado causal. No repetir G0, recompilar AOT ni borrar vendor. El director decidirá siguientes fases con el ZIP.

## 7. G5 — ENTREGA ÚNICA EN ZIP CON MANIFIESTO Y VERIFICACIÓN

Crear exactamente **un archivo ZIP adjuntable**: `PICORADAR_M1F_ACEPTACION_LOCAL_EVIDENCIAS_UNICAS_20261108.zip`. Guardar TODO dentro y adjuntarlo **físicamente** en la conversación con ChatGPT (un enlace `D:\...` NO es adjunto). Incluir:

- `FINAL_REPORT.md`: TASK_ID, RESULT, resultado por gate G0–G4, SHAs HEAD/tree/base/commit si hubo, rutas modificadas, blockers no resueltos, `NEXT_ACTOR=CHATGPT`, `RELEASE=NOT_APPROVED`, `PUBLISH_ALLOWED=NO`.
- `PROVENANCE_AND_TREE.txt`: ruta de clon H4, `git cat-file`, parents, remoto/no-remoto, original read-only, estado antes/después, WIP 101 `NOT_VERIFIED` si no inspeccionado.
- `PATCH_ACCEPTED.diff`: diff completo de 3 rutas o `PATCH_CANDIDATE.diff` preservado con SHA; si no hay cambios nuevos, incluir diff vigente y declarar lo que realmente se aplicó.
- `TEST_COMMANDS_RAW.log`: comandos PHP, salida textual completa, versions, exit codes, gate candidato; no solo resúmenes.
- `TEMPORAL_CONTRACT_MATRIX.csv`: controles de no-simultaneidad, inclusividad, madrugada, offset, límites vacíos, real conflict; `PASS/FAIL/NOT_RUN` por evidencia.
- `COVERAGE_STALENESS_MATRIX.csv`: cobertura, fuente técnica, vencimiento/revisión, comparación con fecha, no declarar `READY` ciudad entera.
- `DIFF_SCOPE_AND_LAWS.md`: tres rutas y por qué, L1-L6, ausencia de nuevos escritores, no duplicar trabajo.
- `AUDIT_10_M1F.csv`: diez controles con nombres específicos y resultados reales, `NOT_VERIFIED` donde corresponda.
- `MANIFEST.json` + `MANIFEST.sha256`: hashes SHA256, tamaño, CRC32 de cada payload. `zipfile.testzip()` / equivalente y verificación independiente post ZIP; SHA externo en texto de entrega.

No incluir `vendor`, archivos grandes de SDK, datos privados, .env real, secretos, PII, base de datos productiva ni logs sensibles; logs test synthetic only. Evitar duplicar archivos que el director ya tiene; ZIP único con material causal necesario.

## 8. HITO SIGUIENTE (SOLO DIRECCIÓN, NO AUTORIZACIÓN PARA CODEX)

El director decide la admisión de código al repositorio remoto desde un commit local trazable y aprobación humana; no transferir H4 WIP en bloque a PR71. Después continúan fases **M1 nacional → M2 motor/agente lector → M3 Laravel→Flutter/cámaras/cuenta opcional → M4 CI/QA físico/firma/GO** según Plan Maestro. Hasta completar esos gates, cualquier estado verde global es falso. **CODEX SOLO EJECUTA, NO PLANIFICA FASES NUEVAS.**

**FIN ORDEN CODEX LUNA M1F.** No ejecutar si ya existe M1F en curso. **NEXT_ACTOR_AFTER_PACKAGE=CHATGPT**.