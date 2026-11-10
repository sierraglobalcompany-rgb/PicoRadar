# CODEX LUNA — PICORADAR G2 V3 CORREGIDO — MACROBLOQUE ÚNICO: MOTOR NACIONAL TIPADO, SEGURIDAD DE RESULTADOS, CONTRATO LARAVEL/FLUTTER, PERSISTENCIA Y ENTREGA RECUPERABLE

**TASK_ID INALTERADO:** `PICORADAR-G2-MOTOR-NACIONAL-TIPADO-20261110`  
**PRECEDENCIA:** ESTA V3 sustituye las órdenes G2 V1 (`CODEX_LUNA_G2_PICORADAR.md`, SHA256 `7356034d55e52adc781a523e8d04b8425a41c3ef344bdafc92ae244ab2b2fe2c`) y G2 V2 (`CODEX_LUNA_PICORADAR_G2_V2_MACROBLOQUE_NACIONAL_AUDITADO_20261110.md`, SHA256 `3e9466da40ca34f993334b6f03924c2e0e93b9b615ee83e03f763844db1cee0b`). **LA TAREA ES G2, NO G1:** la respuesta anterior de Codex repetía G1, ZIP idéntico `aa3b450a…`, ya cerrado. NO repetir G1 ni volver a enviar su ZIP como entrega G2. Si G2 no ha empezado, ejecutar solamente esta V3; si ya empezó G2 V2, conservar la misma rama y TASK_ID y aplicar solo el delta de esta V3. No destruir WIP ni abrir otra ejecución paralela.  
**DIRECTOR:** ChatGPT decide arquitectura, producto, seguridad y aceptación. **CODEX LUNA:** ejecuta exactamente este macrotrabajo, con alternativas menores delimitadas. No delegar decisiones de negocio ni crear diseños.  
**META INNEGOCIABLE:** extender UNA SOLA VEZ el motor existente para nuevas condiciones nacionales, sin reprogramar por ciudad y sin generar falsos permisos. El resultado es **código utilizable**, JSON validado por Laravel, importación persistente Flutter/Drift y consumidores seguros, con un ZIP único y recuperación Git. **No es autorización para publicar normas, desplegar, instalar APK ni afirmar cobertura nacional.**  
**BASE INMUTABLE:** PR #71 moderno `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a` → R1 local `da9d8083bb21bd7c9863a319e07de51a5e692d09` → R2 local `88fc5d1307a80a9781f7b7e23e1912c3316c7531` → G1 local `9b5911dc2f734f89fb265877a568e426fc4b0651`. Solo arrancar si ancestros y árboles verificables. La fuente de R2 legal (`c879a27ce3fc0ef983575a069e995c95c4f9a03fe2b5f89509386dfa8090d5e5`) y ZIP G1 SHA-256 `aa3b450a539334806703f2cff4e898b8398fbb688da5ea7687c298f3a2fc3f1d` son checkpoints, NO autorización de nueva legalidad.  
**LEYES Y PRECEDENCIA:** L1 KISS+Ponytail; L2 antirruido; L3 antiparches; L4 UX congelada; L5 evidencia independiente; L6 antiping-pong. Obedecer `AGENTS.md`, `docs/CURRENT.md`, `docs/SOP.md`, `docs/DESIGN_CONTRACT.md`, baseline y fuentes más altas. Conflicto real: detener exclusivamente el cambio afectado y continuar lo seguro. No actualizar `main` histórico ni tocar C:, Hostinger, credenciales, dispositivos ni PR79/PR71 sin autorización. Proteger checkout original, 101 WIP históricos cuando estén disponibles y cualquier ruta descubierta; ausencia de montaje ≠ permiso para borrar.

---

## A. RESULTADO DE PRODUCTO QUE DEBES ENTREGAR (una sola ejecución con hitos internos)

No queremos otro ensayo de Bogotá ni otro sistema. **M0 preservación de historia → M1 contrato de condiciones y clases → M2 interpretación segura en todas las rutas Flutter → M3 round-trip Laravel schema2 aislado → M4 persistencia/compatibilidad/sincronización → M5 pruebas y ZIP recuperable.** Los hitos son internos de **un solo macrobloque**, sin pedir autorización entre ellos para errores recuperables. Un commit local final (o varios commits focales locales si se requiere trazabilidad técnica, con HEAD final único); un ZIP único. No hacer tareas G3/G4 de geocodificación masiva ni publicar reglas vigentes.

**PRECONTRATO DE TERMINACIÓN Y EVITAR PINGPONG:** El criterio principal de éxito es cambiar 6 predicados/ámbitos en UN conjunto de fixtures de laboratorio y obtener decisiones correctas en servidor, Flutter y consumidores sin introducir un `if` por ciudad. No generar otra auditoría G0 de archivos históricos. Si el entorno impide build/CI físico, informar bloqueo de esos gates sin descartar las pruebas ejecutables. Se admite una única entrega `PASS_SCOPED` si **todos** los gates críticos pasan, o `PARTIAL` con código y evidencias si no pasan; prohibido repetir G1 como sustituto.

**G2 queda aceptable únicamente si (NO basta copiar logs de G1):** (i) nueva condición de pasajero de moto; ocupantes `≥N` y `<N`; peso bruto; ejes; área referenciada funcionan mediante datos; (ii) Laravel rechaza contratos inválidos; (iii) Flutter evalúa triestado coherente, también en **resumen diario, ciudad, rotación, Inicio, Detalle y Viaje** sin crear autorizaciones engañosas; (iv) schema1 y datos privados permanecen intactos; (v) Laravel genera **bytes reales** que Flutter importa con SHA idéntico y último bueno protegido; (vi) el lote es recuperable desde la historia local mediante bundle o alternativa claramente clasificada.

### A1. Qué NO se modifica

