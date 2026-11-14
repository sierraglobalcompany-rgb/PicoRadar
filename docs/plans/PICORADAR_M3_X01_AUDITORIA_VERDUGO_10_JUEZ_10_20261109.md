# PICORADAR — AUDITORÍA ADVERSARIAL DOBLE: 10 VERDUGO + 10 JUEZ

**Corte:** 2026-11-09 Colombia. **Director responsable:** ChatGPT. **Objeto:** cuestionar la orden `PICORADAR-M3-X01-LARAVEL-MANIFEST-FLUTTER-CONTRACT-20261109-DIRECTOR`, confrontarla con el repositorio real y las seis leyes, corregir errores materiales sin abrir un nuevo ciclo.

**Resultado:** `V1_REJECTED_AS_WRITTEN → V2_APPROVED_FOR_ONE_SCOPED_QA_RUN`. No es aprobación del código ni de un release; **cero pruebas PHP/Flutter del puente fueron ejecutadas en esta auditoría**. La comprobación realizada es análisis estático de contratos y de decisiones; Codex deberá ejecutar la prueba para producir un resultado de runtime.

**Prompt V2 completo:** `docs/plans/CODEX_LUNA_PICORADAR_M3_CONTRATO_REAL_LARAVEL_FLUTTER_20261109.md`; respaldo local `[CODEX_LUNA_PICORADAR_M3_CONTRATO_REAL_LARAVEL_FLUTTER_20261109_AUDITADO_V2.md]`; 29,560 bytes y SHA-256 `6865b90c31aaa9d4821bdd752f6143d35ea5f087538f8f1342d5cffbacdd4d9f`. **Mismo TASK_ID, sin M3-X01-C2.**

## Evidencia base que realmente se inspeccionó

- Repo `sierraglobalcompany-rgb/PicoRadar`: rama moderna `recovery/20261019-modern`, PR #71 Draft SHA `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`; PR #79 Draft documental, fuente Plan Maestro/contrato activo. `AGENTS.md` SHA `39091e67ff6ecaf4da880ed8c2be0ac1f5273fbf`; leyes en PingPongLaw SHA `0f6e7b4e62d8660c846f135e18dded629d29e0da`.
- `server/app/Services/RestrictionPublicationService.php` SHA `1fb78bd792871345f2a1e813f5bcf0246888f859` → `publishVersions` valida versiones, usa `RestrictionPayloadEncoder`, `DatasetReleaseValidator`, `DatasetPublisher` y genera versión opaca `rN-<hash>`.
- `server/app/Services/DatasetPublisher.php` SHA `3ba83febca01bab546b1e6260b720288ae4671f2`: publica bytes inmutables y llama a `ManifestPublisher`; **no sustituye la ruta específica de reglas**.
- `server/app/Services/ManifestPublisher.php` SHA `7cf044dd473924fa2f3c13fb3e35e26e732fc1ca` genera `manifest/v1/manifest.json` y URL desde `DATASET_PUBLIC_BASE_URL`; config `server/config/datasets.php` (blob no requerido para el dictamen), base URL por defecto `/storage`.
- `server/tests/Feature/RestrictionPublicationServiceTest.php` SHA `f84788a53fc0594b1739265acdd1498b31f3e272` ya posee fixtures sintéticas `co-alpha/co-beta` y usa `Storage::fake` y SQLite de testing.
- `mobile/lib/core/sync/dataset_sync_service.dart` SHA `ae27aabaf8136e2ffb75062204311a84e5cec3aa`: `_syncDataset` descarga, SHA, metadatos y transacción, usa `publicationRevision`, puede omitir el mismo version/hash instalado; `_resolveDatasetUri` exige mismo origen.
- `mobile/lib/core/sync/dataset_manifest.dart` SHA `f9986472a63aa48ae6e1c7d7d9c1ce28b481747a` exige manifest esquema 1 y revisión positiva; `mobile/lib/features/pico_placa/data/restriction_dataset.dart` SHA `cddba047fa7a99d31735c32d16ff4d94af8486bd` exige dataset esquema 1.
- `mobile/test/core/sync/dataset_sync_hardening_test.dart` SHA `195ee524011f50cf6abc8983977a037a907c8417` ya tiene Python compilador → HTTP → Drift → engine; `server/tests/Feature/DatasetPublisherTest.php` SHA `bdbb2b3f01339b213c918bd403f2fd7ae5dedc1a` ya valida publicación, rollback y manifest. **Tener esos tests no prueba el puente específico Laravel→Flutter**.
- El checkpoint anterior de M1 fuentes conserva cinco reglas NO READY, candidato C1 sin integrar, 101 WIP sin auditar y ausencia de prueba de Flutter en ese lote. Estos hechos no se transforman en PASS por la orden nueva.

