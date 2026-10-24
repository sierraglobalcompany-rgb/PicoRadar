# PicoRadar SOP

## SOP-01 Change/Delete Gate

Antes de borrar, fusionar o mover archivos:
1. confirmar alcance del lote;
2. buscar consumidores con `rg --fixed-strings` del path/nombre exacto;
3. revisar Graphify para dependencias estructurales cuando aplique;
4. revisar `git log -- <path>` para trazabilidad;
5. verificar que el contenido normativo unico este en fuente canonica;
6. aplicar el cambio minimo;
7. ejecutar `git diff --check`;
8. correr gates mobile/server relevantes;
9. restaurar el archivo si se rompe capacidad runtime, CI o build.

No crear carpetas de archivo. Git conserva el historial.

## SOP-02 Design To Flutter

Proceso obligatorio para R01+:
1. localizar mockup/ref baseline;
2. leer `docs/DESIGN_CONTRACT.md`;
3. buscar shared component existente;
4. implementar la pantalla o componente;
5. ejecutar widget tests;
6. renderizar viewport 390x844 como minimo;
7. cubrir 360x800, 412x915 y textScale 1.0/1.5/2.0 en portrait; landscape solo aplica si un lote futuro lo autoriza explicitamente;
8. ejecutar al menos un smoke visual de superficie raiz en Android fisico cuando haya Mi A3 o dispositivo equivalente disponible;
9. registrar expected/actual/severity/fix;
10. iterar hasta declarar `VISUAL_FIDELITY=PASS`.

No aceptar UI con Critical/High mismatches, overflow, clipping, labels ilegibles/truncados/cortados, estado solo por color, controles sin semantics o espaciado que contradiga el baseline.

## SOP-03 Drift And Local Data

- Drift es la fuente central de queries persistentes.
- Vehiculos, preferencias, documentos y datasets son local-first.
- No crear historiales de GPS, viajes, documentos cloud o notificaciones por defecto.
- Toda migracion requiere version bump, path de migracion, test y evaluacion de riesgo sobre datos existentes.
- FK y constraints se prueban cuando protegen integridad.
- `dataset_versions` representa estado actual aplicado, no bitacora historica.

## SOP-04 Dataset Publisher

Cuando el publisher/control plane sea aprobado debe:
1. validar dataset y contrato;
2. producir manifest inmutable con version, origen, hash y metadata;
3. publicar artefactos estaticos/CDN;
4. permitir rollback seguro a version previa;
5. fallar cerrado si hash, origen o contrato no coinciden;
6. mantener backend fuera del hot path de GPS/camara.

No construir API diaria de "puede circular hoy" para la app Free 1.0.

## SOP-05 Export Integrity

- Git commit, PR y GitHub Actions son la autoridad canonica del codigo.
- ZIPs y manifests SHA de repo no son requeridos rutinariamente por lote.
- Cuando se solicite explicitamente un recovery/export ZIP, los hashes deben representar los bytes finales empaquetados.
- Generar manifests despues del contenido final, excluyendo archivos autorreferenciales cuando haga falta.
- Verificar 0 mismatch, 0 missing y 0 extra antes de entregar.

## SOP-06 Visual QA And Release Gate

Antes de PR visual o release:
- correr tests locales requeridos;
- capturar screenshots/goldens canonicos en 360x800, 390x844 y 412x915 cuando aplique a superficies raiz;
- comprobar no overflow en dispositivos pequenos;
- comprobar accesibilidad basica y textScale 1.0, 1.5 y 2.0;
- verificar orientacion portrait-only en superficies raiz de telefono salvo autorizacion explicita por lote;
- ejecutar al menos un smoke visual de superficie raiz en Android fisico cuando haya Mi A3 o dispositivo equivalente disponible;
- para Garaje R02B, comparar contra `docs/design/reference/garage_owner_v1.png` y registrar que los datos de demo no se conviertan en claims runtime;
- probar fisicamente cuando el lote toque camara, GPS, notificaciones OS, foreground/background, TTS/Bluetooth, HUD/brillo, bateria o lifecycle;
- verificar CI si GitHub Actions esta disponible.