Conservar versión productiva de `mobile/assets/datasets/restrictions/restrictions_v1.json`, catálogos 33 divisiones/1.104 registros municipales y 73 municipios de pico y placa, reglas R1/R2/G1, semántica legacy, manifiesto de producción, certificados, configuración de hosting, interfaz aprobada, las pantallas de Garaje y Viaje como flujos de captura y los demás módulos (peajes, Conducir, cámaras, etc.). No añadir microservicios, biblioteca de reglas, `eval`, código remoto, NLP para interpretar decretos ni motor por autoridad. No inventar geografía ni permiso a partir de placas. Las fuentes externas 31/55 siguen STAGING NO_PUBLICAR.

### A2. Inventario obligatorio al inicio (sin reeditar todo el pasado)

Inspeccionar la cadena real de llamadas y los consumidores de: `mobile/lib/features/garage/data/vehicle_profile.dart`, `mobile/lib/features/pico_placa/domain/restriction_rule.dart`, `restriction_engine.dart`, `restriction_day_evaluation.dart`, `city_restriction_summary.dart`, `mobile/lib/features/pico_placa/data/restriction_dataset.dart`, `restriction_store.dart`, `mobile/lib/core/database/app_database.dart`, `mobile/lib/core/sync/dataset_sync_service.dart`, `server/app/Services/RestrictionContractValidator.php`, `RestrictionImportService.php`, `RestrictionRuleVersionService.php`, `RestrictionPublicationService.php`, `DatasetReleaseValidator.php`, `DatasetPublisher.php`, `ManifestPublisher.php` y sus pruebas/consumidores (providers/widgets). Crear en informe una matriz breve `entrada → validador → serialización → Drift → motor → resumen → pantallas`. Si hay rutas bajo otro nombre, descubrirlas mediante `rg` y registrar equivalencia. **El verdadero hallazgo confirmado es que `city_restriction_summary.dart::_ruleMatchesDay` y `_weeklyRotationRow` derivan resultados sin evaluar predicados nuevos, y `restriction_day_evaluation.dart` devuelve allowed si no detecta restricciones. Esos son consumidores obligatorios de G2.**

## B. CONTRATO V2 ÚNICO — MÁXIMO 6 PREDICADOS, OPERADORES TIPADOS

Reutiliza `jurisdictions → coverages → rules` del dataset y un único `RestrictionEngine`. Nuevas condiciones solo en `rules[].conditions`, arreglo de objetos estrictos `{ "type": "...", "value": ... }`. **AND dentro de la misma regla; OR entre reglas según prioridad/efecto existentes.** Sin árbol OR/NOT/expresiones arbitrarias, sin scripts ni intérprete genérico. Esquema 1 antiguo NUNCA acepta condiciones nuevas, aunque el parser V1 anterior ignorase claves extras. Las claves V2 desconocidas fallan cerradas en servidor y cliente; no permitir que valores futuros se degraden silenciosamente a NO_MATCH.

**Tipos EXACTOS y rango espejo PHP/Dart:**

| `type` | `value` en JSON | Hecho tipado en contexto | MATCH cuando... | MISSING |
|---|---|---|---|---|
| `pillion_present` | boolean `true/false` | `bool? pillionPresent` | presencia == valor | UNKNOWN |
| `occupants_at_least` | entero 1–99 | `int? occupantsCount` | total personas, incluido conductor, >= N | UNKNOWN |
| **`occupants_below`** | entero 1–99 | `int? occupantsCount` | total personas, incluido conductor, < N | UNKNOWN |
| `gross_weight_kg_gt` | entero 0–100000 | `int? grossVehicleWeightKg` | peso bruto técnico declarado en kg > N | UNKNOWN |
| `axles_at_least` | entero 1–20 | `int? axleCount` | ejes >= N | UNKNOWN |
| `inside_scope_ref` | string `scopeId@scopeVersion`, ambos no vacíos | `SpatialEvidence?` para ese mismo ID | evidencia de alcance `inside` | UNKNOWN |

`occupants_below` es imprescindible: sin él no puedes expresar «prohibido circular si van menos de tres personas». `occupants_at_least` se conserva porque tiene semántica distinta (por ejemplo, una regla condicionada a un mínimo). Las condiciones V2 deben rechazar doble condición del mismo tipo en una regla; permitir combinación distinta, como `gross_weight_kg_gt` + `inside_scope_ref`. Para reglas con ambos comparadores de ocupación, rechazar intervalos imposibles (`at_least >= below`) como `BAD_CONDITION_VALUE`. No crear un operador universal en JSON.

**Hechos:** un objeto inmutable y tipado `RestrictionFacts` opcional en `RestrictionContext`, con propiedades nullable. No múltiples `Map<String,dynamic>` que salen de UI ni nuevas tablas de perfil. Rango también se valida para **hechos** (ocupantes 1–99, ejes 1–20, peso 0–100000); valores inválidos se rechazan o desconocen, NUNCA producen un permiso. `false` en parrillero es dato conocido, `null` es desconocido; `0` ocupantes no es «ausencia de dato». Peso bruto del vehículo no es carga instantánea ni año modelo.

**Ámbito:** `SpatialEvidence` tipado `{scopeId, scopeVersion, membership: inside|outside|unknown, provenance: ...}`. **Contrato de confianza CERRADO:** en la app distribuible nadie crea evidencia `inside/outside` a partir de una cadena, un centroide, un botón o un booleano proporcionado por pantalla. En G2 **no hay resolvedor de geometría real**: la factory de hechos usada por UI retorna `null` para membresía espacial. Para QA utilizar exclusivamente un adaptador FAKE inyectado en tests con `SpatialEvidence` marcada `SYNTHETIC_TEST_ONLY`; no conectar ese adaptador a providers de producción. El motor puede interpretar los hechos tipados para demostrar su algoritmo, pero NO confundir la inyección de pruebas con pertenencia geográfica probada. El contrato futuro de G3 será `ScopeResolver` que devuelva evidencia con identificador/versión/procedencia comprobable; no implementar el resolver ni guardar GPS en G2. La cadena de `inside_scope_ref` tendrá el formato inequívoco `scopeId@scopeVersion` y se divide por el **último** `@` (validar ambos segmentos no vacíos y rechazar `@` adicionales en el ID); de esta forma una condición JSON puede compararse sin inventar un registro geográfico. Para un `inside_scope_ref` se exige coincidencia exacta de ID **y versión** con el scope publicado; el origen del hecho no puede ser un `bool` enviado por cualquier pantalla. En G2 la prueba solo puede inyectar `SpatialEvidence` desde el adaptador FAKE de tests; esa evidencia jamás acredita GPS ni legalidad. Sin polígono/vía certificada, o si ID/versión/procedencia no coinciden → UNKNOWN; no resolver pertenencia por centroide ni instalar un algoritmo espacial en G2. `outside` explícito y verificable es NO_MATCH de ese predicado, **pero** una cobertura parcial continúa UNKNOWN si no hay otra restricción definitiva.

