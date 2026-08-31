# Pico Jurisdiction Catalog V1

Source: `docs/data/PICO_JURISDICTION_COVERAGE_AUDIT_20260830.md`.

Asset: `mobile/assets/catalogs/pico_jurisdiction_catalog_v1.json`.

Count: 15 records.

Meaning: this is a local UI catalog of Colombian jurisdictions researched for
Pico y Placa coverage. It is not a runtime rule dataset and it is not a list of
all Colombian municipalities.

Filter: cities and metropolitan jurisdictions represented in the 2026 coverage
audit, using the audit's classification per row. The audit itself separates this
scope from the broader RUNT/Datos Abiertos registration-city catalog.

Runtime support: only jurisdictions with local restriction rules loaded by the
app are selectable as `Disponible`. Other catalog records remain visible as
`Próximamente` until a future approved lot encodes and verifies their rules.

P03 policy: unsupported catalog records are disabled in the selector. The app
does not invent restriction windows, digits, categories, notifications or source
claims for those records.
