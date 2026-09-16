# C24 CDA geography source audit

Review date: **2026-09-15**. Status: **owner 866-site operational geography integrated; map/cerca ENABLED for the operational dataset**.

## Decision and operational gate

No reusable source containing both operational CDA sede identity and coordinates
was confirmed during the initial bounded investigation. This is a finding about the
sources and surfaces inspected, NOT proof that such data does not exist.

The final owner decision for this iteration changes the functional universe:
**the app operates on the 866 CDA supplied with address evidence**, while the
remaining 98 historical RUNT inventory IDs are reported as pending enrichment
and stay outside map/cerca/directorio results for now.

Current accepted coverage is **866 operational CDA**, made of **864 geocoded
from address** rows and **2 owner-verified coordinate** rows. Generated
coordinates are map-eligible but must be labelled as approximate. An
address-only match, a municipality centroid, a map on a website, or the
inventory's `sourceVerifiedAt` still must not satisfy map eligibility.

The parent owns application/model/gate implementation. This sidecar changes
only this audit, `mobile/tool/audit_cda_geography.mjs` and its generated
`codex/cda_geography_coverage.csv`. It neither enables nor tests app behavior.

## Scope and method

Read worktree `AGENTS.md`, `codex/lots/C24_SERVICES_CDA_DIRECTORY.md`, the
handoff template and the CDA statements in `docs/CURRENT.md`. No product
behavior or baseline requirements were changed; this is not closure of C24.

Methods: parse the complete local JSON; inspect official public web pages,
published certificate text, public Socrata catalog/schema metadata and a public
ArcGIS catalog; visually inspect the linked Power BI report. External source
review was selective. There was **no individual external location verification
of all 964 businesses**, no bulk certificate download and no coordinate import.
The CSV is exhaustive only with respect to available fields in the local asset.

No RUNT/SIMIT scraping, CAPTCHA bypass, Google Maps scraping, mass Nominatim
geocoding, paid provider, external outreach or new dependency was used.

## Owner Excel and geocoding integration, 2026-09-15

The owner supplied `C:/Users/felip/Downloads/CDA_Colombia_FINAL_866_UBICADOS_2026-09-15.xlsx`.
It was treated as an owner-provided editorial import, not as an automated Google
or RUNT scraper.

Conversion command:

```text
python codex/convert_owner_cda_xlsx_to_import_csv.py
```

Generated artifacts:

- `codex/cda_owner_locations_20260915_import.csv`
- `codex/cda_owner_locations_20260915_audit.json`

Import command from `mobile/`:

```text
node tool/import_cda_geography.mjs ../codex/cda_owner_locations_20260915_import.csv assets/catalogs/cda_geography_v1.json --allow-partial
```

Import result:

| Measurement | Result |
| --- | ---: |
| Catalog inventory | 964 |
| Workbook rows | 866 |
| Imported rows | 866 |
| Duplicate IDs | 0 |
| Unknown IDs | 0 |
| IDs absent from workbook | 98 |
| Rows with address evidence | 866 |
| Rows with valid coordinates | 2 |
| Asset approved for map/cerca before geocoding | false |

Geocoding command:

```text
python codex/geocode_cda_owner_locations.py
```

Generated artifacts:

- `codex/cda_owner_locations_20260915_geocoded.csv`
- `codex/cda_owner_locations_20260915_geocode_cache.json`
- `codex/cda_owner_locations_20260915_geocode_audit.json`

Geocoding/import result:

| Measurement | Result |
| --- | ---: |
| Operational rows | 866 |
| Geocoded from address | 864 |
| Owner-verified coordinate rows | 2 |
| Geocoding failures | 0 |
| Low-score rows below threshold | 0 |
| Map-eligible rows | 866 |
| Historical inventory rows pending | 98 |
| Asset approved for map/cerca | true |

The app may display imported addresses in CDA detail/source surfaces and may
enable map, near-me, distance and navigation for the 866 map-eligible rows.
Rows with `status=geocoded` must display the precision note "Ubicacion
aproximada desde direccion." The 98 missing IDs remain explicit pending work;
they were not silently removed from the historical inventory.