**Identidad y compatibilidad:** la incorporación de `truck`, `bus` y `motocarro` no implica adaptar la pantalla Garaje para crearlos; los valores antiguos de vehículos guardados en Drift deben seguir deserializando exactamente. Si enum/switch antiguo detecta una clase desconocida de laboratorio, es `UNKNOWN/no soportado`, NO se elige automáticamente `car` o `taxi`. Los objetos nuevos de pruebas usan constructores tipados; no alteran el almacenamiento local de placas personales.

**Dimensiones legales:** separar clase física `VehicleKind`, servicio `VehicleServiceType` y uso contextual (`passenger/cargo/mixed` solo cuando exista caso necesario; no es enum obligatorio para G2). Mantener `car/private`, `motorcycle/private`, `car/taxi` sin alteraciones. Agregar en ambos lenguajes exclusivamente `truck`, `bus`, `motocarro` como `VehicleKind` y `public_passenger`, `special`, `public_cargo` como `VehicleServiceType`, **solo** si caben con mapeo seguro en los consumidores existentes. Tabla mínima de pares ensayables sin introducir selects de usuario: `truck/private`, `truck/public_cargo`, `bus/public_passenger`, `bus/special`, `car/special`, `motocarro/private`; además los tres pares actuales. Los pares `truck/taxi`, `bus/taxi`, `motorcycle/public_cargo` se rechazan en V2 para no inventar equivalencias. No habilitar la categoría en UI ni asignarla a usuarios antiguos por default. Si un consumidor `switch` exhaustivo queda incompleto, adaptar su fallback a `UNKNOWN/no disponible` sin tocar el diseño. Si el esquema no puede representar una modalidad oficial futura, registrar brecha, no clasificarla como taxi. Aceptar que otros pares puedan requerir decisión legal futura.

**No introducir por suposición:** género/sexo de pasajero, identificación biométrica, permiso de conducción, edad/modelo o uso del vehículo desde placa, captura GPS, permisos personales. Eso exige fuente y decisión posterior. Campos `verifiedAt`/URL de norma no sirven para inferir `complete`.

## C. CONTRATO DE RESULTADOS Y REGLAS SUPERPUESTAS — CAUSA RAÍZ DE SEGURIDAD

Conservar exactamente estados externos `restricted`, `allowed`, `unknown`, `stale`. Para cada predicado y contexto, el matching interno es `MATCH/NO_MATCH/UNKNOWN`. Una regla temporalmente no activa no obliga a preguntar hechos: primero filtrar jurisdicción, clase/servicio, vigencia, festivos, horario, dígitos y origen. Solo después consultar hechos. AND: si **alguno** es NO_MATCH → regla NO_MATCH; si ninguno NO_MATCH y alguno UNKNOWN → regla UNKNOWN; si todos MATCH → MATCH. OR entre reglas conserva `priority`, `restrict/allow`, excepción y conflicto existente, pero **nunca** cambia UNKNOWN a allowed por falta de información.

**Prioridad orientativa verificable:** si una regla restrictiva conocida supera a todas las inciertas y no hay conflicto en su prioridad → RESTRICTED; si una regla `allow` o ausencia de matches puede verse anulada por una regla restrictiva incierta igual/superior → UNKNOWN; si existen `allow` y `restrict` contradictorias a la misma prioridad → UNKNOWN. Ningún resultado autorizado por condición desconocida. Conservar exacta semántica schema1 (`legacy`) y regresión de la paridad de Bogotá, taxi y moto, `digits=null` significa «sin filtro» y NO «dato faltante»; falta de dígito de placa cuando se requiere → UNKNOWN.

**Cobertura:** esquema 1 importado = `legacy`, sin recertificación. Esquema 2 exige `coverageCompleteness: complete|partial` por cobertura; `complete` requiere una evaluación editorial del ámbito completo por categoría y periodo, no lo concede el mero hecho de tener 1 regla. Toda cobertura V2 de **laboratorio G2 es `partial` por defecto**, incluidas las de carga con área no mapeada y moto con exenciones no evaluadas. En `partial`: `RESTRICTED` sólo si coincide una prohibición conocida y no hay excepción incierta con prioridad capaz de alterar el resultado; cualquier conclusión no restrictiva (incluida regla allow o no match) ⇒ `UNKNOWN`, **no** `allowedNoRestriction`. En `complete`: allowed solo con hechos necesarios conocidos y evidencia de cobertura integral; en G2 no se activa legalmente ninguna `complete`.

**Consumidores obligatorios, sin rediseño:**

