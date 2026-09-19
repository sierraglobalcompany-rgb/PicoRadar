# Lot EF National Coverage Design

## Purpose

This lot makes national data coverage visible without converting historical,
partial, expired, or unverified evidence into operational claims. It covers the
Tramites authority catalog, the 73-municipality Pico source inventory, and the
provenance/status surfaces for the existing camera and toll assets.

## Scope Boundaries

- Do not modify `mobile/lib/features/driving`, Wallet, Home, backend inquiry,
  maintenance, or their tests.
- Do not add network calls, packages, rules, renewal dates, or external facts.
- Keep the existing restriction engine datasets unchanged. Catalog coverage is
  descriptive; it cannot enable an affirmative engine result.
- Use only repository evidence already audited as of the stated source cutoff.

## Tramites

`comparendos_authorities_v1.json` remains the canonical 769-entry identity and
provenance inventory. A typed Tramites adapter consumes that catalog and exposes
its version, source counts, authority/municipality/department search, fallback
destination, and procedure evidence.

Bogota and Medellin retain the four direct procedure links already present in
the approved Tramites screen. Their links are represented as reviewed entries
with an evidence date. Every other authority is `pending`: the UI says
`Por confirmar`, opens a previously reviewed institutional page only when the
territorial catalog already proves it, and otherwise offers the official RUNT
actor directory. Inventory presence never proves registration capability.

Coverage displayed to users and tests is: 769 inventory entries, 1,003 source
rows, 7 individually reviewed authorities, 2 authorities with reviewed direct
procedure coverage, 5 reviewed institutional-only entries, and 762 pending
entries.

## Pico Coverage

The 73 municipality rows in
`PicoRadar_Pico_y_Placa_Colombia_CONSOLIDADO_2026-09-10.xlsx` are represented in
the versioned catalog with four operational statuses:

- `verified`: an audited category is marked `SI`, remains within an explicit
  date boundary when one exists, and is not a documented derogation.
- `expired`: the only affirmative evidence ended before 2026-09-19 or documents
  a derogated regime.
- `conditional`: at least one category is explicitly conditioned and the city
  has no active verified category.
- `pending`: no category supports an affirmative or conditional operational
  claim.

The resulting counts are 6 verified, 36 conditional, 2 expired, and 29 pending.
`engineEnabled` is independent and true only for the 5 municipalities with an
existing active verified runtime rule pack: Bogota, Medellin, Bucaramanga,
Popayan, and Villavicencio. Itagui is source-verified but has no rule pack.
Manizales is expired. Barranquilla has no affirmative runtime rule.

## Camera And Toll Provenance

The camera manifest continues to bind the 360-record ANSV snapshot to its hash,
source, and 293 known speed values. It additionally states the 67 unknown-speed
records, 13 represented departments/territories, operation-status distribution,
and that the snapshot is not a claim of present operation.

A toll manifest binds the 184-station inventory and 184-station tariff catalog
to exact hashes and the existing audited counts. It records 180 inventory-only
operation states, 1 source-reported operating state, 2 historical non-operating
states, 1 damaged/review state, 1,007 numeric general rates, 793 official-source
general rates, 214 secondary-source general rates, and 437 special rates. Missing
amounts remain unknown; inventory presence never means current operation.

Fotomultas and Viaje display compact source/status language derived from these
facts. Zero is shown only when the source explicitly documents zero; missing
coverage is never rendered as zero or current.

## Validation And Evidence

Flutter tests validate typed parsing, search, fallback selection, exact coverage
counts, engine isolation, manifests, hashes, and status copy. A deterministic
repository validator checks the JSON/CSV audit matrices and asset hashes using
only Python's standard library. Markdown audit matrices document every mapping,
source, limitation, and unresolved editorial gap.
