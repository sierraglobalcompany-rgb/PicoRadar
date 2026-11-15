# CODEX LUNA — PICORADAR N1-R1 · MOTOR NACIONAL ÚNICO + CARTAGENA · UN SOLO LOTE REAL

**TASK_ID:** `PICORADAR-N1R1-NATIONAL-SCHEMA2-FULLDAY-CARTAGENA-ONEBATCH-20261115`  
**DIRECTOR:** ChatGPT decide arquitectura, contratos, límites y salida. **EJECUTOR:** Codex Luna implementa sin nueva fase de investigación general.  
**VIGENCIA DE ESTA ORDEN:** reemplaza `PICORADAR-N1-NATIONAL-ENGINE-DATA-ONEBATCH-20261115` **solo si N1 aún NO empezó**. Si está en marcha, NO lanzar otro ejecutor: terminar esa sesión y devolver su ZIP.  
**META:** motor nacional único `schemaVersion=2`, información oficial por jurisdicción/vehículo/servicio y actualizaciones OTA SIN APK distinta por ciudad. **SALIDA:** un commit local recuperable y UN ZIP de evidencias.  
**NO AUTORIZADO:** `push`, merge, PR de producto, PROD, CDN/staging real, Hostinger, reconfigurar antivirus, instalar APK, ADB/Mi A3, release, alterar datos reales, reescribir historia. `PRODUCT_RELEASE=NO_GO`.

## 0. Contrato de continuidad: no reabrir pruebas aprobadas

- Fuente productiva local (NO GitHub): `HEAD=7e2e1f3f311b18e29f63d3a5e05e9439a11c4289`, `TREE=e312c7632fce4c43f9419cba60903e7420c46d85`; checkout y WIP original intactos. Si falta fuente, recuperar del bundle full RC2 (`GIT/full-final.bundle`, SHA-256 `aa85a9beae933457b432b6bbd1d1af47b3bee6102a5001482693c6d91d0df1a9`). No inferir que GitHub contiene este HEAD: el commit de producto sigue local.
- PR #79 `docs/plan-maestro-nacional-v2-20261107` es **solo documentación Draft**, registrada hasta §CO. No tocarlo desde Codex, ni confundir la rama documental con producto.
- **Conservar PASS anteriores:** F0/F1; F2 Laravel 33/279; RC1 formulario schema2, aprobación/rollback y publicación; G2 Laravel-bytes→Flutter; RC2 compilación debug; RC3 inspección de APK/ADB/firma y navegación de DEV anterior. El Mi A3 **NO** tiene certificada la nueva APK. No ejecutar ninguna de esas suites, build Gradle ni QA Android en N1.
- Seis leyes: KISS/Ponytail; cero ruido; evitar parches encadenados; UX veraz; verificaciones reproducibles; cero pingpong. El usuario autoriza la ejecución de N1 cuando todas las condiciones son seguras; no autoriza despliegue público. Trabajar en `D:\codex\PicoRadar` o carpeta aislada REAL conocida por Codex, jamás `git reset --hard` sobre WIP ajeno.
- Preflight **una vez**: único escritor, `git rev-parse HEAD HEAD^{tree}`, `git status --porcelain`, versión PHP/Python/Dart/Flutter disponible. Si HEAD difiere, abrir clon aislado del bundle BASE; registrar diferencia sin modificar checkout del usuario. No repetir inventarios de 1.104 códigos, ni las 20 auditorías históricas.

## 1. Decisión jurídica resuelta: moto sí, temporada de 24 h SOLO candidato

**Dos fuentes institucionales respaldan los campos que se indican, sin exigir PDF:**