Si GitHub Actions queda bloqueado por billing, reportar `CI_INFRA_BLOCKED_GITHUB_BILLING` sin editar workflows para evadirlo.

## SOP-07 Fast Visual Development Loop

Usar este flujo para cambios visuales R01+ cuando el alcance permita iterar sin tocar contratos de datos, codegen ni infraestructura.

### Fast Loop Gate

1. confirmar alcance y archivos autorizados;
2. editar el minimo componente visual necesario;
3. correr formato solo sobre los archivos Dart modificados;
4. correr analisis o tests focalizados cuando el cambio pueda romper layout, rutas o taps;
5. ejecutar `flutter run --flavor dev` en dispositivo/emulador disponible;
6. iterar con hot reload/hot restart, inspeccion fisica, screenshot y comparacion contra referencia;
7. repetir hasta que el candidato visual no tenga overflow, clipping, jerarquia rota ni tap targets dudosos.

No correr `flutter test` completo, build APK completo ni `build_runner` en cada microajuste visual.

### Candidate Gate

Cuando el candidato visual ya parece estable:

1. `flutter analyze`;
2. tests focalizados del lote o pantalla;
3. `flutter test`;
4. `flutter build apk --debug --flavor dev` cuando el lote toque Android/Home/recursos/plataforma;
5. QA visual fisica si el lote lo exige o hay dispositivo disponible;
6. evidencia ligera con screenshot final y SHA cuando el prompt lo solicite;
7. `git diff --check`.

### APK dev reproducible

Cuando el lote aprobado pide APK dev release, usar
`scripts/build_dev.ps1 -FlutterPath <ruta-a-flutter>` desde la raiz. La receta
incluye `--flavor dev --release --dart-define=APP_ENV=dev --no-pub`; no omitir
APP_ENV, porque Seguro oculta su demostracion fuera del entorno dev. La receta
no instala ni borra datos, no habilita publicidad real y no define un CDN ficticio.
Instalar solo despues de los gates del lote, conservando datos con `adb install -r`.
Comparar hash del APK construido e instalado y registrar dispositivo/QA restante.

### Release Gate

Antes de release o merge aprobado:

1. verificar CI canonico si GitHub Actions esta disponible;
2. correr gates de seguridad, privacidad, rendimiento, bateria o plataforma que correspondan al lote;
3. generar AAB/release solo cuando el lote o release manager lo pida;
4. confirmar que no hay secretos, artefactos pesados ni temporales dentro de Git.

### Codegen Gate

Antes de correr `build_runner`, revisar si cambiaron entradas de generacion: tablas Drift, rutas/anotaciones, modelos generados, assets declarados o configuracion que produzca codigo. Si no cambiaron, reportar `CODEGEN_NOT_REQUIRED` y no ejecutar codegen.

## SOP-08 Viaje Map Provider Gate

- `PICORADAR_TRIP_MAP_TILES_APPROVED` permanece `false` por defecto.
- No habilitar tiles por la sola presencia de una URL o credencial. Registrar primero proveedor, licencia de basemap y compatibilidad con la geometria de rutas.
- Configuracion aprobada: `PICORADAR_TRIP_TILE_URL_TEMPLATE` y `PICORADAR_TRIP_TILE_USER_AGENT`; nunca incluir secretos en `dart-define`.
- Tests usan `TileProvider` falso o fallback neutral; no solicitan tiles publicos.
- Un fallo de tiles no borra geometria, marcadores, conteos ni detalles del plan.
- Habilitar basemap no autoriza proveedor de rutas, gasto, deploy publico, GPS, background ni navegacion giro a giro.

## SOP-09 Regional Driving Simulation

