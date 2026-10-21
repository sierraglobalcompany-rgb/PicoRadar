# Lot EF National Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver truthful national Tramites, Pico, camera, and toll coverage from the repository's audited assets.

**Architecture:** Reuse the territorial authority inventory as the canonical Tramites identity source, add typed adapters and explicit status metadata, and keep descriptive coverage separate from runtime rule eligibility. Bind camera and toll assets to deterministic manifests and show their provenance without changing Driving.

**Tech Stack:** Flutter 3.47, Dart 3.13, Riverpod, JSON assets, Python standard-library validation.

**Spec:** `docs/superpowers/specs/2026-09-19-lot-ef-national-coverage-design.md`

## Global Constraints

- Do not modify Driving, Wallet, Home/backend inquiry, or maintenance-owned files.
- Do not add dependencies, network calls, rules, external facts, or renewed dates.
- Existing restriction engine data remains unchanged.
- Unknown never becomes zero, current, verified, or engine-enabled.
- Tests precede production changes and each new behavior is observed failing.

## Review Focus

- Accent-insensitive multi-term authority/municipality/department searches must not hide valid records.
- Pending authorities must never receive a direct procedure URL from inventory membership.
- Source-verified Pico municipalities without rule packs must remain engine-disabled.
- Expired or derogated Pico evidence must not be presented as current.
- Manifest count/hash drift must fail validation instead of silently updating UI claims.

---

### Task 1: Typed National Tramites Catalog

**Files:**
- Create: `mobile/lib/features/tramites/data/tramites_catalog.dart`
- Modify: `mobile/lib/features/comparendos/data/territorial_catalog.dart`
- Modify: `mobile/lib/features/tramites/presentation/tramites_screen.dart`
- Create: `mobile/test/features/tramites/data/tramites_catalog_test.dart`
- Modify: `mobile/test/features/tramites/presentation/tramites_screen_test.dart`

**Interfaces:**
- Consumes: `TerritorialCatalog`, its 769 authorities, summary, sources, and RUNT fallback.
- Produces: `TramitesCatalog`, `TramitesAuthority`, `TramitesProcedure`, and national search/status UI.

- [ ] Add failing data tests for exact counts, normalized search, two direct-link authorities, five institutional fallbacks, and 762 RUNT fallbacks.
- [ ] Run the data tests and confirm failures are caused by the missing typed adapter.
- [ ] Implement catalog metadata retention and the typed Tramites adapter.
- [ ] Run the data tests green.
- [ ] Replace the two-city selector with national search/list/details while preserving the reviewed Bogota/Medellin procedure flows.
- [ ] Add widget tests for verified links, pending copy, institutional/RUNT fallback, and source counts; observe red then green.

### Task 2: Pico 73 Municipality Operational Matrix

**Files:**
- Modify: `mobile/assets/catalogs/pico_jurisdiction_catalog_v1.json`
- Modify: `mobile/lib/features/pico_placa/data/pico_jurisdiction_catalog.dart`
- Modify: `mobile/test/features/pico_placa/data/pico_jurisdiction_catalog_test.dart`
- Create: `docs/data/PICO_73_OPERATIONAL_AUDIT_20260919.csv`
- Create: `docs/data/PICO_73_OPERATIONAL_AUDIT_20260919.md`

**Interfaces:**
- Consumes: workbook `Estado_al_corte`, source cutoff 2026-09-10, runtime restriction asset.
- Produces: 73 typed records with `operationalStatus`, `engineEnabled`, evidence summary, source IDs/URLs, and explicit cutoff.

- [ ] Add failing tests for 73 unique municipalities, status counts 6/36/2/29, exact representative rows, and 5 engine-enabled municipalities.
- [ ] Run tests red against the 16-row catalog.
- [ ] Replace the catalog with the deterministic 73-row reconciliation and strict parser validation.
- [ ] Run tests green and confirm the restriction runtime asset is byte-for-byte unchanged.

### Task 3: Camera And Toll Manifests And Status UI

**Files:**
- Modify: `mobile/assets/datasets/cameras/cameras_manifest_v1.json`
- Create: `mobile/assets/catalogs/tolls_manifest_v1.json`
- Create: `mobile/lib/features/fotomultas/data/camera_dataset_manifest.dart`
- Create: `mobile/lib/features/trip/data/toll_dataset_manifest.dart`
- Modify: `mobile/lib/features/fotomultas/presentation/fotomultas_screen.dart`
- Modify: `mobile/lib/features/fotomultas/presentation/national_department_view.dart`
- Modify: `mobile/lib/features/trip/presentation/trip_route_preview_map.dart`
- Create: `mobile/test/features/fotomultas/data/camera_dataset_manifest_test.dart`
- Create: `mobile/test/features/trip/data/toll_dataset_manifest_test.dart`
- Modify: focused Fotomultas/Trip widget tests.

**Interfaces:**
- Consumes: existing camera pack, toll inventory, and toll tariff assets.
- Produces: strict manifest models and honest provenance/status labels.

- [ ] Add failing manifest tests for exact hashes, counts, distributions, and unknown fields.
- [ ] Run tests red because the strengthened/new manifests and models do not exist.
- [ ] Add manifests and typed readers without changing Driving.
- [ ] Run manifest tests green.
- [ ] Add failing UI tests proving snapshot/unknown language and no zero/current inference.
- [ ] Implement the compact status copy in Fotomultas and Viaje and run widget tests green.

### Task 4: Deterministic Validation Audit And Handoff

**Files:**
- Create: `scripts/validate_national_coverage.py`
- Create: `docs/data/NATIONAL_DATA_PROVENANCE_AUDIT_20260919.md`
- Create: `codex/LOT_EF_NATIONAL_COVERAGE_HANDOFF.md`

**Interfaces:**
- Consumes: committed catalogs, audit CSV, manifests, and source assets.
- Produces: one deterministic validation command and complete lot evidence.

- [ ] Add validator expectations for all requested counts, hashes, statuses, source URLs, and engine isolation; run against an intentionally incomplete state and observe failure.
- [ ] Complete the audit artifacts and make the validator pass.
- [ ] Run focused format, tests, analyzer, validator, and `git diff --check`.
- [ ] Perform a final branch review, record unresolved editorial gaps, and commit all scoped files locally without push or merge.