1. Alcaldía de Cartagena / DATT (comunicado de octubre de 2026), `https://cartagena.gov.co/noticias/cambia-rotacion-pico-placa-para-motos-vehiculos-particulares-cartagena-0`: 05-oct-2026 a 22-ene-2027; último dígito **lunes 1/2, martes 3/4, miércoles 5/6, jueves 7/8, viernes 9/0**; **moto particular 05:00–23:00** y carro particular 07:00–09:00 / 18:00–20:00; lunes-viernes **excepto festivos**. Incluir motocicleta en el LAB si el contrato valida, SIN certificar excepciones o geografía faltantes.
2. Comunicado de enero de 2026, `https://www.cartagena.gov.co/noticias/conozca-el-nuevo-pico-placa-para-particulares-sus-rotaciones-durante-el-2026`: anunció periodos especiales de **06:00 del día de restricción a 06:00 siguiente**, incluido 11-dic-2026→22-ene-2027. **Pero** la Alcaldía aclaró posteriormente que NO aplicaría la modalidad 24 horas para mitad de año: `https://www.cartagena.gov.co/noticias/pico-placa-no-sera-24-horas-datt-reitera-que-mantiene-medida-vigente-establecida-horario-fraccionado`. Por lo tanto, **una previsión de enero NO demuestra que diciembre permanezca inalterado**. Motor genérico de 24 h: SÍ. Activar regla estacional de diciembre en un snapshot: **SOLO ante confirmación oficial posterior inequívoca y compatible con octubre**. Si no se obtiene, marcar `SEASONAL_OFFICIAL_RECONFIRMATION=HOLD` y conservar la rotación de carros vigente, sin extender ni cancelar nada mediante inferencias.

La publicación oficial basta para sus **hechos expresos**; para horarios, excepciones, sectores, festivos y modalidades NO expresos se registra `LEGAL_HOLD`, sin inventar restricciones ni libre circulación. El nocturno de motos 23:00–05:00, centro amurallado, motocarros, permisos laborales y categorías especiales requieren condiciones adicionales verificadas; no representarlos falsamente como parte del pico regular 05:00–23:00. Dataset `LAB` no es dataset certificado nacional.

## 2. Fase A — una capacidad tipada genérica de 24 horas, no un motor Cartagena

**Contrato cerrado `schemaVersion=2`:** `timeWindows: [{"startMinute":360,"endMinute":360,"fullDay":true}]`. `fullDay=true` significa ventana de 24 horas civiles en huso Colombia, **anclada al día de inicio** (p. ej. lunes 06:00 hasta martes 06:00). A las 02:00 del martes se evalúan `weekdays`, `dateParity`, `appliesOnHolidays` y límites de vigencia conforme al **lunes ancla**. Si la regla terminó el viernes, su cola válida del sábado temprano continúa solo si su vigencia anclada lo permite. `endMinute` es exclusivo. Colombia usa UTC−05 sin horario estacional.

**Estrictamente válido:** schema2 + `fullDay` booleano **true** + minutos iguales 0..1439. Rechazar en PHP, Dart y ensamblador Python: igualdad sin marcador; `fullDay:false`, `null`, string o numérico; `fullDay:true` con minutos diferentes; `fullDay` en schema1; `1440` en ventanas de motor. Para ventanas existentes no agregar `fullDay:false` por serialización (campo ausente sigue siendo el contrato legacy). No agregar sinónimos (`allDay`, `is24h`) ni esquemas Drift nuevos.

**Modificar únicamente los archivos necesarios que ya existen:**

