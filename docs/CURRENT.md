# PicoRadar Current State

## Purchase functional extension installed, acceptance pending (2026-09-15)

Owner-approved six-review implementation: optional candidate/plate, independent
tax/transit/fine authority choices, national inventory search with explicit
pending coverage, and preparation-owned private files. The visual cover remains
unchanged. Draft v4 preserves legacy progress and attachment declarations without
representing them as files; Drift v8 adds exclusive preparation ownership.
621 focused integration tests passed; final purchase rerun 76 passed, analyzer
clean. Dev release installed preserving data; local/installed SHA256:
`C8D5B1E2B374AC4517E410F77FD16C345F07D2B3AC20F500391F919646746C00`.
Six optional-context sheets, SIMIT/browser return, selectors and GPS-to-Maps
were exercised on Mi A3; overview retains its normal-text no-scroll fit.
Physical private-file import/scanner/positive-authentication remain unverified.
Full suite produced 2868 pass / 10 skip / 88 fail: 87 prior failures plus one
obsolete corrupt-draft assertion, subsequently corrected and passed in isolation.
The complete suite was not rerun after that correction. Details are recorded in
`codex/PURCHASE_FUNCTIONAL_HANDOFF_20260915.md`; this does not close prior lots,
the 87 existing global failures, scanner/authentication QA, or release readiness.

## Purchase preparation visual candidate installed (2026-09-15)

Purchase preparation correction implemented over preserved WIP; visual approval pending.
Header 164 dp on Mi A3 (supersedes rejected 108 dp candidate), sampled #143963;
reviewed tiles #1D62C6; plain step numbers, raised 32 dp icons, readable states,
all six steps and Save visible without scrolling at normal text size. Existing
buy/sell cover, draft persistence and attachment functionality remain unchanged.
27 focused tests passed, including real AppShell routing, five viewports at
1/1.5/2 text scale and 0/2/6 review states. Analyzer clean. Dev release installed
with data preserved; local and installed APK SHA256 both
`46A13FE89252F0CE2EF198C3D129E6F800CC317FAFFA2C13FA5C0A1DB269B64B`.
Physical evidence: `C:/Users/felip/AppData/Local/Temp/purchase-final-color-20260915.png`.
Vertical swipe changed zero sampled content pixels. Full suite: 2783 passed,
10 skipped, 87 failures outside Buy/Sell; not a global release approval.
Exact commands and prior feature limitations are recorded in
`codex/PURCHASE_LAYOUT_HANDOFF_20260915.md`; visual approval remains pending.

## Insurance policy refinement installed (2026-09-14)

Scoped C13 revision: human-readable protected policy sheet, one insurer selector
with manual exception, Spanish Material calendar, optional exact COP annual/
monthly value and collapsed private contacts. Approved home/banner/plate files
remain byte-identical to the checkpoint below. No schema or user-policy writes.
403/403 focused/regression tests, 9-file format, analyze and dev-release build
pass. Installed with adb install -r on Mi A3; installed APK SHA256 matches export:
375935564b33535288220ac7f6226fd39c4b38fc61020fcff70e72cebd241090.
APK: ../C13_POLICY_REFINEMENT_QA_20260914/
PicoRadar-poliza-calendario-contactos-dev-release.apk (103318671 bytes).
Physical launch, home, empty editor, Spanish calendar and selector inspected;
all drafts cancelled without saving. 60 fictional automated screenshots cover
5 viewports and 3 text scales. Protected physical policy-sheet approval and
earlier positive-authentication/import QA remain pending; FLAG_SECURE unchanged.
Directory: 16 reference entities reviewed, 39/64 supported service routes,
25 pending; not a claim of exhaustive national or individual-policy coverage.
Handoff: codex/C13_INSURANCE_POLICY_HANDOFF.md. Prior WIP preserved; no full-suite,
CI, publication, merge or owner visual approval claimed.

## Insurance vehicle enlargement and readable plate installed (2026-09-14)

Latest owner revision supersedes the insurance size notes below. Banner remains
279 dp, verified pixel-identical in physical before/after comparison. Plate is
80 dp horizontal, with native 20 dp number layout (>=17 dp measured for normal
formats), not a scaled-down whole graphic. An intermediate 10.7 dp number was
rejected and replaced. Extra vehicle request: slot 112 ->144 dp; physical sedan
visible width 320 ->412 px (+28.8%). Car and motorcycle remain fully contained.
Normal compact actions are inline with 48 dp targets; no vertical home scroll.
355/355 tests pass across insurance, plate fidelity and Pico regression files;
six-file format, flutter analyze and dev-release build pass. Mi A3 install -r
and exported/installed SHA256 verified:
750e415b841cc2c0dd61130c43bb269ac977289dafebc44c9c3873391d8e6d76
APK: ../C13_INSURANCE_OWNER_QA_20260913/portada-unica/
PicoRadar-seguro-vehiculo-30-placa-legible-dev-release.apk.
Current physical evidence: 11-vehiculo-30-placa-legible-carro.png and
12-vehiculo-30-placa-legible-moto.png. No user vehicles/policies modified.
Same branch/base, previous WIP preserved. Visual approval pending; no full-suite,
CI, publication, merge or closure of earlier authentication/import debt.

## Insurance single-home correction installed (2026-09-14)

