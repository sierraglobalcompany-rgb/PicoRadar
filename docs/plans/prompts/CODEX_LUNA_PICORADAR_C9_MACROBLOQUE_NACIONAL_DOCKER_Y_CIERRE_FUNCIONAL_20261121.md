# CODEX LUNA — PICORADAR C9 · MACROBLOQUE NACIONAL, DOCKER AISLADO Y CIERRE FUNCIONAL

**EJECUTA: CODEX LUNA. DIRECTOR Y REVISOR: CHATGPT.** 21 de noviembre de 2026, Colombia. `TASK_ID=PICORADAR-C9-NACIONAL-DIRECTO-20261121`. Esta orden es ejecutable **después del retorno C8-V2**, no es un nuevo encargo de auditoría. **Realizar desarrollo, no otro preflight interminable.** Un solo coordinador reúne subagentes, verifica y entrega un único ZIP ligero. Los porcentajes anteriores NO son hitos automáticos.

## 0. Entrada exacta y estado que NO se debe redescubrir

- Repo: `sierraglobalcompany-rgb/PicoRadar`.
- **Rama de partida exclusiva C9 ya integrada y publicada:** `feat/C9-national-delivery-candidate-20261121`, commit **`10bc03bd03c0fb9e4091a57c1fd929257dc49591`**, tree **`4aa96addb8c58039583260192f569572296ea0fd`**. Partir del HEAD remoto actual de esa rama; si cambió, inspeccionar SOLO su delta. No restaurar ni reaplicar los adelantos independientes.
- Padre directo C8-V2: `c8664cd4f3105d945d17b5ded95c8e8e149283c6`, tree `eb98d81516574209e74a4bf3c3ca73b6b43b4bda`. C8 ZIP verificado SHA-256 `2fdbe0ca76a0b3eada1b2656d52b8fb15e79df54982a5481cf4c40c5f6edf187`; 12 miembros, 11/11 manifiesto, CRC PASS. **No reauditar ese ZIP**.
- PR #86 C7 Draft abierto con base `backup/picoradar-c6-source-20261120`, cabeza `9304aa8d…`; PR #79 histórico Draft; `main` en último corte `e9ef37511df3110ffb0fc006ef06be781df432ac`. **NO modificar ni fusionar** esos refs sin puerta indicada.
- **Se encuentran ya EN C9, NO cherry-pick:** (i) C8 con 5 archivos nuevos/modificados; (ii) consentimiento explícito de aliados en 3 blobs; (iii) fechas OTA `generatedAt`/`expiresAt` con zona explícita y pruebas; (iv) script Android 16 KB y siete tests sintéticos; (v) Docker QA aislado con seis archivos y siete tests estáticos. La integración fue un commit de árbol C8 + 10 archivos, sin superposición con los 5 paths C8; su ejecución funcional sigue pendiente.
- Recuperación C8 real: **A_SCOPE y B_PUBLICATION fueron escritos PERO NO ejecutados; C_CONSENT escrito PERO NO ejecutado**. Flutter/Dart faltaban de PATH en el clon aislado; Composer dejó `vendor` incompleto por ZIP bloqueado/autoload ausente, sin fallos PHPUnit observables. `php -l` del controlador y test PASS. No declarar los nuevos flujos PASS todavía.
- **Infraestructura obligatoria por concurrencia de varios proyectos:** PHP, Composer de pruebas, MariaDB y migraciones deben ejecutarse **en Docker Compose aislado**; NUNCA contra PHP/MariaDB/MySQL global del Windows ni bases ajenas. Existe `infra/docker/compose.qa.yml`, `server/Dockerfile.qa`, `scripts/run_picoradar_docker_qa.ps1`; la rama C9 ya los trae. Docker del PC fue reportado como disponible por el propietario; **no se ha certificado aún arranque de esta configuración**. Si no funciona, corregir causa local y continuar otros agentes.
- Checkout del dueño `D:\codex\PicoRadar`: **43 rutas WIP protegidas, NO tocar/limpiar/mover/restaurar/instalar allí**. Trabajar en clon limpio independiente `D:\codex\_isolated\PICORADAR-C9\source` o carpeta igualmente segura. No crear ni usar enlaces `junction` a proyectos vecinos. No tocar otros contenedores, servicios, caches compartidos destructivamente, certificados ni permisos globales.
- Producto Free 1.0: Flutter/Riverpod/Drift + Laravel 13, **Inicio · Garaje · Apps · Viaje · Conducir**, sin cuenta obligatoria, GPS/documentos privados locales, SIN publicidad comercial activa, pagos, premium ni WhatsApp. OTA nacional desde servidor, verificación hash y rollback. Prohibido afirmar `ALLOWED` / “Puede circular” por ausencia de datos: `UNKNOWN`, `STALE` y ausencia de jurisdicción permanecen explícitos. No editar normativa sin acto completo.
- **No pedir ni entregar APK/AAB**, TAR, source snapshot, dependencias, carpetas vendor, logs históricos. No usar teléfono físico ni deploy Hostinger. No ejecutar GitHub Actions si están bloqueadas por cuota. No repetir suites C2-C7 salvo conducta causalmente afectada por nuevos cambios.

