# CODEX LUNA — PICORADAR M1E · CORRECCIÓN CAUSAL FOCAL DE SOLAPAMIENTO CALENDARIO EN H4 · KISS + PONYTAIL

**TASK_ID ÚNICO:** `PICORADAR-M1E-CALENDAR-OVERLAP-VALIDATOR-KISS-20261108-DIRECTOR`.

**ORDEN DEL DIRECTOR CHATGPT:** Esta instrucción inicia M1E, **NO relanza M1C ni M1D**. M1D ya produjo `PARTIAL / BLOCKED_CONTRACT`, ZIP SHA `8bec41abe907bf63efeede6a0eefcf6908b7a26074624efd79c6e8a9c7b58f6f`. El director comprobó su integridad y contrastó la lógica del validador remoto, pero la fuente de implementación H4 es **local**: no copies código desde PR71 como si fuera H4. Esta tarea solo corrige la causa raíz comprobable, nunca simula publicación de datos. **Codex es ejecutor sin autoridad para cambiar arquitectura, normas, alcance comercial ni publicar.** `RELEASE=NOT_APPROVED`.

## A. Resultado exigido y criterio de interrupción

**Éxito técnico:** test RED de falso conflicto taxi 1/7 octubre reproducido, cambio KISS aislado en el validador H4, regresiones que aseguren que reglas verdaderamente concurrentes siguen bloqueadas, tests focales PHP completos, y ensayo de validación del dataset H4 / Bogotá noviembre en BD/discos fake, sin publicar nada real. Resultados explícitos `PASS`, `BLOCKED` y `NOT_RUN` por gate; no inferir aprobación comercial/municipal.

**Éxito honesto alternativo:** si H4 no coincide con el diagnóstico, el schema no da información suficiente para probar disjunción, falta entorno PHP, la corrección segura exige alterar engine Flutter, o aparece otro bloqueo causal, entregar `PARTIAL/DESIGN_DECISION_REQUIRED` **en un solo ZIP** con la prueba y la alternativa mínima delimitada. **No abrir otro pingpong o pedir una orden adicional por pasos mecánicos ya previstos.**

## B. Autoridad y preservación obligatoria

