# PICORADAR — DICTAMEN FORENSE DIRECTOR V6-R3 Y PLAN V6-R4

Fecha de revisión: **13 de noviembre de 2026** (Colombia). Estado: **`PARTIAL_IMPLEMENTED_FLUTTER_NOT_RUN_ENV` corroborado**; `PRODUCT_RELEASE=NO_GO`. Este dictamen NO certifica ejecución Flutter ni Laravel con base real ni una actualización nacional publicada.

## 1. Evidencias inspeccionadas personalmente

- ZIP recibido: `PICORADAR_V6R3_NATIONAL_BULK_OTA_EVIDENCIA_UNICA.zip` de **85.219.088 bytes**, SHA256 `0af760617d38ddeb2a1197822a33a713857e80c6ff0cf835b41c389be86e311b`, **44 entradas**, CRC PASS, **43/43 SHA+bytes del MANIFEST** correctos.
- Bundle `GIT/PicoRadar-V6R3.bundle` íntegro. Clon independiente requirió checkout explícito de la rama porque el bundle no define `HEAD` simbólico predeterminado (esto NO es corrupción). `git bundle verify` PASS, `git status` limpio. Commit `8d4ece555f563b77aa76e88cd48329609c5e50cb`, tree `6371302314d57c8e6a0ac62955984a4414f85f85`, parent V5 `2b36846b5a3dea21b6f08d213e97b5a1f66dd670`. **18 archivos nuevos, 7.797 líneas adicionadas, sin diff de código motor productivo**.
- Ejecución REAL e independiente por Director en clon: `python scripts/tests/test_assemble_national_bulk_v6r3.py` → **7/7 PASS**; `python scripts/qa/assemble_national_bulk_v6r3.py --check` → **PASS**; `php server/tests/contracts/validate_national_lab_v6r3.php` → **PASS** con cinco controles negativos; `php -l` → **PASS**. Snapshot SHA `62593098cf670e507ae692580ad3a8491d2daf18c173e379ae156f1a1253e901`. Esto acredita validación de datos y determinismo, **no** ejecución Flutter.
- Archivo nacional QA: **13 jurisdicciones, 32 DIVIPOLA únicos, 19 coberturas y 105 reglas**, de ellas 2/3/15 son V5, incremento **11/16/90**. Datos parcial/informativo; no geometrias GIS ni permisos de circulación afirmados.
- Codex entregó `national_bulk_v6r3_ota_test.dart` (dos casos), pero **NOT_RUN_ENV** y no existen logs de tests Flutter aprobados. PHPUnit/Laravel con SQLite tampoco ejecutado; PDO del entorno reportó solo `mysql`. No APK, release, CI, merge, Hostinger ni teléfono.

## 2. Hallazgos P0/P1 al contrastar código REAL con evidencias

**H1 — Test Flutter inconsistente con TTL real (P0 del gate):** `mobile/test/features/pico_placa/data/national_bulk_v6r3_ota_test.dart` espera `RestrictionDayStatus.unknown` para Manizales el **2026-12-01**, aunque su cobertura tiene `staleAfter=2026-11-23T00:00-05:00`; el motor `_coverageStaleOnDay()` retorna `STALE`. También espera calendario informativo visible para Itagüí **2026-12-01**, aunque `staleAfter=2026-12-01T00:00-05:00`; `staleAfterCoversBogotaDate()` exige que la marca cubra el día **hasta el inicio del siguiente**; ese día es `STALE`. Comprobación independiente de zonas con Python `zoneinfo`: Itagüí 2026-11-30 cubierto, 2026-12-01 NO; Manizales 2026-12-01 NO. **La prueba NO puede certificarse verde sin corregir esas expectativas o justificar otro caso**, y **prohibido alargar TTL ficticiamente**.

**H2 — Fuente oficial encontrada; HOLD Dosquebradas indebido (P1 oportunidad):** La alcaldía publicó el **26-sep-2026** un boletín de restablecimiento desde el **28-sep** con matrícula carros último dígito, motos primero, lunes 0/1, martes 2/3, miércoles 4/5, jueves 6/7 y viernes 8/9, 06:00–20:00; basta como fuente institucional de estos hechos, incluso sin PDF firmado: `https://dosquebradas.gov.co/web/dosquebradas/ciudad/sala-de-prensa/noticias/303-vigencia-2026/10128-dosquebradas-retoma-desde-este-lunes-el-pico-y-placa-tradicional`. La fila `HOLD_CURRENT_AUTHORITY_ACT` ignora evidencia **contemporánea**; aprobar DOS coberturas LAB parciales bajo control de ámbito/excepciones, no permiso personal. Fuente municipal 2026 adicional confirmó continuidad ordinaria en octubre. Esta corrección no elimina los seis HOLD restantes.

**H3 — Ensamblador NO es aún data-only (P1):** `scripts/qa/assemble_national_bulk_v6r3.py` contiene constante `INPUTS=(...)` con 13 nombres y diccionario `BASELINE_SHA256`. Agregar un municipio obliga editar código Python. Es correcto para laboratorio pero no satisface la promesa de carga nacional por datos. Corrección mínima: manifiesto explícito de fuentes habilitadas con hashes/paths seguros; reutilizar el **mismo** ensamblador y validadores, sin nuevo motor. Deshabilitar dato NO significa declarar libre un municipio.

**H4 — Cronología QA inconsistente (P2):** snapshot `generatedAt=2026-11-12T15:00-05:00`, mientras 16 de 19 coberturas registran `verifiedAt=2026-11-13T01:14:45Z` (5h14m45s DESPUÉS del generatedAt). Mantener V6R3 inmutable y establecer timestamp determinista coherente en V6R4; ninguna fecha debe presentarse como verificación externa sin prueba.

