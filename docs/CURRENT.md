# PicoRadar Current State

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
- Laravel 13 scaffold con tests base; sin API de producto implementada.

## Backend forense

| Area | Estado | Decision |
|---|---|---|
| `server/routes/web.php` | Ruta `/` Laravel scaffold | KEEP |
| Controllers de producto | No existen | MISSING BUT NEEDED FREE 1.0 para B01+ |
| Models de producto | No existen; solo `User` scaffold | SCAFFOLD ONLY |
| Migrations | Usuarios, cache, jobs, sesiones Laravel | SCAFFOLD ONLY |
| Jobs/Commands de producto | No existen | MISSING BUT NEEDED FREE 1.0 para publisher/admin |
| Tests server | Example tests Laravel | SCAFFOLD ONLY |
| Config/env | `.env.example`, sqlite local/CI | KEEP |

Backend/control-plane esta materialmente pendiente. El roadmap C00-C29 original sigue siendo la autoridad para responsabilidades backend: C22 Routes/Places proxy, C25 Reports/Leads, C28 Admin/control plane + dataset publisher y C29 hardening. R00 recomienda adelantar la fundacion publisher/control-plane de C28, pero cualquier numeracion B00/B01 es propuesta hasta aprobacion explicita. No implementar capacidades duplicadas entre Bxx propuesto y Cxx aprobado.

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
| Backend publisher | NEEDED | NOT_STARTED | N/A | NOT_STARTED | NOT_STARTED | NOT_STARTED |
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
- schema v4, obligation/reminder/catalog tests and C13 vehicle status logic remain recovered.
- R03 route/product contract is frozen in `docs/design/R03_REFERENCE_PLAN.md`.
- `/pico?vehicleId=<id>` is **Mi Pico y Placa** personalized vehicle detail.
- `/pico` is **Pico y Placa de la ciudad** regulation overview.
- The Home card is labeled `Pico y placa` while keeping contextual secondary content such as tomorrow/next restriction state; its tap continues to use the focused vehicle.
- R03B is blocked until owner-selected references exist for `soat_owner_v1.png` and `rtm_owner_v1.png`.
- SOAT and RTM current logic remains valid, but their current presentation is owner-rejected visual debt for R03B.

C10B National Pico rollout:
- `docs/data/PICO_JURISDICTION_COVERAGE_AUDIT_20260830.md` is research authority only.
- Candidate cities from the audit are not runtime jurisdictions until a separate approved C10B lot.

B00/B01 proposed backend split:
- bring forward the C28 control-plane/dataset-publisher foundation only if explicitly approved.

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
