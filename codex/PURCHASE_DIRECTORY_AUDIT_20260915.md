# Purchase directory audit and handoff - 2026-09-15

Status: PARTIAL validation; scoped implementation complete, parent-run tests and UI integration pending.

## Scope and Git

- Owner-authorized purchase-guide directory slice. Functional coverage is visible; exhaustive national enrichment is not a release gate for this slice.
- Branch: `codex/cda-owner-map`.
- HEAD: `ddf60407174e3ee8d447b7eff3ca45e0fd983789` (unchanged).
- Worktree: `C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa/temp/VIAJE-R1-real-planner`.
- Existing tracked and untracked WIP preserved. No commit, staging, push, merge, new dependency, migration or changes outside the six files listed below.
- Read AGENTS, baseline Cierre Global/Arquitectura, Flow 03 and relevant Flow 08 purchase/official-directory requirements, C13/C14, CURRENT, DESIGN_CONTRACT, SOP and handoff template. This is an explicit scoped extension, not closure of those lots.

## Result and counting rules

| Measure | Count / result |
|---|---|
| Historical national inventory retained | 769 entries / 1003 source rows |
| Independently confirmed ordinary transfer capability | 2: Bogota/VUS and Medellin |
| Registration capability not confirmed | 767; includes offices and historical records, not 767 proven non-registrars |
| Existing fine-portal reviews | 7, unchanged; not registration evidence |
| Verified new contact fields | 2 phone numbers, 1 named physical office |
| Verified new auxiliary links | 1 appointment referral, 1 forms page |
| Tax fichas audited | 33 / 33 |
| Original distinct tax URLs attempted | 53 / 53 (institutionalUrl, portalUrl and sourceUrls union) |
| Original plus follow-up tax URLs recorded | 58 distinct URLs |
| Tax institutional sources with readable content | 18 |
| Tax institutional sources unresolved in this pass | 15 |
| Tax portal referrals retained/enriched | 8, previously 7; not 8 operationally tested payment systems |
| Tax institutional actions | Atlantico improved; La Guajira invalid PDF action suppressed |
| Calendar scope | 14 partial + 19 pending, unchanged; zero newly verified calendars |

All source readings are public, read-only web-tool requests. No personal lookup, CAPTCHA interaction, RUNT inventory extraction, form submission, appointment booking or payment was performed. Search indexes were leads, not proof of an operational destination.

Editorial day: 2026-09-15 America/Bogota. Recorded audit instant: `2026-09-16T01:01:48Z`, equivalent to 2026-09-15 20:01:48 at UTC-05. This is the observed UTC date, not a future local review. Procedure review dates are local civil dates. Publication dates, editorial dates and calendar deadlines are different concepts.

## Registration evidence and API contract

The optional names requested by the parent are implemented unchanged:
`supportsRegistrationProcedures` (bool, default false), `transferUrl`,
`appointmentUrl`, `formsUrl`, `phone`, `address`,
`procedureEvidenceUrl`, `procedureReviewedAt` (nullable strings).

Schema stays at v1. Legacy rows and constructors require no new fields. Missing/false capability means **Tramites no confirmados**, never "does not perform registration". `search` retains all entries and office-location matching remains separate from issuer jurisdiction. UI must use registration capability, not fine-portal `verificationStatus`, to show confirmed transfers.

A separate local reviewed tuple anchors exact identity, transfer URL, evidence URL, date and every optional contact/link supplied. Data cannot grant capability by changing a JSON flag, copying another entry's proof, supplying arbitrary HTTPS links or adding an unreviewed telephone. Validation runs before the existing pending-authority early return. Optional approved contact fields may be omitted. Existing fine-portal trust tuples/dates are untouched.