## Primera audiencia — VERDUGO: diez pasadas adversariales

| # | Qué hice / evidencia confrontada | Acusación adversarial | Severidad y resultado |
|---|---|---|---|
| **V1** | Contrasté el objetivo M3-X01 con §D del Plan Maestro y `AGENTS.md` (prioridad de dependencias). | M3.1 exige M2.2 y M2.4; un test aislado podría etiquetarse falsamente «M3 terminado» con M1 legal 0/5. | **ALTA: condicionar** como experimento preparatorio, no macro M3 aceptada. |
| **V2** | Enumeré tests existentes en PHP y Flutter y busqué el recorrido Python→HTTP→Drift ya cubierto. | Otro test Python→Flutter, PHP→manifest o duplicación de suites sería puro ruido. | **ALTA: estrechar** a bytes efectivos de Laravel→Flutter y prohibir duplicados. |
| **V3** | Leí `RestrictionPublicationService::publishVersions` frente a `DatasetPublisher::publish` y pruebas PHP. | La V1 permitía `DatasetPublisher` genérico; podría evitar completamente serialización/revalidación y revisión de reglas. | **CRÍTICA: rechazar V1**; exigir transición por `RestrictionPublicationService::publish`. |
| **V4** | Comparé `ManifestPublisher::url` y config `/storage` con `_resolveDatasetUri` de Flutter. | Una normalización manual de URL haría pasar un contrato imposible sin detectar origen distinto o ruta mal resuelta. | **ALTA: corregir**; manifest literal de Laravel, CDN loopback solo inyectado en test. |
| **V5** | Inspeccioné `_validatePublicationOrder`, condición `skippedCurrent` y versión opaca `rN-...`. | Probar un solo asset instalado deja un negativo falso: la app ni descarga una versión que cree actual. | **CRÍTICA: corregir**; dos releases y `publicationRevision` creciente; negativo de v2 contra v1 en DB limpia. |
| **V6** | Confronté el formato `schemaVersion=1` del backend moderno y Dart con C1 local schema2 pendiente. | Un `BRIDGE_PASS` esquema1 se podría presentar como aprobación de la corrección C1 o de 2026 nacional. | **ALTA: limitar** el dictamen a schema1 y mantener C1 `NOT_INTEGRATED`. |
| **V7** | Revisé `Storage::fake`, rutas de test PHP y consumo desde prueba Dart. | Un test PHP aislado puede crear bytes en su propio filesystem, mientras Dart lee fixtures diferentes; dos PASS engañosos. | **CRÍTICA: corregir** `PROVENANCE.csv`, snapshots v1/v2 y comprobación SHA independiente byte-a-byte. |
| **V8** | Cotejé la expectativa de Flutter disponible con los bloqueos Flutter históricos de C1 y los gates de `AGENTS.md`. | Generar harness sin SDK o instalar herramientas fuera de alcance solo produce otra ronda estéril. | **ALTA: adelantar guard** de entorno y cerrar `BLOCKED_ENV` sin implementar puente imaginario. |
| **V9** | Verifiqué el motor y los `unknown/stale`, fechas, esquema, reglas sintéticas y restricciones de datos. | Casos dependientes del reloj real, campos extra de fixture o regla comercial activada pueden dar falso verde o fuga. | **ALTA: fijar** reloj, datos sintéticos, aislamiento, fail-closed, sin tocar datos productivos. |
| **V10** | Revisé alcance de archivos, salidas ZIP, WIP, CI, Git, APK y condición `BRIDGE_PASS`. | El reporte podía llamar «rollback» a solo rechazar bytes malos o etiquetar PASS parcial como release; PR79 solo documental. | **ALTA: redefinir** estados, trazas, no merge, sin confundir rechazo cliente con rollback servidor. |