Supersedes the rejected preview below. No AppBar/title or internal tabs; back
inside promotion, one non-scrolling home, tap vehicle opens its policy. Banner
normal height increased from 186 to 279 dp and exact mockup headline/supporting
copy restored. Three-line titles leave the shield clear. Compact phone actions
preserve direct assistance; vehicle is smaller but fully contained.
226 focused tests pass, scoped format and flutter analyze clean; dev release
build/install -r succeeded on Mi A3. Export and installed SHA256:
ff9b47cd86bce81a41497b4916cc26588498bbc473263e05bd5be5903c7896b3
APK/evidence: ../C13_INSURANCE_OWNER_QA_20260913/portada-unica/.
Handoff: codex/C13_INSURANCE_SINGLE_HOME_HANDOFF.md. Same branch/base and previous
WIP preserved. Owner visual approval pending; no full-suite/CI/publication claim,
no merge, no C25 activation or C15 positive physical authentication/import closure.

## Insurance owner preview installed (2026-09-13)

Branch codex/insurance-owner-mockup, base HEAD
ddf60407174e3ee8d447b7eff3ca45e0fd983789; extensive previous WIP preserved.
Insurance-only adaptive non-scrolling home, vehicle carousel, local policy
editing, protected shared Wallet access and official-purpose insurer directory.
16/16 Fasecolda reference labels audited, 54 enabled channels and 6 inactive
observations; no claim of exhaustive national coverage. Dev-only banner and
fictitious quotation demonstration send no data; C25 and public monetization OFF.
211 focused tests pass, 42-test final visual rerun passes, analyze and scoped
format clean. Final dev release installed with -r on Mi A3; stored user data and
favorite preserved. Temporary QA vehicle/policy removed after capture.
APK: ../C13_INSURANCE_OWNER_QA_20260913/PicoRadar-seguro-asistencia-dev-release.apk
Export AND installed SHA256:
778b9e69473bdd5180b221f65e00285309f6de4a17c087031840d2b0ae5b4ed3
Report: codex/C13_INSURANCE_OWNER_HANDOFF.md; directory sources:
codex/C13_INSURANCE_DIRECTORY_AUDIT.md. Final physical captures and automated
matrix evidence: ../C13_INSURANCE_OWNER_QA_20260913/.
FLAG_SECURE capture denial and locked return from picker observed; successful
PDF import and positive credential authentication remain pending. Visual owner
approval, full suite, isolated publication and CI are not complete. No merge.
Supersedes installed APK references below; release has no debug-only simulation.

## Taxes owner preview installed (2026-09-13)

Branch codex/taxes-owner-calendar preserves previous WIP at base HEAD
ddf60407174e3ee8d447b7eff3ca45e0fd983789. Owner approved the scoped C13 extension
in temp/TAXES_OWNER_PLAN/PROPUESTA.md. Taxes now uses a compact authority/plate
hero, temporary search and explicit per-vehicle save, one calendar source and
grouped date history. Dataset/parser/snapshot recovery and B01 validation share
the v1 tax_calendars contract; no new tables or runtime dependencies.
365 focused mobile tests and 192 server tests passed; analyze, scoped format and
Pint clean. Optimized dev release installed with -r on Mi A3, preserving data.
Physical search, temporary consultation, source/history and external portal return
checked. Explicit persistence tested with fixtures, not personal phone data.
33 territories: 14 partial calendars, 19 pending; 7 officially referred portals.
Real CDN configuration/publication, visual approval and full-suite closure remain
pending. No claim of national calendar completeness or operational remote updates.
APK: temp/TAXES_OWNER_PLAN/PicoRadar-impuestos-dev-release.apk
Export and installed SHA256: 1b3dd80e1c21f7f983a1065176994b1e208b249f36121e5710757913dc808a72
Handoff/evidence: temp/TAXES_OWNER_PLAN/IMPLEMENTATION_HANDOFF.md.
Supersedes installed APK references below. Release has no debug-only simulation.
See .planning/TAXES_OWNER_CHECKPOINT.md. No commit, push, merge or prior-debt closure.

## Fotomultas department mockup: installed preview (2026-09-12)

Department explorer now uses a full map, compact overlay controls and search/filter
sheets. Final owner correction puts zoom/fit at the upper right, 12 dp below the
upper control band. Accessible actions, header wrapping and combined error/empty
notices corrected. National view/data/grouping are not redesigned by this patch.
84 focused tests passed; analyze and touched-file formatting clean; dev release
built and installed with -r on Mi A3. Physical map height 543 dp; unobstructed
central span 342 dp excluding the right control column. Captured map, filtered map,
list, search/filter/source sheets and zoom. Owner liked prior composition; this
last position change still awaits visual approval. Full suite/publication/CI pending.
APK: temp/FOTOMULTAS_OWNER_MAP/PicoRadar-fotomultas-department-dev-release.apk
Export AND installed SHA256: 5d7322f4d6633a9b95c4119c93c6b14b59b264db3da49f7d6dd08db736d0f375
Report: temp/FOTOMULTAS_OWNER_MAP/DEPARTMENT_POLISH_HANDOFF.md.
Supersedes installed APK references below. Release has no debug-only simulation.
Earlier WIP and performance debts preserved; no commit, push or merge.

## Fotomultas compact selection: installed preview (2026-09-12)

