# K7 Functional Audit

Scope: K7-C functional completion audit gates only. Production code, backend, dependencies, permissions, schema and broad refactors were not changed.

Date: 2026-09-04

## Source Coverage

Minimum reviewed sources covered by this audit:

| Source | Coverage in K7-C |
|---|---|
| ANSV | Settings source link and Fotomultas camera-source link inventory. Expected host: `fotodeteccion.ansv.gov.co`. |
| SIMIT | Comparendos and Defensa official handoff inventory. Expected host: `www.simit.org.co`. |
| INVÍAS | Viaje and Settings road-status source inventory. Expected host: `www.invias.gov.co`. |
| C-038/20 | Defensa legal-source handoff inventory. Expected host: `www.corteconstitucional.gov.co`. |
| C-321/22 | Defensa legal-source handoff inventory. Expected host: `www.corteconstitucional.gov.co`. |
| SIC datos personales | Settings privacy source inventory. Expected host: `sedeelectronica.sic.gov.co`. |

## Automated Gates Added

`mobile/test/functional_completion/k7_functional_audit_test.dart` adds consolidated K7-C gates for:

| Gate | Automated check |
|---|---|
| Corrupt `AppPreferences` fail closed | Trip, Compra/Venta and Peritajes corrupt JSON payloads return `null` and remove corrupt values; corrupt Driving preference values fall back to conservative defaults. |
| Diagnostic privacy | `settingsDiagnosticText` includes only schema and camera dataset metadata; it excludes plate, vehicle id, coordinates and defense facts sentinels. |
| Official URLs | ANSV, SIMIT, INVÍAS, SIC, Corte C-038/20, Corte C-321/22, Google Maps and Waze URLs are HTTPS and use expected hosts. |
| Root navigation and Apps visibility | Exactly five root tabs, Apps at center, nine visible primary modules and seven visible secondary modules under default flags. |
| Visible placeholders | Every visible launcher destination is routed through the real app router and must not render `ModulePlaceholderScreen`. |
| Responsive root surface | Root shell plus Apps launcher is exercised at logical `360x800`, devicePixelRatio `2.0`, text scale `2.0`. |
| Destructive local actions | Settings local deletes for Trip draft and Comparendos note require confirmation; cancel preserves data and confirm removes it. |
| Launcher inventory | Every current production file containing `.openExternal(` or `.callPhone(` must have a row in the launcher matrix below. |

## External Launcher Matrix

This matrix documents all current production launcher call sites after K7 integration. Every visible external handoff handles a false launcher result or thrown launcher exception with visible user feedback.

| Call site | Surface | False result | Throw result | K7-C status |
|---|---|---|---|---|
| `lib/features/cda/presentation/cda_finder_screen.dart` | CDA details: Google Maps, Waze, official RUNT/MinTransporte source | Controlled visible snackbar | Controlled visible snackbar | PASS |
| `lib/features/comparendos/presentation/comparendos_screen.dart` | SIMIT and territorial comparendos links | Controlled visible snackbar | Controlled visible snackbar | PASS |
| `lib/features/defense/presentation/defense_screen.dart` | SIMIT, Corte C-038/20, Corte C-321/22 | Controlled visible snackbar | Controlled visible snackbar | PASS |
| `lib/features/fotomultas/presentation/fotomultas_screen.dart` | ANSV source from camera pack | Controlled visible snackbar | Controlled visible snackbar | PASS |
| `lib/features/driving/presentation/driving_screen.dart` | Camera Google Maps handoff | Controlled visible snackbar | Controlled visible snackbar | PASS |
| `lib/features/services/presentation/services_screen.dart` | Google Maps service searches | Controlled visible snackbar | Controlled visible snackbar | PASS |
| `lib/features/vehicle_status/presentation/vehicle_status_screen.dart` | Phone actions, tax calendar portal, official status links | Controlled visible snackbar | Controlled visible snackbar | PASS |
| `lib/features/trip/application/trip_services.dart` | Google Maps route, Waze route, INVÍAS road status | Controlled visible snackbar in presentation | Controlled visible snackbar in presentation | PASS |
| `lib/features/peritajes/presentation/peritajes_screen.dart` | Google Maps peritaje search | Controlled visible snackbar | Controlled visible snackbar | PASS |
| `lib/features/vehicle_status/presentation/soat_rtm_owner_content.dart` | RUNT vehicle link and document/open-source handoffs | Controlled visible snackbar | Controlled visible snackbar | PASS |
| `lib/features/tramites/presentation/tramites_screen.dart` | Medellín/Bogotá official trámite portals | Controlled visible snackbar | Controlled visible snackbar | PASS |
| `lib/features/settings/presentation/settings_screen.dart` | ANSV, SIMIT, INVÍAS, SIC links | Controlled visible snackbar | Controlled visible snackbar | PASS |

## Destructive Local Actions

Confirmed by K7-C automated gate:

| Action | Confirmation expectation |
|---|---|
| Settings: borrar borrador de Viaje | Cancel preserves `trip.draft.v1`; confirm removes it. |
| Settings: borrar nota de Comparendos | Cancel preserves `comparendos.last_checked.<vehicleId>`; confirm removes it. |

Existing focused tests outside K7-C already cover additional destructive actions in feature suites, including Compra/Venta draft delete, Defensa case delete, Documentos local copy delete, Peritajes draft delete and Trip draft delete.

## Privacy Notes

K7-C adds an automated sentinel test for diagnostic text and reviews current logging call sites. The only direct `debugPrint` / `developer.log` production path found is startup timing; current callers log startup markers, asset counts and vehicle count metadata, not plate, vehicle id, coordinates or defense facts.

Risk: `logStartupMarker` accepts a free-form `extra` string. Future production callers must keep `extra` aggregated and non-PII.

## Result

K7-C adds audit gates and K7 integration closes the documented launcher exception handling gaps. This audit does not claim release readiness for physical Android QA or full C29 hardening.