## 1. Brecha demostrada y objetivos FUNCIONALES

Comprobación directa en C9: `mobile/assets/catalogs/pico_jurisdiction_catalog_v1.json` tiene **73** entradas y 73 DIVIPOLA distintos; `mobile/assets/catalogs/colombia_trip_municipalities_v1.json` contiene **1.104** entradas/1.104 DIVIPOLA y ya es consumido por Viaje. El selector `mobile/lib/features/pico_placa/presentation/pico_detail_screen.dart::_CitySelectorSheet` consume solo el catálogo de 73. `PicoJurisdictionCatalog.fromJson` valida exactamente los 73, sus 219 categorías y el resumen; **NO modificar ese dataset de procedencia ni falsear los 5 `engineEnabled` originales**. Catalogar los otros 1.031 municipios NO implica certificar su pico y placa.

**Entregables de producto de C9 (además de cierre de gates C8):**

1. **Móvil: búsqueda nacional de los 1.104 municipios dentro del selector de Pico y Placa** reutilizando el catálogo Viaje existente, con distinción rigurosa entre *municipio localizable*, *jurisdicción publicada consultable* y *jurisdicción sin información verificada*. Debe permitir encontrar municipios homónimos por departamento y código, sin rendimiento deficiente.
2. **Super Admin: acción desde la matriz municipal para preparar jurisdicción de un municipio sin asignación**, reutilizando creación y permisos existentes, precargando el municipio de forma segura; NO crea ni publica reglas sin revisión.
3. **CSV del Super Admin sin ambigüedad semántica:** el `scope=editorial` legacy representaba la última versión editorial, pero C8 lo cambió para exportar datos públicos mientras mantuvo su nombre. Restituir compatibilidad o separar explícitamente `editorial` (borrador/editor), `published` (asset nacional actual verificable) y `municipalities` (vista nacional); documentación/UI y tests consistentes. No romper cabeceras históricas ni protección antifórmulas; agregar solo la columna C8 ya presente `source_editor_version`.
4. **Cierre de pruebas C8 y mejoras ya escritas usando Docker aislado y SDK Flutter existente**; no volver a escribir su lógica si no existe defecto probado. Registrar PASS, FAIL o BLOCKED por separado. No confundir el 58 % histórico de producto con puntuación de evidencia 61/100 ni con 1.104 municipios registrados.

## 2. Paralelismo REAL: propiedad exclusiva de archivos, un integrador

En Codex habilitar agentes en paralelo SOLO si soportan checkout/directorios aislados; no compartir working tree ni archivos de compilación. **Un integrador es el único que publica en GitHub.** Si no hay subagentes disponibles, ejecutar tareas A/B/C en el mismo macrobloque secuencialmente, SIN pedir otra orden. Cada agente entrega sus cambios funcionales al integrador una vez; cada archivo tiene un solo dueño.