## Post-audit source update

Two additional public web surfaces were reviewed during follow-up:

- RUNT actor directory: https://www.runt.gov.co/directorio-de-actores?tipo=3
- CDA directory references supplied by the owner:
  https://rtm.cdas.co/ and https://infocda.com.co/

The RUNT web directory appears to expose CDA identity fields together with
address/phone for individual records. That makes it a useful official
reconciliation target for sede identity and contact data, subject to the
project invariant that forbids RUNT/SIMIT scraping. The acceptable path is an
authorized/exportable source or a manual/legal editorial import with preserved
evidence, not an automated app-side scraper.

The CDA directory references are useful as secondary discovery surfaces and
cross-checks, especially when they point back to the official RUNT directory or
to a CDA's own publication. They are not, by themselves, accepted as the sole
authority for offline coordinates in PicoRadar. A future enrichment pass must
record source URL, review date, match basis and license/permission for each
accepted field.

Google Search/Maps business panels were explicitly rejected as a source for a
stored offline CDA coordinate dataset rendered on OSM. Public visibility does
not grant the right to extract and redistribute those business/place facts, and
Google Maps Platform policy restricts long-term storage or use of its derived
coordinates/content outside Google surfaces. The owner may independently obtain
or license data, but Codex will only ingest a table whose permitted use is clear
or whose fields are backed by primary/authorized evidence.

## Import path prepared in the app

`mobile/tool/import_cda_geography.mjs` now defines the enrichment contract for
the next data pass. It accepts an authorized CSV and writes a geography JSON
compatible with `mobile/assets/catalogs/cda_geography_v1.json`. It supports an
intermediate `address_verified` status for rows with address + evidence but no
coordinate yet, and a `geocoded` status for address-derived coordinates.
`geocoded` and `verified` rows are map-eligible. Required headers:

`cdaId,catalogName,municipality,departmentCode,status,latitude,longitude,address,phone,web,locationSourceUrl,locationReviewedAt,contactSourceUrl,contactReviewedAt,vehicleTypes,compatibilitySourceUrl,compatibilityReviewedAt,locationMethod,locationScore`

The script reconciles by current catalog ID, preserves official catalog names
from the RUNT-derived asset, rejects duplicate/unknown IDs, requires location
evidence for `address_verified`, `geocoded` and `verified` rows, requires
coordinates for `geocoded` and `verified`, and approves the asset when every
imported operational row is map-eligible. Missing historical IDs are reported
as pending instead of blocking the 866-site operational flow. This makes three
source routes viable without app changes:

1. authorized RUNT/manual editorial export for address/phone, followed by a
   permitted geocoding provider;
2. CDA-owned pages or official publications used as primary evidence per sede;
3. secondary directories such as InfoCDA/CDAS only as discovery or cross-check,
   unless their reuse terms explicitly allow redistribution of the field.

## Inventory evidence

Input: `mobile/assets/catalogs/cda_catalog_v1.json`, schema 1, dataset `epfm-5fhb`.

| Measurement from parsing the asset | Result |
| --- | ---: |
| Entries / unique IDs | 964 / 964 |
| Department labels | 30 |
| Distinct municipality names | 211 |
| Distinct (department, municipality) pairs | 213 |
| Distinct NIT values | 853 |
| NIT values shared by multiple IDs | 64 |
| Source period of every entry | 2026-07 |
| Entries with address or coordinate fields | 0 |
| Accepted address evidence after owner import | 866 |
| Geocoded coordinate rows after owner import | 864 |
| Owner-verified coordinate evidence after owner import | 2 |
| Map-eligible operational rows | 866 |
| Historical inventory rows pending enrichment | 98 |

The 211 municipality metric in the asset counts names; 213 counts pairs.
These are different measures, not evidence of two missing records. The 30
department labels describe this inventory, not completeness across every
Colombian administrative unit.