National map receives spare height; no empty selection reservation. Selected card
is ~74 dp normally (was 140); map controls 36 dp translucent, 48 dp touch targets.
64 focused tests, analyze, formatting and dev release build passed. Installed -r on
Mi A3; physical no-selection/Antioquia/zoom/return/reset reviewed. Data preserved.
Follow-up: count and ANSV + short real date moved to header right; title nearer back.
Duplicate body strip removed; Mi A3 map gains ~54 dp. Header captures also reviewed.
APK: temp/FOTOMULTAS_OWNER_MAP/PicoRadar-fotomultas-header-dev-release.apk
Export/installed SHA256: 93ea8d2d5c9bc78ff0b72ea2f9e8df737617c6b16171be49c267611a7c0d6888
Report: temp/FOTOMULTAS_OWNER_MAP/COMPACT_SELECTION_HANDOFF.md.
Release has no debug-only driving simulation. This supersedes older installed APK
references below, not their pending work. Owner approval/full-suite/publication/CI
pending; no merge. Earlier WIP and separate performance debts are preserved.

## Vehicle detail mockup: installed preview (2026-09-11)

No-scroll vehicle detail implemented over preserved Garage/Home/Pico WIP.
Mi A3 preview uses dev debug with driving simulation. Data kept by install -r.
Report: temp/VEHICLE_DETAIL_MOCKUP/INFORME_DETALLE_VEHICULO.md.
Local/installed SHA256: 531483824A5752607D2F78EB85F658556D22DE786F09BAF101FB8E78C90E8617.
115 targeted regressions passed; after final spacing 73 layout/deletion and
17 action/deletion tests passed (overlapping counts). Analysis/build passed.
Owner visual approval, full-suite closure, isolated publication and CI pending.
No new commit, push or merge. Earlier outstanding work remains separate.

## Garaje single favorite: installed preview (2026-09-11)

Branch codex/garage-single-favorite, HEAD ddf60407174e3ee8d447b7eff3ca45e0fd983789;
earlier Home/plates/Personal Pico WIP preserved, no publication or merge.
The existing active identifier is the sole favorite. Garage has Todos/Favorito;
Home independently selects verified restrictions today/next seven days on eligible
entry, retaining manual/detail focus. Open forms keep their selected vehicle.
Undo cancels within five seconds BEFORE irreversible private cleanup.

Preview with driving simulation installed on Mi A3 preserving all three vehicles.
Physical favorite change, independent Home priority, detail return, Drive no-write
and persistence after restart verified; original favorite restored. Local/installed
APK hashes match. Analysis, format, focused functional/layout tests and build pass.
Full suite, owner visual approval, isolated publication and CI remain pending.
Report: temp/GARAGE_SINGLE_FAVORITE/INFORME_GARAJE_FAVORITO.md.
Checkpoint: .planning/GARAGE_SINGLE_FAVORITE_CHECKPOINT.md.

## Mi Pico y Placa preview, resumed and verified (2026-09-11)

Home is owner-approved visually; that is not global technical/performance closure.
Personal Pico now has compact unframed identity, one shared TodayRestrictionSummary,
calendar and expandable source/rule details. Home delegates to the same summary
without changing its appearance or navigation. Personal city consultation remains
temporary; no restriction engine, dataset, GPS or backend changes in this sublot.

Resume audit: HEAD ddf60407174e3ee8d447b7eff3ca45e0fd983789, existing WIP preserved.
378 focused tests re-executed PASS, plus 12 layout exports PASS; analysis and source
formatting PASS. Release APK installed on Mi A3; local and installed hashes match.
Physical restricted/allowed states, calendar/day detail, source expansion and
Bogota consultation followed by unchanged Medellin Home captured after resume.

Status: PARTIAL, preview ready for owner visual approval. Full suite, final
regressions, commit separation, push and CI are pending after that approval.
No commit/push/merge in this sublot. Earlier Home/plate WIP remains separate in
scope and must be separated before publication. No fresh performance acceptance.
Report: temp/PLATE_OWNER_FIDELITY/INFORME_PICO_PERSONAL_VISTA_PREVIA.md.
Recovery: .planning/PICO_PERSONAL_CLARITY_CHECKPOINT.md.

## Latest Home countdown preview (2026-09-11)

Owner subsequently requested a moving clock hand. A private 16 dp clock now
repaints its hand by 6 degrees once per second; the shared restriction clock
still updates only by minute. The decorative timer stops for hidden routes,
disabled TickerMode, reduced motion, background and disposal. No card rebuilds
or data queries are triggered by its ticks. Pixel, coverage, route and lifecycle
guards pass along with 399 focused tests. The visual timer explicitly supersedes
the prior static-icon choice; it does not replace the restriction clock.

Home now shows the daily label "Tiene pico y placa hoy", the full schedule once,
and a minute-level countdown from the shared Bogota clock. Before start it counts
to start; while active to the end of the current window; pauses show the next
window and the unrestricted-currently message. Finished/unknown/stale states
never count down. No new timers, providers, data contracts or restrictions.
Green summary, 96 dp plates, centered titles and 64 dp obligation cards preserved.
397 focused tests PASS, including clock/notification and Home performance guards.
Real-device evidence and the latest APK identity are in the countdown handoff
under `temp/PLATE_OWNER_FIDELITY/`. Visual approval is still required before
full-lot closeout/publication. Earlier performance acceptance debt remains open.

## Latest Home name alignment correction (2026-09-11)

Owner reported the carousel title offset after the status icon. Tests confirmed
16 dp rightward displacement. Equal 32 dp side reservations now center nickname,
brand and fallback against the whole card. Enlarged-text title measurement
accounts for both sides. No data, selection or navigation change.
350 focused tests PASS; analysis, source formatting and diff check PASS.
Latest preview/build evidence is recorded in the local plate checkpoint/report.
The 96 dp plate and compact SOAT/RTM cards remain unchanged by this correction.