- Owner-requested QA only: build dev debug with `--dart-define=PICORADAR_DRIVING_SIMULATION=true`. The normal APK and profile/release do not expose these controls.
- In Conducir, use the existing debug simulation controls: `Niquia -> La Estrella` or `La Estrella -> Niquia`. The active screen identifies the simulation; stop it before switching direction.
- Both scenarios use `mobile/assets/config/driving_regional_demo_v1.json`: independently computed local OSRM v5.27.1 driving geometries along the Regional/Norte/Sur corridor and legal station access connections, not the reversal of one coordinate list.
- Endpoints are vehicle-access points near Metro Niquia in Bello and Metro La Estrella in Sabaneta. The latter is not a station in Caldas. Distances returned by OSRM: 26,131.3 m southbound and 24,905.1 m northbound.
- The sampler advances at 80 km/h with one point per second, changing heading with the road geometry. This is a synthetic test speed, not a recommendation or a claim about legal speed limits. The final partial step stops at the endpoint.
- The route runs locally without the device location gateway or per-position backend calls. The existing camera dataset, matcher, alert settings and feedback remain authoritative; cameras are not invented to force an alert.
- The recording is public road geometry, not a stored user journey. Source URLs and OpenStreetMap attribution are inside the fixture. No account, permission, dependency or public service was added.
- Capture both directions with the simulation label, a camera episode if encountered, and manual stop. Whole-route offline tests exercise the complete geometry; short physical captures do not certify camera coverage, field GPS accuracy, Bluetooth or legal road suitability.

## SOP-10 Recuperación y continuidad en D:

- Entrada única: README → CURRENT → handoff de recuperación → lote. Documentos antiguos de consolidación y estados GSD se consultan como historial.
- Desarrollo principal en `D:/codex/PicoRadar` sobre NTFS, según clon limpio MIG-G1C (rama `recovery/20261019-modern`). Las rutas CAND-01…13 antiguas fueron trasladadas reversiblemente a la Papelera por una limpieza selectiva autorizada, sin vaciado; preservar el resto de C:, la Papelera, respaldos privados de D:, clones heredados y QA E:; no efectuar operaciones adicionales de limpieza o recuperación por esta SOP. Git con confianza de proceso para ruta exacta (nunca `*`), `core.autocrlf=false` y `core.longpaths=true`; no modificar seguridad ni configuración global. Worktrees nuevos solo por lote activo y fuera del checkout principal, por ejemplo `D:/codex/PicoRadar-worktrees/`. No recrear automáticamente los 12 de C:.
- Los SDK y cachés son dependencias instaladas legítimas; no son fuente de proyecto. Temporales voluminosos se dirigen a D: mediante variables del proceso.
- Reconstrucción independiente: crear clon desde GitHub únicamente si el destino no existe; fijar SHA/tree y comprobar `fsck`/alternates. MIG-G1C ya reportó `D:/codex/PicoRadar` limpio y autónomo, por lo que **no reclonarlo ni sobrescribirlo**. No copiar `.env`, código, vendor, `node_modules`, `.dart_tool` ni assets privados desde los checkouts originales para certificarla.
- Servidor: pruebas SQLite y migraciones en archivos nuevos sintéticos; MariaDB solo instancias locales efímeras de los scripts. Nunca usar bases reales ni consultar Hostinger.
- Rescate anterior: `D:/PicoRadar_Rescue` (histórico). G1A/G1B nuevos: `D:/codex/PicoRadar-migration-private/`, fuera de Git. G1A registró 720 WIP / 451.590.665 bytes y hashes verificados; G1B registró bundle íntegro, 196 ramas, 13 HEAD, bare independiente y `fsck` PASS. No publicar manifiestos, capturas WIP, bases, tokens ni secretos. La unidad D: USB no es respaldo independiente de sí misma. No formatear C: antes de verificar todos los componentes que solo existan allí.
- Logs completos privados; resumen sanitizado en handoff. CI solo acredita el SHA exacto ejecutado; filtros o billing bloqueados se registran sin evadirlos. QA física heredada permanece pendiente.
