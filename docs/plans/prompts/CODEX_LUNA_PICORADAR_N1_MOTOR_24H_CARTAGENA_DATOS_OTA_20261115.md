# CODEX LUNA — PICO RADAR N1 · MOTOR NACIONAL DE DATOS / 24 HORAS / CARTAGENA / OTA

**TASK_ID:** `PICORADAR-N1-NATIONAL-ENGINE-DATA-ONEBATCH-20261115`  
**ORDEN:** ejecutar UN macrobloque de IMPLEMENTACIÓN y devolver UN ZIP de evidencia. Director técnico: ChatGPT. Ejecutor: Codex Luna.  
**NEXT_ACTOR AL ENTREGAR:** `CHATGPT_DIRECTOR`.  
**ESTADO INICIAL:** `PRODUCT_RELEASE=NO_GO`. No autoriza merge, push de producto, staging/CDN real, Hostinger, Android físico, firma release, ni publicación de restricciones LAB al público.

## 0. Meta, límites y por qué este bloque existe

**Meta principal:** avanzar el producto nacional con UN motor `schemaVersion=2` y reglas descargables por autoridad/ciudad/municipio/departamento/centro poblado: implementar soporte general y probado para una ventana **24 horas anclada** cuando el acto oficial así lo exige; añadir cobertura de motocicletas de Cartagena sustentada en una publicación oficial; preparar el régimen estacional de fin de año con garantías, y producir un snapshot LAB por manifiesto explícito sin perder las otras jurisdicciones. **No construir un motor por ciudad.**

**Este macrobloque NO intenta investigar 1.104 municipios en una ronda, ni declarar cobertura nacional completa.** El hito de producto nacional es que la arquitectura incorpore datos nuevos sin APK por cambio de calendario. El catálogo geográfico y las fuentes jurídicas se completarán por lotes reproducibles. Todas las categorías sin respaldo permanecen `UNKNOWN/STALE`/pendientes; **ausencia de fuente no significa circulación autorizada**.

**No volver a ejecutar:** F0/F1/F2 (PHP 33/279, Flutter/Drift/OTA anteriores), RC1 (panel schema2, tres pruebas de publicación), RC2 (build Android), RC3 navegación antigua/ADB ni R2 de firma del Mi A3. Las comprobaciones nuevas SOLO cubren el delta funcional de N1. No hacer 10+10 auditorías de nuevo: el director ya hizo la revisión adversarial y fijó estas decisiones. Seis leyes: KISS/Ponytail; cero ruido; cero parches acumulativos; UX veraz; evidencia reproducible; cero pingpong.

## 1. Fuente de verdad y custodia: F0 mínimo (una vez)