## Latest Home preview: compact obligations (2026-09-11)

Supersedes the 128 dp preview below. The owner approved the 96 dp plate design
and requested shorter SOAT/RTM cards without smaller text or icons. Cards now
use 64 dp instead of 72 dp at normal text scale; vertical padding is 4 dp
instead of 8 dp. Enlarged text retains adaptive height. The existing measured
layout transfers the recovered 8 dp to the Home carousel, without a new layout
service or changes to the allowed-day summary.

Detailed compact plates: 96 dp, approx 46 dp high, 20 sp number, 7 dp emblem,
10 sp caption aligned with the lower screw slots. Physical screenshot body
widths after the card change are 162.5/163 dp against the 96 dp plate. Actual
visible body pixels were measured, not transparent image widget bounds.

338 focused tests, analysis, source formatting and release build PASS.
Latest installed APK and evidence: `temp/PLATE_OWNER_FIDELITY/INFORME_COMPACTO_96.md`.
Owner approval applies to the plate, not to unmeasured performance or the
full-lot technical closeout. Full-suite regression, CI and publication remain
pending. No commit, push, PR or merge for this lot. User data preserved.

## Plate/Home preview correction 2026-09-11

The owner rejected the first plate preview (oversized, missing emblem for a
legacy six-character value). Updated WIP uses 128 dp compact plates with a
9 dp emblem, non-validating alphanumeric 3+3 grouping and the new green-check
Home allowed-day summary. The owner's follow-up requested a smaller yellow
surface and larger characters: number 26 sp, tighter margins, height about 60 dp.
Source analysis, formatting and 334 focused tests (including visual export)
pass. Physical preview is installed; OWNER VISUAL APPROVAL is required before final
suite, commit, push and PR. No merge or data reset. Earlier full-suite results
do not certify this newer revision. See the preview checkpoint in .planning/.

## Plate owner fidelity 2026-09-10

`codex/plate-owner-fidelity` starts at `ddf6040`, targeting
`codex/app-performance-kiss` without merge. The owner's correction explicitly
extends the detailed plate from Home to Garage, personal Pico and the vehicle
shortcuts in city Pico. One inset black border, four horizontal slots and a
reserved circular monogram replace the double border/plain tiny ring.
The shared local registration catalog supplies municipality-only captions;
motorcycles and missing registration use COLOMBIA. Unmatched legacy text is
preserved. No persistent vehicle field or restriction jurisdiction is changed.
The local plate wrapper is not a startup barrier. Existing carousel reuse and
legacy plates in unrelated screens remain. Enlarged text measures the plate
and allows additional height instead of scaling its entire content down.
Evidence and exact gates belong to `temp/PLATE_OWNER_FIDELITY/INFORME_PLACAS.md`.
This visual correction does not close the prior performance acceptance debt.

## Performance KISS audit and implementation 2026-09-10

`codex/app-performance-kiss` starts from `d2bb976` and targets
`codex/home-owner-responsive`, without merge. Scope: measured startup,
progressive Home, bounded and correctly invalidated local work, and proven
unused-code cleanup. The approved visual layouts, GPS ownership, camera/toll
semantics, private cleanup and local data contracts remain authoritative.

The instrumented baseline distinguishes Android TTID, Flutter first frame,
critical data and Home content frames. Physical release testing exposed a
pre-Flutter Room/WorkManager constructor removal by R8. The scoped constructor
keep rule has passed optimized APK launches on Mi A3 without deleting data.
The ten-launch release sample records Home raster completion at median896ms
and p95 2316ms from the pre-launch device clock sample, including ADB transport;
it is not a touch-to-display scanout measurement. First update is retained.
Evidence, actual before/after measurements, incomplete targets and final gate
results belong to `temp/APP_PERFORMANCE_KISS/INFORME_RENDIMIENTO.md`.
Acceptance remains PARTIAL: Apps raster performance is below the95% target;
first Home/Garage traversals also miss it. Cold startup improvement does not
certify global fluency, absence of leaks or the live Viaje routing service.
Normal profile and Driving harness evidence are explicitly distinguished.
The enlarged-text simulation checks exposed a pre-existing unbounded brand
row; a local Flexible constraint preserves the normal layout and full text.
The optional simulation gate is tested separately with its compile-time flag.
No backend, schema, permission, new dependency or framework change is allowed.

## Inicio/Garaje/Pico audit followup 2026-09-10

PR #63 remains scoped to Home and its audited Garage/Pico/location interactions,
targeting `integration/VIAJE-R1-real-planner`, without merge. The audit reproduced
ambiguous city-wide personal verdicts, clipped city/source text, Home focus loss
on a location refresh, and superseded GPS operations overwriting manual choice.
Corrections retain focused vehicle IDs, separate collective and personal copy,
reflow accessible text, and serialize current location preference snapshots.
Garage favorite updates and initial active-vehicle loading are also audited.

The unchanged `2026.09.10-r4-a` dataset contains 7 jurisdictions/12 coverages.
Four-city checks exercise Medellin, Bogota, Bucaramanga and Manizales against
that catalog; they do not certify national completeness or legal freshness.
GPS resolves supported city radii, not municipal polygons or continuous driving
jurisdiction tracking. Real Mi A3 GPS evidence covers the current Medellin
location only. Gates and limitations belong to the indexed
`temp/HOME_GARAGE_PICO_AUDIT_20260910` handoff, not inferred from this note.
No Driving, backend, dataset, schema, dependency or permission change.

## Inicio/Pico owner correction 2026-09-10