| Agente | Archivos de escritura | Entregable verificable | Dependencias / límites |
|---|---|---|---|
| **A — Flutter Pico nacional** | `mobile/lib/features/pico_placa/data/pico_jurisdiction_catalog.dart`, `mobile/lib/features/pico_placa/presentation/pico_detail_screen.dart`, tests nuevos/afectados de esas rutas | Selector nacional 1.104 DIVIPOLA, búsquedas correctas y estados seguros | Lee `trip_municipality_catalog.dart` y su JSON; no edita fuente congelada, reglas, OTA ni aliados |
| **B — Laravel Super Admin/CSV** | `server/app/Http/Controllers/Admin/JurisdictionController.php`, `server/resources/views/admin/jurisdictions/create.blade.php`, `server/resources/views/admin/restrictions/municipalities.blade.php`, `server/app/Http/Controllers/Admin/RestrictionRuleController.php` y tests focales | Alta asistida SIN escritura automática; CSV editorial/published no engañosos | Reusa `JurisdictionService`; no migraciones, no cambios a Publisher/roles/seed legales |
| **C — Infraestructura y QA** | `scripts/run_picoradar_docker_qa.ps1`, `infra/docker/*`, `server/Dockerfile.qa`, tests estáticos SOLO si falla un caso; documentación de ejecución | Docker limpio real, pruebas PHP focales; localizar Flutter SDK y ejecutar A/C8/OTA/consentimiento | No edita rutas A/B ni usa servicios globales. Nunca mete claves o dumps al repo |
| **D — Fuentes y campañas (optativo, solo lectura)** | Solo `LEGAL_SOURCES_DELTA.csv`/reporte, no runtime por defecto | Buscar actos oficiales COMPLETOS para un grupo NUEVO acotado de ciudades, declarar faltantes; verificar campañas Free OFF | No repetir Medellín/Bogotá/Cali C7; no publicar reglas ni encender publicidad |
| **Integrador** | Git, pruebas de intersección, manifest, ZIP, PR Draft | Una sola rama C9 funcional y trazable; integración `main` sin force-push | No realizar pruebas repetidas por agente ni fusionar a producción |

La falta de SDK Flutter, internet para descargar imágenes Docker, teléfono, HTTPS, actos legales o CI **no detiene que A y B implementen y publiquen código**. Estos bloqueos permanecen identificados y no se transforman en PASS.

## 3. A — selector Pico y Placa en toda Colombia (prioridad máxima)

1. Preservar el validador de 73 y 219 en `PicoJurisdictionCatalog.fromJson` y el asset original. Importar/reutilizar **`TripMunicipalityCatalog`** y `tripMunicipalityCatalogProvider` ya existente, únicamente como **índice de municipios**. Crear un adaptador puro mínimo, preferiblemente en `pico_jurisdiction_catalog.dart`, que combine POR **DIVIPOLA de 5 dígitos** los 1.104 registros Trip con los 73 registros Pico. No crear un cuarto JSON, otro modelo completo, otro endpoint ni esquema OTA nuevo. Identidades únicas, orden determinista y preferencia por denominación/departamento del catálogo nacional cuando falten en Pico.
2. Para entradas de los 73, conservar los metadatos de fuente/estado/evidencia y las restricciones de habilitación basadas en el dataset runtime. Para los restantes **1.031**, construir representación neutra `pending`, `engineEnabled=false`, sin enlace de motor ni prueba legal, con ID estable `co-mun-<DIVIPOLA>` (u otro identificador canónico sin colisión). **El campo `jurisdictionId` estático del catálogo Viaje NO autoriza activar el motor**: la autorización proviene del dataset efectivo instalado y su `consultationEnabled` + cobertura de categoría, nunca de estar en una lista.
3. Adaptar `pico_detail_screen.dart::_CitySelectorSheet` para esperar los dos catálogos sin duplicar carga ni perder el fallback en ausencia de uno: si el nacional falla, conservar el selector previo de 73 con aviso no engañoso. Mantener navegación y accesibilidad originales (`ValueKey`, taps, sheet). Evitar construir 1.104 widgets al abrir: para búsqueda vacía presentar un subconjunto manejable (p.ej. ciudades disponibles + invitación a buscar) y usar lista lazy o límite de resultados para búsquedas (p.ej. 40–80). Buscar por nombre normalizado, departamento y código DIVIPOLA; homónimos se diferencian por departamento. La búsqueda no debe generar centenares de llamadas Drift ni evaluar todas las ciudades: solo categorías runtime existentes.
4. Una ciudad sin datos verificados abre el sheet seguro YA existente: **«No hay información verificada para determinar si tiene restricción»**; nunca afirmar que está exenta. `UNKNOWN` / `STALE` siguen impidiendo un “Puede circular” confiable. Una ciudad realmente habilitada debe conservar el flujo de evaluación local existente. No migrar vehículos, no activar GPS, anuncios ni registros remotos.
5. Tests NUEVOS/CAUSALES: fusion 73+1.104 = 1.104 DIVIPOLA únicos; 1.031 neutrales sin motor; selección Medellín y al menos dos homónimos; búsqueda acentos/departamentos/código; municipio ausente abre consulta no disponible y no evalúa/avisa en verde; y municipio publicado mantiene flujo de evaluador. Usar `mobile/test/features/pico_placa/data/pico_jurisdiction_catalog_test.dart` y tests de pantalla solo afectados; NO correr todo Flutter.