1. Trabajar en Windows bajo `D:\codex\<proyecto>` en clon **nuevo/aislado** o worktree de Codex sin pisar el checkout del usuario; confirmar que NO hay otro escritor PicoRadar. Buscar primero la ruta real que ya utiliza Codex, no recorrer todo `C:\` o `D:\`.
2. BASE PRODUCTO exacta: `HEAD=7e2e1f3f311b18e29f63d3a5e05e9439a11c4289`, `TREE=e312c7632fce4c43f9419cba60903e7420c46d85`. Restaurable desde el bundle `GIT/full-final.bundle` dentro del ZIP RC2-R1 previamente recibido, SHA-256 del bundle `aa85a9beae933457b432b6bbd1d1af47b3bee6102a5001482693c6d91d0df1a9`. Si el clon de producto ya tiene ese HEAD y está limpio, reutilizarlo; si difiere, NO resetear WIP: clonar desde ese bundle en carpeta aislada. Anotar HEAD/TREE/status inicial. Ni checkout principal ni Mi A3 deben cambiar.
3. Estado anterior validado: ZIP R2 de QA Mi A3 SHA256 `57fce71df800dcb25849652fd9039d1d9bb2e56158f992138402eb5c6416bd9a` confirma firma antigua=RC2, pero `RUNTIME_SCOPE=NOT_TESTED_NEW_CODE`; no volver a solicitar el teléfono en N1.
4. GitHub: PR #79 `docs/plan-maestro-nacional-v2-20261107` está DRAFT DOCUMENTAL, Plan Maestro hasta §CN. **NO confundir sus commits con código de producto.** Código RC1/RC2 no está remotamente sincronizado; antecedente Gitleaks 9 hallazgos benignos y uno Power BI histórico sin cotejar, por tanto N1 **NO hace `git push`, `merge`, `force`, PR ni sube informes con valores de secretos**. Conservar cambios mediante commit local y ZIP de delta.
5. Entorno: PHP, Python, Flutter/Dart son independientes. Identificar una sola vez los ejecutables fijados por repo. Flutter exacto 3.47.9/Dart 3.13.7 usado en RC2; no actualizar major ni descargar SDK repetidamente. Sin Flutter, escribir pruebas Dart y reportar `DART_TEST=NOT_RUN_ENV` (NO PASS). No correr Gradle, APK ni emulador en N1.

## 2. Fase A — función genérica schema2: ventana 24 horas anclada

**Hallazgo real:** PHP `server/app/Services/RestrictionContractValidator.php`, Flutter `mobile/lib/features/pico_placa/data/restriction_dataset.dart` y `mobile/lib/features/pico_placa/domain/restriction_rule.dart` rechazan `startMinute == endMinute`. El motor ya interpreta ventanas ordinarias y nocturnas; el comunicado oficial Cartagena describe **06:00 a 06:00 del día siguiente** para periodo especial 11-dic-2026 a 22-ene-2027. Representarlo con 06:00–05:59 o dos ventanas independientes causa pérdidas o interpretación incorrecta de festivos. Necesitamos una capacidad genérica, no lógica Cartagena.

**CONTRATO ÚNICO ESTRICTO:** solo en reglas **schema2** aceptar en `timeWindows[]` `{"startMinute":360,"endMinute":360,"fullDay":true}`. `fullDay=true` señala exactamente 24 horas desde la hora ancla local hasta la misma hora del día siguiente; 00:00 a 05:59:59 pertenecen al día ANTERIOR para ancla 06:00. Sin `fullDay`, mantener `startMinute != endMinute`. Rechazar `fullDay:false`, `fullDay` no booleano, `fullDay:true` con minutos distintos, valores fuera de 0..1439 y `fullDay` en schema1. No aceptar `1440` como minuto de la regla. Evitar otra propiedad redundante (`allDay`, `is24h`, `durationHours`). Usar el huso civil de la jurisdicción, no añadir servidor horario por ciudad ni migración Drift.

**Archivos de cambio permitidos y responsabilidad:**

- `server/app/Services/RestrictionContractValidator.php`: validar shape schema2 con el contrato anterior; legacy no cambia. No cambiar `DatasetReleaseValidator::validateRestrictions` para desbloquear `coverageCompleteness=complete`.
- `mobile/lib/features/pico_placa/data/restriction_dataset.dart`: parser igual al PHP y persistencia del atributo en el JSON normalizado existente, sin nuevo esquema de BD.
- `mobile/lib/features/pico_placa/domain/restriction_rule.dart`: `RestrictionTimeWindow` tiene `fullDay=false` opcional por defecto; `contains` para `fullDay` cubre el día entero, respetando el anclaje usado por el motor. Aserciones de constructor consistentes con parser.
- `mobile/lib/features/pico_placa/domain/restriction_engine.dart`: para `fullDay` calcular **fecha efectiva anclada** (si hora local < inicio, usar día previo), y usarla para `weekdays`, `dateParity`, festivo y límites de vigencia. Revisar el orden actual de `_matchRule` (compara vigencia/holiday con fecha BRUTA antes de `_effectiveDateTimeForWindow`); corregirlo solo para el caso general anclado con pruebas de borde. **No reutilizar `context.isHoliday` del martes 02:00 como si fuera el lunes 06:00**: ese booleano describe el instante actual. Añadir a `RestrictionContext` una dependencia opcional y acotada `bool Function(DateTime)? isHolidayOnDate` (o nombre equivalente) para preguntar por el DÍA ANCLA; el evaluador diario que ya recibe `ColombiaHolidayCalendar holidays` le pasa `holidays.isHoliday`. Si hace falta la consulta del día ancla y el callback NO está disponible, el resultado debe ser `UNKNOWN` (no `ALLOWED`, ni inferir que no es festivo). Si hay distintas ventanas, calcular por regla/ventana; un único booleano de «festivo anterior» no resuelve anclas distintas. Mantener `UNKNOWN` al faltar datos de geografía/condición y el contrato de ventanas ordinarias/legacy sin cambios, salvo regresión focal que demuestre causa.
- `mobile/lib/features/pico_placa/domain/restriction_day_evaluation.dart` y visualización de horario afectada: el evaluador diario ya dispone de `holidays`, pasarlo como proveedor de festivos por fecha (sin reloj global). Un intervalo `fullDay` debe cubrir 00:00–24:00 en la vista del día pertinente SI el ancla lo exige, pero dividir en el cambio de ancla (06:00) si cambia la condición de día hábil; NO producir ventana vacía por igualdad ni «0 horas». Presentar «24 horas (de 6:00 a. m. a 6:00 a. m. siguiente)» cuando corresponda, sin rediseñar UI.
- `scripts/qa/assemble_national_bulk_v6r3.py`: aceptar el mismo shape schema2 `fullDay` sin modificar los 14 datos históricos. Mantener COMPILADOR LAB determinista, paths seguros y manifiesto SHA.

**PRUEBAS CAUSALES (nuevas/focales, no suite antigua):**

A1. PHP rechaza `fullDay` en schema1, `false`, igualdad sin marcador y `fullDay` + start≠end; acepta exactamente `fullDay:true` schema2 con start=end. En `server/tests/Unit/RestrictionContractValidatorV2Test.php` añadir 1–2 métodos focales.

A2. Dart parser rechaza los casos anteriores y acepta ventana válida sin alterar las actuales; añadir en `mobile/test/features/pico_placa/data/restriction_g2_schema_test.dart` o el test de parser existente adecuado.

A3. Evaluación Dart, en `mobile/test/features/pico_placa/domain/restriction_g2_typed_engine_test.dart`: casos 05:59 (ancla día anterior), 06:00 (ancla día actual), 23:59, festivo a las 02:00 con día ancla hábil, viernes→sábado, lunes festivo→martes, fecha inicial y fecha final, `UNKNOWN` por geografía no certificada y **`UNKNOWN` en madrugada sin proveedor de festivos del día ancla**. Comprobar que el calendario conocido devuelve la regla correcta y que ventanas legacy siguen iguales.

A4. Vista del día y horario: una prueba focal con miércoles hábil→jueves festivo y viernes→sábado que pruebe ventanas resultantes, los cortes en 06:00 cuando corresponda y ausencia de intervalos de 0 minutos; no repetir suite total de widgets. Si detectas incompatibilidad estructural mayor, detener SOLO la publicación del `fullDay` real, no improvisar una representación legal falsa; mantener un `ENGINE_GAP_24H` explícito y continuar Fase B solo con moto normal segura.

**Condición de PASS A:** contrato PHP, Dart y ensamblador coinciden; tests focales GREEN; no se altera schema1, persistencia de Garage/Drift, ni se eliminan gates de `UNKNOWN/STALE`. Si falta Flutter, A queda `PARTIAL_NOT_RUN_ENV`, no PASS ni habilitación de la regla 24h en snapshot consumidor.

## 3. Fase B — ampliar datos nacionales verificados sin cambiar el motor por ciudad

**Partir de datos reales:** `server/database/data/restrictions/lab/national_sources_manifest_v1.json`, `server/database/data/restrictions/lab/national_bulk_v6r4_2026-11-13.json` y el archivo Cartagena `2026-11-12-cartagena-q4-2026.json`. Cuenta base verificable: 14 autoridades / 33 DIVIPOLA / 21 coberturas **todas partial** / 115 reglas; solo 13 carro particular, 7 moto particular y 1 motocarro particular. No duplicar autoridad `co-bol-cartagena` ni municipio `13001`.

**FUENTES OFICIALES IDENTIFICADAS por Director, verificar vigencia y contexto en el lote una vez:**

- Cartagena, DATT oct-2026 motos/carros (rotación, horarios, fechas): `https://cartagena.gov.co/noticias/cambia-rotacion-pico-placa-para-motos-vehiculos-particulares-cartagena-0` — comunica 5-oct-2026 a 22-ene-2027, lunes 1-2, martes 3-4, miércoles 5-6, jueves 7-8, viernes 9-0; motos 05:00–23:00, carros 07:00–09:00 y 18:00–20:00; excepto festivos. **Esta es fuente para los campos expresos; no exige PDF.**
- Cartagena, fuente de temporada y otras excepciones: `https://www.cartagena.gov.co/noticias/conozca-el-nuevo-pico-placa-para-particulares-sus-rotaciones-durante-el-2026` — para particulares indica especiales 11-dic-2026 a 22-ene-2027 de 06:00 a 06:00 siguiente, días hábiles, salvo festivos; también comunica régimen nocturno de motos y zonas/vías/exenciones. No convertir una frase general de «toda la ciudad» en ámbito individual certificado sin contexto.
- Medellín, fuente para **candidatos posteriores**, no inventar tabla taxi de fechas: `https://www.medellin.gov.co/es/secretaria-de-movilidad/pico-y-placa-medellin-2023-segundo-semestre/` (la URL histórica actualmente muestra segundo semestre 2026). Describe taxi cada 2 semanas, 06:00–20:00 y rotación variable. Si NO publica la tabla concreta de cada dígito/fecha, registrar `HOLD_TAXI_DATES` en matriz, NO generar reglas de taxis con inferencia.