`codex/home-owner-responsive` targets `integration/VIAJE-R1-real-planner` without
merge. Physical audit reproduced a cached September 9 clock on September 10:
Home/Pico showed an allowed day while the explicit calendar correctly restricted
Thursday. Restarting the unchanged APK restored the correct day. The correction
uses one lifecycle-aware UTC clock, separates daily and immediate state, and
replaces Home's tomorrow strip with the owner-selected navy current-status card.
The compact summary leaves space for a carousel sized from the measured viewport.
The latest owner correction restores a nickname/brand band with a static status
shadow. Home plates use yellow/private or white/taxi, inner borders/fixings and
the stored registration city; motorcycles and absent city use COLOMBIA. This
label never selects restriction jurisdiction. Other screens keep legacy plates.
No backend, dependency, schema, permission or Driving change is authorized.
Fresh automated, physical, APK and CI results are recorded in the requested
HOME_PICO_SUMMARY handoff; this note alone does not certify those gates.

## Active owner correction: Viaje toll estimates and contextual cities

PR #55 remains on `integration/VIAJE-R1-real-planner`, without merge. The current owner-approved private OSRM pilot supersedes the historical provider-access blocker described below for this local pilot only; it does not authorize public deployment or TollGuru spending.

Viaje now uses route-local toll estimates consistently in summary, alternatives, route-only tariff consultation and map details. Directional/conditional/blocked charges remain pending and nominal prices remain inspectable. Other operator categories are consultation-only. A single city-labeled Pico block opens transient jurisdictions without changing the global location; general caveats/checklist are collapsed under Informacion importante.

Verification and physical evidence for this correction are recorded in the explicitly requested `temp/VIAJE_PEAJES_UX` handoff. This note does not claim physical or CI completion before their recorded results. The existing preview validator now accepts today's date-only query without inventing a user departure hour; past dates and the 30-day ceiling remain rejected. No new dependencies, schemas, permissions or endpoints are part of this correction.

The owner subsequently rejected the first toll/Pico presentation. Followup work simplifies tolls to names/prices plus expandable categories/location, folds technical sources, and makes both Pico city rows consistent. Public road fixtures for two explicitly requested debug simulations (Niquia/La Estrella, 80 km/h) are separate from real user GPS and camera data. Final tests, physical captures and outstanding frame-performance measurements must be read in the current handoff, not inferred as passed from this note. PR #55 remains unmerged.

## V01B merged; VIAJE-R2C verified locally, owner toll tariffs added, provider access still pending

Owner-authorized PR #54 squash: `e9ef37511df3110ffb0fc006ef06be781df432ac`, parent `c1010b5a2d23b2c3c4f8cf00874f4ecfd2780d44`. It preserves the approved V01B HEAD `d84a1765224481e629ab60586e79da35b3cc9841` tree `3e3a6c05bf09c1b059262ba5cf311d3e6b348b6f`. Postmerge Mobile CI `33988444392` passed on that squash. Server CI did not trigger for the visual-only merge. This is bounded V01B approval, not approval of all 43 screens or historical P07/F01/F02 gates.

`integration/VIAJE-R1-real-planner` starts at that exact squash. The 2026-09-05 owner instruction combines R12/S07/F01 into the existing Viaje flow: explicit plan CTA, vehicle-specific departure date/time, real route response presentation, COP toll breakdown and local origin/departure plus destination/ETA restrictions. S07 remains an alias, not a new module. Contract: `docs/contracts/VIAJE_R1.md`.

The development-only Laravel bridge protects a fixed TollGuru endpoint with explicit access/license flags and conservative atomic global budget reservations. It is disabled by default, even with a key. R2C supports a zero-money trial only when free access, owner access, provider license, key, positive request/unit limits and an unexpired UTC deadline are all configured; every gate remains fail-closed. No live access, spending, provider-data license or APK-accessible backend has been approved. Runtime fixtures are absent; missing configuration is an honest error while local restrictions remain usable. Tests with synthetic responses do not demonstrate live Colombian routes. Status remains `PARTIAL_DATA_REVIEW_AND_PROVIDER_ACCESS`; the Viaje PR must stay draft and unmerged until the separate live/physical gates are met.

VIAJE-R2 extends that same flow with the owner-approved responsive one-page hierarchy and a pre-trip map contract. Route geometry travels in the existing preview response and is never persisted. The map associates the selected geometry with the local 184-location toll inventory and the existing 360-camera ANSV pack. Counts distinguish physical locations from candidate passages; cameras remain `nearbyUnconfirmed`, historical toll locations are opt-in, and absent tariffs remain null. R2C adds a versioned, fail-closed review gate: six priority coverages were reviewed, zero reached `verified_executable`, and zero runtime rules were published. All 219 coverage rows, 261 dated rows, 73 rotation/validity rows and 74 explicit `NO PUBLICAR` rows remain accounted for. The runtime restriction asset is unchanged. Contract: `docs/contracts/VIAJE_R2.md`.

The 2026-09-08 owner toll workbook is compiled into a separate local tariff catalog, not into `tolls_inventory_v1.json`. The normal app can search published amounts by physical toll ID without TollGuru and the selected-route map/detail can show Category I/local breakdown for candidate toll passages when the geometry supplies matching IDs. Amounts are stored as whole COP pesos in the asset and converted once to minor units only for existing plan-money UI. Null means not informed, not free; special/suspended/secondary records remain visible with controls and are not applied without eligibility or route validation.

