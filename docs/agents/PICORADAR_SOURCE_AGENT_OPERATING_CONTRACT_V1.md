# PicoRadar — Contrato operativo del agente independiente de fuentes V1

**Fecha:** 2026-11-07. **Estado:** contrato de trabajo DOCUMENTADO, **agente NO implementado ni desplegado**. **PR documental:** #79 Draft. **Precedencia:** `AGENTS.md` y baselines → contratos actuales → este archivo; este documento no los sustituye ni autoriza escrituras productivas.

## Propósito y límites

Mantener un registro nacional reutilizable de alcaldías, secretarías, institutos y demás autoridades competentes, vigilar fuentes públicas de pico y placa y proponer cambios **sin ejecutar publicación**. La aplicación móvil debe seguir siendo local-first y sin cuenta obligatoria; la evaluación de circulación ocurre en el teléfono mediante datasets versionados. **Laravel existente** es el único módulo de aprobación, generación, publicación y rollback. No crear microservicios, un segundo registro de verdades legales, bases productivas duplicadas, scraping agresivo o permisos de escritura de producción para el investigador.

La investigación documental M1B es **trabajo manual/dirigido por Codex bajo ChatGPT**, no evidencia de que este agente automatizado ya exista. Una posterior implementación requiere rama propia, contrato aprobado, pruebas y autorización independiente.

## Registros lógicos mínimos (reutilizar modelos antes de migrar)

1. **`authority`**: `authority_id`, nombre público, competencia acreditada, territorio DIVIPOLA o polígono explícito, URL institucional, estado activo/incierto. La URL no prueba competencia por sí sola.
2. **`source`**: `source_id` inmutable, URL canónica y exacta, portal padre, entidad emisora, tipo (comunicado/calendario/PDF/acto/social/tercero), idioma, clase de vehículo a la que se refiere, `allowed_for_runtime=NO` por defecto, última captura y estado.
3. **`source_check`**: clave `(source_id, checked_at_utc, url_exact, source_run_id)`, HTTP real o null, redirección final, ETag/Last-Modified, captura real y SHA-256 si está permitida, resultado de extracción, `evidence_strength`, cambios y próxima consulta. Nunca atribuir hash al enlace sin bytes capturados.
4. **`jurisdiction_rule_proposal`**: DIVIPOLA, autoridad y evidencia de competencia, tipo vehículo, último/primer dígito, días, rangos horarios incluso tras medianoche, zona/corredor, festivos/exenciones, inicio/fin legal (fin null es válido si la fuente declara vigencia abierta), publicación oficial, valor previo/nuevo, conflicto, pruebas propuestas; `activation=false` por defecto.
5. **`review_decision`**: quién acepta/rechaza, por qué, evidencia y fingerprint de regla. Propuesta aprobada se remite a Laravel; el agente no posee credenciales de publicación.

No aprobar nuevas tablas por anticipado: primero mapear a `DatasetSource`, `DatasetRelease`, `RestrictionPublication`, `CameraSource` y herramientas Laravel B07 existentes. Cambios schema requieren migración y test en lote independiente.

## La misma fuente nunca se analiza innecesariamente

- Clave de consulta: `(source_id, url_exact, divipola, vehicle_category, target_validity_period)`; usar la URL compartida **una sola vez por ejecución**, pero permitir múltiples reglas relacionadas cuando el acto demuestra su alcance.
- `checked_at` significa visita, `source_published_at` fecha de comunicado, `effective_from/effective_until` vigencia normativa, `next_review_at` vigilancia y `dataset_stale_after` TTL técnico del dataset. Son campos distintos. Conservar timestamps UTC/offset y zona jurídica `America/Bogota`.
- Si `ETag`/`Last-Modified` demuestran no-cambio y existe captura previa íntegra, anotar `NO_CHANGE` y reprogramar; `304` sin snapshot previo NO valida contenido jurídico.
- El digest de contenido del acto debe ignorar el timestamp de la consulta, preservando huellas de bytes reales. Distinguir cambios cosméticos de cambio de regla. Nunca generar cientos de 'actualizaciones' porque cambió `checked_at`.
- Códigos DIVIPOLA no prueban que exista una medida: `NOT_SEARCHED`, `OFFICIAL_PARTIAL`, `FULL_OFFICIAL_RULE_CANDIDATE`, `OFFICIAL_NO_MEASURE` (únicamente negación expresa y actual por autoridad competente), `CONFLICT`, `INACCESSIBLE` permanecen separados. `NOT_FOUND`/HTTP 404 no significa libre circulación.
- Fechas límite y frecuencia: 7 días para periodos próximos a rotar, 15 para calendarios frecuentes, 30 para medidas estables; check extraordinario ante nuevas publicaciones o suspensión. Las frecuencias son configuración propuesta, no automatización actualmente ejecutándose.