**Acciones exactas B1–B5:**

B1. Crear SOLO `server/database/data/restrictions/lab/2026-11-15-cartagena-q4-n1.json` como fuente **LAB derivada** de Cartagena y `server/database/data/restrictions/lab/national_sources_manifest_n1.json` con TODOS los 14 `jurisdictionId` ya enumerados. Dejar intactos el manifest v1, JSON y SHA V6R4, y fuentes de las otras 13 autoridades. Actualizar la entrada Cartagena en el nuevo manifest con SHA-256 del nuevo archivo, campos `expectedSha256`/`editorialDate` coherentes. **No añadir una segunda entrada `co-bol-cartagena` ni una nueva ciudad duplicada.**

B2. En el mismo objeto Cartagena `co-bol-cartagena`, conservar cobertura `car/private` preexistente, agregar `motorcycle/private` solo para las horas/fechas respaldadas. `digitPosition=lastNumeric`, días lunes-viernes con dígitos oficiales exactos, `timeWindows` 300–1380, `appliesOnHolidays=false`, `coverageCompleteness=partial`; agregar `inside_scope_ref` desconocido como hace el compilador LAB (no inventar evidencia GPS), fuentes/verifiedAt reales y `staleAfter` como caducidad de revisión editorial, distinta de vigencia. Distinguir vigencia rotación de vigencia horario especial; no prometer «ALLOWED» en 23:00–05:00 porque existe otra restricción nocturna de motos y excepciones sin modelar. Ningún `allow` artificial.

