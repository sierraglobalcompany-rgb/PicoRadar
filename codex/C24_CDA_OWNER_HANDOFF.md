# C24 CDA owner map handoff

Date: 2026-09-15
Branch: `codex/cda-owner-map`
HEAD: `ddf60407174e3ee8d447b7eff3ca45e0fd983789`

## Changed

- Replaced the old CDA infinite/first-40 list with a new owner flow:
  - home page with search, Cerca de mi, Explorar mapa, Directorio RUNT and source access;
  - directory with empty initial state, search, territory filters, compatibility filters, continuous `ListView.builder` and shared detail sheet;
  - map/list implementation over the approved 866-site operational geography;
  - shared source/details sheets with explicit external actions.
- Added CDA geography contract for the operational 866-site dataset:
  - 866 owner-provided rows carry address evidence from `CDA_Colombia_FINAL_866_UBICADOS_2026-09-15.xlsx`;
  - 864 rows were geocoded from the owner-provided address and 2 rows kept owner-provided verified coordinates;
  - map, near-me, spatial query and details now operate only over those 866 eligible sites;
  - the remaining 98 historical RUNT inventory rows stay reported as pending enrichment and are not included in operational counts.
- Added spatial query/grouping logic and tests using fixture geodata.
- Added local import tool `mobile/tool/import_cda_geography.mjs` for an authorized address/coordinate CSV.
- Added owner Excel converter `codex/convert_owner_cda_xlsx_to_import_csv.py`.
- Added differentiated geography states:
  - `address_verified`: address evidence only, not map-eligible;
  - `geocoded`: address plus generated coordinate, map-eligible with approximate-location copy;
  - `verified`: coordinate accepted from owner/source evidence, map-eligible.
- Added ArcGIS geocoding script and reproducible outputs:
  - `codex/geocode_cda_owner_locations.py`;
  - `codex/cda_owner_locations_20260915_geocoded.csv`;
  - `codex/cda_owner_locations_20260915_geocode_cache.json`;
  - `codex/cda_owner_locations_20260915_geocode_audit.json`.
- Added/updated audit artifacts:
  - `codex/C24_CDA_GEODATA_AUDIT.md`;
  - `codex/cda_geography_coverage.csv`.
  - `codex/cda_owner_locations_20260915_import.csv`;
  - `codex/cda_owner_locations_20260915_audit.json`.

## Data decision

Google Search/Maps business panels were not copied into the app dataset.
The owner-provided workbook was accepted as the editorial source for the 866
operational records, then geocoded through ArcGIS World Geocoding Service.
Acceptable enrichment routes for the remaining 98 are:

1. authorized RUNT/manual editorial export for address/phone plus permitted geocoding;
2. CDA-owned pages or official publications as primary evidence per sede;
3. InfoCDA/CDAS/RTM only as secondary discovery or cross-check unless reuse terms explicitly allow redistribution.

The current app remains truthful: the functional CDA universe is 866 sites with
address and coordinate. Generated coordinates show "Ubicacion aproximada desde
direccion" in the detail sheet when applicable. The imported workbook leaves 98
historical inventory IDs missing; those are exposed in source/update surfaces as
pending and no longer block map/near-me for the 866. The import evidence date
was set to `2026-09-14`, matching the Mi A3 date used for QA, so the app does
not reject the owner data as future evidence.

## Verification

- `flutter analyze`: pass.
- `flutter test test/features/cda --no-pub --reporter expanded`: 89 tests pass.
- `node mobile/tool/audit_cda_geography.mjs --check`: 964 inventory rows, 866 address-verified rows, 864 geocoded rows, 2 externally verified rows, 866 map-eligible rows, 98 pending rows, hard gate true for the operational dataset.
- `node mobile/tool/audit_cda_geography.mjs --check`: pass.
- `python codex/convert_owner_cda_xlsx_to_import_csv.py`: 866 import rows, 98 missing IDs, 0 duplicates, 0 unknown IDs.
- `python codex/geocode_cda_owner_locations.py`: 866 geocoded rows, 0 failures, 0 low-score rows.
- `node mobile/tool/import_cda_geography.mjs ../codex/cda_owner_locations_20260915_geocoded.csv assets/catalogs/cda_geography_v1.json --allow-partial`: pass, `approved=true`.
- `flutter build apk --release --flavor dev --dart-define=APP_ENV=dev`: pass.

## APK

Path: `mobile/build/app/outputs/flutter-apk/app-dev-release.apk`
SHA-256: `3D016EA8AAD669BAA89F322BF8525177E266702DAB256A83E1C341BDF9947597`
Installed on Mi A3 with: `adb -s 116f2191b19a install -r build\app\outputs\flutter-apk\app-dev-release.apk`
Install result: `Success`

Physical screenshots:

- Previous screenshots before owner Excel integration:
  - `C:\Users\felip\AppData\Local\Temp\cda-home-after-address-gate-20260914.png`
  - `C:\Users\felip\AppData\Local\Temp\cda-gate-after-address-gate-20260914.png`
- New physical screenshots after owner Excel date fix:
  - `C:\Users\felip\AppData\Local\Temp\cda-home-fixed-phone.png`
  - `C:\Users\felip\AppData\Local\Temp\cda-source-fixed-phone.png`
- Final operational screenshots after geocoding/map enablement:
  - `C:\Users\felip\AppData\Local\Temp\cda-final-home.png`
  - `C:\Users\felip\AppData\Local\Temp\cda-operational-source.png`
  - `C:\Users\felip\AppData\Local\Temp\cda-operational-map.png`
  - `C:\Users\felip\AppData\Local\Temp\cda-final-nearby-map.png`
  - `C:\Users\felip\AppData\Local\Temp\cda-final-nearby-list.png`

Physical notes:

- Home shows `866 CDA disponibles`; Cerca de mi and Explorar mapa are active.
- Source sheet states `866 CDA con direccion y coordenada para mapa` and `98 registros pendientes`.
- Explorar mapa opens OSM with CDA clusters over Colombia.
- Cerca de mi now opens directly in map mode, centered on the device location, with list still available as an alternate view.
- List mode no longer shows OSM attribution over the results.

## Risks / pending

- The map is enabled for 866 operational CDA; most coordinates are generated from addresses and must be presented as approximate.
- 98 inventory IDs are absent from the owner workbook and remain pending outside the current operational flow.
- RUNT/SIMIT scraping remains prohibited by repository policy; use authorized export/manual editorial import or another permitted provider.
- Public OSM tiles require policy review before production volume; the implementation uses feature-scoped tile provider and attribution.

## Git status note

The worktree contains extensive preexisting WIP from other lots. This handoff identifies only the CDA slice and does not merge or clean unrelated files.