**A_NATIONAL_SELECTOR=PASS** únicamente si funcionalidad y prueba focal ejecutada; si código escrito sin SDK reportar `IMPLEMENTED_UNEXECUTED` y proceder con B/D/GitHub.

## 4. B — flujo administrativo nacional REAL con reutilización KISS

**Ya existe** `JurisdictionController.create/store` + `JurisdictionService.create`, la ruta `admin.jurisdictions.create`, lista de 1.104 municipios y permisos `jurisdictions.edit`. **No crear un segundo editor ni una nueva API de asignación.**

1. En la fila `NO_JURISDICTION` de `municipalities.blade.php`, mostrar vínculo **«Preparar jurisdicción»** SOLO con permiso `jurisdictions.edit`. Enlazar a la creación EXISTENTE pasando `primary_geographic_unit_id` de ese municipio. Otros roles conservan estado solo lectura. No implementar botones de «publicar» ni cambios silenciosos de estado.
2. `JurisdictionController.create` recibe query opcional `primary_geographic_unit_id` **escalar entero** y valida que exista, esté activo y sea `level=municipality` antes de precargarlo. Arrays, IDs inexistentes/departamento, strings largas o `0` → sin preselección, sin 500 y sin mutación. En `create.blade.php`, usar old input válido del formulario prioritariamente y el ID precargado únicamente para `selected` del `<option>`. Falla de datos no puede crear jurisdicción; POST sigue validándose y usando `JurisdictionService` (sin esquemas ni mutaciones nuevas).
3. Revisar `RestrictionRuleController::streamEditorialCoverage` en C8: actualmente etiqueta `scope=editorial` pero lee el snapshot publicado. Es un **cambio de semántica respecto a C6/C7**. Resolver explícitamente SIN destruir compatibilidad: `scope=editorial` debe volver a representar cobertura de la versión editorial de cada jurisdicción, `scope=published` exporta cobertura nacional vigente y verificada, `scope=municipalities` conserva la matriz. Mantener filtros, CSV protegido de fórmulas y cabeceras estables: `source_editor_version` fue añadido por C8; no eliminar columnas. Indicar en el CSV y en la UI a cuál fuente corresponde cada descarga. No modificar contrato de datos públicos OTA por arreglar una exportación.
4. Tests focales: a) matriz con municipio sin jurisdicción → link para editor autorizado, 403/ausencia link para otro rol, GET select seguro; b) `scope=editorial` con editor v2 Draft y nacional v1 publicado → en CSV editorial se ve v2 y en published v1; c) rollback del dataset y assets corruptos permanecen UNKNOWN en published, editor no se interpreta como publicado; d) GET arrays/inyección CSV y filtro departamento siguen válidos. Reusar fixtures sintéticas de C8; no duplicar 3 suites generales.
5. Si surgen defectos del servicio de jurisdicción existente, solo corregir causalmente; no tocar migraciones, permisos de roles históricos, contratos legales ni crear otro generador nacional.