B3. Solo si Fase A pasa **PHP+Dart+Python** y el alcance/fechas oficiales están comprobados, agregar reglas `car/private` estacionales 24 horas 06:00→06:00 siguiente usando SOLO `fullDay:true`, condiciones de ámbito conservadoras y fechas ancla correctas; no reemplazar antes del 11-dic la rotación regular. Si no están comprobados los límites de fin de vigencia/holiday, dejar la temporada en `HOLD_SEASONAL_24H` y NO introducir reglas semánticamente falsas. También mantener el régimen nocturno de motos, centro amurallado y exenciones como `LEGAL_OR_ENGINE_GAP` cuando no puedan publicarse con precisión; no extender de forma artificial `validUntil` o `staleAfter`.

B4. Ejecutar `python scripts/qa/assemble_national_bulk_v6r3.py --manifest server/database/data/restrictions/lab/national_sources_manifest_n1.json --write`, y acto seguido el mismo comando con `--check`. No modificar el script para fabricar PASS en base a conteos esperados viejos. Crear salida con nombres únicos en sección `release` del nuevo manifest (p. ej. `national_bulk_n1_2026-11-15.json` y su `.sha256`). El resultado debe seguir con 14 autoridades y 33 códigos, preservar byte a byte las **13 jurisdicciones no Cartagena** (en objeto normalizado) y crecer al menos de 21 a **22 coberturas** si B2 PASS. Las reglas podrán crecer; informar conteo REAL, no inventado. `generatedAt` fijo, explícito, real para reproducibilidad; NO manipular reloj de QA ni atribuir publicación pública.