1. `RestrictionEngine.evaluate`: matching triestado con los hechos opcionales. No duplicar lógica de condiciones en cada pantalla.
2. `evaluateRestrictionDay`: calcular estado de todo el día a partir de la evaluación del motor por segmentos, y distinguir **sin información** de **sin medida**. Si faltan hechos para una regla V2 potencialmente activa, devolver `UNKNOWN` aun cuando una franja muestre no-match; no afirmar ALL DAY ALLOWED. Para franjas cruzando medianoche, verificar el tramo [00:00–06:00] heredado y el [18:00–24:00] del día anterior/siguiente sin construir ventanas negativas ni aserciones inválidas.
3. `summarizeCityRestrictionDay`, `_ruleMatchesDay`, resúmenes de rotación semanal y por fecha: **la vista sin placa/hechos NO puede reutilizar `_ruleMatchesDay` como decisión legal**; debe derivar solo información calendario verificable y devolver `UNKNOWN/CONDICIONAL` para V2 parcial. Para schema1 preserva etiquetas, dígitos y los oráculos de R1/R2. Cuando una franja V2 se conoce `RESTRICTED` y otra es incierta, añadir una indicación de incertidumbre de la jornada sin transformar el tramo incierto en `ALLOWED`. `restrictionPhaseAt` debe operar con intervalos diarios NORMALIZADOS [0,1440) y respetar medias noches, no con ventanas de regla crudas start>end. Exigir pruebas 29/oct 18:00; 30/oct 00:00, 05:59, 06:00; 2/nov 18:00; 3/nov 06:00. La compatibilidad de intervalos nocturnos es **un riesgo de regresión**, no se presupone un fallo previo sin test que lo reproduzca.
4. Inicio, Detalle y Viaje: prueba de widgets/proveedores de que V2 `partial` y hechos ausentes no muestren permiso amplio ni reintroduzcan aviso de carro en moto o taxi. **No agregar pantallas, nuevos controles, cambiar mockups o solicitar datos a usuarios.** Si el contrato actual no admite representar UNKNOWN, usar el estado de incertidumbre existente o detener ese subgate con `UI_CONTRACT_BLOCKED` y no declarar producto utilizable. No usar un `if (city == Bogota)` como parche.
5. Known-empty (`rules=[]`) en schema1 preserva la conducta histórica; en schema2 `partial` = UNKNOWN; schema2 `complete` solo puede presentar ALLOWED tras prueba editorial completa fuera de este lote.

### C1. Matriz de evaluación mínima (oráculo NO derivado del mismo código)

| Caso | Hechos | Resultado del MOTOR (scope partial) |
|---|---|---|
| Moto, 30/oct 2026 19:00 Bogotá, parrillero=true, fixture histórico | presente | RESTRICTED de esa regla, no autorización de todas las excepciones |
| Mismo instante, parrillero=false | conocido falso | UNKNOWN global (la regla no aplica, el scope es parcial) |
| Mismo instante, parrillero=null | desconocido | UNKNOWN |
| Moto, 03/nov 2026 06:00 | cualquiera | regla histórica no vigente; NO afirmar ALLOWED global |
| Camión, 8.501 kg, pertenencia zona de laboratorio inside, martes 07:00 | peso y scope inyectados **sintéticos** | RESTRICTED del fixture condicionado |
| Camión, 8.500 kg, inside | peso conocido, regla no aplica | UNKNOWN global en cobertura parcial |
| Camión, 9.000 kg, zona=unknown/mismatch | falta scope | UNKNOWN |
| Camión, 9.000 kg, outside verificado de fixture | no-match de esa restricción | UNKNOWN global por cobertura parcial |
| Ocupación 1 o 2 y regla `occupants_below:3` | known | RESTRICTED si efectivamente está dentro del scope temporal; con 3 → UNKNOWN en partial |
| `occupants_at_least:3` con 3 | known | MATCH si la regla se mantiene aplicable, no sustituir semántica de `<3` |
| Dos reglas contradictorias `restrict`/`allow` misma prioridad | known | UNKNOWN |
| Restricción antigua de Bogotá car/private schema1 | n/a | MISMOS resultados R1/R2/G1, sin recertificación |

**Nota legal:** las pruebas históricas documentan un predicado, NO afirman que una moto sin parrillero estuviera legalmente autorizada, pues había exenciones y 19 corredores con otra restricción. Tampoco una carga outside puede tener permiso total si no se conoce el resto de normas.

## D. VERSIÓN DE DATOS, IMPORTADOR Y PERSISTENCIA: UNA SOLA RUTA

**DECISIÓN ADOPTADA POR EL DIRECTOR: COMPATIBILIDAD MIXTA SOLO ENTRE CIUDADES, NUNCA DENTRO DE UNA COBERTURA.** Dos hechos de código gobiernan G2: (i) `server/app/Models/Dataset.php::booted()` impide modificar `schema_version` si el dataset YA tiene releases; (ii) `RestrictionPublicationService::publishVersions()` sustituye solo ciudades seleccionadas y conserva las otras sin transformar su payload. Por eso se PROHÍBE cambiar el dataset productivo V1 a `schema_version=2`, alterar su historial o forzar la excepción del modelo. No imponer una conversión masiva de las 7 ciudades/12 coberturas, que no han sido recertificadas.

**Forma definitiva del CONTRATO:**
- **Envelope publicado V1:** `schemaVersion:1`, todas las ciudades heredadas sin `schemaVersion` propio (o `1` explícito si realmente existente), cobertura legacy, sin `conditions` ni `coverageCompleteness`; Flutter anterior se comporta exactamente como antes.
- **Envelope publicado de laboratorio V2:** `schemaVersion:2`, `datasetKey`, `version`, `generatedAt`, `jurisdictions`; puede contener ciudades **legacy** intactas (sin `schemaVersion`: interpretar 1; opcional `schemaVersion:1`) y ciudades V2 (`schemaVersion:2` explícito). No mezclar V1/V2 **dentro de una ciudad** ni permitir `conditions` en un `rules[]` legacy. Ciudad V2 exige que cada una de sus coberturas declare `coverageCompleteness:partial|complete`; en G2 solo `partial`. Nunca asignar `complete` por transformación automática.
- La protección G1 sigue comparando identidad de coverages en publicaciones normales. Pasar de V1→V2 en **una ciudad** requiere un borrador completo de esa ciudad. Las otras ciudades siguen payload legacy canónico igual: verificar comparaciones estructurales/hash por jurisdicción, 7/12, reglas y `staleAfter`, NO actualizar `verifiedAt` ni declarar frescura por cambiar envelope.
- **LAB SQLite/Storage fake:** crear un dataset `restrictions` nuevo con `schema_version=2` **antes de crear su primer release**; construir su baseline raíz V2 mediante **envolver** el release R2 original: conservar las 7 ciudades EXACTAS como legacy, cambiar solo envelope/version/generatedAt de laboratorio (no publicar a usuarios). A partir de él, confirmar una **octava jurisdicción sintética** `co-example-lab` schema2 parcial con su unidad geográfica/authority ficticias sembradas en DB fake. Así se conservan sin editar TODAS las 7 ciudades/12 coberturas heredadas; en el release de prueba habrá 8 jurisdicciones y al menos 13 coberturas, con recuento exacto por fixture. No transformar Bogotá/Popayán reales ni inventar norma actual. Probar aparte pipeline V1 original en otro dataset/DB fake sin mutarlo. **No cambiar `Dataset::booted()` ni invocar forceUpdate para eludir inmutabilidad**.
- **G2 NO es plan de despliegue de schema2.** La ruta de conversión del dataset V1 productivo requerirá autorización y migración/cutover explícitos en fase de lanzamiento, con clientes antiguos bloqueados de descargar V2 mediante compatibilidad efectiva. No intentar ese corte productivo durante G2.