Basemap network access is disabled by default with `PICORADAR_TRIP_MAP_TILES_APPROVED=false`. Enabling it requires an approved provider/license combination and explicit tile URL/user-agent configuration. Without that approval, the vector route, local markers, disclosures and neutral fallback remain usable and no tile request is sent.

R2C visual fixtures are test-only, visibly labeled `DATOS DE PRUEBA - NO ES UN PLAN REAL`, and use a local neutral map provider. They are evidence of responsive widget behavior, not live routes, live tolls or an approved basemap.

Only municipality endpoints, departure and technical vehicle category may leave the phone on the CTA. Plate/vehicle identity and restriction evaluation stay local. Responses/geometries are not persisted. Taxi toll mapping remains unsupported until verified; unknown counts/costs are not zero. No new dependency, schema, permission, account, public deployment or D02 work is authorized. The existing Trip geography asset stays distinct from the RUNT registration catalog.

KEEP and other unselected REDESIGN decisions remain frozen. F02 manual camera updates, P07 actual PDF picker import, the historical external SOAT intent risk, Driving road smoke and prepublication legal review remain separate unresolved gates. Evidence for this lot is in its PR/CI and the explicitly requested `temp/VIAJE_R1/viaje_r1_handoff.zip`, not inferred from this state note.

Fecha de recuperacion R00: 2026-08-27. Base auditada: `main` en `0905d394b0379665e4a9dd343045072582d976a0`.

## Invariantes vigentes

- Marca: **PicoRadar**.
- Titulo previsto en tiendas: **PicoRadar: Pico y Placa**.
- Navegacion inferior: **Inicio · Garaje · Apps · Viaje · Conducir**, con **Apps** siempre al centro.
- Orientacion canonica de telefono: **portrait-only**.
- Free 1.0 funciona sin cuenta, sin monetizacion y sin cloud obligatorio.
- Pico y placa se evalua localmente desde datasets versionados.
- Conducir no envia GPS continuo, no consulta backend por cada posicion y no almacena historial GPS por defecto.
- Laravel es control plane, no backend transaccional del vehiculo activo, garaje, widget, pico de hoy, GPS history, camaras hot path, documentos privados, notification history ni cuentas obligatorias.

## Implementado en `main`

- Fundacion monorepo Flutter/Laravel con flavors Android `dev`, `staging`, `prod`.
- App shell Flutter con Riverpod, go_router y cinco tabs aprobadas.
- Drift schema v4 con `vehicles`, `vehicle_obligations`, `notification_preferences`, `dataset_versions` y `restriction_coverages`.
- Preferencias no sensibles, secure storage y cifrado AES-GCM para archivos privados.
- Motor local de manifest/dataset sync con verificacion SHA-256 de bytes descargados.
- Alta local de vehiculo, garaje raiz/detalle y vehiculo activo.
- Importador/evaluador local de restricciones y cobertura por jurisdiccion.
- Inicio/Pico con estado local y planificacion inicial de notificaciones.
- Launcher Apps en recuperacion R02C como accion central overlay/bottom sheet; widget Android de acceso rapido en estado neutral/local.
- Laravel 13 Control Plane: B00 Control Plane Foundation y B01 Dataset Registry + Publisher están merged en `main`. B01 aporta `datasets`, `sources`, releases inmutables, audit logs append-only, publisher de manifest estático, rollback y separación de roles. No existe API de producto en el hot path móvil.
- Contrato estático B01: el manifest móvil y público del servidor es `/v1/manifest.json`; los datasets publicados siguen `/storage/datasets/{key}/{version}/{key}-{version}.json`. Flutter no se conecta directamente a MariaDB.
- CDA01 implementa el finder oficial de CDA desde el dataset abierto RUNT/MinTransporte `epfm-5fhb`, con catálogo local versionado, búsqueda por nombre/municipio/departamento, entrada desde Apps Más y RTM `Buscar CDA`. No incluye direcciones, coordenadas, distancias, precios, teléfonos, WhatsApp, ratings ni patrocinados.

## Backend forense

| Area | Estado | Decision |
|---|---|---|
| `server/routes/web.php` | Control Plane B00/B01: health, operadores y administración de datasets | Sin hot path móvil |
| Controllers de producto | Health API, sesión de operadores y registry/publisher B01 | Control plane estático; sin hot path móvil |
| Models de producto | Operadores B00 y `datasets`/`sources`/releases inmutables/audit logs B01 | Control plane únicamente; sin usuarios móviles |
| Migrations | Usuarios B00 y datasets/sources/releases/audit B01 | Control plane MariaDB/SQLite compatible |
| Jobs/Commands de producto | Creación de `super_admin` y regeneración de manifest B01 | Publisher síncrono, sin queues |
| Tests server | Health/auth B00 y pruebas de registry/publisher B01 | Publisher, rollback, manifiesto y permisos cubiertos |
| Config/env | SQLite local/tests, MySQL/MariaDB documentado y CI PHP 8.3–8.5 | B00 MERGED; B01 MERGED; CI remoto pendiente por infraestructura externa |

El Control Plane B00 y el publisher B01 están merged en `main`; la deuda de CI remoto B00/B01 es infraestructura (jobs sin runner/steps), no un PASS. El roadmap C00-C29 sigue siendo autoridad para responsabilidades posteriores: C22 Routes/Places proxy, C25 Reports/Leads y C29 hardening. No implementar capacidades duplicadas ni iniciar B03 antes de aprobación.