**Veredicto del VERDUGO:** `ORDER_V1_NOT_SAFE_AGAINST_FALSE_PASS`, por V3/V5/V7; no autorizar ejecución de V1 sin parche contractual de instrucciones. La función objetivo es válida; **no** cambiar Flutter/Laravel para tapar una prueba mal diseñada.

## Segunda audiencia — JUEZ: diez pasadas de contraste, refutación y decisión

| # | Prueba favorable y cuestionamiento de la acusación | Decisión judicial fundamentada |
|---|---|---|
| **J1** | Leí la jerarquía `AGENTS.md` y Plan Maestro: permiten pruebas en entorno aislado sin release; M3 real exige M1/M2 completos. | **Mantener el experimento** solo como `M3-X01_PREPARATORY`, sin declarar dependencias satisfechas ni modificar M1/M2. |
| **J2** | El repo contiene `DatasetPublisherTest` y `dataset_sync_hardening_test`; el puente de **bytes publicados por Laravel específico** no aparece demostrado en la evidencia existente. | **Merece un único ensayo focal**, no una reimplementación de sync/manifest ni toda una suite nueva. |
| **J3** | `RestrictionPublicationService` llama internamente al `DatasetPublisher` real y agrega validación, versiones de ciudad y `RestrictionPayloadEncoder`. | **Exigir servicio específico** como fuente v2; baseline v1 genérico en fixture sintética existente no invalida la procedencia de v2. |
| **J4** | Una URL `/storage/...` puede resolverse correctamente bajo CDN loopback y satisface mismo-origen; no hay un bug demostrado solo por usar URL relativa. | **No parchear URL ni aplicación**; testearla literalmente y entregar RED solo si falla. |
| **J5** | Con `publicationRevision` positiva, el motor móvil admite versión opaca; el caso `skippedCurrent` está diseñado para evitar descargas redundantes. | **Crear dos estados reales** y ejecutar negativo desde otra Drift DB con v1 instalada y v2 corrupta, de modo que sí intente descarga. |
| **J6** | Laravel `DatasetReleaseValidator` y Dart exigen schema1, que es el contrato remoto actual; C1 fue una rama local aparte. | **Aceptar PASS solo schema1**; no exigir migrar schema2 en esta prueba ni esconder el pendiente C1. |
| **J7** | `Storage::fake('local/public')` ya se usa en PHPUnit; el artefacto entregado puede exportarse sin alterar el producto si se aísla. | **Reutilizar los fakes** y exportar los cuatro archivos finales de test sin reserialización, con `PROVENANCE.csv`. No nuevo servidor. |
| **J8** | El contrato `AGENTS.md` exige análisis, tests y build según componente; una prueba focal aislada puede ejecutarse sin aceptar release, pero no suplanta CI. | **Un guard de entorno**; `NOT_RUN` siempre separado de PASS. Si SDK faltante, ZIP de bloqueo y no abrir M3-X01-C2. |
| **J9** | Sintéticos `co-alpha/co-beta`, URI `example.test` y pruebas loopback existentes permiten QA sin PII ni normas colombianas reales. | **Conservar arquitectura KISS**. Establecer `APP_ENV=testing`, storage/SQLite efímeros y fecha fija de Bogotá. |
| **J10** | Un ZIP manifiesto+logs+bytes+parche limitado es auditabilidad suficiente para una prueba focal; 101 WIP no son dependencia para calcular SHA de un fixture. | **Autorizar V2 una sola vez**, Codex solo ejecutor; ChatGPT audita después. Sin releases, CI verde, deployment ni publicación comercial. |