- `server/app/Services/RestrictionContractValidator.php`: el `knownKeys` de cada ventana depende del `schemaVersion` del documento; mantener rechazo en v1. Verificar conflicto/prioridad del validador con casos focales, sin suprimir reglas de seguridad.
- `mobile/lib/features/pico_placa/data/restriction_dataset.dart`: `_timeWindow` necesita conocer schema1/schema2 para admitir solo la ventana nueva correcta; preservar la propiedad al construir `RestrictionTimeWindow` y durante el parseo de los documentos de reglas. Rechazar campos desconocidos como antes.
- `mobile/lib/features/pico_placa/domain/restriction_rule.dart`: agregar `bool fullDay = false` opcional con aserciones coherentes. `contains()` cubre el instante durante la ventana anclada, sin convertir ventanas legacy en 24h. **No equiparar `{360,360,false}` con 24h**.
- `mobile/lib/features/pico_placa/domain/restriction_engine.dart`: el código HOY filtra vigencia y `context.isHoliday` **antes** de calcular la fecha ancla. Corregir **solo para ventana fullDay** la precedencia: seleccionar ventana y su ancla, evaluar vigencia/semana/paridad/festivo de ESA ancla, después placa/condiciones/prioridad. Si hay varias ventanas, evaluar cada una por separado, sin usar la fecha actual errónea para las reglas nocturnas ancladas. Mantener `UNKNOWN/STALE` frente a huecos o incertidumbre.
- `RestrictionContext`: añadir proveedor opcional de festivos por fecha, `bool Function(DateTime)? isHolidayOnDate`, sin global/servicio nuevo. El `isHoliday` actual solo representa el instante de consulta; **NO** representa por sí solo el día anterior. En `fullDay` con ancla distinta a fecha actual, si falta el proveedor y la respuesta depende de su festivo, devolver **`UNKNOWN`**, nunca `ALLOWED`; propagar mediante el motivo de incertidumbre existente (sin nueva taxonomía salvo error realmente demostrado). Para los caminos existentes que sí conocen calendario, entregar `ColombiaHolidayCalendar.isHoliday`. No alterar el comportamiento de reglas sin fullDay.
- `mobile/lib/features/pico_placa/domain/restriction_day_evaluation.dart`: el cálculo diario debe dividir en límites 00:00 / ancla 06:00 / 24:00 y conservar intervalos sin longitud cero; pasar calendario por fecha al contexto de cada evaluación. Vigilar que `RestrictionDayWindow` requiere start < end. No producir una ventana 06:00–06:00 como intervalo diario vacío.
- **Ruta adicional que el N1 anterior omitió:** `mobile/lib/features/pico_placa/domain/city_restriction_summary.dart` (`_ruleMatchesDay`, `_windowsFrom`, `_informationalCalendarForDay`) usa lógica de días distinta y `RestrictionDayWindow` afirma start < end; con `fullDay` 06→06 podría lanzar ASSERT o mostrar 0 horas. **No forzar UI falsamente precisa**: adaptar proyección de ventanas al día civil con calendario anclado **si cabe con cambios mínimos**, o emitir `CALENDAR_COMPLEXITY_HOLD`/`UNKNOWN` y no construir intervalo inválido. Las rutas de formato `mobile/lib/features/pico_placa/presentation/city_pico_widgets.dart` y `mobile/lib/features/pico_placa/presentation/pico_detail_screen.dart` deben mostrar `24 h, de 06:00 a 06:00 siguiente` **solo para reglas fullDay seguras**; en caso de complejidad presentar `Por verificar`. Evitar rediseño visual.
- `scripts/qa/assemble_national_bulk_v6r3.py`: validar shape de ventana en el compilador LAB con misma regla estricta schema2, *no aceptar por omisión*. No alterar 14 fuentes anteriores ni permitir `coverageCompleteness=complete`.

**Pruebas DELTA (sin suites aprobadas):**

A1 `server/tests/Unit/RestrictionContractValidatorV2Test.php`: esquema1 rechazado, igualdad sin marcador rechazada, true+igual acepta, false/no bool/diferente/1440 rechazados. Ejecutar selección PHPUnit de métodos nuevos o una clase acotada cuando filtrar por método resulte imposible (un solo proceso).

A2 `mobile/test/features/pico_placa/data/restriction_g2_schema_test.dart`: parser válido/estricto y compatibilidad schema1, v2 ventanas sin fullDay no cambian.

A3 `mobile/test/features/pico_placa/domain/restriction_g2_typed_engine_test.dart`: lunes 05:59→06:00, lunes 23:59→martes 02:00/05:59→06:00, viernes→sábado, festivo de madrugada cuyo día ancla fue hábil, día ancla festivo cuya cola cae en hábil, `validFrom/validUntil` en bordes, dos ventanas con anclas distintas, ausencia de proveedor festivo→UNKNOWN, datos geográficos desconocidos→UNKNOWN, no `ALLOWED` con cobertura parcial.

A4 prueba focal de vista diaria/informacional que recorra `evaluateRestrictionDay` Y `summarizeCityRestrictionDay`: ninguna ventana `start==end`, no crash ni horario «0 h» en pantallas y no «Libre» para cobertura parcial; si esa vista carece de evidencia para resolver 24h, `CALENDAR_COMPLEXITY_HOLD` sin ventana engañosa. No repetir suite total de widgets.

**PASS A solo con PHP + Dart + Python reales GREEN.** Si falta Flutter/Dart 3.47.9: escribir tests, anotar `N1_ENGINE=PARTIAL_NOT_RUN_ENV`, y NO publicar temporada 24h ni afirmar PASS de consumidor. Python y PHP pueden avanzar independientemente.

