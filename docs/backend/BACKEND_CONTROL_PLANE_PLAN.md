# PicoRadar — Backend / Control Plane Plan

## Estado actual

El backend Laravel existe como scaffold técnico, pero todavía no implementa el control plane definido por producto.

Actualmente NO hay evidencia de:

- API propia versionada;
- modelo de datasets;
- catálogo de fuentes;
- publisher;
- releases de datasets;
- admin real;
- audit log;
- proxy de Routes/Places;
- reports de datos incorrectos;
- push/invalidation;
- control de publicación a CDN.

Por tanto, E10 Backend/control plane está esencialmente pendiente.

## Qué necesita realmente Free 1.0

### B00 — Foundation

Objetivo: convertir Laravel scaffold en control plane mínimo sin construir un SaaS.

Necesario:

- `/api/v1/health`;
- operadores admin únicamente, no cuentas de usuarios finales;
- roles mínimos `admin` / `editor` si realmente hay más de una persona;
- rate limiting;
- HTTPS en entornos reales;
- app/env diagnostics sin secretos;
- tests server.

No necesario:

- registro público;
- login móvil;
- sync de vehículos;
- perfiles de conductores;
- guardar GPS;
- guardar documentos.

### B01 — Dataset registry + publisher

Objetivo: que una persona pueda mantener datos críticos sin editar la APK.

Modelo KISS propuesto:

#### `datasets`

- id/key
- title
- schema_version
- enabled
- current_version nullable
- timestamps

#### `dataset_releases`

- id
- dataset_key
- version
- status: draft/validated/published/retired
- sha256
- content_encoding nullable
- asset_path
- generated_at
- verified_at
- published_at nullable
- metadata JSON nullable

#### `sources`

- id
- dataset_key
- jurisdiction_id nullable
- title
- url
- authority
- verified_at
- valid_from nullable
- valid_until nullable
- notes nullable

#### `audit_logs`

- id
- actor_id
- action
- subject_type
- subject_id
- metadata JSON
- created_at

No crear una tabla por cada propiedad de cada regla.

## Publisher flow

`Draft → Validate → Build file → Hash → Publish immutable asset → Build manifest → Atomic pointer/version update`

Reglas:

- una release publicada es inmutable;
- una corrección crea nueva versión;
- rollback cambia el pointer/manifest, no edita el archivo ya publicado;
- manifest y assets pueden servirse por CDN;
- la app usa ETag/versioning y no golpea DB por usuario.

## Distribución

Arquitectura objetivo:

`Admin Laravel → DB maestra → Publisher → object/static storage → CDN → app`

No:

`app → SQL → DB` para reglas estáticas.

## Manifest

El backend debe producir el contrato ya consumido por C05, no inventar uno nuevo.

Responsabilidades:

- schemaVersion compatible;
- minAppVersion;
- datasets con version/url/sha256/contentEncoding/expiresAt;
- feature flags únicamente cuando C28 los conecte.

## B02 — Cameras / road datasets

Antes de C16/C19 productivos:

- source traceability;
- regional packs;
- camera IDs estables;
- lat/lng;
- dirección/corredor/rumbo cuando exista;
- tipo;
- speed limit solo si verificado;
- source + verified_at;
- confidence/verification status;
- pack/version.

No usar backend en hot path durante conducción.

## B03 — Routes/Places proxy

Solo cuando Viaje lo necesite.

Responsabilidades:

- proteger API key del proveedor;
- normalizar request/response mínimo;
- cache donde aporte;
- rate limiting;
- timeout;
- partial failure;
- no persistir rutas personales por defecto.

No crear un microservicio: controller/service concreto dentro del monolito Laravel.

## B04 — Admin mínimo

El panel debe resolver tareas, no ser un ERP.

Pantallas iniciales:

1. Datasets.
2. Releases.
3. Sources.
4. Validate/publish.
5. Audit log.

Después:

- cameras;
- tolls;
- services;
- legal templates;
- reports.

## B05 — Urgent invalidation

FCM/push solo si hace falta acelerar una corrección urgente.

Push NO lleva el dataset completo.

Mensaje conceptual:

`dataset restrictions changed → trigger sync`

La app sigue validando manifest/hash.

## B06 — Hardening

Antes de producción:

- admin 2FA;
- rate limits;
- least privilege DB;
- backups;
- restore drill;
- sanitized logs;
- no PII en observability;
- CSP/secure headers panel;
- release audit trail;
- publisher idempotency;
- rollback test.

## Qué NO se debe guardar

No almacenar en servidor por defecto:

- placa de cada usuario;
- garaje personal;
- SOAT manual guardado;
- RTM manual guardada;
- seguro personal;
- documentos;
- ubicación exacta;
- viajes;
- historial de cámaras vistas;
- preferencias personales.

## KISS database rules

Antes de crear una tabla preguntar:

1. ¿Es fuente maestra dinámica?
2. ¿Debe ser consultada/actualizada por operadores?
3. ¿No cabe mejor como JSON versionado?
4. ¿No puede derivarse?
5. ¿Existe una query real que justifique el índice?

Índices iniciales solo donde haya consultas reales:

- `dataset_releases(dataset_key, status)`;
- `dataset_releases(dataset_key, version)` unique;
- `sources(dataset_key, jurisdiction_id)` si el publisher consulta por ambos;
- `audit_logs(created_at)` y actor si el panel lo requiere.

No indexar cada columna “por si acaso”.

## Orden recomendado en paralelo

Mientras Flutter recupera UI:

1. B00 foundation.
2. B01 registry/publisher.
3. publicar el dataset restrictions piloto mediante el mismo contrato C05/C10.
4. cuando C16 se acerque, B02 cameras.
5. cuando C21/C22 se acerque, B03 routes proxy.

Así backend avanza sin bloquear ni contaminar el hot path móvil.