B5. Emitir `docs/data/PICORADAR_N1_NATIONAL_DELTA_20261115.md` y una **sola tabla CSV** `docs/data/PICORADAR_N1_GAPS_20261115.csv`: por autoridad/modalidad, URL oficial, fecha consulta, fuente exacta de dígitos/horas/vigencia, `coverageCompleteness`, `staleAfter`, estado `LAB_ADDED / LEGAL_HOLD / ENGINE_GAP / SOURCE_STALE / NOT_RESEARCHED` y causa; filas mínimas Cartagena carro/moto/24h/nocturna y Medellín taxi. NO hacer nuevo listado ornamental de 1.104 filas ni confundir catálogo DANE con normatividad. Para municipios sin restricción oficialmente confirmada usar estado editorial explícito, nunca `ALLOWED` por silencio. El diagnóstico histórico `docs/data/NATIONAL_COVERAGE_SCORECARD.md` es 11-nov y permanece histórico; no sobrescribirlo. **No recopilar de nuevo todas las fuentes que ya constan en manifest.**

## 4. Fase C — mantener bloqueadas las afirmaciones que no podemos certificar

`server/app/Services/DatasetReleaseValidator.php` aún rechaza `coverageCompleteness=complete` en schema2 y `server/app/Services/RestrictionPublicationService.php` impide que una aprobación editorial ordinaria lo eleve a complete sin prueba de ámbito. **CONSERVAR ESOS GATES EN N1.** `complete` permite al motor producir `ALLOWED` cuando no hay regla aplicable; no se puede desbloquear con un simple booleano, un CSV sin zonas o una fuente general que omite excepciones. El trabajo N2 posterior será aprobar un certificado tipado/validable de ámbito+excepciones antes de permitir complete; NO diseñarlo ni implementarlo a medias en este lote.

No editar `mobile/android/`, rutas del Garaje, firmware, firma, APK, ni teléfono. La actualización de datos del motor está diseñada para OTA, pero N1 es una entrega **LAB** y no un despliegue real. `consultationEnabled` solo habilita consulta, NO certifica completitud. Mantener no conocidas/STALE, incluso si fuentes son antiguas.

## 5. Fase D — pruebas focales y política de errores (una pasada)

