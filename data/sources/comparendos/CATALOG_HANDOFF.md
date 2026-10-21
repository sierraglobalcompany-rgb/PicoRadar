# Comparendos territorial catalog handoff

## Final Preview Dataset Status

Prepared for main's preview integration; national verification remains PARTIAL.
1,003 source rows -> 769 inventory records. Seven individually reviewed records:
TWO direct consultations (Medellin and Manizales), FIVE institutional-only entries
(Bogota, Barranquilla, Bucaramanga, Itagui, Pereira). The five institutional entries
have consultationUrl null and a Portal institucional label. Their reviewed landing
pages are exposed only through institutionalUrl, never as direct query destinations.
762 records are not individually researched and have no clickable portal; 93 retain
unresolved office codes. SIMIT is separate from these territorial counts.

Medellin consultationUrl is exactly
`https://www.medellin.gov.co/portal-movilidad/#/public`; institutionalUrl/evidenceUrl
remain `https://www.medellin.gov.co/es/pag-movilidad/`. Exact official href and HTTP
200 evidence are recorded in `medellin_referral.json`. Personal forms were not used.

Existing `before.png` was found and visually reviewed, then preserved. It shows
the older Comparendos screen and is BEFORE evidence, not a screenshot of this new
dataset or acceptance of the upcoming preview. No build/install was performed here.

## Status

Implementation and source-row intake: implemented and tested.
Nationwide current-authority, link and legal-coverage verification: PARTIAL.
This is not full C14 closure or a census of unique currently competent authorities.
The user goal includes individual research of EVERY inventoried authority. That
goal is NOT COMPLETE: 7 records individually reviewed, 762 not individually reviewed.
Three additional municipality-level leads (Cali, Cartagena, Envigado) do not count
as completed individual authority research. `individual_review_queue.json` carries
the remaining record IDs and the precise partial status.

## Lot and Git

- C14 Comparendos: delegated territorial catalog subtask only.
- Branch: `codex/comparendos-owner-directory`.
- HEAD: `ddf60407174e3ee8d447b7eff3ca45e0fd983789`.
- Base: existing owner worktree; no branch creation or switch.
- Worktree: `C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa/temp/VIAJE-R1-real-planner`.
- No commits, installs, push or merge. Existing/shared WIP preserved.
- Full observed status is recorded in `CATALOG_GIT_STATUS.txt`. Catalog files are untracked; audit artifacts are under ignored temp.

## Outcome and API

- Added bundled, versioned offline inventory, strict parser and Riverpod loader.
- Existing agreed fields, constructor and APIs remain available.
- `territorialCatalogProvider` is `FutureProvider<TerritorialCatalog>`.
- `simitConsultationUrl` is exactly `https://www.fcm.org.co/simit/`.
- `forMunicipality(code)` returns verified issuer coverage only.
- Added `search(String query, {int? limit}) -> List<TerritorialAuthority>` for direct authority selection. Searches current/source names, platform, department and office municipality. Empty query lists all records; no implicit limit. Pending entries are included.
- UI must select the returned authority directly. Do not map search results through municipalityCodes: pending entries intentionally have an empty coverage list.
- Additional fields: `officeMunicipality`, `department`, `officeMunicipalityCode`, `entryKind`, `verificationStatus`, `coverageStatus`, `sourceRecordIds`, `sourceNames`.
- Office location is descriptive and never confers legal coverage. Unknown office codes are null; source location labels remain searchable.
- The existing 1,104-municipality Trip catalog remains the national municipality source, distinct from this authority inventory. No new municipality provider or pubspec edit.
- Syntax-safe URLs are not necessarily official. Loading checks exact reviewed authority/name/URL/evidence/date/coverage pairs. Unknown clickable links, invented coverage, orphaned/reused source rows and unknown sources fail with FormatException.
- A verified link establishes provenance, not successful personal consultation or live availability of every downstream form.

## Counts and Sources

Sources reviewed on 2026-09-13:

| Source | Observed rows | PDF pages | Rows per page |
|---|---:|---:|---|
| [FCM Organismos](https://www.fcm.org.co/wp-content/uploads/2021/07/Directorio-Organismos-de-Transito.pdf) | 398 | 4 | 130, 130, 135, 3 |
| [FCM Autoridades](https://www.fcm.org.co/wp-content/uploads/2021/08/Base-de-Datos-Autoridades-de-Transito.pdf) | 308 | 7 | 47, 47, 47, 47, 46, 47, 27 |
| [RUNT extensions directory](https://www.runt.gov.co/sites/default/files/documentos/LISTADO%20EXTENSIONES%20IP%20ORGANISMOS%20DE%20TRANSITO.pdf) | 297 | 18 | 14, then 17 on pages 2-17, then 11 |

FCM's [institutional information page](https://www.fcm.org.co/informacion-de-la-entidad/) links both historical PDFs. The 2021 upload paths are not represented as fresh legal verification. No precise publication date was inferred for the undated RUNT file.

- 1,003 source rows, each assigned exactly once to an inventory record.
- 769 inventory records after 234 repeated/variant rows were reconciled.
- 7 verified portal/municipal-coverage records; 762 pending records.
- Of those seven, 2 have direct consultation destinations and 5 have institutional pages only. The 762 other records remain without individually verified portal evidence.
- 676 inventory records have an exact office-location match in the existing municipality catalog; 93 retain unresolved office codes.
- 458 distinct raw department/location label combinations, not a municipality or jurisdiction count.
- These counts are not 769 certified unique legal entities. Names may refer to historical authorities, offices, companies or unresolved aliases.
- Normalization merges equivalent name words at the same stated location, retaining entity type and department names. Seven portal records also have explicitly reviewed historical aliases. Other possible equivalences are retained separately, with sameOfficeLocationIds and source names in the asset. Neither co-location nor a similar name proves succession or shared coverage.

## Verified Link Evidence

Detailed findings, exact source aliases, access limitations and dates are in `mobile/tool/comparendos_verifications.json` and `link_review.json`.

| Authority / code | Active destination and provenance |
|---|---|
| Medellin / 05001 | [Direct Movilidad en Linea portal](https://www.medellin.gov.co/portal-movilidad/#/public), exact href of the institutional button on [pag-movilidad](https://www.medellin.gov.co/es/pag-movilidad/). HTTPS 200, title Movilidad en Linea, JS shell read; no personal query submitted. Source HTML confirms the fragment omitted by the web reader. `medellin_referral.json` records this check. Other Aburra municipalities are not inferred. |
| Bogota / 11001 | [District comparendos page](https://www.movilidadbogota.gov.co/consulta-de-comparendos), offering its own WebFenix referral. Cundinamarca's office in Bogota remains separate. |
| Barranquilla / 08001 | [City multas entry](https://barranquilla.gov.co/transito/tus-multas), with official account-query referral. Metrotransito and Atlantico entries remain separate. |
| Bucaramanga / 68001 | [DTB institutional entry](https://transitobucaramanga.gov.co/dtb/), with Estado de Cuenta referral. The statistical observatory is not exposed as personal consultation. |
| Itagui / 05360 | [Secretaria site](https://www.transitoitagui.gov.co/), offering online services and photodetection query. Also cross-checked against the [city's domain referral](https://www.itagui.gov.co/sitio/ver_noticia/itagui-cuenta-con-nuevo-servicio-para-pagos-en-linea). |
| Pereira / 66001 | [Institute tramites entry](https://movilidadpereira.gov.co/tramites), indexed official content for comparendos/payment service. Live root returned an empty body; downstream forms not tested. |
| Manizales / 17001 | [Exact referred portal](https://www.movilidadmanizales.com.co/portal-servicios/#/public), supported by the [24 April 2026 city notice](https://centrodeinformacion.manizales.gov.co/fotodetecciones-en-manizales-asi-puede-consultar-gestionar-y-pagar-de-forma-segura/). The .com.co domain is accepted by this exact referral, not by generic domain trust. Target JS shell read; form not submitted. |

Separate SIMIT national entry: [FCM FAQ evidence](https://www.fcm.org.co/preguntas-frecuentes-simit/), not a municipality-assigned authority record.

## Outstanding Review Scope

- Revalidate present existence, names, legal successors and competence for 762 pending inventory records. A historical PDF entry alone does not establish these.
- Resolve remaining cross-source aliases and department/municipality-label anomalies before claiming a count of unique current agencies.
- Resolve the 93 unmatched office codes from explicit geographic evidence. Do not turn those codes into legal coverage.
- Verify each future clickable portal and its issuer-specific coverage against official current content; update both reviewed evidence and the Dart trust anchor.
- Cali: official indexed query page found, live fetch 403; not promoted.
- Cartagena: city referral found, destination fetch failed; not promoted.
- Envigado: indexed portal template found with incomplete content; not promoted.
- Downstream personal-query forms, browser redirects, external-link Android smoke and physical QA are not tested here. No personal identifiers were entered.
- Historical PDFs have clipped/fused source text and inconsistent labels. Original extracted names are preserved; no synthetic URL or guessed coverage repairs them.

## Updating Reviewed Portals

The asset and Dart allowlist intentionally have different roles: the asset carries
the inventory; the checked-in allowlist supplies reviewed trust. Neither an asset
flag nor a gov.co suffix grants approval. Each allowlist tuple now has its OWN
reviewedAt, and the builder reads each record's verifiedAt; updating one agency
does not refresh the others' verification dates.

For an actual evidence-backed update:

1. Research issuer identity, current official reference, exact outgoing href (including fragment), HTTPS destination and explicit coverage. Record blocked/unknown states as pending.
2. Edit `mobile/tool/comparendos_verifications.json` with evidence, findings, source aliases and the actual per-record verifiedAt date.
3. Update only that authority's tuple in `_reviewedPortals` (name, code, URL, evidence and reviewedAt). Do not relax the parser to accept an arbitrary verified flag.
4. Rebuild with `python mobile/tool/comparendos_import.py`; use `--extract` only when source PDFs are being re-intaken. A count change requires source/reconciliation review.
5. Run the catalog and importer tests, adjust explicitly asserted inventory/review counts only with supporting evidence, then format/analyze the owned Dart paths.

This small explicit allowlist is deliberate at current scope. It needs further
maintainability review before hundreds of verified portals are promoted; no broad
trust-policy refactor is included here.

## Exact Implementation Paths

- `mobile/lib/features/comparendos/data/territorial_catalog.dart`
- `mobile/assets/catalogs/comparendos_authorities_v1.json`
- `mobile/test/features/comparendos/data/territorial_catalog_test.dart`
- `mobile/tool/comparendos_import.py`
- `mobile/tool/comparendos_import_test.py`
- `mobile/tool/comparendos_verifications.json`

All other writes are catalog audit artifacts under `temp/COMPARENDOS_OWNER/`:
`fcm_organismos.pdf`, `fcm_autoridades.pdf`, `runt.pdf`, three corresponding `.page1.png` renders, `source_rows.json`, `intake_counts.json`, `extraction_checks.json`, `location_review.txt`, `reconciliation.json`, `link_review.json`, `individual_review_queue.json`, `medellin_referral.json`, this report and `CATALOG_GIT_STATUS.txt`.

## Tests Executed

Flutter/Dart executable directory: `C:/Users/felip/.codex/tooling/flutter_3.47.1/flutter/bin`.
Audit Python: `C:/Users/felip/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`.

| Exact command (relative to mobile unless stated) | Result |
|---|---|
| `flutter.bat test --no-pub test/features/comparendos/data` | PASS, 56 tests after direct/institutional separation |
| `dart.bat analyze lib/features/comparendos/data test/features/comparendos/data` | PASS, no issues |
| `dart.bat format --output=none --set-exit-if-changed lib/features/comparendos/data/territorial_catalog.dart test/features/comparendos/data` | PASS, zero changes |
| `python.exe -X utf8 mobile/tool/comparendos_import.py --extract` (repo root) | PASS; 398/308/297 rows; RUNT IDs 1-297, zero unassigned body words; rebuilt asset |
| `python.exe -B -X utf8 mobile/tool/comparendos_import_test.py` (repo root) | PASS, four reconciliation/privacy tests |
| `git diff --check` (repo root) | PASS |

Initial URL test exposed Dart normalization dropping an empty user-info marker. Added a pre-parse rejection and reran successfully. Source-column geometry on first-page renders was inspected; RUNT table extraction was replaced because it omitted boundary rows.

Full mobile suite/build/physical QA remain with the main C14 integrator. This subtask neither changes the screen nor claims its acceptance.

## Data, Privacy and Dependencies

- No schema changes, migrations, user data changes, runtime web calls or new dependencies.
- Local asset is approximately 1.06 MB, including every source reference and name needed for offline traceability.
- Source contact/person/phone/address/email columns are excluded from the runtime dataset.
- Existing audit runtime supplies pdfplumber. No package installation was performed.
- Source-document hashes are provenance fields, not repository SHA manifests.

## Manual / Physical QA

- Reviewed public directory layout, official entry content and referral provenance.
- Physical Android QA: not performed; pure catalog subtask has no new platform integration.
- No SIMIT/RUNT forms, CAPTCHA, personal fines or user identifiers accessed.

## Next Work Unblocked

- Main Comparendos screen can load the catalog, retain national municipality lookup, and independently search/select pending authorities using catalog.search.
- Present pending status and office context honestly; enable only non-null verified destinations.
- Full C14 visual/interaction/external-link acceptance remains with main. No next lot is declared globally unlocked.