Every entry has exactly these fields:
`certified`, `department`, `departmentCode`, `generatedAt`, `id`,
`municipality`, `name`, `nit`, `novelty`, `sourceMonth`, `sourceMonthName`,
`sourceVerifiedAt`, `sourceYear`.

The catalog records `sourceVerifiedAt=2026-08-31T21:27:06Z`. This audit does not
validate that historical claim or promote it to location verification.
`certified` is also not evidence of coordinates or a fresh ONAC accreditation
check. Asset metadata describes future source periods being ignored; this
sidecar preserves the July population and does not refresh its source rows.

## Official sources inspected

All observations below have review date 2026-09-14. URLs are plain source
links for reproduction; live data and pages may change after review.

### 1. MinTransporte / datos.gov.co inventory and exports

- Dataset: https://www.datos.gov.co/Transporte/ACTORES-RUNT-POR-MUNICIPIO-Y-DEPARTAMENTO-RUNT2-0/epfm-5fhb
- Metadata inspected by HTTPS GET: https://www.datos.gov.co/api/views/epfm-5fhb.json
- Standard CSV route for a future authorized source refresh, **not downloaded
  or independently reconciled in this audit**: https://www.datos.gov.co/api/views/epfm-5fhb/rows.csv?accessType=DOWNLOAD

Metadata explicitly reports `licenseId=CC_40_BY_SA`, attribution to Ministerio
de Transporte - MinTransporte, and a Creative Commons Attribution Share Alike
4.0 International license link:
https://creativecommons.org/licenses/by-sa/4.0/legalcode

The eleven published columns inspected are `id_empresa`, `nombre_empresa`,
`nit_empresa`, `nombre_municipio`, `codigo_departamento`,
`nombre_departamento`, `tipo_actor`, `mes_nombre`, `a_o`, `certifico`,
`registro_novedad`. No address, latitude, longitude, geometry or location
column exists in this observed schema. Reusable identity inventory is
confirmed; a coordinate source is not. Attribution/share-alike treatment of
a future derived distribution remains to be documented by its owner.

The source's total live row count was not queried. Counts such as 110009
source rows and 21545 CDA rows are asset metadata, not newly verified totals.

### 2. National open-data discovery

Public catalog metadata queries inspected:

- https://api.us.socrata.com/api/catalog/v1?search_context=www.datos.gov.co&q=automotor&limit=100
- https://api.us.socrata.com/api/catalog/v1?search_context=www.datos.gov.co&q=CDA&limit=100
- https://api.us.socrata.com/api/catalog/v1?search_context=www.datos.gov.co&q=ACTORES%20RUNT&limit=100
- https://api.us.socrata.com/api/catalog/v1?search_context=www.datos.gov.co&q=supertransporte&limit=100

Responses returned 98, 11, 7 and 15 catalog results respectively. These
counts refer to search results, not CDA sites or coordinates. Names/column
metadata were inspected; underlying rows of every search hit were not read.
A broader `diagnostico` query returned 413 hits, of which only its first 100
were retrieved; it was dominated by medical datasets and is not an exhaustive
search result review.

Relevant actor result `epfm-5fhb` has no coordinates. `akpq-tuqi` and local
views concern transactions by actor/location, not a sede point directory.
The coordinate-bearing `automotor` results inspected describe accidents or
tourism in Fusagasuga, not CDA sites. Address-bearing results describe Choco
repair businesses or Huila dealers/used-car businesses. The `CDA` acronym
also returns unrelated administrative datasets. None was treated as a CDA
location candidate merely because its title contained a matching word.

This search did not identify a national CDA coordinate export. Search indexing
and naming limitations remain; no claim is made about every datos.gov.co item.

### 3. Supertransporte public CDA dashboard