D1. Preflight sintaxis solo para archivos PHP cambiados: `php -l`; ejecutar `python -m unittest scripts.tests.test_assemble_national_bulk_v6r3` o la selección específica realmente definida por el runner existente y **un test nuevo** del manifiesto N1 que mida 14/33/22+, sin correr los 14 tests pasados por protocolo. Ejecución obligatoria `--check` después de escribir el snapshot. `git diff --check` y pruebas PHP unit focales de A.

D2. En Flutter 3.47.9: `flutter test` de los **dos archivos focales modificados** (parser y engine) y la prueba nueva de horario/ingesta N1 si la escribiste. No volver a correr los 33 PHPUnit, G2 same-bytes o suites RC1, porque no cambió su publisher; ampliar solo si un test focal prueba una regresión causada por N1. Si falta toolchain, escribir el test y reportar `DART_TEST=NOT_RUN_ENV`/`PRODUCT_READY=NO`; no asignar PASS solo por `flutter analyze` ausente.

D3. Si los datos reales contradicen el contrato, mantener la fuente con estado `LEGAL_HOLD` o `ENGINE_GAP` en el CSV, no hacer «patch» para aprobar un calendario falso. Si una prueba falla, permitir **una corrección causal**, rerun únicamente de esa selección; no cascada de diez intentos ni cambios ajenos.

D4. Asegurar que el snapshot LAB no elimina 13 jurisdicciones preexistentes, no cambia 33 códigos, no promueve `complete`, no afirma `ALLOWED` en cobertura parcial, no duplica reglas semánticamente iguales y que el SHA sidecar coincide exactamente con bytes exportados. `N1_PRODUCT_RESULT=PASS_SCOPED` solamente si A/B/D pasan. Si fuentes no verificables, `PARTIAL_LEGAL` con avance real B2 seguro y GAPS claros.

D5. Registrar antes/después en un resumen CON NÚMEROS REALES (14→14 autoridades, 33→33 códigos, 21→22+ coberturas si B2 pasó, 115→valor contado de reglas); citas de fuentes oficiales y marcas temporales; resultados PHP/Python/Dart con comando, exit, duración si existe y `HEAD/TREE` exactos. No presentar «ya Colombia completa» ni `RELEASE=GO`.

## 6. Fase E — commit local recuperable y UN ZIP de retorno

- Si hubo cambios y PASS/PARTIAL con contenido útil: **un commit local** en rama de trabajo aislada `feat/picoradar-n1-schema2-cartagena-lab`; no push de código ni tocar PR71/79/main. Si parcial por Flutter, mantener commit local de candidato y estado `NO_GO`, nunca release. No crear múltiples commits de corrección por inercia.
- Evidencia en `D:\codex\_REPORTES\PicoRadar\N1-NATIONAL-20261115\delivery\PICORADAR_N1_EVIDENCIA_UNICA.zip` y **ningún otro ZIP paralelo en `delivery`**.
- Contenido: `FINAL_REPORT.md` con done/holds y next actor; `GATES.csv`; `NATIONAL_DELTA.csv` (conteos + fuentes, sin secretos); `LOGS/` sanitizados SOLO del delta; `MANIFEST_SHA256.csv` (tamaño, SHA256, CRC32 por miembro); `README_RESTORE.md`; **un bundle Git incremental** de BASE `7e2e1f3...` a HEAD nuevo (si Codex puede crear bundle portable con prerequisito BASE) o alternativamente un `.patch` de cambios + inventario SHA por ruta. Validar reconstrucción del HEAD/TREE sobre una copia de la base RC2 ya entregada; si falta la base para restaurar en destino, incluir bundle FULL restaurable con reporte de tamaño y un solo ZIP (no perder recuperabilidad por ahorrar espacio). Incluir nuevos JSON/manifest/reportes de datos del repositorio sin copiar otros ZIP.
- NO adjuntar APK de 211 MB, secretos, archivos Gitleaks `.private.json`, datos personales, respuestas completas de terceros, backups del Mi A3, ni reportes antiguos repetidos. Verificar CRC de ZIP final, hashes/tamaños de TODOS los miembros, prueba de extracción y `git bundle verify`/restore (o aplicación exacta del parche sobre BASE); SHA256 del ZIP final después del último byte. Entregar solo link Windows local, SHA, resultados y NEXT_ACTOR=CHATGPT_DIRECTOR.
- En caso de bloqueo por política o WIP ajeno no eludible: conservar copia local intacta, informar `HOLD` con causa concreta y entregar el mismo único ZIP pequeño con evidencia; NO modificar seguridad del equipo ni desactivar antivirus.

