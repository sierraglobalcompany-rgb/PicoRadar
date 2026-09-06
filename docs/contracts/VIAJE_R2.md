# VIAJE-R2 contract

Authority: `PicoRadar_VIAJE_R2_DATOS_MOCKUP_KISS.zip` (2026-09-05). This contract extends `VIAJE_R1.md`; it does not authorize provider access, spending, public deployment, D02, live navigation, GPS, background work, voice, or proximity alerts.

## Workflow and UI

Viaje remains one portrait phone page: preparation, explicit preview CTA, result summary, vertical alternatives, pre-trip map, restrictions/toll disclosures, and external Google Maps/Waze handoff. A successful request reveals its result once. Rebuilds, route selection, local restriction refresh, cancellation, stale responses, offstage completion and user interaction do not repeat or steal that reveal. Reduced motion, keyboard focus, 360x780/800, 390x844 and 412x915 at text scales 1.0/1.5/2.0 are required.

## Route geometry

Each route carries one bounded GeoJSON LineString decoded as immutable ordered latitude/longitude coordinates. Transport order is `[longitude, latitude]`. Two to 3,000 points and the existing 262,144-byte mobile response ceiling apply. Missing, malformed, non-finite or entirely zero-length geometry is unavailable; no straight-line fallback is permitted. Geometry reuses the existing provider response and does not make a second route call or persist a trip.

## Local associations

The selected route is projected against local toll/camera coordinates with a documented deterministic corridor. Results retain cross-track and along-route distance, stable ordering and separate repeated passes. Adjacent usable segments are one passage even when zero-length vertices occur between them. Physical location count and candidate-passage count remain separate.

The toll dataset contains 184 physical locations and 1,288 null tariff cells. It proves neither active charge events nor current prices/free passage. Historical non-operating locations are hidden by default behind an explicit layer. Camera data reuses the existing 360-record ANSV pack; coordinate proximity alone is always `nearbyUnconfirmed`, never confirmed road, carriageway or direction.

## Data and sync

National restriction preparation accounts one-to-one for 219 vehicle coverages, 261 dated rows, 73 rotation/validity rows and 74 explicit `NO PUBLICAR` rows. All remain quarantined or informational and publish zero new runtime rules. Downloaded toll snapshots are bounded, SHA-256 bound to `dataset_versions`, atomically activated/rolled back and recover after an unusable local snapshot plus ETag/304.

## Map and external gates

The map supports route/start/end, local toll/camera layers, pan, pinch, zoom, reframe, marker details and fullscreen. Tile failure retains vector/list data and offers bounded retry. Tile network access is off by default until provider/license compatibility is explicitly approved. Tests use no public tile traffic. Live TollGuru access, quota, price, license, Colombian route/tariff matrix and physical end-to-end provider validation remain external blockers; the PR stays draft and the lot remains `PARTIAL_WAITING_PROVIDER_ACCESS` until those gates close.