Fallback exported for the parent: `runtActorsDirectoryUrl` =
[Directorio de actores RUNT](https://www.runt.gov.co/directorio-de-actores).
The public page was opened only as a directory landing. It distinguishes actor types and warns that additional office details should be confirmed with the entity. Do not present every historical inventory entry as an enabled registering authority.

### Bogota / VUS

- Independent issuer referral: [SDM ordinary transfer notice, 29 July 2026](https://www.movilidadbogota.gov.co/noticias/vendio-su-vehiculo-no-olvide-hacer-el-traspaso-y-evite-problemas). Confirms that VUS handles transfers of vehicles registered in Bogota.
- [Exact transfer ficha and primary evidence](https://www.ventanillamovilidad.com.co/tramites/traspaso-propiedad): capability, phone and appointment referral; linked forms section.
- [Appointment destination](https://vus.circulemosdigital.com.co/): explicit referral from both transfer ficha and VUS homepage; requires JavaScript/login. Availability and booking not tested.
- [Official forms page](https://www.ventanillamovilidad.com.co/formularios): readable, includes automotor request and mandate forms. Link is to the maintained official page, not a generated form.
- Phone `6012916999`: normalization of the ficha's published citizen-service line; no number inferred.
- Address null: the footer labels its address as correspondence/document management; not repurposed as a transfer service office.

### Medellin

- [Exact official transfer ficha and primary evidence](https://www.medellin.gov.co/es/tramites-y-servicios/traspaso-de-propiedad-de-un-vehiculo-automotor/) names Secretaria de Movilidad and the ownership-transfer procedure.
- Phone `6044457777` and address `Sede Caribe: Carrera 64 C # 72 - 58, Medellin`: same ficha, named Sede Caribe. Phone digits normalized from the public source.
- The ficha's action opens [Movilidad en Linea](https://www.medellin.gov.co/portal-movilidad/), but an exact appointment-specific workflow was not confirmed; `appointmentUrl` remains null.
- The form download link could not be recovered successfully; `formsUrl` remains null. The transfer ficha itself remains available.
- Ficha contains legacy-looking tariffs and RTM conditions. Those were not copied or certified as current legal requirements. The new fields establish service/contact provenance only.

## All 33 tax fichas

Every row below was audited on the editorial day above. Detailed checked URLs and outcome are also stored in each JSON `directoryAudit`. `source_read` means institutional content was readable; it does not certify a payment portal, current calendar, tax amount or legal eligibility. A failed attempt does not advance the legacy `reviewedAt`. Existing review instants remain unchanged except for the improved Atlantico ficha and new Quindio referral.

| Territory | Institutional source audited | Result / unresolved issue |
|---|---|---|
| Amazonas | [Attempted source](https://www.amazonas.gov.co/) | Portal responde con plantilla Territoriales sin contenido legible. Identidad previa FND conservada; dependencia, tramite y pago pendientes. |
| Antioquia | [Readable source](https://www.antioquia.gov.co/) | Inicio oficial remite exactamente al portal conservado; noticia tributaria legible. Destino dinamico, sin consulta personal ni pago. |
| Arauca | [Readable source](https://arauca.gov.co/secretaria-de-hacienda/) | Secretaria legible; noticia de remision agota tiempo en dos intentos. Edesk responde con controles vacios. Evidencia y fecha previas conservadas; remision pendiente de revalidacion. |
| Atlántico | [Readable source](https://www.atlantico.gov.co/index.php/impuestos-departamentales) | Inicio remite a Impuestos Departamentales; se mejora el enlace institucional a esa pagina. La remision al portal existe pero el destino devuelve errores; portalUrl sigue null. |
| Bogotá D.C. | [Readable source](https://www.haciendabogota.gov.co/es/impuestos/impuesto-sobre-vehiculos-automotores) | Ficha vehicular y Pagos Bogota legibles, remision directa confirmada. Noticia de calendario accesible. No se ejecuta pago ni se actualiza calendario. |
| Bolívar | [Readable source](https://impuestos.bolivar.gov.co/gobol_web/) | Ficha vehicular en subdominio institucional legible; no se acredita remision independiente. Conserva solo acceso institucional, sin portal directo. |
| Boyacá | [Readable source](https://www.boyaca.gov.co/secretariahacienda/) | Secretaria, noticias y resolucion accesibles. Remision textual al portal exacto confirmada; boton usa SafeLinks y destino agota tiempo. No se afirma disponibilidad. |
| Caldas | [Readable source](https://www.caldas.gov.co/) | Inicio y noticia oficiales legibles y con remision al portal existente. Destino rentas agota tiempo; enlace conserva evidencia previa, no acredita operacion. |
| Caquetá | [Attempted source](https://www.caqueta.gov.co/) | Portal responde con plantilla Territoriales sin contenido legible. Dependencia, tramite y pago pendientes. |
| Casanare | [Readable source](https://impuestos.casanare.gov.co/impuesto-vehiculos) | Ficha y pagina de calendario legibles; formulario externo solicita datos personales. Tarifas 2024 visibles: no inferir vigencia ni fechas nuevas. Remision independiente de pago pendiente. |
| Cauca | [Readable source](https://www.cauca.gov.co/rentas/SaladePrensa/Paginas/Liquidaci%C3%B3n-y-pago-del-impuesto-vehicular-en-linea.aspx) | Noticia oficial remite exactamente al destino conservado; destino vehicular legible. No se consultan datos personales ni se realizan pagos. |
| Cesar | [Readable source](https://cesar.gov.co/d/es/noticias/boletines/8164-boletin-2026-3) | Noticia oficial tributaria legible; indica acceso desde icono del inicio, sin remision directa comprobada en esta ficha. portalUrl sigue null. |
| Chocó | [Attempted source](https://www.choco.gov.co/) | Portal responde con plantilla Territoriales sin contenido legible. Dependencia, tramite y pago pendientes. |
| Córdoba | [Attempted source](https://impuestos.cordoba.gov.co/RentasCord/vehiculos_calendario.jsp) | Calendario institucional y noticia complementaria no recuperables con herramienta web. Conserva enlace y revision previa; revalidacion pendiente. |
| Cundinamarca | [Readable source](https://www.cundinamarca.gov.co/dependencias/sechacienda/impuestos/vehiculos) | Ficha, remision exacta y destino vehicular legibles; PDF de ampliacion accesible. No cambia el calendario ni se ejecuta pago. |
| Guainía | [Attempted source](https://www.guainia.gov.co/) | Portal responde con plantilla Territoriales sin contenido legible. Dependencia, tramite y pago pendientes. |
| Guaviare | [Attempted source](https://www.guaviare.gov.co/) | Portal responde con plantilla Territoriales sin contenido legible. Dependencia, tramite y pago pendientes. |
| Huila | [Attempted source](https://www.huila.gov.co/hacienda/) | Secretaria devuelve 403; noticia complementaria tampoco recuperable. Conserva referencia y fecha previas, sin nueva certificacion. |
| La Guajira | [Attempted source](https://www.laguajira.gov.co/NuestraGestion/Normatividad/Resolucion%20No.%2005%20de%202025.pdf) | El enlace institucional previo termina en .pdf pero devuelve HTML sin el acto. Alternativa de impuestos tambien incompleta. Se deshabilita institutionalUrl, se conserva la fuente para trazabilidad; portal y calendario pendientes. |
| Magdalena | [Attempted source](https://www.gobernaciondelmagdalena.gov.co/ultimos-dias-para-acceder-al-100-de-descuento-en-intereses-por-impuestos-vehiculares-tasas-y-multas-de-transito/) | Noticia oficial devuelve 403. Sin evidencia nueva de portal o procedimiento; enlace previo conservado. |
| Meta | [Attempted source](https://meta.gov.co/buscar/pagar-impuesto-vehiulo) | Ruta previa de busqueda solo devuelve aviso de JavaScript; no acredita una ficha ni portal de pago. Enlace previo conservado sin nueva verificacion. |
| Nariño | [Readable source](https://narino.gov.co/noticias/narino-impulsa-el-ahorro-ciudadano-con-incentivo-del-20-en-el-impuesto-vehicular/) | Noticia oficial legible con remision a www.impuestovehicular.narino.gov.co; destino no recuperable. Conserva portalUrl null; no se amplian fechas. |
| Norte de Santander | [Readable source](https://administrador.nortedesantander.gov.co/gobernacion-llama-a-ponerse-al-dia-con-el-impuesto-vehicular/) | Noticia oficial legible del 26 de agosto de 2026; describe canales presenciales, no acredita portal vehicular en linea. Sin promocion a pago digital. |
| Putumayo | [Readable source](https://www.putumayo.gov.co/publications/116?type=2) | Noticia Liquidaton accesible. Evidencia informativa conservada; no se acredita remision independiente a pago en linea. |
| Quindío | [Readable source](https://www.quindio.gov.co/) | Inicio oficial enlaza exactamente a https://isva.quindio.gov.co/portal-quindio/. Se habilita el enlace por remision primaria; destino dinamico sin contenido extraible, operacion no comprobada. |
| Risaralda | [Attempted source](https://tramites.risaralda.gov.co/tramites/171/impuesto-sobre-vehiculos-automotores/) | Ficha de tramite devuelve 403. Conserva referencia previa; procedimiento y portal directo pendientes. |
| San Andrés, Providencia y Santa Catalina | [Readable source](https://ventanilla.sanandres.gov.co/tramites/154/impuesto-sobre-vehiculo-automotor/) | Ficha oficial legible de tramite presencial. Tarifas y telefonos publicados muestran datos antiguos; no se copian como valores actuales ni se habilita pago digital. |
| Santander | [Attempted source](https://santander.gov.co/publicaciones/11394/es-tiempo-de-ponerse-al-dia-con-el-pago-del-impuesto-vehicular-2026/) | Noticia oficial devuelve 403. Conserva enlace y revision previa; revalidacion pendiente, sin portal directo. |
| Sucre | [Attempted source](https://www.sucre.gov.co/) | Portal responde con plantilla Territoriales sin contenido legible. Dependencia, tramite y pago pendientes. |
| Tolima | [Readable source](https://tolima.gov.co/hacienda/rentas-e-ingresos/impuestos/impuesto-de-vehiculos/formas-de-pago) | Instrucciones oficiales de pago y noticia legibles. Destino exacto del boton no acreditado; conserva acceso institucional y portalUrl null. |
| Valle del Cauca | [Readable source](https://datosabiertos.valledelcauca.gov.co/es/organization/about/unidad-administrativa-especial-de-impuestos-rentas-y-gestion-tributaria) | Ficha institucional de datos abiertos acredita la unidad de rentas; no ofrece tramite vehicular. Conserva referencia institucional y portalUrl null. |
| Vaupés | [Attempted source](https://www.vaupes.gov.co/) | Portal responde con plantilla Territoriales sin contenido legible. Dependencia, tramite y pago pendientes. |
| Vichada | [Attempted source](https://www.vichada.gov.co/) | Portal responde con plantilla Territoriales sin contenido legible. Dependencia, tramite y pago pendientes. |

### Direct portal evidence retained or added

| Territory | Official referral source | Destination / outcome |
|---|---|---|
| Antioquia | [Official homepage](https://www.antioquia.gov.co/) and source article retained in JSON | [Vehicle portal](https://www.vehiculosantioquia.com.co/impuestosweb/); dynamic, no payment test |
| Arauca | [Existing anti-fraud notice](https://arauca.gov.co/gobernacion-de-arauca-advierte-a-contribuyentes-que-usen-solo-enlaces-de-pago-oficiales/) | [Edesk](https://edeskprisma.syc.com.co/ARAUCA); notice timed out twice, prior 13 September evidence retained, revalidation pending |
| Bogota | [Vehicle tax ficha](https://www.haciendabogota.gov.co/es/impuestos/impuesto-sobre-vehiculos-automotores) | [Pagos Bogota](https://www.haciendabogota.gov.co/es/sdh/pagos-bogota); both readable |
| Boyaca | [Hacienda payment notice](https://www.boyaca.gov.co/secretariahacienda/la-secretaria-de-hacienda-de-boyaca-informa-que-el-plazo-para-la-declaracion-y-pago-del-impuesto-sobre-vehiculos-automotores-vence-martes-31-de-marzo-de-2026/) | [Vehicle portal](https://vehiculos.boyaca.gov.co/siver-v-boyaca/liquidacionweb/primeraa.php); exact URL in source text, SafeLinks wrapper, direct timeout |
| Caldas | [Official homepage](https://www.caldas.gov.co/) | [Rentas](https://rentas.caldas.gov.co/); referral readable, target timeout |
| Cauca | [Official online-payment notice](https://www.cauca.gov.co/rentas/SaladePrensa/Paginas/Liquidaci%C3%B3n-y-pago-del-impuesto-vehicular-en-linea.aspx) | [Vehicle portal](https://www.softwareenlanube.net/sivervcauca/redirect2/); referral and landing readable |
| Cundinamarca | [Vehicle tax ficha](https://www.cundinamarca.gov.co/dependencias/sechacienda/impuestos/vehiculos) | [Vehicle portal](https://impuvehiculo.cundinamarca.gov.co/sivervcundinamarca/redirect/gov_co/); referral and landing readable |
| Quindio, added | [Official homepage](https://www.quindio.gov.co/) | [Vehicle portal](https://isva.quindio.gov.co/portal-quindio/); exact primary referral, dynamic landing with no extractable content |

Eight links is a provenance count including the existing Arauca review, not eight successful revalidations or usable payment journeys. Quindio's homepage explicitly labels the destination as vehicle tax. Its external application may require JavaScript. No user information was entered.

### Contradictions, stale material and pending work

- La Guajira: previous institutional URL ends in .pdf but now returns HTML without the resolution. Removed only the action (`institutionalUrl: null`); the original source remains for traceability. Its alternative taxes page was also incomplete. No invented replacement.
- Atlantico: official page has a payment referral but its destination returns repeated application errors. Improve the institutional page, keep direct `portalUrl: null`.
- Casanare displays a 2024 tariff section; San Andres includes legacy tariff/telephone formatting. Do not copy these as 2026 tariffs or contact evidence.
- Boyaca's older March notice coexists with an accessible amending resolution. The existing calendar already records its editorial scope; this link audit neither replaces that calendar nor claims a full amendments audit.
- Nariño's article contains a future deadline in December. No new deadline added; its portal destination could not be retrieved, so its direct action stays null.
- Medellin's published transfer prerequisites/tariffs need their own currency review before reproducing legal advice.
- 767 historical entries still need procedure-specific confirmation; absence of evidence is not absence of service. UI must label them not confirmed and offer the RUNT directory fallback.
- Tax dates/events and partial/pending statuses are structurally identical to the starting snapshot; there is no fabricated 2027 calendar, amount estimate or automated debt result.

## Files changed

1. `mobile/lib/features/comparendos/data/territorial_catalog.dart`
2. `mobile/assets/catalogs/comparendos_authorities_v1.json`
3. `mobile/assets/catalogs/tax_calendars_v1.json`
4. `mobile/test/features/comparendos/data/purchase_directory_test.dart` (new)
5. `mobile/test/features/vehicle_status/data/purchase_tax_directory_test.dart` (new)
6. `codex/PURCHASE_DIRECTORY_AUDIT_20260915.md` (this report)

## Verification and handoff

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed` on the three owned Dart files | PASS, 0 changes; direct bundled Dart executable used |
| Structured JSON parse, 33 IDs retained, all 53 original URLs accounted for, 58 checked URLs recorded | PASS |
| ReadAllLines whitespace scan of all six owned files | PASS, no trailing spaces or tabs |
| Territorial JSON inventory, source reconciliation counts and enriched contacts | PASS: schema v1, 769 entries, 1003 source rows, 2 confirmed, 767 unknown, 2 phones and 1 address |
| Starting vs final complete `calendars` arrays compared structurally | PASS, unchanged |
| New data tests | Written, not executed; parent coordinates Flutter |
| `flutter analyze`, `flutter test`, build | NOT RUN by instruction; no concurrent Flutter invocation |
| `git diff --check` across shared worktree | FAIL on unrelated pre-existing/parallel tracked WIP whitespace, including C15 and services; not altered |
| UI / manual external opening on Android | Parent integration and device smoke pending |

Parent command from `mobile`:
`flutter test test/features/comparendos/data/purchase_directory_test.dart test/features/vehicle_status/data/purchase_tax_directory_test.dart test/features/comparendos/data/territorial_catalog_test.dart test/features/vehicle_status/data/tax_catalog_test.dart`.

**Known existing-test update outside this worker's ownership:** in
`mobile/test/features/vehicle_status/data/tax_catalog_test.dart`, test
`seed portals retain independent referral and explicit exclusions`
(current `portalIds` set near line 458), add `quindio` to the seven-element expected set.
Without that parent-owned update the old snapshot assertion will fail. This worker did not modify existing test files.

New tests cover legacy v1 defaults, complete national search, two-only capability, copied/missing/altered evidence, unverified contacts, future review-date mutation, wrong boolean types, RUNT fallback, all 33 audit records and unchanged partial/pending calendar counts.

Physical Android QA: not required for this data-only worker; external-link smoke recommended and not performed. No device, install, private storage, vehicle, GPS or document changes.

Security/privacy: fixed public official URLs only, no personal parameters, no RUNT/SIMIT scraping or CAPTCHA bypass, no backend calls introduced. Runtime dependencies and database schema unchanged.

Next unblocked: parent purchase-guide UI using exact optional fields, visible not-confirmed inventory state, external fallback and source/review display. National exhaustive capability research is follow-up coverage work, not a gate imposed on this slice.

Git status: the five owned code/data/test files are untracked WIP in this shared worktree; this report is also new/untracked. Extensive unrelated tracked/untracked changes predate or run in parallel with this slice. Branch/HEAD unchanged and no clean-worktree claim.
