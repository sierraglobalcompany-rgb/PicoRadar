# B01 — Dataset Registry + Publisher

## Goal

Publicar datasets versionados consumibles por C05 sin editar APK y con rollback.

## Depends on

- B00
- contracts C05 manifest

## Scope IN

Tablas KISS:

- datasets
- dataset_releases
- sources
- audit_logs

No más salvo necesidad demostrada.

## Required operations

- create/update dataset metadata;
- create draft release;
- validate release;
- calculate SHA-256;
- mark validated;
- publish immutable asset;
- generate manifest-compatible entry;
- retire/rollback pointer to prior release;
- audit operator/action.

## Contracts

NO inventar contrato nuevo.

Publisher debe producir exactamente lo que `DatasetSyncService` entiende:

- version
- url
- sha256
- contentEncoding optional
- expiresAt optional

Manifest conserva schemaVersion/minAppVersion/features según contrato existente.

## Storage/CDN

Adapter concreto mínimo:

- local filesystem para dev/tests;
- production path configurable para storage/CDN deployment.

No crear storage abstraction zoo. Una frontera concreta pequeña es suficiente porque filesystem/CDN sí es proveedor intercambiable real.

## Data quality

Cada release crítica debe tener:

- sources;
- verified_at;
- validity metadata;
- schema validation;
- duplicate ID validation cuando aplique.

## Immutability

Published release:

- no edit;
- fix = new version;
- rollback = pointer/manifest to previous release.

## Tests

- draft → validate → publish;
- invalid release no publish;
- SHA correct;
- manifest contract;
- immutable published release;
- rollback;
- audit event;
- two operators cannot create inconsistent current pointer;
- idempotent publish retry.

## Scope OUT

- UI admin sofisticada;
- camera editor;
- n8n;
- AI data extraction;
- FCM.

## Acceptance

El restrictions pilot puede pasar por publisher y generar un manifest/asset compatible con la app actual sin cambiar código móvil.