- Official landing page: https://transformaciondigital.supertransporte.gov.co/index.php/transitotransporte/cda/
- Published description: https://transformaciondigital.supertransporte.gov.co/wp-content/uploads/2024/12/Ficha-Tablero-CDA.pdf
- Power BI URL linked by the official page:
  https://app.powerbi.com/view?r=eyJrIjoiMDM2ZTEzZGItMDYzNS00MjNmLWFhN2UtYjMzMzQ1MDk3ODU2IiwidCI6IjAyZjMzOGMyLTVkZmEtNGNlOS05ZWQxLTJlNmY1NTI0Y2M3NSIsImMiOjR9

The landing page identifies RUNT as the dashboard source. The visible report
page was `Requerimiento RTM`, showing update text `13/09/2026 9:27:05`, a
department choropleth and municipal RTM totals. This is evidence of an
aggregate geographic visualization, not operational-sede coordinates.
No sede-identity/coordinate table or downloadable coordinate export was
confirmed in the inspected interface. No specific dataset reuse license was
confirmed there. Other possible report pages or unexposed export capabilities
were not exhaustively investigated. Accepted coordinate records: zero;
possible underlying coordinate count: unknown.

### 4. Supertransporte observatory and public geographic catalog

- https://transformaciondigital.supertransporte.gov.co/index.php/observatorio/
- Linked StoryMap: https://chamaeleon.supertransporte.gov.co/portalsuper/apps/storymaps/stories/f371b3ff4bd14762bbf892677824db99
- Public StoryMap JSON inspected: https://chamaeleon.supertransporte.gov.co/portalsuper/sharing/rest/content/items/f371b3ff4bd14762bbf892677824db99/data?f=json
- Public catalog query inspected: https://chamaeleon.supertransporte.gov.co/portalsuper/sharing/rest/search?f=json&q=CDA&num=100

The linked story describes road-concession services: service areas, tolls,
weigh stations, transit stops, pedestrian bridges and SOS posts. It was not
evidence of a CDA layer. The public catalog query returned `total=0` without
an error. That result is scoped to the public query, not private layers or
the agency's full holdings. The observatory's open-data links inspected concern
passenger dispatch, port traffic/containers and rail traffic. No reusable CDA
point source was confirmed through these links.

### 5. ONAC published directory and one certificate example

- Directory: https://onac.org.co/directorio-de-acreditados/
- Geography page: https://onac.org.co/directorio-de-acreditados/por-geolocalizacion/
- Public CDA results: https://onac.org.co/directorio3/index.php/buscador/resultado_busqueda_especifica/CDA/0/0/0/0
- One detail inspected: https://onac.org.co/directorio3/index.php/acreditaciones/23-CDA-008
- One published PDF inspected: https://onac.org.co/certificados/23-CDA-008.pdf

The CDA results provide organization, scheme, accreditation code/status and
city. The geography page's inspected HTML/text did not expose a downloadable
sede-coordinate dataset. A map-library reference alone does not establish
coordinate provenance, export availability or reuse rights. The footer's
`Terminos de uso` link was `#`; a dataset-specific open license was not
confirmed. SIPSO terms concern a separate service and were not treated as
the directory's license. A complete interactive geography review was not
completed: the attempted additional browser tab was unavailable to this
sidecar. No Google map data was extracted.

The inspected detail HTML returned HTTP 200 with no latitude/longitude or
coordinate field tokens and no iframe. This observation applies to that
single detail response, not to all ONAC records or dynamically loaded data.

The single example offers a useful candidate identity match to local ID
`22799886` by NIT `901635334`, establishment name and municipality. Its current
detail lists the Toberin establishment address and accreditation expiry in
2031, with renewal in June 2026. The retrieved PDF text instead displays a
2026 expiry and distinguishes a legal-address header from the operational
sede address in its annex. The detail includes multiple inspection-line rows
for one establishment, not multiple sites. No coordinate pair was confirmed
for the example. It remains pending in the matrix.

This demonstrates identity/address evidence opportunities and document
freshness pitfalls. It does not establish 964 matches, address reuse rights,
current accreditation for the whole inventory, or a reusable coordinate feed.

## Reproducible per-ID matrix

Run from the worktree root:

```text
node mobile/tool/audit_cda_geography.mjs
node mobile/tool/audit_cda_geography.mjs --check
```