La capacidad B02 de geografía/jurisdicciones del Control Plane usa identidad DANE DIVIPOLA/MGN 2025, jerarquía Colombia → departamento → municipio y cobertura operativa por jurisdicción. No almacena geometrías ni crea un hot path móvil o una publicación de dataset.

No construir backend para vehiculo activo, garaje, widget, pico de hoy, historial GPS, hot path de camaras, documentos privados, historial de notificaciones ni cuentas obligatorias Free 1.0.

## Drift / datos locales

`main` esta en schema v4. Tablas actuales:
- `vehicles`: perfil local del vehiculo, placa unica por `vehicles_plate_idx`.
- `vehicle_obligations`: obligaciones por vehiculo, FK cascade a `vehicles`, indices por vehiculo y fecha.
- `notification_preferences`: flags locales de notificaciones.
- `dataset_versions`: estado actual de datasets instalados, clave unica por `dataset_key`; no es historial.
- `restriction_coverages`: reglas locales por jurisdiccion/tipo de vehiculo/servicio con indice unico de lookup.

No hay tablas de historial de GPS, viajes, documentos cloud, camaras remotas ni eventos de usuario.

Checkpoint C13 preservado: PR #16, HEAD `06f4d6dee2b45336f35669d6a279b19d75e29abb`. R03 debe recuperar desde C13 schema v4, obligation model/store, reminder planning, official catalogs, source verification y tests utiles. R03 no esta obligado a conservar layout, widgets, presentacion ni estilos reemplazables de C13.

## Graphify R00

Graphify code-only produjo 1306 nodos, 1731 edges, 69 comunidades y 0 ciclos de import. Hubs principales: `build`, `activeVehicleProvider`, `vehicleListProvider`, `VehicleServiceType`, `HomeScreen`, `vehicleRepositoryProvider`, `PicoDetailScreen`, `_PicoRadarAppState`, `AppDatabase` y `AppsScreen`.

Hallazgos estructurales:
- Home/Pico/Garage/Apps concentran dependencias visuales privadas y deben pasar por shared components en R01/R02.
- `AppDatabase` esta conectado a repositorios/datasets esperados y no muestra dependencias a backend.
- Documentos historicos root, handoffs, package manifests y SHA manifests no son consumidores runtime/CI/build.

Extraccion semantica sin LLM API key se hizo por lectura manual/subagentes siguiendo el extraction spec. Hiperconexiones relevantes: pipeline de datasets versionados, progresion Driving local, Free 1.0 privacy/monetization OFF y superficie backend minima dinamica.

## Scorecard de fidelidad

| Area | Producto | Codigo | Visual | Tests | Backend | Veredicto |
|---|---|---|---|---|---|---|
| Navigation | PASS | PASS | PARTIAL | PASS | N/A | PARTIAL |
| Onboarding | PARTIAL | PARTIAL | PARTIAL | PASS | N/A | PARTIAL |
| Home/Pico | PARTIAL | PARTIAL | FAIL | PASS | N/A | FAIL |
| Garage | PARTIAL | PARTIAL | PARTIAL | PASS | N/A | PARTIAL |
| Apps | PARTIAL | PARTIAL | FAIL | PASS | N/A | FAIL |
| Vehicle status | PARTIAL | DEFER/PR #16 | FAIL | PR #16 | N/A | DEFER |
| Widget | PARTIAL | PARTIAL | PARTIAL | PASS | N/A | PARTIAL |
| Notifications | PARTIAL | PARTIAL | PARTIAL | PASS | N/A | PARTIAL |
| Camera/Driving | NOT_STARTED | NOT_STARTED | NOT_STARTED | NOT_STARTED | N/A | NOT_STARTED |
| Trip | NOT_STARTED | NOT_STARTED | NOT_STARTED | NOT_STARTED | N/A | NOT_STARTED |
| Services | NOT_STARTED | NOT_STARTED | NOT_STARTED | NOT_STARTED | N/A | NOT_STARTED |
| Defense | NOT_STARTED | NOT_STARTED | NOT_STARTED | NOT_STARTED | N/A | NOT_STARTED |
| Backend publisher | IMPLEMENTED B01 | MERGED | N/A | LOCAL PASS / REMOTE CI INFRA BLOCKED | Static manifest/assets | MERGED / CI INFRA DEBT |
| Backend routes proxy | NEEDED | NOT_STARTED | N/A | NOT_STARTED | NOT_STARTED | NOT_STARTED |
| iOS | FUTURE | NOT_STARTED | NOT_STARTED | NOT_STARTED | N/A | NOT_STARTED |

## Roadmap V2

R00 pauses normal Cxx execution and restores repo hygiene, forensic state and governance.

R01 Design System Recovery:
- rebuild shared tokens/components from baseline and mockups;
- replace Material-default surfaces;
- establish visual gates and screenshot/golden workflow.

R02 Root UI Fidelity:
- repair Navigation, Onboarding, Inicio/Pico, Garaje and Apps visual fidelity;
- eliminate overflow and spinner-first loading where skeletons are required;
- keep runtime behavior unchanged unless a visual defect exposes a real bug.

R02A Home Owner V4:
- `docs/design/HOME_OWNER_V4.json` and `docs/design/reference/home_owner_v4.png` are the current owner-approved Home visual authority for the R02A Home slice.
- Home keeps brand top-left, avatar + notification inside one top-right capsule, no greeting copy and no Start Driving CTA on Home.
- Home banner runtime ad network remains `PREPARED_NOT_INTEGRATED`: no Google Ads SDK, no real AdMob and no C25 leads in R02A.
- Future owner decisions documented but not implemented in R02A: R02C Apps overlay, Maintenance module, Pre-trip checklist and Tips.