## 3. Fase B — datos oficiales Cartagena, conservando 13 jurisdicciones

**Datos base verificados en el código:** `server/database/data/restrictions/lab/national_sources_manifest_v1.json` (14 entradas), `national_bulk_v6r4_2026-11-13.json` (14 autoridades, 33 códigos DIVIPOLA, 21 coberturas parciales, 115 reglas), y `2026-11-12-cartagena-q4-2026.json`. No duplicar la autoridad `co-bol-cartagena` ni su código `13001`; no tocar fuentes de las otras 13.

B1. Crear **solo** la nueva fuente versionada `server/database/data/restrictions/lab/2026-11-15-cartagena-q4-n1.json`, partiendo de la fuente Cartagena histórica, y el manifiesto paralelo `server/database/data/restrictions/lab/national_sources_manifest_n1.json` con las 14 entradas ordenadas. Cambiar SOLO la entrada Cartagena, con SHA-256 calculado de bytes del archivo creado; conservar `expectedSha256` de las otras 13. `editorialDate` de la nueva fuente = fecha Colombia del `verifiedAt` más reciente en sus coberturas, no la fecha arbitraria del nombre. No sobrescribir JSON/SHA/manifest V6R4.

B2. Agregar `motorcycle/private` con la publicación oficial octubre: cinco reglas exactas lunes→viernes 1/2, 3/4, 5/6, 7/8, 9/0; `lastNumeric`, ventana `[300,1380)`; `appliesOnHolidays=false`, `coverageCompleteness=partial`, `verifiedAt` y `staleAfter` trazables al último examen editorial real. **Fuente octubre válida para dígitos/horas pero no certifica TODO el ámbito ni las exenciones.** Conservar condición espacial `inside_scope_ref` sin afirmar GPS certificado. No mostrar ALLOWED a las 23:30 por ausencia del régimen nocturno acreditado.

B3. **Temporada 24h:** dejar `HOLD_OFFICIAL_RECONFIRMATION` en matriz salvo respuesta oficial posterior clara para diciembre; aunque el motor fullDay pase, NO incluir reglas temporales contradictorias en el snapshot si falta esa confirmación. Si aparece confirmación inequívoca, registrar fuente, fecha y campos exactos, y SOLO añadir regla temporal tras PASS A, límites de vigencia anclados y ausencia de contradicción con la rotación regular; ninguna regla con dos efectos simultáneos conflictivos. Nunca inferir que la cancelación de JUNIO también canceló diciembre. Tampoco inferir que el anuncio de ENERO prueba por sí solo la implementación de diciembre.

B4. Compilar por EL SCRIPT YA EXISTENTE (no reescribir publicador):

`python scripts/qa/assemble_national_bulk_v6r3.py --manifest server/database/data/restrictions/lab/national_sources_manifest_n1.json --write`

`python scripts/qa/assemble_national_bulk_v6r3.py --manifest server/database/data/restrictions/lab/national_sources_manifest_n1.json --check`

El nuevo manifest define explícitamente `release.version`, `generatedAt` CON ZONA, `outputFile=national_bulk_n1_2026-11-15.json` y `shaFile=national_bulk_n1_2026-11-15.sha256`; `generatedAt` debe ser posterior a TODOS los `verifiedAt` y nunca simular un reloj. Contar salida real: si B2 PASS, esperar **14 autoridades, 33 códigos, 22 coberturas** y **120 reglas** solo si exactamente se incorporan cinco moto y ninguna estacional; de lo contrario contar y explicar delta, no alterar el test para forzar cifras. Para las 13 autoridades ajenas a Cartagena, equivalencia profunda del objeto semántico ANTES/DESPUÉS. Mantener `complete` bloqueado, 21 coberturas antiguas sin convertirse en permisos.

B5. Publicar únicamente en archivos locales de repositorio: `docs/data/PICORADAR_N1_NATIONAL_DELTA_20261115.md` y **un CSV** `docs/data/PICORADAR_N1_GAPS_20261115.csv` con 5 filas focales como mínimo (Cartagena carro/moto/24h/nocturno, Medellín taxi); URL oficial, campos sustentados, `staleAfter`, estado `LAB_ADDED / LEGAL_HOLD / ENGINE_GAP / SOURCE_STALE`, motivo y fecha consulta. No crear un inventario alterno de 1.104 municipios. La fuente institucional expresa basta sin PDF obligatorio, pero **no equiparar falta de datos a ausencia de prohibición**.