Node built-ins only; no network or current-clock dependency. Paths resolve
relative to the script. Output uses UTF-8 CSV, quoted/escaped cells, CRLF and
stable source-ID string ordering. Names, municipality, department and IDs are
preserved exactly. The script reads the original asset and writes only the
authorized coverage CSV. `--check` is read-only.

Columns: `id`, `name`, `municipality`, `department`, `status`,
`missing_location`, `missing_evidence`, `inventory_source_url`,
`inventory_source_period`, `inventory_fields_checked_on`,
`location_source_url`, `location_verified_at`, `evidence_scope`.

`missing_evidence` means accepted location provenance is absent, not that no
official identity source exists. Both location evidence columns are empty;
`inventory_fields_checked_on` is 2026-09-14 and is explicitly not a per-sede
external review date. `evidence_scope` is
`inventory_fields_only_no_external_location_verification` for every row.

The generator fails on duplicate/blank IDs, missing identity fields, changed
entry field sets, schema, population, department count, source or period.
New geography must trigger re-review; this script must not silently discard it
or upgrade a record to verified. This CSV is an audit worklist, not an app
geography dataset or a mechanism to pass the gate.

## Next data required and stops

1. Keep the 866-site operational asset as the active CDA universe until the
   owner provides an enriched table for the remaining 98 IDs or a new official
   inventory replaces the denominator through a documented refresh.
2. For each missing ID, require ID/RUNT actor ID where available, NIT, legal and
   establishment name, sede identifier, operational address, municipality and
   department, latitude, longitude, point meaning/precision, source record URL,
   review date, license/terms and any accreditation status with its own
   provenance.
3. Do not reactivate any of the 98 by using municipality centroids, headquarters
   locations for branches, inferred coordinates, copied Google panels, or
   unaudited matching by NIT alone.
4. A later pass may promote `geocoded` rows to `verified` only after reviewing
   each coordinate against stronger evidence. Until then, the app must keep the
   approximate-location copy for generated coordinates.
5. Stop coordinate publication/activation for any new row when identity or
   coordinate evidence is missing, licensing remains unresolved, a source
   requires credentials/CAPTCHA, or address/status conflicts cannot be resolved.
   Preserve pending status and request the missing official/editorial data.

## Handoff

- Lot: C24 CDA operational map enablement.
- Worktree: `C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa/temp/VIAJE-R1-real-planner`.
- Observed branch: `codex/cda-owner-map`.
- Observed HEAD: `ddf60407174e3ee8d447b7eff3ca45e0fd983789`.
- Base branch: not independently established; existing WIP preserved.
- Files changed include CDA geography asset/model/query/presentation/tests,
  import/audit tools, geocoding scripts and generated CDA geodata artifacts.
- Outcome: map and near-me are enabled for the 866 operational CDA, with 98
  historical records disclosed as pending enrichment.
- Tests/verification: commands and results recorded below; all final checks passed.
- Manual QA: public report visual inspection and official source/metadata review;
  no physical sede validation and no complete interactive ONAC map review.
- Physical Android QA: required before final handoff; build/install/captures
  are recorded in `codex/C24_CDA_OWNER_HANDOFF.md`.
- Data/migrations: source inventory unchanged; geography asset regenerated for
  the 866-site operational dataset. No SQLite migration.
- Security/privacy: no user location or private documents processed; no
  credentials requested and no restricted-source collection performed.
- Dependencies: none added.
- Known debt: 98 location/evidence gaps, coordinate precision upgrades for
  geocoded rows, source reuse documentation for future refreshes and evidence
  freshness remain for the parent/data owner.
- Next lot unblocked: manual/authorized enrichment of the remaining 98 and
  later promotion of approximate coordinates to verified where evidence allows.
- Git status: pre-existing shared WIP spans app/tests/server/docs; intentionally
  preserved. Sidecar artifacts remain uncommitted. No commit, merge, staging,
  reset, checkout, branch creation or push performed.