**Esquema editorial de laboratorio V2 fijado:**

```json
{
  "schemaVersion": 2,
  "jurisdictions": [
    {
      "schemaVersion": 2,
      "id": "co-example-lab",
      "name": "Ejemplo SINTÉTICO",
      "coverages": [
        {
          "vehicleKind": "truck",
          "serviceType": "public_cargo",
          "coverageCompleteness": "partial",
          "verifiedAt": "2026-11-10T00:00:00Z",
          "staleAfter": "2026-11-20T00:00:00Z",
          "sourceUrls": ["https://www.movilidadbogota.gov.co/preguntas-frecuentes/cuales-son-las-areas-y-horarios-de-restriccion-de-circulacion-de-vehiculos-de"],
          "rules": [{
            "id": "SYNTHETIC_G2_CARGO", "priority": 100, "effect": "restrict",
            "validFrom": "2026-11-10T00:00:00-05:00",
            "validUntil": "2026-11-19T23:59:59-05:00",
            "weekdays": [1,2,3,4,5], "timeWindows": [{"startMinute":360,"endMinute":480},{"startMinute":1020,"endMinute":1200}],
            "appliesOnHolidays": false,
            "sourceUrl": "https://www.movilidadbogota.gov.co/preguntas-frecuentes/cuales-son-las-areas-y-horarios-de-restriccion-de-circulacion-de-vehiculos-de",
            "verifiedAt": "2026-11-10T00:00:00Z",
            "conditions": [{"type":"gross_weight_kg_gt","value":8500},{"type":"inside_scope_ref","value":"co-dc-bogota-zone1@2026-lab"}]
          }]
        }
      ]
    }
  ]
}
```

Este JSON es **SINTÉTICO**, no debe guardarse como fuente oficial ni publicarse. El scope `co-dc-bogota-zone1@2026-lab` es nombre ficticio de prueba, no una geometría. Ajustar solo fechas de laboratorio si el reloj de prueba exige, registrándolas; no usar tiempo futuro como autoridad legal. El dataset **publicado por Laravel** conserva su envelope habitual `schemaVersion`, `datasetKey=restrictions`, `version`, `generatedAt`, `jurisdictions`; **NO sustituir todo ese envelope por el editorial**.

**Importador real y control exacto:** `RestrictionImportService::read()` acepta lista o `{jurisdictions:[...]}` y hoy DESCARTA `schemaVersion` externo. Para G2:
1. En `read()` validar que envelope `schemaVersion:2` contiene **lista de ciudades**; cada ciudad puede declarar `schemaVersion:2`, o permanecer sin campo (legacy 1) para preservación en release compuesto. Para la importación de **un borrador V2**, exigir ciudad con `schemaVersion:2`; rechazar ciudad V2 oculta en envelope V1 o `conditions`/`coverageCompleteness` en ciudad legacy.
2. Transmitir el envelope schema2 a través de `analyze→normalize→confirm→createDraft` mediante validación contextual simple y conservando `schemaVersion:2` de cada payload de ciudad; evitar inventar un segundo importador o persistir una copia íntegra del envelope en todas las filas cuando bastan metadatos por import. Las filas JSON de ciudad legacy en importación V1 mantienen ruta histórica.
3. `RestrictionPublicationService` al componer release de laboratorio `Dataset.schema_version=2` debe validar que las ciudades heredadas SIN marcador son legacy, y que la nueva ciudad V2 declara condiciones/partial correctamente. `DatasetReleaseValidator` verifica tanto envelope V2 como mezcla legítima entre ciudades, **nunca** permitir condiciones V2 en una ciudad legacy. Si el dataset local de prueba es de schema1, publicar V2 debe fallar sin escribir release ni manifest.
4. No cambiar default histórico `publish=yes`, ni tocar CSV/XLSX; V2 editorial se importa por JSON exclusivamente y en SQLite + Storage fake. `analyze()` escribe/audita pero no confirma, valida ni publica por sí solo. Exigir etapas separadas y consentimiento de editor en el laboratorio. El publisher de G1 conserva rollback y revisión de cobertura; no convertir `REVIEW_REQUIRED` en bypass automático.
5. Probar explícitamente la combinación: **7 jurisdicciones legacy originales y una octava V2 parcial sintética**, preservar 7/12 objetos/coverages heredados exactamente, más la(s) cobertura(s) sintéticas declaradas; comparar fuente/TTL originales idénticos en todas las legacy; prueba inversa schema1+ciudad2 se rechaza. No convertir una ciudad real a V2 para este gate ni actualizar los 1.104 registros municipales.

**Regla de composición y protección:** G1 impide omitir identidades de cobertura en publicación normal; preservarla y probar rollback. En G2 agregar únicamente la validación de **cambio semántico material** cuando una coverage conserva ID y pasa de N reglas a 0, pierde un conjunto restrictivo o amplía vigencia sin fuente: producir diff clasificable (`REVIEW_REQUIRED`) y bloquear promoción automática sin decisión editorial explícita. Evitar un veto ciego que impida la revocación legítima; no inventar un panel ni bypass `--force`. Implementar solo el gate mínimo dentro del flujo editorial actual en laboratorio, con evidencia de antes/después, actor y motivo; si no existe una autorización explícita compatible, **rechazar normal publish** y conservar rollback. No convertir este subgate en reescritura del sistema de licencias/permisos.