## 7. Criterios de salida inequívocos

`N1_ENGINE_24H=PASS|PARTIAL_NOT_RUN_ENV|HOLD_CAUSAL`  
`N1_CARTAGENA_MOTORCYCLE=PASS_LAB|HOLD_LEGAL`  
`N1_CARTAGENA_SEASONAL=PASS_LAB|HOLD_LEGAL_OR_ENGINE`  
`N1_SNAPSHOT=PASS_DETERMINISTIC|HOLD`  
`N1_KEEP_13_JURISDICTIONS=PASS|FAIL`  
`N1_NO_FALSE_ALLOWED=PASS|FAIL`  
`N1_GITHUB_PRODUCT=NOT_PUSHED_HOLD_SECURITY`  
`ANDROID_PHYSICAL=NOT_TOUCHED`  
`PRODUCT_RELEASE=NO_GO`  
`NEXT_ACTOR=CHATGPT_DIRECTOR`

Finalizar la ejecución y devolver exactamente **UN ZIP**. No preguntar de nuevo al propietario por permisos de publicación: N1 prohíbe publicación y QA física. No iniciar N2 ni una segunda auditoría sin orden posterior del Director.

## 8. Revisión adversarial del Director (ya resuelta; Codex NO la repite)

| V | Verdugo: riesgo revisado y resolución |
|---|---|
| 01 | Motor por ciudad → prohibido; solo contrato tipado schema2. |
| 02 | Igualdad de minutos sería intervalo vacío → `fullDay:true` explícito. |
| 03 | Festivo de madrugada equivocado → fecha ancla del inicio 06:00. |
| 04 | Vigencia hasta medianoche cortaría cola 00–06 → prueba específica de borde. |
| 05 | Contaminación schema1 → rechazo estricto en v1. |
| 06 | Cartagena con horario no confirmado → diferenciar moto regular, car estacional y nocturno HOLD. |
| 07 | Reemplazo de snapshot nacional → conservar 13 objetos originales y DIVIPOLA. |
| 08 | Certificar `complete` sin ámbito → conservar el bloqueo. |
| 09 | Falsa aprobación sin Flutter → no declarar PASS ni release. |
| 10 | ZIP sin restauración o doble binario → bundle/patch DELTA verificado, un ZIP. |

| J | Juez: prueba de suficiencia y decisión |
|---|---|
| 01 | Contrato 24h reutilizable sin operador municipal particular. |
| 02 | Fecha ancla define hábiles/festivos y madrugada inequívocos. |
| 03 | Ventanas legacy y esquema1 inalterados con regresión focal. |
| 04 | UI no presenta intervalo cero ni circulación libre sin cobertura. |
| 05 | Fuente oficial Cartagena sustenta días/dígitos/horas de moto; no exige PDF. |
| 06 | Fuente oficial de temporada sustenta el candidato; excepción dudosa queda HOLD. |
| 07 | Solo una fuente Cartagena actualizada en manifest de 14. |
| 08 | Los municipios sin medida no se infieren de silencio; matriz explícita. |
| 09 | Pruebas del delta y contadores reproducibles, sin suites históricas. |
| 10 | Un commit local, una entrega y ChatGPT decide la siguiente etapa. |

**ÚLTIMA LÍNEA: NEXT_ACTOR=CHATGPT_DIRECTOR — N1 entrega evidencia, nunca publica release.**