**H5 — F6/F7 realmente pendientes (P1 de finalización):** las 7 pruebas Python y contrato PHP nunca sustituyen la prueba Drift/OTA/UI real ni el flujo administrativo con DB QA. Flutter no estuvo en PATH de Codex V6R3; **V5 sí dispuso de Flutter con `package_config.json` y pasó 5 tests usando `--no-pub`**, por lo que conviene buscar una ruta SDK precisa antes de clasificar `NOT_RUN_ENV` de manera definitiva. No instalar toolchain ni buscar todo el disco en un bucle; aceptar la falta si no se resuelve una vez. Laravel PDO solo MySQL: no fabricar SQLite; DB aislada autorizada o `NOT_RUN_ENV`.

**H6 — Snapshot QA NO publicable nacional (P1):** la importación en Drift reemplaza **todo el conjunto**. Las 13 jurisdicciones no son el país completo ni equivalen a cobertura legal de 1.104 municipios; publicar este snapshot como nacional quitaría jurisdicciones previamente aprobadas no incluidas. Se mantiene `LAB_ONLY` y publicación humana por Laravel de un snapshot compuesto exhaustivo.

## 3. Diez pasadas de VERDUGO (escrutinio contra falso éxito)

| Pase | Qué confronté | Fallo / conclusión |
|---|---|---|
| V01 Custodia | ZIP SHA, tamaño, entradas y CRC | 44 miembros íntegros, hash exacto |
| V02 Integridad miembro | MANIFEST y bytes reales | 43/43 coinciden, selfhash correctamente excluido |
| V03 Historia | Git bundle y commit contra padre | HEAD/tree concuerdan; checkout explícito requerido |
| V04 Código contra informe | 18 rutas/`git diff --check` | Solo datos/QA/scripts/docs nuevos, sin runtime alterado |
| V05 Ejecución acreditada | Logs y ejecuciones mías | 7 Python + PHP sí; Flutter/DB no |
| V06 Test nuevo sin ejecutar | Línea de Itagüí 1-dic y expiración | Expectativas falsas respecto a TTL (H1) |
| V07 Fuente HOLD | Dosquebradas 26-sep oficial vs HOLD | Bloqueo editorial injustificado (H2) |
| V08 Escalabilidad real | INPUTS y hashes hardcoded | Incorporar ciudad requiere editar script (H3) |
| V09 Trazabilidad temporal | generatedAt vs verifiedAt | 16/19 coberturas posterior a generación (H4) |
| V10 Riesgo de publicación | ZIP LAB 32 códigos vs escala nacional | Reemplazo OTA incompleto si se publicara (H6); NO_GO |

## 4. Diez pasadas de JUEZ (contrapesos, decisión proporcional)

| Pase | Contrahipótesis justa | Decisión |
|---|---|---|
| J01 | Bundle sin default HEAD parece roto | No: verificado íntegro tras elegir rama |
| J02 | El fallo Flutter invalida todos los datos | No: 7 pruebas Python y PHP validadas de manera independiente |
| J03 | 105 reglas equivalen a 105 permisos seguros | No: cobertura parcial protege decisión personal desconocida |
| J04 | Una fuente sin decreto firmado debe bloquear ciudad | No: publicación oficial clara de Dosquebradas acredita calendario, con límites |
| J05 | Dosquebradas es idéntica a Pereira y puede heredarla | No: jurisdicción autónoma 66170 y prueba de mapeo DIVIPOLA |
| J06 | Hacer data-only requiere motor/reglas por ciudad | No: basta registro declarativo + ensamblador actual |
| J07 | Para volver test verde se puede mover staleAfter | No: se corrigen expectativas/fuente, no legalidad |
| J08 | Completar admin exige levantar DB de producción | No: solo DB local efímera aislada o bloqueo declarado |
| J09 | Repetir V5 y todas las suites da mayor seguridad | No: solo deltas de V6R3→V6R4 con condiciones previas preservadas |
| J10 | Se debe anunciar release/apk tras validar PHP | No: Flutter, admin, publicación legal, Android aún faltan; NO_GO |

## 5. Plan de cierre sin pingpong

**V6R4 único macrobloque**: (1) corregir el test Flutter de stale sin tocar vigencia, (2) nueva jurisdicción Dosquebradas car/moto con fuente municipal, (3) sustituir lista hardcoded del ensamblador por **registro de datos habilitables** y corregir invariantes timestamp, (4) snapshot QA de 14 jurisdicciones / 33 DIVIPOLA / 21 coberturas / 115 reglas si confirma fuentes, (5) transición OTA válida V5→V6R3→V6R4+rollback SHA en Flutter/Drift y UI DB real, (6) flujo administrativo Laravel solo en DB de QA, (7) un ZIP y commit local. No hacer búsquedas nacionales nuevas, ni publicación, APK o merge.

**Prompt maestro íntegro descargable:** `CODEX_LUNA_PICORADAR_V6R4_CIERRE_NACIONAL_MANIFIESTO_QA_20261113.md`, SHA256 `d0457ea68e7fff921628d8fd28c5c8fdf0d9dd067b6687621d166900ce342f5b` (contenido también debe guardarse en PR79 documental). **Solo ejecución si no hay otro Codex activo.**

**Estado de recuperación:** `LAST_VERIFIED_PRODUCT_COMMIT=8d4ece555f563b77aa76e88cd48329609c5e50cb`, `V6R3=PARTIAL_IMPLEMENTED_FLUTTER_NOT_RUN_ENV`, `NEXT=CODEX_LUNA_V6R4_IF_IDLE`, `AFTER=CHATGPT_DIRECTOR_AUDITS_ONE_ZIP`, `PRODUCT_RELEASE=NO_GO`.