**Migración Drift justificada:** el estado `coverageCompleteness` es necesario en consultas y resumen sin releer arbitrariamente cada rule JSON. Agregar **UNA** columna a `restriction_coverages` de tipo texto con default `'legacy'`, whitelist `legacy|complete|partial` en parse/operaciones, una sola migración v9→v10, codegen reproducible con dependencia instalada, test upgrade desde v8 y v9 a v10. Schema1 escribe `legacy`; schema2 `partial` o `complete` **explícitos**. Conservar todas las filas actuales, vehículos, preferencias y documentos cifrados; hash y conteos pre/post. Ninguna otra tabla ni versión forzada de perfiles. Si el `build_runner` no puede ejecutarse por ambiente, marcar `BLOCKED_CODEGEN` con patch y pruebas parciales, **no** fingir un Drift generado correcto.

**Regresión de sync:** cliente V1 debe rechazar schema2 y preservar bytes / `dataset_versions` / filas del último bueno. Cliente G2 acepta schema1 y envelope schema2 con ciudades legacy + V2 **solo en laboratorio**, verifica manifest, `sha256`, versión, `publicationRevision`, `minAppVersion` y rollback, conserva last-good si falla hash, JSON, versión, condición desconocida, migración o descarga. No modificar `minAppVersion` ni habilitar hosting real en G2. Test `ImportError` que deja intacto schema1 last-good. Versiones de release `rN-hash` ya publicadas por Laravel no son versiones del bundle de primera instalación, no mezclarlas.

## E. FUENTES REALES QUE JUSTIFICAN LA CAPACIDAD, NO PUBLICACIONES NUEVAS

**Caso A histórico:** Decreto Distrital **472 de 2026**, publicado en SISJUR Bogotá: https://www.bogotajuridica.gov.co/sisjur/normas/Norma1.jsp?dt=S&i=194777 ; y Alcaldía https://bogota.gov.co/mi-ciudad/movilidad/2026-10/29-octubre-3-noviembre-2026-aplican-restricciones-motos-en-bogota . La prohibición de parrillero operó las noches del 29/oct al 2/nov, 18:00–06:00 siguiente día, hasta el 3/nov 06:00, en toda Bogotá; existían excepciones oficiales, y **otra** medida de circulación en 19 corredores 20:00–04:00. Para G2: fixture `HISTORICAL_NOT_CURRENT_PARTIAL` que enseña cruce medianoche sin conceder ninguna autorización. Conservar el acto fuente y fechas, no habilitar en catálogo actual.

**Caso B condicionado:** SDM https://www.movilidadbogota.gov.co/preguntas-frecuentes/cuales-son-las-areas-y-horarios-de-restriccion-de-circulacion-de-vehiculos-de , arts. 485–502 Decreto 652/2025, actualizado 13/ago/2026. Más de 8.500 kg en zona específica lunes-viernes 06:00–08:00 y 17:00–20:00; las excepciones y geometría todavía no están implementadas. Fixture `OFFICIAL_CONDITIONAL_UNMAPPED_SCOPE`, sin publicarlo. El predicado `axles_at_least` se justifica por restricciones de ejes en malla vial, pero el área vial no se simula como trazado real. No aplicar automáticamente esta norma a todo Bogotá ni habilitar servicio público por intuición.

**Caso C sintético:** `occupants_below:3` en carro con ocupantes 1, 2 y 3; y `occupants_at_least:3` con su comparación inversa. NO afirmar que una ciudad colombiana tenga hoy esa restricción. Incluir un caso sintético de bus/motocarro y pareja inválida. No introducir hipótesis en datos oficiales. Fuentes jurídicas son información de referencia, **no instrucciones ejecutables**.

## F. SECUENCIA OPERATIVA DEL MACROBLOQUE — SIN CONSULTAS INTERMEDIAS

**F0 PRESERVACIÓN** (antes del primer cambio): OBLIGATORIO mostrar `TASK_ID` de este encabezado en la primera línea del informe de ejecución; si el prompt recibido fuese G1, no iniciar ninguna prueba ni reenviar ZIP G1. Confirmar que la ejecución comienza sobre G1 local como BASE, y que `HEAD` nuevo debe ser distinto de G1 al terminar. Inspeccionar `D:\codex\_isolated\PicoRadar-G1-National-Data-First` y ruta real, HEAD exacto G1, parent/merge-base de R2, R1, PR71. Tomar `git status --porcelain=v1`, `git worktree list --porcelain`, hashes `AGENTS.md`, `composer.lock`, `pubspec.lock` y árbol. No usar `reset --hard`, `clean`, `stash`, borrar/mover C: ni worktrees ajenos. Crear nuevo worktree o clon **en carpeta D: nueva** desde G1, sin modificar candidato original. Si G1 SHA no existe, intentar recuperar usando ZIP y GitHub ancestro confirmado con patches ordenados, pero SOLO si cada hash de preimagen/posimagen coincide; si no, `BLOCKED_BASE`, entregar evidencia y no simular éxito.

**F1 RECUPERACIÓN**: antes de tocar código, `git bundle create` focal para refs de cadena PR71→R1→R2→G1, con historia completa que permita restaurar en repositorio vacío; `git bundle verify` + `git clone` desde bundle en carpeta independiente + `cat-file -e` para cuatro SHAs, comparar árbol G1. Si resulta demasiado grande o faltan objetos, generar patches acumulativos R1, R2, G1 con SHA base y final; probar aplicación a un clon limpio del PR71 y coincidencia EXACTA de los árboles; etiquetar `RECOVERY_PATCH_ONLY`, no llamarlo bundle autónomo. Incluir bundle o patches **dentro del ZIP**. No interrumpir la implementación segura si la alternativa por patches cumple identidad local, pero reporte `RECOVERY_FULL=PARTIAL`.

**F2 CONTRATO/REGLAS**: agregar tipos/conversores PHP+Dart, matriz de pares, parser estricto y condiciones, compatibilidad. Implementar primero pruebas RED: V1 rechaza conditions y schema2; V2 falta de ocupantes, peso, acompañante y scope no da ALLOWED; `occupants_below:3` se evalúa correctamente. Luego GREEN. No convertir el motor en DSL ni agregar dependencias.