## Verification executed

Node version observed: v24.18.0. Commands run from the worktree root:

| Command | Final result |
| --- | --- |
| `node --check mobile/tool/audit_cda_geography.mjs` | PASS |
| `node mobile/tool/audit_cda_geography.mjs --check` | PASS: 964 inventory rows, 866 address-verified, 864 geocoded, 2 externally verified, 866 map-eligible, 98 pending, hard gate true |
| `python codex/geocode_cda_owner_locations.py` | PASS: 866 rows, 0 failures, 0 low-score rows |
| `node mobile/tool/import_cda_geography.mjs ../codex/cda_owner_locations_20260915_geocoded.csv assets/catalogs/cda_geography_v1.json --allow-partial` | PASS: `approved=true`, 866 map-eligible, 98 missing rows |
| `flutter analyze` | PASS |
| `flutter test test/features/cda --no-pub --reporter expanded` | PASS: 89/89 |
| In-memory Node assertions below | PASS: order, 9 rejection cases, CSV escaping |
| PowerShell CSV round-trip below | Historical sidecar command retained for audit context; no longer the active geography gate |

An initial negative-test fixture renamed the sole Amazonas department label,
which preserved the department count and correctly did not trigger the count
assertion. The fixture was corrected to add a label while retaining the old
department, and the final nine cases passed. This is a count guard, not a
claim that the generator verifies official department identities.

Exact final in-memory validation command (no fixture files written):

```powershell
$validation = @'
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { buildCoverage } from './mobile/tool/audit_cda_geography.mjs';
const c = JSON.parse(fs.readFileSync('mobile/assets/catalogs/cda_catalog_v1.json', 'utf8'));
const base = buildCoverage(c);
const reversed = structuredClone(c);
reversed.entries.reverse();
assert.equal(buildCoverage(reversed).csv, base.csv);
const mutations = [
  x => x.entries[1].id = x.entries[0].id,
  x => x.entries[0].id = '',
  x => x.entries[0].id = 123,
  x => delete x.entries[0].name,
  x => x.entries[0].latitude = 4.5,
  x => x.entries[0].sourceMonth = 8,
  x => x.entries.pop(),
  x => x.source.datasetId = 'other',
  x => x.entries[1].department = 'NEW DEPARTMENT',
];
for (const mutate of mutations) {
  const x = structuredClone(c);
  mutate(x);
  assert.throws(() => buildCoverage(x));
}
const special = structuredClone(c);
const q = String.fromCharCode(34);
special.entries[0].name = 'CDA, ' + q + 'sample' + q + String.fromCharCode(10) + 'sede';
assert.ok(buildCoverage(special).csv.includes(q + special.entries[0].name.replaceAll(q, q + q) + q));
console.log('PASS: deterministic order, 9 rejection cases, CSV comma/quote/newline escaping; no fixture files written.');
'@
node --input-type=module -e $validation
```

Exact round-trip command:

```powershell
$ErrorActionPreference='Stop'; $c=Get-Content mobile/assets/catalogs/cda_catalog_v1.json -Raw | ConvertFrom-Json; $rows=@(Import-Csv codex/cda_geography_coverage.csv); if($rows.Count -ne 964){throw 'Wrong row count'}; if(@($rows.id|Sort-Object -Unique).Count -ne 964){throw 'Duplicate ID'}; foreach($e in $c.entries){$r=@($rows | Where-Object id -CEQ $e.id); if($r.Count -ne 1){throw 'ID mismatch'}; foreach($k in @('id','name','municipality','department')){if($r[0].$k -cne $e.$k){throw "Field mismatch: $k"}}; if($r[0].status -cne 'pending' -or $r[0].missing_location -cne 'true' -or $r[0].missing_evidence -cne 'true' -or $r[0].location_source_url -ne '' -or $r[0].location_verified_at -ne ''){throw 'Incorrect evidence status'}}; 'PASS: Import-Csv round trip preserves all 964 IDs/names/municipalities/departments; all pending and evidence fields empty.'
```