## Evidencia oficial suficiente sin exigir decreto por defecto

Comunicado/calendario vigente de alcaldía, secretaría u organismo legalmente competente puede bastar si especifica autoridad, territorio, clase, dígitos/posición, días, horario, período y excepciones relevantes. Cuando faltan campos materiales o hay conflicto, hacer búsqueda oficial adicional, no inferir valores. PDF/imagen ilegible es `REQUIRES_HUMAN_REVIEW`; red social oficial puede ser señal, pero autoría y contenido deben comprobarse. Nunca extrapolar la restricción de Medellín a Bello ni un anuncio en Atlántico a veinte municipios sin acreditar alcance literal.

Para `OFFICIAL_NO_MEASURE` registrar territorio, categoría, fecha, autoridad, URL y frase explícita; no se infiere por ausencia de búsqueda. Cuando se indica «hasta nueva rotación» u otra vigencia abierta, no inventar fecha de fin: mantener revisión periódica independiente de la validez jurídica.

## Seguridad y recursos

Solo fuentes públicas sin login ni bypass de CAPTCHA, robots, límites de acceso, paywall o credenciales privadas. Limitar páginas documentales por ejecución (M1B máximo 100, no objetivo). Ante cinco fallos de fuentes independientes parar solicitudes de red y conservar cola. Registrar URLs sin parámetros de sesión/PII; no guardar placas, documentos, geolocalización continua ni HTML autenticado. No modificar SSL ni desactivar antivirus. Guardar extractos mínimos y datos de procedencia; capturas crudas solo si son públicas y está permitido.

**Entrega y entrada verificable:** ningún investigador, agente ni Codex debe dar por recibido un ZIP, CSV o evidencia a partir de un enlace Markdown, una ruta Windows supuesta o el nombre de archivo. Primero confirmar los bytes presentes en el adjunto/ruta real, validar SHA-256, CRC y manifiesto; buscar acotadamente solo si hace falta. Si no hay acceso, registrar `INPUT_ATTACHMENT_REQUIRED` sin simular que se investigaron ciudades, generar reglas ni reabrir pruebas de otras fases. El bloqueo de transferencia M1B del 2026-11-07 queda en `SRC-15` del registro de errores. **Esta regla es operativa para las tareas de investigación; el agente sigue sin implementar/desplegar.**

## Estados de operación y gates

`DISCOVERED` → `OFFICIAL_PAGE_FOUND` → `OFFICIAL_PARTIAL` / `FULL_OFFICIAL_RULE_CANDIDATE` / `OFFICIAL_NO_MEASURE` / `CONFLICT` → `PROPOSAL_DRAFT` → `VALIDATED_BY_LARAVEL` → `PUBLISHED_BY_LARAVEL` / `REJECTED`. `INACCESSIBLE`, `STALE_REVIEW` y `NOT_SEARCHED` son observaciones independientes. Un agente lector **no** marca `PUBLISHED` por sí mismo.

Tests mínimos antes de automatizar: misma fuente+regla NO_CHANGE, captura ausente no SHA, fuente 304 con/sin snapshot, dos URLs equivalentes, fuente compartida sin alcance, 404 no_measure falso, calendario de 06:00→06:00, festivo, cambio de horario, suspensión confirmada, conflicto entre actos, digest estable, idempotencia de doble ejecución, rollback, ausencia de PII y recuperación offline. Una prueba jurídica focal no dispara AOT/Flutter; QA final sobre SHA efectivo sigue siendo obligatoria.

## Métricas separadas por corte

`divipola_universe`, `jurisdictions_with_authority_identified`, `urls_legacy`, `urls_new`, `urls_live_checked`, `sources_with_snapshot_hash`, `territory_source_relations`, `vehicle_categories_reviewed`, `full_official_rule_candidates`, `official_no_measure`, `not_searched`, `jurisdictions_runtime_enabled`, `pending_review`, `last_successful_run_at`, `agent_deployed=false`.

**Referencia de errores y correcciones:** `docs/agents/PICORADAR_AGENT_ERRORS_DECISIONS_LEDGER_20261107.md`. **Orden vigente para siguiente ejecución:** `docs/plans/CODEX_LUNA_PICORADAR_M1E_VALIDATOR_CALENDARIO_KISS_ORDEN_20261108.md` (nuevo TASK_ID M1E focal derivado del M1D `PARTIAL / BLOCKED_CONTRACT`; NO repetir M1B, M1C ni M1D). **Referencia de dirección:** Plan Maestro V2, apartados Q/R/S. M1D conserva solo valor histórico/forense. Los contratos existentes de agente lector, revisión humana y publicación exclusiva Laravel NO CAMBIAN. **GitHub:** PR #79 solo documental Draft. **Release:** `NOT_APPROVED`.