**B_ADMIN=PASS** exige tests PHP focales reales + php -l/Pint del delta. Si PHP no arranca, `IMPLEMENTED_UNEXECUTED`; no crear 3 nuevos prompts por Composer.

## 5. C — desbloquear QA usando Docker, sin interferir con otras aplicaciones

**Entrada ya escrita en C9:** `infra/docker/compose.qa.yml`, `server/Dockerfile.qa`, `server/.dockerignore`, `scripts/run_picoradar_docker_qa.ps1`, tests estáticos. La red es interna, MariaDB 11.8 temporal `tmpfs`, SIN `ports`, `container_name`, host bind mounts ni volúmenes persistentes; proyecto aleatorio por invocación. Mantener `/server/.env` excluido de imágenes; flags de anuncios, leads, cuentas y marketing OFF. Nunca ejecutar servicios Windows globales ni `docker compose down -v`, `system prune`, `volume prune`, `git clean`, `reset --hard`.

1. Solo sobre copia **limpia** de la rama C9 ya integrada: confirmar Docker Desktop Linux engine y Docker Compose disponible; registrar imagen/versión, no enumerar ni tocar otros proyectos. Ejecutar `scripts/tests/test_picoradar_docker_isolation.py` únicamente si esos scripts cambiaron; anteriormente pasaron 7/7 checks estáticos (NO significa Docker real).
2. Hacer una compilación Docker de app si cache/red funcionan. Probar `-Mode schema` (MariaDB sintética, migraciones, status), luego **un filtro** `-Mode test -Filter C8RestrictionCurrentCoverageTest` y, si el cambio B altera matriz/CSV, el test nuevo B. Si el wrapper reconstruye imagen en cada llamada, se permite una **mejora mínima que reutilice una imagen dentro de esa ejecución**; no convertir optimización de QA en otro proyecto. Por defecto PHPUnit usa SQLite `:memory:`; **no declararlo test MariaDB**. Para migraciones usar SOLO la BD temporal del contenedor.
3. Si Composer/Docker falla por red, pull de imagen o dependencia: un diagnóstico con error real y **como máximo una alternativa concreta aislada**. No borrar caches compartidos ni volver a `composer install` fuera de contenedor; informar `DOCKER_QA_BLOCKED_ENV` con comando/salida y continuar A/B/GitHub. No inventar PASS de PHPUnit porque pasó `php -l`.
4. Flutter: C6 pudo compilar un APK en un entorno distinto. Buscar SDK de lectura/ejecución en `Get-Command`, `where.exe`, variables `FLUTTER_ROOT`, caché de herramientas aprobada `D:\codex\_tool-cache` o SDK estándar; **no examinar ni modificar archivos fuente/caches de otros proyectos**. Si se ubica, ejecutarlo desde la copia C9 con configuración/cache **específica del proyecto**. No instalar Flutter global ni tocar PATH permanente. Si no existe y instalar en la carpeta aislada requiere descarga no disponible, registrar `FLUTTER_ENV_BLOCKED` y **no detener desarrollo**.
5. Pruebas Flutter focales cuando haya SDK: 
   - `mobile/test/features/pico_placa/presentation/bogota_scope_notice_test.dart` (C8, no ejecutada),
   - `mobile/test/features/home/data/partner_inquiry_client_test.dart` (consentimiento, no ejecutada),
   - `mobile/test/core/sync/dataset_sync_service_test.dart` **filtrada a las 2 pruebas nuevas de zona horaria** cuando sea posible,
   - tests nuevos/afectados del selector nacional A.
   `dart format --output=none --set-exit-if-changed` y `flutter analyze` SOLO archivos que cambian; NO `flutter test` completo ni build APK por rutina.