## 4. Gates inalterables: release, actualización OTA y geografía

- `server/app/Services/DatasetReleaseValidator.php` y `server/app/Services/RestrictionPublicationService.php` **mantienen el rechazo de schema2 `coverageCompleteness=complete`** hasta que exista evidencia suficiente de ámbito y excepciones; NO «resolverlo» quitando validaciones. Con coberturas parciales no afirmar `ALLOWED`.
- `consultationEnabled` solo permite consultar; no certifica que la regla cubra todas las vías, vehículos, exenciones o horarios. Mantener `UNKNOWN/STALE` y rechazo del dataset corrupto.
- N1 prueba compilador y snapshot local: **NO** certifica el ciclo OTA Android REAL ni autoriza CDN, staging o la variante release. Ese gate queda pendiente del lote futuro, igual que QA Mi A3 de RC2. No reabrir las pruebas de datos previas.
- No tocar `mobile/android`, Gradle, firma release, datos del teléfono, configuración de Windows ni GitHub remotos; cero motor por ciudad o tabla hardcodeada en APK.

## 5. Ejecución focal, fallos y criterios

1. `php -l` únicamente en archivos PHP modificados. PHPunit seleccionar casos NUEVOS en `RestrictionContractValidatorV2Test`; ejecutar una vez, reportar salida real. No repetir F2 33/279 ni RC1 editor/publicador.
2. Python correr únicamente casos nuevos de `scripts/tests/test_assemble_national_bulk_v6r3.py` y la comprobación `--write`/`--check` del manifest N1. **No** toda la suite Python ya aprobada por protocolo.
3. Flutter 3.47.9/Dart 3.13.7: correr parser, engine y proyección diaria/ciudad **afectados por el delta**, una vez. No `flutter test` global. `flutter analyze` solo de los archivos tocados si el comando admite ese alcance. Sin SDK: `DART_NOT_RUN_ENV`, NO PASS ficticio.
4. Verificar `git diff --check`; diff limitado a archivos declarados y pruebas/fixtures focales. Si test falla por error real, **una corrección causal y rerun únicamente del caso afectado**, no diez cambios encadenados. Si fuente oficial contradice regla, HOLD LEGAL, no parche para aprobar.
5. Gate `N1_NO_FALSE_ALLOWED` prueba cobertura parcial, festivos de día ancla, ventanas de 24h y representación informativa sin crash; si B3 HOLD, **no** se exigen pruebas E2E de una temporada que no se publicó. Mantener todo el progreso independiente B2.

**Resultado de salida:** `N1_ENGINE_24H=PASS|PARTIAL_NOT_RUN_ENV|FAIL_CAUSAL`; `N1_CARTAGENA_MOTO=PASS_LAB|HOLD_SOURCE`; `N1_SEASONAL=HOLD_OFFICIAL_RECONFIRMATION|PASS_LAB_CONTRACT_VERIFIED`; `N1_SNAPSHOT=PASS|HOLD`; `N1_NO_FALSE_ALLOWED=PASS|FAIL|NOT_RUN_ENV`; `PRODUCT_RELEASE=NO_GO`. Cierre `PASS_SCOPED_LAB` SOLO si los tests del motor/consumidor que se cambiaron de verdad pasaron; avance parcial útil se devuelve como `PARTIAL`, nunca se descarta.

## 6. UNA entrega, restaurable y liviana

Un **commit local máximo** en rama aislada `feat/picoradar-n1-schema2-cartagena-lab`; registrar HEAD/TREE padre, rutas modificadas, diff, pruebas y resultado. No push de producto por `HOLD_SECURITY` ni PR/merge. Crear SOLO:

`D:\codex\_REPORTES\PicoRadar\N1-R1-NATIONAL-20261115\delivery\PICORADAR_N1_R1_EVIDENCIA_UNICA.zip`