R02B Garage Owner V1:
- `docs/design/reference/garage_owner_v1.png` is the owner-selected visual authority for the future R02B Garage slice.
- Runtime data in that mockup is illustrative only; do not fake comparendo counts/status before C14.
- Maintenance-related UI remains disabled/omitted until its own approved lot.
- `docs/design/GARAGE_OWNER_V1.json` captures the R02B Garage V2 contract: shared PicoRadar header, Todos/Favoritos/Activos filters, native carousel, AppPreferences favorites, truthful info panel, Add Vehicle card and four quick actions.
- P02 post-R03A regression fixes are merged on `main`: Garage focused vehicle/data sync, active/non-active action visibility, Apps launcher runtime reopen, Home geometry regression fixes and registration-city catalog are accepted.
- Garage focus is local to Garage. Swiping the carousel does not mutate the global active vehicle; only the explicit `Hacer activo` action does.
- Mileage, maintenance records and comparendos claims remain not implemented in R02B.

R02C Apps Launcher Owner V1:
- `docs/design/APPS_LAUNCHER_OWNER_V1.json` and `docs/design/reference/apps_launcher_owner_v1.png` are the current owner-approved Apps visual authority.
- Bottom nav center **Apps** acts as an overlay launcher; it must not navigate to a full-screen Apps tab from the center action.
- Principales keeps the 3x3 module order; Mas keeps secondary modules only. Maintenance, Tips and Pre-trip remain out of scope.
- Phone visual QA for root surfaces is portrait-only unless a future approved lot explicitly adds landscape.

R03 C13 Logic Integration + UI Restyle:
- R03A Pico visual recovery is implemented and merged.
- P03 Pico shell/month calendar/catalog selector fixes are merged.
- schema v4, obligation/reminder/catalog tests and C13 vehicle status logic remain recovered.
- R03 route/product contract is frozen in `docs/design/R03_REFERENCE_PLAN.md`.
- `/pico?vehicleId=<id>` is **Mi Pico y Placa** personalized vehicle detail.
- `/pico` is **Pico y Placa de la ciudad** regulation overview.
- The Home card is labeled `Pico y placa` while keeping contextual secondary content such as tomorrow/next restriction state; its tap continues to use the focused vehicle.
- R03B SOAT/RTM owner V1 is implemented on branch `feat/R03B-soat-rtm-owner-v1` from owner-selected `soat_owner_v1.png` and `rtm_owner_v1.png`.
- SOAT and RTM preserve C13 local obligation logic: due dates, optional metadata, reminders, RUNT official links and focused vehicle context.
- SOAT/RTM now use a shared local private document store for optional PDF/image copies. Payloads are app-owned and AES-GCM encrypted; metadata remains local and no document bytes are stored in SQLite/detailsJson.
- Plaintext viewer copies are temporary only: stale cache is purged before each view, after app resume, during startup, on failed external open and when replacing/deleting the document.
- RTM `Buscar CDA` abre el finder oficial CDA01. `CDA02_COORDINATES` queda como seam futuro para direcciones verificadas, coordenadas, distancia real, orden por cercanía y vista de mapa. Paid ranking y backend de patrocinados no estan implementados.
- SOAT/RTM history shows real records only; history persistence for replaced obligations remains a future lot.
- SOAT due/expired CTA updates local SOAT data; it does not claim renewal unless a real renewal destination is integrated. Commercial seams render house content or nothing unless a real HTTPS sponsored campaign exists; no ads are shown in document viewing.

C10B National Pico rollout:
- `docs/data/PICO_JURISDICTION_COVERAGE_AUDIT_20260830.md` is research authority only.
- Candidate cities from the audit are not runtime jurisdictions until a separate approved C10B lot.
- Current Pico catalog count is 15 researched jurisdictions. Runtime available jurisdictions remain Bogota and Medellin / Valle de Aburra only.
- C10B_NATIONAL_PICO = NOT_STARTED.

B00/B01 backend split:
- B00 Control Plane Foundation está merged en `main`.
- B01 Dataset Registry + Publisher está merged en `main`.
- B01 merge SHA: `ed691be34b8681e73d3d1aa3257b8b17d06a5431`.
- CI remoto B00/B01 permanece bloqueado por infraestructura externa, con jobs configurados intactos y sin steps ejecutados.

C14+ resumes product functionality only after the chosen R01/R02/R03/backend authority path is explicitly approved.

Bloques de recuperacion:
- A: Governance and source of truth.
- B: Design system and visual fidelity.
- C: Root UX and app shell.
- D: Local data and dataset pipeline.
- E: Vehicle status recovery.
- F: Backend control plane.
- G: Release QA and store readiness.

## Estado de release

No release-ready. Las razones actuales son visuales/gobernanza, no una necesidad de backend runtime: algunas superficies heredadas siguen en recuperacion visual frente al baseline, "Cambiar vehiculo" no abre selector rapido H-005, Apps tiene deuda visual fisica pendiente y los loaders heredados deben revisarse contra el criterio de skeletons. Home R02A sigue el contrato owner V4, que excluye CTA de conduccion dentro de Inicio.

## Flow 05 continuity

Existe una variante de soporte mas nueva para Flow 05: Fotomultas / Conducir / Velocimetro / Voz / HUD. Estado: `CANDIDATE_TO_PROMOTE` antes de C16-C20, solo despues de compararla contra Cierre Global y Arquitectura Tecnica. No es canonica automaticamente.