6. `scripts/android_16k_audit.py` y tests sintéticos ya están en C9. No recrearlos. Si hay un artefacto Android **local del mismo HEAD comprobado**, usar el verificador en el host sin adjuntar APK; `PASS_STATIC_APK` no acredita Play, firma release ni teléfono. Si solo existe APK C6, etiquetar `OLD_BINARY_NOT_C9` y no certificar C9. No disparar build pesado solo para sumar un gate.

## 6. D — ámbito legal y campañas sin falsos positivos (no bloqueante)

- No repetir investigación C7 de Medellín/Bogotá/Cali sin un hecho nuevo. Si existe agente libre, recopilar para **máximo 3 jurisdicciones adicionales relevantes** actos COMPLETOS oficiales vigentes (decreto/resolución, fecha exacta, vehículos, horario, perímetro, exenciones, fuente), registrar `VERIFIED_ACT_COMPLETE` o `UNCONFIRMED`, con URL y fecha de consulta. No publicar drafts/OTA automáticamente; **no inventar cobertura legal nacional**.
- Publicidad, Sponsors, campañas, control de permisos, operador y validación de catálogo ya existen. El contrato de Free 1.0 conserva `CAMPAIGN_PUBLIC_CATALOG_ENABLED=false`, `PARTNER_INQUIRIES_ENABLED=false`, pagos y anuncios OFF; el consentimiento anterior solo se considera ejecutado si su prueba focal pasa. **No escribir otro módulo de publicidad por no encontrar marketing activado**. Si detecta defecto causal con evidencia y tiempo, informar con archivo/test y dejarlo al integrador; no interferir con A/B.

## 7. Integración GitHub SIN ping-pong y NO volver a rehacer `main`

1. Tras integrar A/B y solucionar solo fallos causales, publicar C9 mediante push normal desde **un único integrador**, comprobar HEAD/tree remoto y árbol limpio. No crear 10 ramas de producto ni re-auditar el respaldo C6; **las tres ramas preparatorias ya están integradas a C9**. No modificar PR #86, #79, `main`, ni checkout WIP. Registrar que los diez archivos de infraestructura/OTA/Android ya estaban en la base de C9.
2. Crear **UN Draft PR C9 contra rama C8** cuando el código esté materialmente implementado, incluso si Flutter/Docker está bloqueado, pero describir `IMPLEMENTED_UNEXECUTED`, gates y límites con precisión. No merge. Solo un PR nuevo; no abrir PR por agente ni para preparatorios. Esta visibilidad facilita retomar en otro chat.
3. **Puente seguro hacia `main` como trabajo final solo si A y B tienen QA ejecutada y análisis de integración satisfactorio.** `main` y árbol C9 carecen de ancestro útil común; no ejecutar merge recursivo ni force-push. La estrategia propuesta es un **commit explícito de reconciliación** en rama `integration/C9-main-history-20261121` con **primer padre HEAD de `origin/main`, segundo padre HEAD de C9 y árbol EXACTAMENTE igual al C9 aceptado**. Esta estrategia conserva ambas historias y representa de forma revisable la decisión de reemplazar el árbol legacy. Solo ejecutarla tras verificar la eliminación intencional de los dos paths exclusivos main (`RootPlaceholderScreen`, `HomeBannerSlot`), todos los assets/versiones/paquetes y controles de seguridad. No reintroducir el slot obsoleto solo porque `main` lo usa; comprobar que el Home moderno funciona y no lo importa. Si se prepara el puente, abrir **Draft PR contra main**, no fusionar sin aprobación del dueño. Si no pasan gates, dejar `MAIN_BRIDGE_HOLD` preciso sin retrasar los resultados A/B.
4. No ejecutar CI remota si hay cuota agotada. Seguridad focal de cambios nuevos: `git diff --check`, patrones de secretos y ausencia de `.env`, credenciales, `.sqlite`, APK/AAB, TAR, datos de placas, llaves y configuraciones externas. Falso positivo de escáner → revisión motivada, no saltarse validación. Si herramienta estándar no está en PATH, decir `SCANNER_UNAVAILABLE`; no declarar escaneo completo.
5. No modificar ni desplegar servidor de producción, Hostinger o apps de otros proyectos. Nada de llamadas HTTP con PII ni GPS remoto. No instalar la APK en el Xiaomi Mi A3 sin autorización.