**F3 CONSUMIDORES**: trazar el cálculo de Inicio/Detalle/Viaje y resúmenes diarios/de ciudad/rotación para V2. Añadir propagación mínima `coverageCompleteness` y hechos tipados. Para un contexto V2 sin hechos, emitir UNKNOWN; no mostrar “Puede circular”, “Sin restricción” ni status ALLOWED. Mantener exactamente la UI para schema1 y los tests de R2 del aviso de moto/taxi. Si hace falta un pequeño adaptador compartido para evitar lógica duplicada, uno solo; no crear nuevo motor ni pantallas.

**F4 PERSISTENCIA**: implementar UNA migración Drift v9→v10, upgrade v8/v9, codegen, parser V1/V2. Test instalación desde base con 7 jurisdicciones y 12 coberturas más datos de usuarios ficticios; comprobar last-good tras intento de instalar dataset V2 en cliente V1 o tras hash erróneo. No tocar datos reales ni modificar el JSON semilla.

**F5 LARAVEL E2E**: DOS laboratorios SQLite/Storage fake separados: A) baseline R2 raíz V1 (`schema_version=1`) inalterado; B) dataset nuevo `schema_version=2` **sin release previo**, sembrado con raíz2 que contiene las 7 ciudades legacy del mismo R2, sin tocar fechas/coverages; crear unidad/jurisdicción SINTÉTICA habilitada en DB fake y añadir su objeto de ciudad schema2 parcial vía `analyze → confirm → validate → publish`, release/manifest reales. Validar coexistencia de 7 legacy + 1 V2, sin modificar las 7 legacy, ni recertificar Bogotá/Popayán. Probar V2 en dataset1 y envelope1 con ciudad2 como RECHAZOS. Comprobar que Flutter G2 importa **los mismos bytes** SHA del release y que Flutter V1 rechaza la raíz2 conservando last-good. Ejecutar por separado regresión schema1 R2, con los 7/12 intactos. No reaprovechar una fixture sintética como si fuera release actual. Cero skips E2E obligatorios; si falta export, FAIL/BLOCKED, no SKIP silencioso.

**F6 PRUEBAS FOCALIZADAS Y VECINOS**: PHP tests de contrato, 6 tipos, pares, esquema y publicación; Flutter tests de engine, day, city, rotación, widgets relevantes, sincronización, Drift v8/v9→v10; frontera fecha/hora y conflicto. Ejecutar Pint, PHP lint, Dart format, `flutter analyze --no-pub`, `git diff --check`; ejecutar también suites regresivas de vecinos modificados. **No repetir todas las 3.000 pruebas históricas sin cambio de código**, pero no omitir las afectadas. Registrar comandos, exit code, tests PASS/FAIL/SKIP y ambiente. Error recuperable: máximo un ajuste focal de entorno conocido, repetir solo gate afectado; defecto de contrato: corregir causa raíz y correr vecinos, no una cascada de patches.

**F7 CIERRE**: comparar estado original de todos los worktrees conocidos sin tocarlos. Verificar solo archivos esperados en diff, SHA de locks y que no se cambió `main`, PR71, PR79, PROD ni APK. Commit local identificado por SHA nuevo; decidir push **NO** si identidad/CI/coste no acreditados. Regenerar paquete de recuperación si el SHA final no está en bundle original; mejor un único bundle final que cubra R1/R2/G1/G2, restaurado en repo vacío. Validar ZIP contra extracción independiente, hashes, rutas seguras y ausencia de secretos. **Una sola entrega.**

## G. DOCE GATES DE SALIDA — NO SON DOCE LOTES

| Gate | Prueba vinculada a código y evidencia REAL | PASS únicamente si |
|---|---|---|
| G201 | G1 base, PR71/R1/R2 ancestros, WIP, bundle o patches | hashes y restauración comprobados sin tocar protegidos |
| G202 | schema1 R1/R2/G1 | 7 jurisdicciones / 12 coberturas y estado legacy, reglas y datos de usuario intactos |
| G203 | PHP V2 real en DB fake, compatibilidad por ciudad | dataset **nuevo** schema2, envelope2 con 7 ciudades legacy y octava ciudad V2 de laboratorio; import→confirm→validate→publish; preservar 7/12 originales |
| G204 | Contrato tipado 6 condiciones, rangos y pairs | PHP/Dart rechazan invalid type, missing, duplicados, parejas ilegales, condiciones en V1 |
| G205 | Moto Halloween 2026, 18→06 y excepciones | cronograma nocturno 29/oct→3/nov probado en límites; históricos V2 `partial` y UNKNOWN donde corresponde, NO claims actuales |
| G206 | Carga >8500 kg, franja doble, zona | 8500 vs 8501, inside/outside/unknown, versión/procedencia, no permiso global |
| G207 | Ocupantes ≥3 y **<3**, ejes, intersecciones | hechos explícitos, límites, nulos, AND y ejemplos del dueño |
| G208 | Camión/bus/motocarro, servicios y pares | sin reinterpretar taxi, privada o un vehículo preexistente |
| G209 | Engine, día, ciudad, rotación, Inicio/Detalle/Viaje | V2 `partial` no produce falsas autorizaciones por segmento incierto, test límites nocturnos; legacy intacto |
| G210 | Release V2 con ciudades legacy + V2: HTTP loopback → Flutter/Drift | mismos bytes SHA release = manifest = import, last-good ante fallos; cliente V1 rechaza V2 |
| G211 | Drift única migración y compatibilidad | v8/v9→v10 con fixtures, codegen y preservación de vehículos/documentos |
| G212 | GIT, pruebas, paquete y cierre | diff acotado, logs, bundle/patch reproducible, ZIP validado, no publicación |

**Categorías de reporte por gate:** `PASS`, `PARTIAL`, `FAIL`, `BLOCKED`, `NOT_RUN` + archivo, comando, exit, SHA, prueba positiva/negativa. Distinguir `PHP_TESTS_PASS_REPORTED`, `FLUTTER_TESTS_PASS_REPORTED`, `G2_TYPED_ENGINE_LAB_PASS_SCOPED`, `PRODUCT_RELEASE=NO`; jamás declarar PASS productivo con fuente histórica o sintética. Si G209, G203, G210 o G211 falla, resultado integral no puede ser `PASS_SCOPED`: detener promoción y entregar `PARTIAL` con código útil y blocker preciso.

