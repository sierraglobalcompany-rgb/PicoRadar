# PicoRadar Current State

Fecha de recuperacion R00: 2026-08-27. Base auditada: `main` en `0905d394b0379665e4a9dd343045072582d976a0`.

## Invariantes vigentes

- Marca: **PicoRadar**.
- Titulo previsto en tiendas: **PicoRadar: Pico y Placa**.
- Navegacion inferior: **Inicio · Garaje · Apps · Viaje · Conducir**, con **Apps** siempre al centro.
- Free 1.0 funciona sin cuenta, sin monetizacion y sin cloud obligatorio.
- Pico y placa se evalua localmente desde datasets versionados.
- Conducir no envia GPS continuo, no consulta backend por cada posicion y no almacena historial GPS por defecto.
- Laravel es control plane, no backend transaccional del vehiculo activo, garaje, widget, pico de hoy, GPS history, camaras hot path, documentos privados, notification history ni cuentas obligatorias.

## Implementado en `main`

- Fundacion monorepo Flutter/Laravel con flavors Android `dev`, `staging`, `prod`.
- App shell Flutter con Riverpod, go_router y cinco tabs aprobadas.
- Drift schema v3 con `vehicles`, `vehicle_obligations`, `notification_preferences`, `dataset_versions` y `restriction_coverages`.
- Preferencias no sensibles, secure storage y cifrado AES-GCM para archivos privados.
- Motor local de manifest/dataset sync con verificacion SHA-256 de bytes descargados.
- Alta local de vehiculo, garaje raiz/detalle y vehiculo activo.
- Importador/evaluador local de restricciones y cobertura por jurisdiccion.
- Inicio/Pico con estado local y planificacion inicial de notificaciones.
- Launcher Apps y widget Android de acceso rapido en estado neutral/local.
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

Backend roadmap aprobado:
- B01 Dataset Publisher / Control Plane.
- B02 Routes / Places Proxy.
- B03 Admin Publisher.
- B04 Leads / Reports.

No construir backend para vehiculo activo, garaje, widget, pico de hoy, historial GPS, hot path de camaras, documentos privados, historial de notificaciones ni cuentas obligatorias Free 1.0.

## Drift / datos locales

`main` esta en schema v3. Tablas actuales:
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

R03 C13 Logic Integration + UI Restyle:
- recover C13 vehicle status logic from PR #16;
- integrate schema v4 and obligation/reminder/catalog tests;
- restyle presentation through recovered shared components.

B01 Minimal Dataset Publisher:
- build Laravel control plane for validated immutable dataset publishing.

C14+ resumes product functionality only after R01/R02/R03/B01 gates are green.

Bloques de recuperacion:
- A: Governance and source of truth.
- B: Design system and visual fidelity.
- C: Root UX and app shell.
- D: Local data and dataset pipeline.
- E: Vehicle status recovery.
- F: Backend control plane.
- G: Release QA and store readiness.

## Estado de release

No release-ready. Las razones actuales son visuales/gobernanza, no una necesidad de backend runtime: AppBottomNav no esta implementado como componente propio, el theme esta incompleto frente al baseline, Inicio no tiene CTA dominante de conduccion, "Cambiar vehiculo" no abre selector rapido H-005, Apps tiene overflow fisico en Mi A3 y los loaders usan spinners donde el baseline espera skeletons.