## 8. Resultado cuantificado y definición de PASS (sin métricas inventadas)

| Indicador | Base cierta hoy | Acreditación que C9 puede producir |
|---|---|---|
| Catálogo territorial Viaje | 1.104/1.104 DIVIPOLA presentes en asset | No es cobertura legal ni QA de restricciones |
| **Selector Pico actual** | **73/1.104 municipios catalogados para Pico** ≈ 6,6 % de disponibilidad de selección | `PICO_SELECTOR_NACIONAL=1.104/1.104` solo si UI+código+test lo demuestran; 1.031 sin reglas verificadas siguen UNKNOWN |
| Fuente jurídica y motor | 73 municipios catalogados, 219 categorías históricas; calidad de reglas desigual | No inventar nuevas reglas; reportar cuántas coberturas PUBLICADAS y VIGENTES cuentan con acto verificable (si hay insumos) |
| C8 test PHP/Dart | `WRITTEN_NOT_EXECUTED` | Ejecutar 1 vez en ambiente aislado; PASS o FAIL exacto |
| OTA zoned timestamp | Código + 2 tests escritos, aún no ejecutados | PASS solo al pasar tests Flutter focales |
| Docker QA / Android 16 KB | 7 tests sintéticos cada uno reportados PASS; runtime Docker no ejecutado | Docker PASS solo con `docker compose` real; Android 16 KB static no es QA Play |
| Evidencia global | **61/100** última matriz firme; no hay nueva ponderación | No aumentar automáticamente por datos, commits ni tests. Actualizar solo gates con definición y prueba, dejando denominador explícito |
| Producto integral | 58 % histórico / 83 % núcleo histórico, ambos **NO certificados** | No sustituir por porcentaje inventado; reconstruir métrica solo con inventario completo y aceptación funcional |

**Resultado A/B aceptable:** funcionalidad implementada + tests específicos ejecutados y PASS. **Resultado útil pero parcial:** código subido con diff/QA `IMPLEMENTED_UNEXECUTED`, sin falsa certificación. No terminar C9 solo con verificación documental si A/B aún pueden implementarse sin herramientas externas.

## 9. Macrobloque y gates finales exactos

- **G0_SOURCE**: branch C9 y árbol esperados, limpio y solo copias aisladas.
- **G1_NATIONAL_PICKER**: 1.104 DIVIPOLA, 73 previos intactos, neutralidad jurídica y búsqueda eficiente, pruebas focales.
- **G2_ADMIN_ONBOARDING**: acceso desde `NO_JURISDICTION` por permisos correctos, municipio precargado sin mutación, tests.
- **G3_CSV_SOURCE_SEPARATION**: `editorial` ≠ `published` en datos, `municipalities` mantenido; pruebas del caso v1 publicado/v2 Draft y CSV seguro.
- **G4_C8_REGRESSION**: validar **solo** C8 current release + C7 matriz afectada + Bogotá y consentimientos que estaban escritos sin ejecutar; no repetir suites totales.
- **G5_OTA**: dates timezone (`Z`/offset) y fallos sin zona; no apagar OTA ni inventar fecha.
- **G6_DOCKER_DB**: migración sintética en contenedor `mariadb`; tests PHPUnit SQLite memory distinguidos; Docker no certificado si no arranca.
- **G7_ANDROID_STATIC**: script 16KB sintético (ya cubierto) y evidencia de APK real solo si existe del mismo HEAD; no nuevo build ni Play PASS.
- **G8_GITHUB**: C9 remote y PR Draft con gates, ninguna rama del dueño destruida; main Draft solo si puente QA aprobado.
- **G9_LEGAL_RELEASE**: normas nuevas solo si completas; `RELEASE=NO_GO` hasta Android real, HTTPS autorizado, actos y UX final.