Dentro: `FINAL_REPORT.md`, `GATES.csv`, `NATIONAL_DELTA.csv`, `LOGS/` con evidencia sanitizada de **pruebas nuevas**, `MANIFEST_SHA256.csv` con tamaños/SHA256/CRC32 de cada miembro, `README_RESTORE.md`, nuevos JSON/manifest/CSV/MD, y **un método verificable de recuperación del código**: bundle incremental BASE→HEAD con requisito base claramente documentado O parche binario/archivo + hashes de las rutas, probado aplicándolo en un clon limpio de `7e2e1f3...`. Si solo un bundle FULL garantiza restauración, meterlo en **el mismo ZIP** y documentar el tamaño (no generar otro ZIP aparte). NO meter APK 211 MB, bundles históricos duplicados, tres informes antiguos, secretos `.private.json`, PII o datos Mi A3. Verificar CRC, manifiesto, extracción y reconstrucción real de HEAD/TREE al cerrar. Si una política bloquea escribir, no eludir: reportar HOLD en el mismo ZIP cuando sea posible.

**Respuesta Codex:** una línea `TASK_ID | N1_ENGINE_24H=... | N1_CARTAGENA_MOTO=... | N1_SEASONAL=... | N1_SNAPSHOT=... | HEAD=... | TREE=... | ZIP_SHA256=... | PRODUCT_RELEASE=NO_GO | NEXT_ACTOR=CHATGPT_DIRECTOR` y enlace al **único** ZIP.

## 7. Auditoría adversarial del director — YA CERRADA, NO REEJECUTAR

| Verdugo | Hallazgo y reparación de la versión N1 anterior |
|---|---|
| V01 | El anuncio enero 24h no equivale a vigencia incondicional: una fuente oficial de junio anuló la aplicación de mitad de año. Diciembre queda condicionado a reconfirmación. |
| V02 | PHP y Dart rechazan minutos iguales: `fullDay` schema2 booleano estricto, sin cambiar schema1. |
| V03 | El parser `_timeWindow` no recibe versión: prohibir el campo en v1 expresamente. |
| V04 | El engine compara `validFrom/validUntil` y `isHoliday` antes del ancla: ordenar la comprobación para fullDay, no inferir feriado anterior. |
| V05 | `RestrictionDayEvaluation` exige start < end: segmentar 00/ancla/1440. |
| V06 | `city_restriction_summary._windowsFrom` y `_ruleMatchesDay` también usan horarios antiguos: evitar crash/0h y CALENDAR_COMPLEXITY_HOLD. |
| V07 | `city_pico_widgets` y `pico_detail_screen` pueden presentar 06–06 como 0h: texto veraz o HOLD, sin rediseño. |
| V08 | El compilador Python no conoce fullDay, aunque PHP y Dart pasen: paridad triple y test focal. |
| V09 | `generatedAt` anterior a `verifiedAt` o SHA de fuente viejo romperá manifest: sincronizar fecha/hashes reales, sin falsear reloj. |
| V10 | QA de Mi A3 y OTA no están probadas por N1: evitar falso release y devolver un único ZIP reconstruible. |

| Juez | Decisión validada contra código/fuentes |
|---|---|
| J01 | Motor único schema2; ninguna regla especial por municipio. |
| J02 | Moto Cartagena 05:00–23:00 con 5 pares y excepción festivos sí está respaldada por fuente octubre 2026. |
| J03 | Enero anuncia especial diciembre pero junio cancela temporada de mitad de año: distinguir periodos, no inferir autorización ni cancelación automática. |
| J04 | fullDay genérico independiente de si diciembre se confirma. |
| J05 | El festivo consultado es el de la fecha ancla; si no puede saberse, UNKNOWN. |
| J06 | Proyecciones y UI no inventan horas ni permisos en parcial. |
| J07 | Manifiesto de 14 fuentes conserva las 13 ajenas a Cartagena y SHA determinista. |
| J08 | `coverageCompleteness=complete` queda bloqueado hasta certificación espacial y de exenciones. |
| J09 | Solo tests nuevos y un intento/corrección causal; no repetir 33 PHP, Flutter/Drift anterior, APK o seguridad. |
| J10 | Handoff único recuperable y un ZIP con siguiente actor, sin push ni despliegue. |

**FIN — NEXT_ACTOR=CHATGPT_DIRECTOR DESPUÉS DEL ZIP ÚNICO.**