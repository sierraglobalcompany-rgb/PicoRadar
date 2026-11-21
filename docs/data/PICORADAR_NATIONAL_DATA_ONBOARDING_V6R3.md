# PicoRadar: incorporar datos nacionales de pico y placa

Este procedimiento describe el carril schema2 existente. V6R3 es un conjunto **LAB**; no está aprobado para publicar ni sustituye una revisión jurídica o espacial.

## Incorporar una jurisdicción

1. Selecciona un ID estable de autoridad y confirma el código DIVIPOLA de cada municipio. Una autoridad departamental conserva un solo ID y declara únicamente sus municipios expresamente cubiertos. No atribuyas reglas metropolitanas a municipios vecinos.
2. Usa una fuente oficial vigente que documente modalidad, rotación, dígitos, horario, ámbito y fechas. Registra la URL y la fecha real de consulta. `validFrom`/`validUntil` describen la vigencia publicada; `verifiedAt` y `staleAfter` controlan la revisión editorial por separado.
3. Crea un objeto schema2 con `id`, `name`, `municipalityCodes`, `consultationEnabled` y `coverages`. Cada cobertura lleva modalidad, `coverageCompleteness`, `verifiedAt`, `staleAfter`, `sourceUrls` y reglas schema2. Usa solo pares admitidos por `RestrictionContractValidator`.
4. Si hay vías excluidas, excepciones o clasificación personal que la app no puede verificar, usa cobertura `partial` e incluye `inside_scope_ref` en las reglas aplicables. La app puede mostrar el calendario como información, pero el resultado individual debe seguir `UNKNOWN` mientras falte evidencia espacial o personal. No uses `complete` ni una lista vacía para inferir permiso.
5. Añade el archivo a la lista explícita del ensamblador QA y genera el **snapshot completo** con `python scripts/qa/assemble_national_bulk_v6r3.py --write`. Comprueba determinismo, pares, IDs, reglas, códigos y frescura con `python scripts/qa/assemble_national_bulk_v6r3.py --check`; valida las mismas entradas y el snapshot con `php server/tests/contracts/validate_national_lab_v6r3.php`.
6. Revisa la matriz por autoridad, municipio y modalidad. Un código enumerado por una autoridad no demuestra que la norma aplique a todas sus vías ni a todos los vehículos. Los códigos geográficos DANE son un catálogo, no evidencia legal de cobertura.

## Autoridad departamental y ámbito desconocido

Una autoridad departamental se modela como una jurisdicción con varios códigos DIVIPOLA y una o más coberturas. Antes de habilitarla, confirma la lista oficial, modalidad y el corredor o tipo de vía. Si solo puede expresarse el horario pero la app no conoce la vía consultada, conserva `partial`, `inside_scope_ref` y `UNKNOWN`. Retén por separado cualquier franja nocturna que el motor no modele con seguridad.

## Flujo administrativo existente

El panel está protegido por autenticación de operador activo. `datasets.edit` permite abrir `/admin/restrictions/import`, subir JSON/CSV/XLSX, analizarlo, revisar las filas y confirmar filas válidas como borradores por jurisdicción. El JSON schema2 puede pasar el contrato sin usar el formulario manual. Después, `datasets.review` permite validar una versión y abrir la vista previa; los cambios materiales requieren aprobación editorial independiente. La publicación compone un snapshot con las jurisdicciones vigentes y los borradores elegidos, valida el release y solo entonces `DatasetPublisher` actualiza el asset y el manifest.

No publiques desde este procedimiento. Requiere una autorización de publicación separada, revisión humana de fuentes y alcance, snapshot completo, SHA-256 y preflight OTA. El rollback administrativo solo admite una versión publicada cuyo asset y hash sigan íntegros.

## Límites comprobados de la interfaz administrativa

`RestrictionFormPayloadBuilder` ofrece cuatro combinaciones nominales (carro/moto × particular/taxi), mientras el contrato schema2 admite nueve pares distintos y rechaza `motorcycle/taxi`. El importador JSON valida payloads schema2; el formulario no ofrece todas las modalidades. V6R3 deja esta brecha como P1 y no modifica el panel sin la prueba de base de datos requerida. El validador de release también bloquea coberturas schema2 `complete` con `REVIEW_REQUIRED` hasta que exista evidencia espacial compatible.

## Frescura y rollback

Un `staleAfter` vencido produce datos desactualizados incluso si `validUntil` es posterior. Cuando acaba la vigencia de la regla, no extiendas la fecha para mantener el calendario visible: publica una revisión oficial nueva o conserva el estado desconocido. OTA reemplaza el dataset completo; la app verifica el SHA del manifest antes de importar y conserva el último dataset bueno cuando falla la verificación. La prueba QA V6R3 cubre V5→snapshot nacional, persistencia de Garaje/preferencias, reapertura y rechazo de SHA incorrecto.

## Estado de esta entrega

El snapshot V6R3 permanece en LAB. No se ejecutó el flujo Laravel con base de datos: PHP expone `mysql` pero no `pdo_sqlite`. La matriz de cobertura y los bloqueos jurídicos del lote están en el ZIP de evidencia V6R3.