**Regla anti-ping-pong:** si un gate falla, corregir la causa una vez dentro del MISMO bloque, correr prueba causal una vez más y continuar. No reescribir contratos, no informes separados ni consultas al director por errores solucionables. Entregar un diagnóstico honesto cuando la causa sea externa. Los agentes no reauditan 10+10: lo hace el director sobre este prompt.

## 10. ÚNICA entrega ligera para el director

Crear **un solo ZIP** `PICORADAR_C9_RETORNO_UNICO_LIGERO.zip`, objetivo ≤2 MiB / máximo 5 MiB, con `FINAL_REPORT.md`, `GATES.csv`, `CHANGELOG_DIFF.md`, `GITHUB_STATUS.md`, `QA/` registros *focales y legibles* (comando, cwd, exit, tests/assertions, Docker project ID anonimizados), `LEGAL_SOURCES_DELTA.csv` solo si hay nuevas fuentes, `MANIFEST.csv` SHA-256/CRC32/bytes de todos los demás miembros. Un patch textual saneado SOLO si cabe y añade valor; GitHub lleva código fuente. Validar ZIP, manifest y hashes antes de responder. **No incluir APK/AAB, instaladores, TAR, dumps DB, `vendor/`, SDKs, llaves, credenciales ni imagen Docker.** Código completo y pruebas en GitHub.

La respuesta de Codex debe tener una sola línea de resumen y enlace al ZIP local:
`TASK=PICORADAR_C9 | RESULT=... | A_NATIONAL_SELECTOR=... | B_ADMIN=... | B_CSV=... | C8_PHP=... | C8_FLUTTER=... | OTA=... | DOCKER=... | GITHUB_HEAD=<sha> | PR=<n> | MAIN_BRIDGE=... | RELEASE=NO_GO | ZIP_PATH=<ruta> | ZIP_SHA256=<sha> | NEXT=CHATGPT_DIRECTOR`.

## 11. Auditoría del director — 10 VERDUGO + 10 JUEZ (ya realizadas, NO ejecutar en Codex)

| # | VERDUGO: error anterior perseguido | JUEZ: resolución exigida |
|---|---|---|
| 1 | C8 escribió 5 archivos y no ejecutó ninguna prueba | C9 incluye Docker aislado; PASS exige ejecución real y errores honestos |
| 2 | Composer falló por ZIP de vendor bloqueado en Windows | No reinstalar Composer global; imagen Docker copia lock y aísla deps |
| 3 | SDK Flutter ausente detuvo gates pero no debería detener código | SDK read-only acotado; desarrollo A/B continúa aunque falte |
| 4 | Retomar CSV sin revisar contrato significa `editorial` ambiguo | Tres scopes con significado explícito, compatible con versión C7 |
| 5 | 73 municipales para Pico cuando Viaje ya tenía 1.104 | Reusar asset existente, cruzar DIVIPOLA, no crear cuarto catálogo |
| 6 | 1.104 nombres se pueden confundir con normas verificadas | 1.031 adicionales neutral/UNKNOWN; ninguna regla fabricada |
| 7 | 1.104 widgets en un selector podrían congelar Android | Resultados acotados/lazy, búsqueda normalizada, no Drift masivo |
| 8 | Crear jurisdicciones desde cero duplica editor vigente | Reutilizar JurisdictionController y servicio, únicamente preselección segura |
| 9 | Integración main sin ancestro causó 1.082 diferencias | Puente con árbol exacto y dos padres, SOLO tras QA, PR Draft sin merge |
| 10 | Proyectos Codex concurren y pisan PHP/DB/caches | Docker por proyecto efímero sin puertos ni volúmenes compartidos; checkout WIP intocable |

**SIGUE AHORA: CODEX LUNA. NO REINICIAR POR RUTINA. EJECUTAR C9 EN UN SOLO MACROBLOQUE.**

**DESPUÉS DEL ZIP C9 SIGUE CHATGPT DIRECTOR PARA REVISIÓN DIFERENCIAL, GATES Y PRÓXIMO CIERRE FREE 1.0.**