1. **ANTES DE ESCRIBIR**: en `D:\codex\PicoRadar` (solo lectura), reconocer `AGENTS.md`, `AGENTS.override.md` si existe, `docs/CURRENT.md`, `docs/SOP.md`, `docs/DESIGN_CONTRACT.md`, los baselines `docs/baseline/11_Cierre_Global_Baseline_v1_0.docx` y `12_Arquitectura_Tecnica_Android_First_v1.docx`, y leyes PingPongLaw L1–L6 originales instaladas. No describas compliance de DOCX si no los leíste. Si existen overrides más específicos, preserva su precedencia.
2. Orden de autoridad: seguridad/privacidad/store > cierre global > arquitectura técnica > flujos > diseño > plan maestro/documentos recientes. La directiva no revoca normas de producto establecidas. Registrar paths y SHA de documentos realmente consultados.
3. Fuente real del lote: `D:\codex\_CANDIDATOS\PicoRadar-R21V2-LOCAL` en H4 `1b5badd9aafb7746ae9a904f0b1ba4903e83bf9c`, árbol esperado `dc2f2fdc5521af4cb4ad16969d76248b1e021688`. El checkout original `D:\codex\PicoRadar` en `recovery/20261019-modern`, HEAD reportado `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`, no es el H4. No manipular checkout original ni 101 WIP históricos. Los hashes de estos WIP siguen `NOT_VERIFIED`.
4. Crear **un clon nuevo aislado** desde H4 dentro de `D:\codex\_CANDIDATOS\` con nombre que incluya `M1E` (o reutilizar un clon aislado limpio M1D si se demuestra sin modificaciones y procedencia exacta; nunca borrar directorios). Clon sin remotes, sin alternates externos ni manipular C:. Mantener el historial original, no usar `git clean`, `reset --hard`, `stash`, `restore`, `force`, cambios de reloj, cambio de firma, Android/ADB, Hostinger ni red/producción. Registrar HEAD/tree/status y si `vendor` está ignorado/existe.
5. GitHub: leer PR79 Plan Maestro y contrato en HEAD documental vigente si accesible; no escribir GitHub, ni en PR71, PR79, main o ninguna rama remota. Toda corrección será **candidato local**, con diff reversible. No modificar SDK/build ni instalar herramientas globales. Flutter `NOT_RUN` si no hay SDK disponible sin alteraciones.
6. Arquitectura congelada: Flutter + Riverpod + go_router + Drift local-first; Laravel **único** validador/publicador; un solo esquema de datasets versionados; sin cuenta obligatoria/GPS continuo en servidor; sin publicidad ni monetización activada; ningún segundo writer Python, backend, motor por ciudad ni cambio de baseline/UX.

## C. Rutas permitidas y prohibidas

**Edición potencial máxima, SOLO si tests RED prueban causa y semántica clara:**
- `server/app/Services/RestrictionContractValidator.php` (único archivo de producción candidato);
- `server/tests/Unit/RestrictionContractValidatorTest.php` (test RED/GREEN obligatorio);
- `server/tests/Feature/RestrictionPublicationServiceTest.php` (regresión publicada en **Storage::fake** y SQLite memory, si los tests existentes permiten extenderse sin nuevos fixtures complejos).

Si la ruta H4 difiere, localizar por `git ls-tree` + método/clase exactos y **NO** cambiar otro archivo de producción sin `DESIGN_DECISION_REQUIRED`. Se permiten artefactos temporales de test **fuera** del repo y reportes en `D:\codex\_REPORTES\PicoRadar\PICORADAR-M1E-CALENDAR-OVERLAP-20261108\`. No editar `mobile/assets/datasets/restrictions/restrictions_v1.json`, taxi/particular, catálogo, `composer.json`, lockfiles, migraciones, rutas, config, Flutter, servidor/cliente de manifests, `AGENTS.md`, leyes ni documentos de producto.

Si para una prueba PHP hay que crear harness efímero fuera del repo, registrar su SHA en ZIP. No dejar cambios ajenos en el clon ni hacer commit sin necesidad; máximo un commit **local** en rama de clon si hay delta legítimo; sin push ni PR.

## D. Ejecución cerrada G0–G6, sin rondas repetitivas

### G0 — procedencia y entorno (una comprobación cada uno)

- Verificar `git rev-parse HEAD`, `git rev-parse HEAD^{tree}`, `git status --porcelain`, `git remote -v`, alternates, y estado del original antes/después sin abrir contenidos WIP. H4 esperado arriba; `BLOCKED_BASE` si no coincide y no hay forma segura de reconciliarlo.
- Verificar presencia de `php`, `vendor/bin/phpunit`, `pdo_sqlite`, `sqlite3` y `server/vendor` disponible en el clon anterior sin copiar datos privados. Reutilizar el éxito M1D: ejecutar PHPUnit **directamente** con flags de extensión reales, descubiertos localmente, si PHP CLI default no tiene SQLite. NO correr dos Artisan a la vez (M1D tuvo carrera `bootstrap/cache/packages.php`). Si falta vendor y Composer offline dispone de caché: una sola instalación aislada `--no-interaction` sin cambios lock; si no, `BLOCKED_TEST_RUNTIME`, no descargar ni actualizar paquetes globales. No borrar recursivamente vendor por una política de limpieza.
- Comprobar archivo original M1D en el director de reportes solo por SHA/hashes si existe; no reabrir 20 archivos o buscar otro ZIP si la evidencia ya está incluida en este prompt. Reutilizar PASS anteriores con su SHA, no fingir que fueron ejecutados ahora.

### G1 — diagnóstico exacto del contrato H4 y consumidores (lectura acotada)

- Leer *completo* `server/app/Services/RestrictionContractValidator.php` H4; localizar `conflictFingerprint`, comparación de intervalos, manejo de `validFrom`/`validUntil`, `legalValidFrom`/`legalValidUntil` y ventanas calendarias (usar nombres exactos del código, **no presumirlos**). Comparar rutas del parser y evaluador Flutter **solo lectura** para entender alcance de ventanas efectivas: local-day/timezone (`America/Bogota`), límites inclusivos/exclusivos, cambios de día, prioridad, weekdays, holidays, digits y reglas de taxi.
- Comparar el par original `bogota-taxi-2026-10-2026-10-01` y `bogota-taxi-2026-10-2026-10-07` dentro del asset H4 por lectura exacta; documentar campos legal/calendar, prioridades, tipo de vehículo, servicios, dígitos, fuentes y su fingerprint. No inferir más allá del payload.
- Verificar el orden real de `RestrictionRuleVersionService::validate`, `DatasetReleaseValidator::validate` y `RestrictionPublicationService` para no confundir **validar** con **publicar**. Si está implementado un mecanismo equivalente ya utilizable sin cambio, elegir `ALREADY_SUPPORTED`; no forzar diff.
- **Diagnóstico clave:** distinguir dos intervalos legales abiertos de dos ventanas efectivas de calendario de un único día. Este test debe poder demostrar que no hay intersección de instantes, no solo que IDs/rangos textuales son diferentes.
- Si la semántica del motor H4 no permite demostrar que fechas disjuntas impiden activación simultánea, detener edición y reportar `DESIGN_DECISION_REQUIRED`; NO volver permisivo el validador.

### G2 — primero tests RED adversariales (NO parche aún)

Crear/añadir casos focales en el test unitario autorizado para cubrir:

1. **Falso conflicto real H4:** dos reglas taxi con misma prioridad, mismo scope, mismo bloque legal, días calendario distintos `2026-10-01` y `2026-10-07` -> deben poder coexistir (RED actual). Demostrar contra los dos IDs H4, no solo synthetic arbitrario.
2. **Mismo instante efectivo:** dos reglas idénticas con mismo día calendario, solapamiento horario y prioridad -> mantener `Conflicting restriction rules share scope and priority.` (GREEN antes/después).
3. **Intersección parcial:** ventanas calendario que comparten alguna fecha y tiempo -> rechazar, aunque identificadores distintos.
4. **Fin/inicio adyacente:** fechas o instantes de borde; documentar si el contrato trata extremos cerrados/abiertos; nunca permitir una intersección efectiva.
5. **Calendario omitido o abierto:** si no se puede probar disyunción, mantener la verificación actual y el rechazo correspondiente, NO aceptar por omisión de campo.
6. **Legal no solapado:** debe seguir válido y sin cambio semántico.
7. **Diferencias de zona horaria/medianoche:** construir un caso en `America/Bogota` con representaciones ISO UTC y offset; no comparar fechas lexicográficamente cuando compromete la respuesta. Si el contrato H4 no modela overnight con estas ventanas, registrar límite y probar el borde equivalente admitido.
8. **Reglas de otro tipo/ámbito:** mantener aislamiento previo por coverage y las demás validaciones de URL/fecha/dígitos/priority.

Guarda nombres, salida RED, comando, exit code y hashes de fixtures. Evita añadir un framework, helper general para todos los calendarios o lógica duplicada de Flutter.

### G3 — un único cambio mínimo de causa raíz

- Modificar **solo** la detección de conflicto del validador H4 para **rechazar cuando se demuestre que los instantes efectivos pueden coincidir** y solo eximir pares con disyunción **explícita, válida, comprobable** de sus ventanas. La mejora debe respetar primero intervalos legales y además el calendario **cuando ambos aportan evidencia suficiente**. A falta de campos completos o ante ambigüedad, conservar el comportamiento restrictivo vigente.
- Usar parsers/helpers existentes y métodos privados pequeños; no cambiar estructura JSON, prioridades, fuentes, contratos públicos, tipos, migraciones, clases nuevas, API, settings, fechas legales ni TTL. No suprimir el mensaje de error ni alterar otras validaciones.
- Si hay una función de evaluación temporal ya centralizada y reutilizable en PHP, preferirla a duplicación. No traer un motor completo de Flutter a Laravel.
- Prohibido editar las 28 reglas taxi, quitar su cobertura, convertir reglas `restrict` a `allow`, filtrar taxis de la jurisdicción o silenciar la excepción. No añadir `if Bogotá` ni `if taxi`, ni alterar producción para forzar resultados.
- Una sola implementación que satisfaga la matriz. Si aparecen nuevos defectos causales fuera del solapamiento, **no sumar un segundo parche** en el mismo lote: entregar una decisión focal con prueba.

### G4 — verificación técnica real, serial y limitada

- Ejecutar después `server/tests/Unit/RestrictionContractValidatorTest.php` y `server/tests/Feature/RestrictionPublicationServiceTest.php`, y los casos RED nuevos; registrar tests/aserciones, errores y exit code. Nunca declarar PASS si no se corrieron. Los 20/57 de M1D sirven de **baseline histórico**; no son conteo M1E.
- Reejecutar la validación H4 del conjunto `co-dc-bogota` en entorno sintético, además de las reglas car/private noviembre; **no alterar el dataset H4 empaquetado**. El resultado normal esperado es que el mismo taxi Octubre ya no provoque conflicto falso. Si aparece una colisión verdadera u otro validador/sourcing bloquea, `PARTIAL` honesto y no tratar de ocultarlo.
- Validar el candidato completo **offline en test** con `SQLite :memory:` y `Storage::fake` en todos los discos que toque; no tocar servidor/discos reales ni invocar acciones `publish` en un DB/Storage real. Si el test incluye el servicio Laravel que publica, solo con fakes y asserts de asset SHA/manifiesto/rollback. Incluir prueba `0 releases` en fallo y que no haya datos falsos verdes. Si no hay fuente verificada completa, no inventar exenciones/ámbitos ni declarar publicable.
- `git diff --check`, revisar `git diff --stat` y `git diff` byte a byte; comprobar que el parche no cambió otras funciones, que no creció código sin necesidad y que lockfiles/JSON/migraciones quedan bit a bit iguales.
- Flutter focal solo si ya hay SDK y configuración válida; si no, `NOT_RUN` con prueba de ausencia; **sin instalar Flutter ni copiar binarios**. CDN/red/Hostinger/ADB/QA físico/firma siempre `NOT_RUN` en este lote.

### G5 — diez controles de auditoría de salida

Entregar **diez filas** numeradas, cada una con status y evidencia concreta: 1 identidad H4; 2 docs/leyes y contrato; 3 conflicto taxi reproducido RED; 4 matriz temporal y casos negativos; 5 diff KISS ≤3 archivos permitidos; 6 tests unitarios/focales PHP; 7 candidato Bogotá aislado (o bloqueo exacto); 8 preservación original/WIP con honestidad; 9 GitHub/publicación/Flutter NOT_RUN reales; 10 siguiente actor y no pingpong. Estados `PASS`, `FAIL`, `BLOCKED`, `NOT_RUN`; NO transcribir el PASS del trabajo anterior como si se repitiera.

### G6 — entrega única, verificable y sin dispersión

Generar **exactamente UN ZIP** real en la ruta de reportes de M1E, adjuntarlo a la conversación y reportar su nombre y SHA256 externo, no solo un enlace `D:`. Estructura interna mínima:

- `FINAL_REPORT.md` con TASK_ID, resultado causal, HEAD/tree inicial/final, contexto del clon, síntesis real de tests, archivos alterados, fuentes, limitaciones, release NO, siguiente actor ChatGPT.
- `ROOT_CAUSE_H4.md` con citas de líneas/métodos reales del validador H4, IDs/intervalos fuente, explicación de diferencia legal vs calendario vs horario, decisión y por qué no es parche.
- `CALENDAR_CONFLICT_MATRIX.csv` con casos 1–8, inputs/expected/actual RED/GREEN y evidencia de ejecución; fechas/offset.
- `PHP_TEST_RESULTS.csv` con comandos literales, exit codes, tests/aserciones, baseline histórico separado, gates `NOT_RUN`.
- `BOGOTA_FULL_CITY_CANDIDATE_GATE.md` con validación de jurisdicción, restricciones parciales y taxi, emisión/NO emisión de asset fake, SHA de candidate si existe, booleans `PUBLISH_ALLOWED=NO`; si falló, causa exacta.
- `PATCH_CANDIDATE.diff` **si hubo cambios**, para restaurar y auditar. Si no hubo cambios, `NO_PATCH_REASON.md` con prueba/bloqueo exacto.
- `TREE_AND_PRESERVATION.txt` con HEAD/tree/status, SHA de JSON/lockfile, diff/paths permitidos, estado antes/después original, WIP `NOT_VERIFIED` si no se hashearon.
- `AUDIT_10_M1E.csv` con 10 controles/hallazgos, sin falsos PASS.
- `MANIFEST.json` (path, bytes, sha256, crc32 de cada payload, excluyendo manifest y su SHA) y `MANIFEST.sha256` (hash exacto del manifiesto). Validar testzip(), CRC/sha de payloads y external sha256. Prohibido incluir .env, passwords, claves, PII, credenciales, logs sensibles o datos de vehículos reales.

**Campos de salida obligatorios en respuesta Codex:** `TASK_ID`, `RESULT=PASS_CANDIDATE_LOCAL | PARTIAL | BLOCKED`, `ROOT_CAUSE_CONFIRMED`, `PATCH_FILES`, `TESTS_PASS/FAIL/NOT_RUN`, `FLUTTER=NOT_RUN/PASS`, `CODE_PUSH=NO`, `GITHUB_WRITES=NO`, `RELEASE=NOT_APPROVED`, `NEXT_ACTOR=CHATGPT`, nombre y SHA256 del **ZIP físico**.

## E. Alternativas cerradas (sin pedir órdenes infinitas)

| Situación | Acción cerrada |
| --- | --- |
| El validador H4 ya soporta ventanas disjuntas correctamente | `NO_PATCH_NEEDED` con reproducibilidad; centrar fallo en test/fixture, no fabricar cambio. |
| Dos taxis muestran misma vigencia legal, diferente calendario diario y misma firma | RED focal → cambio mínimo → GREEN con pruebas 1–8. |
| Fechas en H4 no permiten demostrar efectiva no-concurrencia o hay reglas con scope incompleto | `DESIGN_DECISION_REQUIRED`, no relajar validador; único ZIP. |
| Reparado el falso conflicto pero persiste bloqueo diferente (p. ej., fuente/verifiedAt, contrato/schema o manifest) | `PARTIAL_NEXT_ROOT_CAUSE` con stack, sin segundo parche. |
| Solo falta Flutter SDK para prueba móvil | PHP y candidato local continúan; `FLUTTER_NOT_RUN`, sin descargar. |
| PHP no disponible sin instalar paquetes ajenos | Reusar vendor offline una vez; si imposible `BLOCKED_TEST_RUNTIME`, no declarar código PASS. |
| Imposibilidad de trabajar en clon aislado sin afectar original | `BLOCKED_BASE/ISOLATION`, no tocar original ni WIP. |
| Test de publicación fake pasa | `PASS_CANDIDATE_LOCAL` exclusivamente, **NO significa publicado**, ni fuente legal completa, ni APK probado. |

## F. Plan posterior congelado y roles

El director ChatGPT revisa **solo ZIP M1E** y decide cuándo y cómo seguir M1 cobertura nacional, M2 agente lector/pipeline Laravel existente, M3 Flutter/CDN/cámaras/cuentas opcionales, y M4 CI/QA físico/JNI/firma/release humano. No crear la fase M1F por costumbre. No reabrir M1B/M1C/M1D. La fuente oficial de particulares noviembre y taxi octubre/noviembre se considera evidencia primaria focal pero **no** autoriza claims fuera de ámbito legal verificado.

**ESTADO OBLIGATORIO FINAL: `CODEX LUNA → CHATGPT`, `RELEASE=NOT_APPROVED`, `GITHUB_WRITES=NO`.**