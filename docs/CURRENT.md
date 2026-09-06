# PicoRadar Current State

## V01B merged; VIAJE-R2C verified locally, provider access still pending

Owner-authorized PR #54 squash: `e9ef37511df3110ffb0fc006ef06be781df432ac`, parent `c1010b5a2d23b2c3c4f8cf00874f4ecfd2780d44`. It preserves the approved V01B HEAD `d84a1765224481e629ab60586e79da35b3cc9841` tree `3e3a6c05bf09c1b059262ba5cf311d3e6b348b6f`. Postmerge Mobile CI `33988444392` passed on that squash. Server CI did not trigger for the visual-only merge. This is bounded V01B approval, not approval of all 43 screens or historical P07/F01/F02 gates.

`integration/VIAJE-R1-real-planner` starts at that exact squash. The 2026-09-05 owner instruction combines R12/S07/F01 into the existing Viaje flow: explicit plan CTA, vehicle-specific departure date/time, real route response presentation, COP toll breakdown and local origin/departure plus destination/ETA restrictions. S07 remains an alias, not a new module. Contract: `docs/contracts/VIAJE_R1.md`.

The development-only Laravel bridge protects a fixed TollGuru endpoint with explicit access/license flags and conservative atomic global budget reservations. It is disabled by default, even with a key. R2C supports a zero-money trial only when free access, owner access, provider license, key, positive request/unit limits and an unexpired UTC deadline are all configured; every gate remains fail-closed. No live access, spending, provider-data license or APK-accessible backend has been approved. Runtime fixtures are absent; missing configuration is an honest error while local restrictions remain usable. Tests with synthetic responses do not demonstrate live Colombian routes or current toll tariffs. Status remains `PARTIAL_DATA_REVIEW_AND_PROVIDER_ACCESS`; the Viaje PR must stay draft and unmerged until the separate live/physical gates are met.

VIAJE-R2 extends that same flow with the owner-approved responsive one-page hierarchy and a pre-trip map contract. Route geometry travels in the existing preview response and is never persisted. The map associates the selected geometry with the local 184-location toll inventory and the existing 360-camera ANSV pack. Counts distinguish physical locations from candidate passages; cameras remain `nearbyUnconfirmed`, historical toll locations are opt-in, and absent tariffs remain null. R2C adds a versioned, fail-closed review gate: six priority coverages were reviewed, zero reached `verified_executable`, and zero runtime rules were published. All 219 coverage rows, 261 dated rows, 73 rotation/validity rows and 74 explicit `NO PUBLICAR` rows remain accounted for. The runtime restriction asset is unchanged. Contract: `docs/contracts/VIAJE_R2.md`.

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