**Veredicto del JUEZ:** `ORDER_V2_APPROVED_FOR_ONE_SCOPED_QA_RUN`. No se ha demostrado ningún bug de producción por la auditoría. Sí se demostraron **defectos del diseño de la orden V1**, ahora corregidos.

## Decisiones inamovibles y límites antiping-pong

1. **Mismo TASK_ID:** `PICORADAR-M3-X01-LARAVEL-MANIFEST-FLUTTER-CONTRACT-20261109-DIRECTOR` y mismo archivo canónico. No V3/C2/preflight independiente.
2. **Prueba buena:** `RestrictionPublicationService` (Laravel) → dos snapshots de manifest + bytes publicados → HTTP loopback de test → `DatasetSyncService` Flutter → Drift/engine, y negativo v2 corrupto sobre segunda DB con v1. Igualdad SHA real y `publicationRevision` observada.
3. **Si falta entorno:** `M3_X01_BLOCKED_ENV` sin tests inventados; no tocar sistema para instalar toolchain. Los tests históricos solo se reutilizan con identidades de gate compatibles.
4. **Si hay mismatch real:** `M3_X01_CONTRACT_GAP_CONFIRMED`, RED, diff, alternativas; **no** parches productivos por iniciativa de Codex.
5. **Git/WIP protegidos:** pre/post checkout idénticos o STOP; 101 WIP `NOT_VERIFIED`; ningún cambio de JSON legal, real TTL, PII, Android, producción, PR71/main.
6. **Una entrega:** UN ZIP con `FINAL_REPORT.md`, `CONTRACT_MATRIX.csv`, `PROVENANCE.csv`, `SYNTHETIC_BYTES_MANIFEST.json`, manifests v1/v2 y payloads v1/v2 si realmente generados, logs PHP/Flutter, `GATES.csv`, diez controles operativos, patch únicamente si se cambió test, CRC/SHA manifiesto, resultado explícito y `NEXT_ACTOR=CHATGPT_DIRECTOR`.

## Ruta de cierre del producto (mantener, no rediseñar)

| Etapa | Siguiente hito real | Gate que impide falsos DONE |
|---|---|---|
| **M1** | Continuar autoridades y documentos faltantes, cobertura municipal×vehículo, exenciones, vigencias, cartografía; 0/5 reglas del núcleo siguen NO READY. | Ninguna regla activa sin fuente oficial completa y revisión humana. |
| **M2** | Reusar motor y compilador; agente lector/proponente solo después de aprobar contratos y entradas nacionales verificadas. | No añadir backend/worker paralelo; Laravel único publicador y ninguna regla inferida. |
| **M3** | Completar **un único puente sintético de esquema1** Laravel→Flutter, luego pruebas de sync/publicación/rollback con datasets autorizados, sin perder datos offline. | `BRIDGE_PASS_SCOPED` no es `M3 DONE`. Requiere pruebas de configuración real y artefacto SHA final. |
| **M4** | Admitir y probar C1 schema2, auditar WIP, validar CI, JNI/arranque, Android físico, firma, privacidad, seguridad y aprobación humana. | Release GO solo con evidencia física, CI y permiso expreso. |

**Quién sigue:** `CODEX LUNA` con la **V2 del mismo M3-X01** si aún no lo ejecutó. Si ya está ejecutando la V1, **no reiniciar**: pedirle evidencias y que la auditoría posterior aplique estos criterios; los controles nuevos no satisfechos quedan `PARTIAL`/`NOT_VERIFIED`.

**RELEASE=NOT_APPROVED · PUBLISH_ALLOWED=NO · NO_PUSH_CODE · NO_MERGE · NO_DEPLOY.**