## H. MATRIZ DE DECISIONES ACOTADAS (NO AUTONOMÍA ARQUITECTÓNICA)

1. **Migración Drift incompatible con baseline** → no edites tablas privadas ni fuerces el esquema. Conserva parser V2 en branch y entrega `BLOCKED_MIGRATION` con SQL/trace y 1 propuesta, sin fingir G211.
2. **Un enum nuevo rompe un widget aprobado** → conservar visual y usar estado genérico no disponible/UNKNOWN; si exige pantalla nueva, `UI_SCOPE_BLOCKED` y test negativo. No convertir bus en taxi.
3. **Origen espacial sin geometría real** → prueba etiquetada sintética + `UNKNOWN_SCOPE` para uso normal. No inventar polígonos ni marcar test como jurídicamente aprobado.
4. **Cambios semánticos por editor (borrado de reglas sin borrar coverage)** → exigir diferencial y revisión humana; si no existe flujo seguro, bloquear normal publish, rollback histórico intacto.
5. **Importador CSV/XLSX no puede portar schema2** → G2 usa JSON V2; NO romper ni reescribir CSV/XLSX históricos. Documentar schema2 JSON como canal admitido y las hojas antiguas como V1.
6. **Git bundle grande** → probar patches acumulativos y SHA árboles; si el host impide crear bundle completo, `RECOVERY_PATCH_ONLY` y anexar diagnóstico, sin ocultarlo.
7. **Entorno offline** → `--no-pub` si el lock y dependencias están disponibles, no modificar versión ni instalar paquetes para simular PASS; dejar gate bloqueado si faltan dependencias.
8. **CI remoto/cuenta Git/hosting inciertos** → cero push, merge, costos, deploy o publicación. Código local sí puede quedar listo.
9. **Criterio no contemplado** → resolver en el límite más conservador (`UNKNOWN`/no activación); documentar en `BLOCKERS.md`, no inventar alcance legal ni solicitar microautorizaciones.

## I. ÚNICO ZIP AUTOSUFICIENTE PARA CHATGPT DIRECTOR

Ruta sugerida `D:\codex\_REPORTES\PicoRadar\PICORADAR_G2_V3_MACROBLOQUE_NACIONAL_20261110\delivery\PICORADAR_G2_V3_MACROBLOQUE_EVIDENCIA_UNICA.zip`. El ZIP debe contener: `FINAL_REPORT.md` con G201–G212 y los valores verdaderos; `GIT_REFS.txt` y `GIT_STATUS_PRE_POST.txt`; `GIT_DIFF.patch` + un bundle completo restaurado o patches recuperables; `V1_V2_CONTRACT.md` de una página con los 6 tipos y límites; `SOURCE_LEGAL_MATRIX.md` que separa acto vigente, norma histórica y fixture sintético; `TEST_ORACLES.md`; fixture V1 de contraste y fixture V2 etiquetada; `PHP_G2_REAL_LAB_RELEASE.json`/`PHP_G2_REAL_LAB_MANIFEST.json` bytes exactos; `FLUTTER_SAME_BYTES_IMPORT_RESULT.md`; logs de PHP, Flutter, migración/format/analyze y tests de widgets; `SCHEMA_MIGRATION_RESULT.md`; `COVERAGE_AND_RELEASE_GAPS.md`; `BLOCKERS.md` solo si aplica; `MANIFEST.json` de miembros con SHA256/tamaño; `MANIFEST.sha256`. Hash ZIP completo y tamaño en respuesta. Cero secretos, `*.env`, certificados, PII, GPS de usuarios o documentos privados. Proteger zip-slip y validar CRC+extracción+hash de cada miembro desde carpeta independiente. No incluir archivos vacíos fingiendo PASS. Código y cambio deben poder auditarse desde patch o bundle, no solo mediante explicación.

**Respuesta mínima fuera del ZIP:** `TASK_ID=PICORADAR-G2-MOTOR-NACIONAL-TIPADO-20261110 | PROMPT=G2_V3_MACROBLOQUE | RESULT=... | G201..G212=... | PHP=... | FLUTTER=... | SAME_BYTES_SHA=... | DRIFT_MIGRATION=... | GIT_RECOVERY=... | LOCAL_HEAD=... | PR_PUSH=NO/VERIFIED | CI=... | APK=NO | PRODUCT_RELEASE=NO | ZIP_SHA256=... | NEXT=CHATGPT_DIRECTOR`.

## J. RUTA A LANZAMIENTO DESPUÉS DE G2 (NO MÁS MACROAUDITORÍAS DE LO MISMO)

**G3 geografía**: conservar 33 divisiones/1.104 municipios oficiales preexistentes; añadir versiones de puntos/centros poblados y geometrías DANE adecuadas, sin confundir centroide con ámbito jurídico; resolver `inside_scope_ref` a partir de geometría y contexto de viaje legítimos sin GPS continuo ni historial. **G4 carga por lotes**: Medellín carro/moto y excepciones de ámbitos, Bogotá regional/carga, Cartagena y otras autoridades previamente investigadas; cada norma oficial validada en JSON editorial y habilitada solo con coverage jurídicamente completa o `PARTIAL/UNKNOWN`. **G5 producto real:** canales de dataset versionados, GitHub/CI coste verificado, APK dev, QA física Android/last-good, permisos y autorización humana GO. KPI = modalidades/autoridades/regímenes **realmente evaluables en la app** con fuente/vigencia/ámbito, no número de catálogos ni de tests sintéticos.

**CIERRE:** Una sola ejecución del macrobloque G2 V3. ChatGPT dirige y audita, Codex Luna ejecuta, NO publica, NO rediseña, NO borra WIP. Evidencias consolidadas en UN ZIP. Cuando entregue, `NEXT=CHATGPT_DIRECTOR`. FIN.
