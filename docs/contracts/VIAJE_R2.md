# VIAJE-R2 contract

Authority: `PicoRadar_VIAJE_R2_DATOS_MOCKUP_KISS.zip` (2026-09-05). This contract extends `VIAJE_R1.md`; it does not authorize provider access, spending, public deployment, D02, live navigation, GPS, background work, voice, or proximity alerts.

## Workflow and UI

### Owner toll/UX correction (2026-09-08)

The map-first result uses one route-local pricing result for the summary, alternatives, passage list and map detail. Category I is the ordinary car estimate; Los Santos uses its explicit AUTOMOVIL source code. Other operator categories are consultation-only per station, with source descriptions or an explicit missing-description label. They do not change the garage vehicle or authorize heavy-vehicle routes.

Nominal amounts remain inspectable. Unresolved directional groups (Oriente, La Linea, Garzones), Los Santos collection conditions, suspensions, blocked records and inconsistent base/multiplier amounts stay outside the estimate with a visible pending reason. No automatic interpretation of legal prose. Empty candidates do not prove a free route. Ordinary repeated passages retain separate estimates.

The route sheet filters only selected-route passages and updates when asynchronous local pricing arrives. Missing local data never becomes an endless loading claim. General caveats, checklist and source metadata live under collapsed Informacion importante; errors, partial costs and restriction statuses stay visible.

City Pico links use a transient jurisdiction without changing global preferences. Unknown explicit cities do not fall back to a different city. Without departure time, including today, origin retains day evaluation and destination arrival remains undetermined. The existing preview validator accepts date-only today through day 30; it still rejects past dates. An unavailable local inventory never removes valid route geometry; its counts and costs remain explicitly unknown.

This correction adds no provider, endpoint, dependency, permission or schema migration. The private engine remains a car-route pilot.

Viaje remains one portrait phone page: preparation, explicit preview CTA, result summary, vertical alternatives, pre-trip map, restrictions/toll disclosures, and external Google Maps/Waze handoff. A successful request reveals its result once. Rebuilds, route selection, local restriction refresh, cancellation, stale responses, offstage completion and user interaction do not repeat or steal that reveal. Reduced motion, keyboard focus, 360x780/800, 390x844 and 412x915 at text scales 1.0/1.5/2.0 are required.

## Route geometry

Each route carries bounded GeoJSON or polyline6 decoded as immutable ordered latitude/longitude coordinates. GeoJSON transport order is `[longitude, latitude]`. The private-pilot bounds are two to 50,000 points and 524,288 response bytes. Missing, malformed, non-finite or entirely zero-length geometry is unavailable; no straight-line fallback is permitted. Geometry reuses the existing provider response and does not make a second route call or persist a trip.

## Local associations

The selected route is projected against local toll/camera coordinates with a documented deterministic corridor. Results retain cross-track and along-route distance, stable ordering and separate repeated passes. Adjacent usable segments are one passage even when zero-length vertices occur between them. Physical location count and candidate-passage count remain separate.

The toll dataset contains 184 physical locations and 1,288 null tariff cells. It proves neither active charge events nor current prices/free passage. Historical non-operating locations are hidden by default behind an explicit layer. Camera data reuses the existing 360-record ANSV pack; coordinate proximity alone is always `nearbyUnconfirmed`, never confirmed road, carriageway or direction.

## Data and sync

National restriction preparation accounts one-to-one for 219 vehicle coverages, 261 dated rows, 73 rotation/validity rows and 74 explicit `NO PUBLICAR` rows. R2C reviews six priority coverages through a versioned, fail-closed decision input; none currently satisfies the complete legal, source and runtime-schema gates, so all remain quarantined or informational and publish zero new runtime rules. Downloaded snapshots are bounded, SHA-256 bound to `dataset_versions`, atomically activated/rolled back and recover after an unusable local snapshot plus ETag/304. The restriction release is exercised through the real HTTP sync, Drift importer and `RestrictionEngine` in tests.

## Map and external gates

The map supports route/start/end, local toll/camera layers, pan, pinch, zoom, reframe, marker details and fullscreen. Tile failure retains vector/list data and offers bounded retry. Tile network access is off by default until provider/license compatibility is explicitly approved. Tests use no public tile traffic and their fixtures carry the visible label `DATOS DE PRUEBA - NO ES UN PLAN REAL`. A zero-money provider trial remains OFF by default and requires explicit free-access confirmation, authorization, license, key, positive non-money quotas and an unexpired deadline. Live TollGuru access, quota, price, license, Colombian route/tariff matrix and physical end-to-end provider validation remain external blockers; the PR stays draft and the lot remains `PARTIAL_DATA_REVIEW_AND_PROVIDER_ACCESS` until those gates close.
