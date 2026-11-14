# CODEX LUNA — PICORADAR N1 V2 — IMPLEMENTAR INGESTA NACIONAL REVISABLE SIN TOCAR EL MOTOR, B07 NI DATOS ACTIVOS

**TASK_ID ÚNICO:** `PICORADAR-N1-NATIONAL-CANDIDATE-INTEGRATION-20261109` — **V2 SUSTITUYE INTEGRAMENTE LA ORDEN V1** `CODEX_LUNA_PICORADAR_N1_IMPLEMENTACION_NACIONAL_REAL_20261109.md`. Si ya comenzó V1, **no repetir**: inspeccionar primero los cambios y reutilizar lo válido, corrigiendo solo el delta de seguridad/alcance descrito en V2. No ejecutar dos tareas N1 en paralelo.

**DIRECTOR TÉCNICO:** ChatGPT, responsable de la arquitectura, priorización, decisiones legales, especificación y aceptación. **EJECUTOR:** Codex Luna, exclusivamente implementa y verifica este contrato. **OBJETIVO DE PRODUCTO:** terminar posteriormente la cobertura de pico y placa y restricciones vehiculares **en Colombia** para carros particulares, motocicletas, taxis y servicio público/carga cuando la autoridad y el contrato lo permitan. **ALCANCE REAL N1:** convertir con código ejecutable las 31 medidas de investigación existente en 55 propuestas mecanizadas y no publicables por modalidad. **NO declarar que eso ya implementa todas las restricciones nacionales en la app**; N2–N5 llevan a cobertura operativa. La V2 elimina trabajo superfluo y riesgos de V1.

**INVARIANTES:** `RELEASE=NO` · `PUBLISH_ALLOWED=NO` · `ACTIVATION=FALSE` · `CODEX_NO_LEGAL_APPROVAL` · `NO_MERGE` · `NO_DEPLOY` · `NO_HOSTINGER` · `NO_PRODUCTION_DB` · `NO_ASSET_MUTATION` · `NO_ANDROID` · `NO_GPS_TRACKING` · `NO_USER_DATA` · `NEXT_AFTER_ZIP=CHATGPT_DIRECTOR` · **UN SOLO ZIP**.

## 0. Decisión de arquitectura V2 — cerrada, sin alternativas creativas

**Implementar exactamente un nuevo programa de consola de propósito editorial** `scripts/build_pico_n1_review_candidates.py` y **una suite de pruebas focal** `scripts/tests/test_build_pico_n1_review_candidates.py`. Este programa **NO** es otro motor de pico y placa, publicador, sincronizador ni catálogo runtime: prepara datos de revisión desde fuentes no aprobadas. Solo `csv`, `json`, `hashlib`, `argparse`, `pathlib`, `tempfile`, `os` y biblioteca estándar, compatibles con Python 3 existente. Sin nuevas dependencias. Puede usar funciones puras del repositorio **solo si su importación no ejecuta trabajos ni necesita openpyxl**; preferir dos funciones locales de CSV sencillas a acoplarse al compilador histórico.

**No modificar ni ejecutar en su directorio real** `scripts/compile_pico_operational_catalog.py`. Importa `openpyxl` y su ejecución predeterminada escribe `mobile/assets/catalogs/pico_jurisdiction_catalog_v1.json`, `docs/data/PICO_73_OPERATIONAL_AUDIT_20260919.csv` y `.md`; no se justifica tocarlo en N1. **No modificar ni invocar** `server/app/Services/RestrictionImportService.php` salvo lectura de contrato y, de ser útil, suite existente con **BD/Storage de prueba aislados**. Su método `analyze()` **sí escribe** en almacenamiento privado, `RestrictionImport`, `RestrictionImportRow` y auditoría; `normalize()` usa `publish=yes` por defecto. Por tanto, queda **VETADO** pasarle los 55 candidatos externos en cualquier entorno real, incluso bajo la palabra “preview”. **No editar servidor, mobile, migraciones, catálogos, datasets ni controladores.** Si falla un requisito que necesite ese cambio, marcarlo `DEFERRED_N2/N3`, no expandir N1.

**Archivos de código permitidos, máximo dos** (más un `*.md` de notas SOLO en ZIP, nunca dentro del repo):
1. `scripts/build_pico_n1_review_candidates.py` — programa nuevo.
2. `scripts/tests/test_build_pico_n1_review_candidates.py` — tests nuevos.

Si existe ya una implementación N1 identificable y compatible en branch/WIP, hacer **solo la diferencia mínima** en lugar de crear una copia. Si resulta necesario tocar un tercer archivo de producto, no hacerlo: emitir `BLOCKED_CONTRACT` para esa parte y entregar lo implementado.

## 1. Proveniencia exacta y precedencia — nada de main histórico ni merge de PR #79

**Código moderno aprobado como base de lectura**, `sierraglobalcompany-rgb/PicoRadar`, rama `recovery/20261019-modern`, SHA `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`. PR de código **#71 Draft** contra `main` histórico; `main` no se usa como base de N1. **Documentación NO FUSIONADA** del PR **#79 Draft**, rama `docs/plan-maestro-nacional-v2-20261107`:
- Fuente de los inputs N1: commit documental fijo **`3396ec4a01fce70df8d69ac3585978b24a239644`** (se conserva aunque la PR79 avance luego). `EXTERNAL_PICO_MEASURES_31_STAGING.csv` tiene Git blob SHA **`0311ba31eea892ca02d564e5ca106af7c5d640fa`**.
- `EXTERNAL_MEASURES_31_N1_MODALITY_WORKLIST_20261109.csv` tiene Git blob SHA **`f6090f15e991772896856ff420c5b4d3d2c2d7c3`**. Ambas rutas están bajo `docs/data/external-research/`.
- `EXTERNAL_PICO_20261109_UNVERIFIED.txt` (informe íntegro no certificado de otra IA), `EXTERNAL_PICO_CATALOG_65_STAGING.csv` (65 entradas, algunas agregadas), `EXTERNAL_PICO_CONTRASTES_20261109.csv` (35 contrastes al cierre de §AK), Plan Maestro V2 §AL y ledger SRC-48 están en **ramas documentales**, NO en el checkout de código. No suponer que aparecen en la rama moderna.
- Además, la rama documental pudo recibir un commit adicional de V2/ledger; **no se usa su HEAD variable para los insumos**. Solo importan el commit de fuentes fijado y los blobs de arriba. Las secciones canónicas del Plan Maestro gobiernan la estrategia; **la V2 es la orden de ejecución final para N1**.
- Workbook histórico `data/sources/restrictions/PicoRadar_Pico_y_Placa_Colombia_CONSOLIDADO_2026-09-10.xlsx`, 73 municipios/219 categorías, compilador viejo y catálogo `mobile/assets/catalogs/pico_jurisdiction_catalog_v1.json` **solo lectura**. No regenerar ni migrar ese catálogo.
- `M3_X01_BRIDGE_PASS_SCOPED`, cierre sintético schema1: **CERRADO**. `C1/schema2` no integrado. Test-only patch M3-X01 no aplicar. QA Android/firma/JNI/CI histórica no repetir. No mezclar cámaras/peajes/RUNT scraping.

**Procedimiento Git obligatorio sin escritura al checkout protegido:**
1. Inspecciona con `git remote -v`, `git status --porcelain=v1 -uall`, `git worktree list --porcelain` y `git rev-parse HEAD` los posibles checkouts `D:\Dev\PicoRadar` o `D:\codex\PicoRadar`. No afirmar que las **101 rutas WIP históricas** están limpias. Proteger el borrado histórico `scripts/tests/test_hostinger_installer_browser.ps1`; no restaurarlo ni eliminarlo. No ejecutar `reset --hard`, `clean`, `checkout -f`, `stash pop`, `rebase` o borrados de worktree; no tocar C:.
2. Crear **clon independiente**, con `.git` propia y sin `alternates` que dependan del original, en una nueva carpeta libre bajo `D:\codex\_WORKTREES\PicoRadar\N1-national-v2`. Si existe, inspeccionarla y **NO sobrescribirla**; escoger carpeta hermana nueva, documentar ruta. Si clone remoto falla, clonar localmente con copia independiente de objetos y conservar el remoto canónico; nunca mutar el worktree original. Sin capacidad de aislamiento, `BLOCKED_SAFE`, con ZIP mínimo de evidencia.
3. `git fetch --no-tags origin recovery/20261019-modern docs/plan-maestro-nacional-v2-20261107` en **clon**, solo lectura remota; verificar que el commit moderno y el documental están disponibles, y que las rutas correctas pertenecen al mismo repo. Crear rama **`feat/N1-national-restriction-review`** desde SHA de código **exactamente** `0d3a6a2a...`, sin `main`, merge, cherry-pick o checkout del código desde docs.
4. Extraer únicamente los DOS CSV desde el commit documental fijo, con operación equivalente a `git show 3396ec4a...:docs/data/external-research/<archivo>` hacia carpeta de entradas del laboratorio **fuera de las rutas seguidas por Git**. IMPORTANTE en Windows: **no usar `git show ... > archivo.csv` en PowerShell antiguo**, porque puede alterar la codificación. Emplear Python `subprocess.run(["git","show","<SHA>:<ruta>"], stdout=archivo_abierto_en_modo_wb, check=True)` o un método que preserve bytes. No mergear PR #79.
5. Validar la identidad Git de **cada byte** de entrada con `git hash-object -- <archivo>` y exigir los Git blob SHA anteriores; calcular además SHA-256 real de bytes del CSV para el manifiesto (no confundir Git SHA-1 con SHA-256, ni con el campo `source_sha256` de 64 caracteres que identifica el **informe externo de otra IA**).
6. Consultar `AGENTS.md`, `docs/CURRENT.md`, los baselines/aprobaciones específicas y leyes oficiales `sierraglobalcompany-rgb/PingPongLaw/docs/engineering/LEYES_IMPLEMENTACION_1_A_6.md` (canon L1–L6; no reemplazar normas específicas), más §AL y contrato de fuentes del PR79 **por lectura**, no merge. Validar que el repositorio es PicoRadar y que no hay otro proceso N1 activo. Si la V1 ya produjo código, registrar su ubicación y comprobar si se puede reaprovechar en este clon; **no duplicar**.

**Extracción de bytes en Windows PowerShell (en el clon aislado, tras el fetch)**: no redirigir salida de texto con `>`; desde la raíz del clon, definir una carpeta vacía nueva `D:\codex\_INPUTS\PicoRadar\N1-V2-20261109` (si ya existe, crear otra carpeta nueva), y ejecutar este bloque. Requiere disponer de la revisión documental exacta en `.git`:

```powershell
@'
from pathlib import Path
import subprocess
repo = Path.cwd()
out = Path(r'D:\codex\_INPUTS\PicoRadar\N1-V2-20261109')
if out.exists():
    raise SystemExit('Carpeta de entrada ya existe; NO sobrescribir')
out.mkdir(parents=True)
ref = '3396ec4a01fce70df8d69ac3585978b24a239644'
for name in ('EXTERNAL_PICO_MEASURES_31_STAGING.csv',
             'EXTERNAL_MEASURES_31_N1_MODALITY_WORKLIST_20261109.csv'):
    path = f'docs/data/external-research/{name}'
    with (out / name).open('wb') as target:
        subprocess.run(['git', '-C', str(repo), 'show', f'{ref}:{path}'],
                       stdout=target, check=True)
    actual = subprocess.check_output(['git', '-C', str(repo), 'hash-object', str(out / name)], text=True).strip()
    expected = {
        'EXTERNAL_PICO_MEASURES_31_STAGING.csv':'0311ba31eea892ca02d564e5ca106af7c5d640fa',
        'EXTERNAL_MEASURES_31_N1_MODALITY_WORKLIST_20261109.csv':'f6090f15e991772896856ff420c5b4d3d2c2d7c3',
    }[name]
    if actual != expected:
        raise SystemExit(f'DRIFT de bytes {name}: {actual}')
print('INSUMOS_GIT_BLOB_IDENTICOS=PASS')
'@ | python -
```

Si la carpeta de destino se creó parcialmente por fallo, **no reutilizarla**: anotar la ruta, preservar evidencia y escoger un destino nuevo sin eliminar contenido protegido. Si `git show` falla, un único fetch de la rama documental en ese clon y repetir una vez; después `BLOCKED_INPUT`, sin editar código.

**Regla sobre drift:** si PR79 cambia después pero los dos blobs de entrada siguen idénticos, continuar. Si el commit de código deja de ser base aprobada o alguno de los dos blobs no coincide, detener N1 con `BLOCKED_INPUT_DRIFT`, no deducir ni reparar datos por cuenta propia. Reintento de fetch de red **una vez** si es transitorio, luego salida acotada; no pedir repetidamente un ZIP que ya está en GitHub.

## 2. Datos exactos y política de clasificación — no convertir afirmaciones en leyes

**Input A** `EXTERNAL_PICO_MEASURES_31_STAGING.csv`: exactamente **31 registros** con `candidate_id` `EXTERNAL-MEASURE-001` a `EXTERNAL-MEASURE-031`, sin duplicados. Cabeceras de control: `candidate_id`, `source_line`, `source_sha256`, `Ciudad / Municipio(s)`, `Decreto / Acto Administrativo`, `Categoría Vehicular`, además de columnas textuales que debes **conservar en el archivo fuente, no reescribir**.

**Input B** `EXTERNAL_MEASURES_31_N1_MODALITY_WORKLIST_20261109.csv`: exactamente **31 registros** y columnas:
`candidate_id,source_line,source_sha256,territory_raw,act_raw,vehicle_category_raw,modalities_claimed_direct,other_exemption_claims_from_raw,requires_mode_split,requires_independent_territorial_scope,mode_support_status,provenance_class,publish_allowed,engine_enabled,source_fields_need_official_validation`.

Validar por **join de `candidate_id`, NO por orden de filas** los seis campos inmutables:
- `candidate_id` ↔ `candidate_id`
- `source_line` ↔ `source_line`
- `source_sha256` ↔ `source_sha256`
- `territory_raw` ↔ `Ciudad / Municipio(s)`
- `act_raw` ↔ `Decreto / Acto Administrativo`
- `vehicle_category_raw` ↔ `Categoría Vehicular`

**Cómputo reproducido previamente por director** y exigible de nuevo al script: 31 candidaturas originales, **55 proyecciones únicas** `candidate_id:modalidad`, **5 candidaturas con alguna modalidad no soportada**, concretamente `EXTERNAL-MEASURE-002`, `003`, `005`, `014` y `016`, y **9 candidaturas de grupo/corredor con `requires_independent_territorial_scope=YES`**, IDs `004`,`005`,`006`,`009`,`010`,`016`,`017`,`020`,`031`. Si cambia un conteo, **no cambiar el objetivo codificado para forzar PASS**: comparar entradas SHA y explicar drift.

Modalidades permitidas en **investigación**, no enumeraciones nuevas de Flutter:

| Etiqueta de propuesta | Pareja tipo/servicio de app, solo como metadato | Admisión |
|---|---|---|
| `CAR_PRIVATE` | `car:private` | `ENGINE_PAIR_EXISTS_NOT_LEGALLY_APPROVED` |
| `MOTORCYCLE_PRIVATE` | `motorcycle:private` | `ENGINE_PAIR_EXISTS_NOT_LEGALLY_APPROVED` |
| `TAXI` | `car:taxi` | `ENGINE_PAIR_EXISTS_NOT_LEGALLY_APPROVED` |
| `PUBLIC_SPECIAL` | **ninguna** | `UNSUPPORTED_MODE` |
| `CARGO` | **ninguna** | `UNSUPPORTED_MODE` |
| `MOTO_RELATED_OTHER` | **ninguna** | `UNSUPPORTED_MODE` |

**Importante:** 55 proyecciones no equivalen a 55 normas, modalidades legales equivalentes ni ciudades únicas. Grupos territoriales y corredor ambiental **no reciben DIVIPOLA** durante N1, ni permiso de circulación. Para las demás filas tampoco es obligatorio asignar DIVIPOLA en N1; mantener `territory_resolution=NOT_LEGALLY_RESOLVED` hasta cotejo por autoridad en N2. `source_sha256` de la fila = identificación del texto externo; **no** sello de norma oficial. Las fechas/horarios/paridad de ese texto NO se compilan a reglas de runtime. Prohibido marcar una fila `READY`, `VERIFIED`, `PUBLISHED`, `AVAILABLE` o `ALLOWED`.

**Conflictos que no se pueden silenciar**: `BOG-URBAN` paridad original invertida respecto a SDM, `CART-DEC` 24 horas futuras/no resueltas, Cartagena moto nocturna y centro, Soledad `SOL-DAY30` derogado según fuente secundaria (decreto primario no recuperado), `QUIB-MOTO` calendario en conflicto, exenciones territoriales Medellín. No construir una regla «corregida» sin acto y admisión; conservar `provenance_class`, `source_fields_need_official_validation`, y emitir al menos `LEGAL_REVIEW_REQUIRED` para todas las proyecciones. Si campo `provenance_class=KNOWN_CONFLICT_OR_SCOPE_GAP`, emitir adicional `KNOWN_SOURCE_CONFLICT_OR_SCOPE_GAP`, sin afirmar qué subregla es legal.

## 3. Programa, CLI y contratos exactos — implementar, no deliberar arquitectura

Crear `scripts/build_pico_n1_review_candidates.py` con interfaz:

```text
python scripts/build_pico_n1_review_candidates.py --measures <ruta CSV A> --worklist <ruta CSV B> --output-dir <nueva carpeta>
python scripts/build_pico_n1_review_candidates.py --measures <ruta CSV A> --worklist <ruta CSV B> --validate-only
```

- Python estándar, `utf-8-sig` para abrir cabeceras, `csv.DictReader`, `newline=""`, detectar cabeceras requeridas, columnas faltantes y duplicadas, filas inválidas, ID vacíos y filas extra. Orden de entrada no afecta la salida: ordenar por `candidate_id` y modalidad en el orden de `modalities_claimed_direct` de B; explícitamente **no** hardcodear las 55 filas ni una lista de 31 reglas dentro del código.
- `--validate-only`: valida y calcula conteos, termina exit 0 con un resumen **sin tocar archivos**, o exit distinto de cero si hay divergencias. El resumen no indica leyes verificadas.
- Rechazar **antes de cualquier escritura**: inputs ausentes, CSV inválido, no exactamente IDs 001–031, duplicados, seis campos con drift, modalidades fuera de la tabla, modalidad duplicada dentro de un padre, banderas `publish_allowed/engine_enabled` distintas de `false`, cabecera o fila incorrecta, total no 55, cinco o nueve controles no coinciden, orígenes de alto riesgo no reconocidos. No poner valores por defecto complacientes en campos faltantes.
- Crear `--output-dir` **únicamente si no existe**. Preparar todos los bytes en memoria y validar primero; después crear una carpeta temporal nueva **hermana en la misma unidad** y renombrarla al destino una sola vez. Si cualquier error ocurre, no sobrescribir archivos previos ni dejar un artefacto aceptado parcialmente. Si quedan temporales y una policy prohíbe borrarlos, reportar su ruta y excluirlos del ZIP. Rechazar si destino dentro de `mobile/`, `server/`, `data/sources/`, árbol de fuentes históricos o carpeta de otro proyecto. No seguir symlinks/junctions que salgan del sandbox. No almacenar entradas en directorio Git seguido.
- Salidas UTF-8, `newline=""`, orden fijo, LF, JSON con `sort_keys=True`, separadores/indent fijo. Nada de `datetime.now()` en archivos generados, paths absolutos, usuario local, hostname o timestamps de ejecución; registrar esos metadatos **solo en informes/logs de ZIP**, no en los artefactos deterministas.

### 3A. Archivos de salida que deben existir

**`N1_NATIONAL_REVIEW_CANDIDATES.csv` — exactamente 55 filas** en carpeta de salida. Cabeceras fijas en ese orden:

`parent_candidate_id,projection_key,source_line,source_sha256,territory_raw,act_raw,vehicle_category_raw,claimed_modality,matched_vehicle_kind,matched_service_type,territory_resolution,mode_support_status,legal_review_status,provenance_class,source_validation_fields,source_urls,publish_allowed,engine_enabled,activation`

- `projection_key = parent_candidate_id + ':' + claimed_modality`. Conservar texto del input sin reinterpretarlo; manejar celdas de potencial fórmula Excel `=`, `+`, `-`, `@` al abrir exportaciones de revisión: no ejecutarlas; escapar explícitamente una celda peligrosa solo en la copia CSV, registrar el cambio `CSV_CELL_ESCAPED` en gaps y mantener el raw original en las fuentes de entrada. Nunca modificar silenciosamente fuentes.
- `matched_*` solo para los tres pares soportados; las demás cadenas vacías. `territory_resolution` = `GROUP_SCOPE_UNVERIFIED` para nueve IDs conocidos de la entrada o `NOT_LEGALLY_RESOLVED` en otros; N1 no asigna DIVIPOLA. `legal_review_status=EXTERNAL_UNVERIFIED`; `source_urls` vacío porque las 31 filas no traen URL exacta por fila (no inventar herencia del CSV de contrastes). **Los tres flags son el literal `false` en cada fila**.

**`N1_NATIONAL_REVIEW_GAPS.csv` — problemas accionables** con columnas:

`projection_key,gap_code,blocking_for_runtime,evidence_field,detail,next_action`

Mínimo por proyección `LEGAL_REVIEW_REQUIRED`; añadir según entradas `UNSUPPORTED_MODE`, `TERRITORY_GROUP_UNVERIFIED`, `KNOWN_SOURCE_CONFLICT_OR_SCOPE_GAP` y `TEMPORAL_OR_EXCEPTION_REQUIRES_PRIMARY_ACT` cuando el metadato exija validación. No crear 55 copias de un párrafo idéntico: describir problema breve por clave; no inferir `OFFICIAL_NO_MEASURE`, `NO_RESTRICTION` ni `ALLOWED`.

**`N1_NATIONAL_REVIEW_MANIFEST.json` — resumen determinista** con claves fijas: `schemaVersion=1`, `taskId`, `artifactKind="REVIEW_ONLY_NOT_RUNTIME"`, `sourceInputGitCommit="3396..."`, `inputSha256` (bytes reales de los dos CSV), `outputSha256` (bytes de los dos CSV generados), `counts` (31 originales, 55 proyecciones, 5 candidaturas con modalidad no soportada, 9 grupos), `publicationAllowed=false`, `runtimeActivationAllowed=false`, `legalApprovalGranted=false`. El manifiesto no requiere auto-hash y no contiene fechas/paths del PC.

**No crear** un fichero que pretenda ser importación legal válida de Laravel; no añadir `rule_id`, `validFrom` inferido, `staleAfter` nuevo, fecha de actualización simulada ni JSON compatible con `restriction_dataset.dart` schema1 para datos no certificados.

### 3B. Ejemplo de una conversión correcta

`EXTERNAL-MEASURE-002` informa «Taxis y Especial»: genera exactamente **dos propuestas**:
- `EXTERNAL-MEASURE-002:TAXI` → metadato `car:taxi`, `EXTERNAL_UNVERIFIED`, flags `false`.
- `EXTERNAL-MEASURE-002:PUBLIC_SPECIAL` → sin `matched_*`, `UNSUPPORTED_MODE`, flags `false`.

Ambas conservan `parent_candidate_id=EXTERNAL-MEASURE-002`, su acto y territorio raw; NO crean dos leyes, ni se envían a B07 `analyze`, ni marcan disponibilidad de Bogotá. Para grupos del Valle de Aburrá, generar proyecciones por clase **sin** multiplicarlas ficticiamente por 10 municipios.

## 4. Tests obligatorios: menos ruido, mayor valor, ningún falso PASS

Crear `scripts/tests/test_build_pico_n1_review_candidates.py` usando `unittest`, `tempfile`, fixtures sintéticas pequeñas para negativos y los dos CSV reales PINNED cuando estén presentes en el laboratorio. Si el test depende de GitHub red en runtime, está mal: recibir paths al checkout/lab vía argumento o variables locales, con defaults aislados explícitos. **Todos los tests generan datos en tmp**, no en `mobile/`, `server/` ni repo protegido.

| Test | Caso y aserción indispensable |
|---|---|
| T01 | Dos CSV reales con blobs correctos; 31 padres, 55 proyecciones distintas, todos los parents presentes |
| T02 | Exactamente 5 padres contienen moda `UNSUPPORTED_MODE`, IDs `002/003/005/014/016` |
| T03 | Exactamente 9 padres de ámbito agregado; cero DIVIPOLA, cero `AVAILABLE` |
| T04 | `TAXI → car:taxi`; carro/moto privados a sus pares, especiales/carga/otros vacíos |
| T05 | Drift de `territory_raw`, acto, clase, source_line o hash entre A/B bloquea con exit distinto de cero |
| T06 | Id duplicado, modalidad duplicada, 32 filas, cabecera extra peligrosa o modo no conocido bloquean |
| T07 | `publish_allowed=true`, `engine_enabled=true` o cualquier `activation` implícita bloquea |
| T08 | BOG paridad conflictiva, CART 24h/nocturno, Soledad día30 y Quibdó permanecen solo metadatos no publicables |
| T09 | Igualdad byte a byte de candidatos, gaps y manifest entre 2 carpetas nuevas A/B con mismos inputs |
| T10 | `--validate-only` no escribe; destino preexistente rechaza sin mutaciones; falla a mitad no deja carpeta aceptada |
| T11 | Fórmula CSV maliciosa no se ejecuta al abrir en planilla; raw original intacto y escape documentado, sin PII ni secretos en salida |
| T12 | Código/proyecto histórico no mutado: comparación de `git diff --name-only` y hashes de fuentes protegidas, no enmascarada por un test sintético |

**NO duplicar la batería Laravel** para afirmar que B07 procesa un formato que todavía no tiene. Dar evidencia de contrato estático `RestrictionImportService::analyze` (escribe) y `normalize` (default yes), y decidir `B07_BRIDGE=DEFERRED_BY_DESIGN`. Si se ejecuta un test PHP **existente** voluntariamente como regresión, `APP_ENV=testing` y SQLite/Storage **efímeros/fakes**, nunca servicio en ejecución ni base productiva; no alterar PHP ni convertir su ejecución en gate obligatorio N1.

Comandos recomendados en el clon aislado, registrando exits reales:

```text
python -B -m unittest discover -s scripts/tests -p test_build_pico_n1_review_candidates.py -v
python -B scripts/build_pico_n1_review_candidates.py --measures <A> --worklist <B> --validate-only
python -B scripts/build_pico_n1_review_candidates.py --measures <A> --worklist <B> --output-dir <SALIDA_A_NUEVA>
python -B scripts/build_pico_n1_review_candidates.py --measures <A> --worklist <B> --output-dir <SALIDA_B_NUEVA>
git diff --check
git status --porcelain=v1 -uall
```

Aserciones de QA independientes: comparar SHA-256 de los tres artefactos A/B; parsear con un **segundo pequeño verificador de stdlib ejecutado en memoria/terminal**, no solo llamar a las mismas funciones bajo prueba; validar conteos, flags falsos, keys únicas y lista de archivos realmente modificados. Capturar stdout/stderr y códigos de salida. Si Python/herramientas no están, `BLOCKED_ENV` honesto; no volver a instalar herramientas sin necesidad. No ejecutar `flutter test`, Android, M3-X01, ni CI remoto por un lote Python puramente editorial.

## 5. Git, política de entrega y único ZIP

**Git local:** crear UNA rama N1 en clon, con solo los 2 archivos mencionados, y UN commit si QA pasa. `git diff --check`, lista de tracked modificados y estado WIP del original preservado. **No editar** `AGENTS.md`, baselines, Plan Maestro PR79, XLSX histórico, assets, dataset, server ni mobile. Sin WIP ajeno en el commit. Si los tests fallan, corregir en el mismo lote una vez por causa y rerun focal/vecinos; sin desactivar tests, sin autocomentarios de PASS y sin repetir M1/M3.

**GitHub remoto:** antes de cualquier push/PR, confirmar que el commit es descendiente del SHA moderno exacto, que solo contiene rutas `scripts/` N1, que PR79 y PR71 siguen en Draft y que los workflows remotos no cambiaron. En la revisión previa del director, `.github/workflows/mobile.yml` y `server.yml` usan paths para `mobile/**`, `server/**` y excepciones, **no `scripts/**`**; esto NO es una garantía de minutos de terceros. Si sigue siendo seguro según políticas/costo, permitir **una sola rama nueva `feat/N1-national-restriction-review`**, **push normal** y PR Draft apuntando a `recovery/20261019-modern`, nunca `main`, sin merge y sin force-push. No disparar manualmente Actions. Si hay política de cuota, disparadores inciertos, PR remoto concurrente, credenciales ausentes, base moved o coste no verificable, **NO push**; entregar commit/diff local y el ZIP, reportar bloqueo sin inventar CI verde. Si V1 ya abrió una PR N1, inspeccionarla antes: no abrir PR duplicada ni push que pise cambios.

**Ruta de entrega sugerida, creando solo nueva carpeta:** `D:\codex\_REPORTES\PicoRadar\N1-NATIONAL-REVIEW-V2-20261109\delivery\PICORADAR_N1_NACIONAL_IMPLEMENTACION_UNICA.zip`. Si la ruta ya existe, no sobrescribir y escoger nombre de ejecución único dejando constancia. **Solo un ZIP enlazado**, los demás informes **dentro**. No sub-ZIP, ni scripts ejecutables dudosos ni copia de los 101 WIP. ZIP debe contener:

- `FINAL_REPORT.md` con hecho vs informado, alcance REAL, código/PR/ramas, 31/55/5/9, planes próximos sin porcentajes inventados.
- `SOURCE_PROVENANCE.md` con commit documental, blobs Git, SHA-256 reales, hashes de outputs y trazabilidad de los CSV; diferencias por campo y qué se verificó.
- `N1_NATIONAL_REVIEW_CANDIDATES.csv`, `N1_NATIONAL_REVIEW_GAPS.csv`, `N1_NATIONAL_REVIEW_MANIFEST.json` (salida A validada).
- `AUDIT_10_EXECUTION_CHECKS.md` con diez pruebas/gates de Codex y estado real por uno, separadas de las 20 pasadas del director (no llamarlas verificación independiente).
- `TEST_COMMANDS_AND_EXIT_CODES.txt`, logs mínimos reales, `GIT_STATUS_PRE_POST.txt`, `WORKTREE_PROTECTION_CHECK.txt`, `FILES_CHANGED.txt`, `BRANCH_AND_HEAD.txt`.
- `PATCH_N1.diff` con los dos archivos modificados/nuevos si hubo cambios, o explicación de ausencia. Se recomienda incluir copia de esos dos scripts en `source_changes/` para que el director pueda ejecutar tests sin depender de Windows, si el ZIP es razonable.
- `NEXT_N2_N5.md`: fases secuenciales, con listas de autoridades y modalidades P1, sin repetir N1 ni declarar cobertura nacional lista.
- `MANIFEST.json` con `path,bytes,sha256` de miembros de entrega salvo el propio manifiesto/hash, y `MANIFEST.sha256` con SHA-256 del manifiesto. ZIP sin secretos/placas reales/PII. Validar rutas sin `../`, CRC, tamaños, SHA de cada entrada **después de cerrar y reabrir** el ZIP. Si CRC/hash falla, NO declarar éxito ni generar diez reportes separados.

**Resumen externo de Codex (solo hechos y UN enlace):**

```text
TASK_ID=PICORADAR-N1-NATIONAL-CANDIDATE-INTEGRATION-20261109
PROMPT_REVISION=V2
RESULT=PASS_SCOPED | PARTIAL_IMPLEMENTED | BLOCKED_SAFE
SOURCE_COMMIT=3396ec4a01fce70df8d69ac3585978b24a239644
CODE_BASE=0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a
ROWS=31
PROJECTIONS=55
UNSUPPORTED_PARENT_ROWS=5
GROUP_SCOPES=9
TESTS_EXECUTED=...
TESTS_PASSED=...
TESTS_FAILED=...
TESTS_SKIPPED=...
B07_BRIDGE=DEFERRED_BY_DESIGN
RUNTIME_CHANGED=NO
PUBLISH_ALLOWED=NO
RELEASE=NO
COMMIT_SHA=... | NOT_CREATED
PUSH_AND_PR=... | NOT_RUN
ZIP_BYTES=...
ZIP_SHA256=...
EVIDENCE=<UN_SOLO_ZIP_EXISTENTE>
NEXT_ACTOR=CHATGPT_DIRECTOR
```

Si bloquea red, CI o herramienta, conservar avances y evidencia sin tocar original; **no solicitar otra ronda de prompts por molestias menores**. Solo un bloqueo material de fuente/seguridad detiene la acción afectada. No decir `PASS` si Python no ejecutó el programa.

## 6. Plan de finalización nacional — foco en restricciones reales, no auditorías infinitas

**N1 (este lote, ejecutable ahora):** procesamiento determinista y comprobable de TODAS las 31 medidas externas hacia 55 propuestas por modalidad sin publicación, con clasificación de los 5 casos no soportados y 9 territorios agrupados. Resultado aceptable: **código y tests de conversión**, no afirmación de cobertura real del usuario final.

**N2 (siguiente lote dirigido por ChatGPT, no tarea simultánea):** admitir **por autoridad y clase** los campos jurídicos existentes del informe nacional, la base de 73/219 y los 35 contrastes, sin reinvestigar 31 medidas desde cero; convertir propuestas que tengan evidencia suficiente en versiones de regla del B07 existente. Usar una sola matriz de brechas por `candidate_id/modalidad` que N1 ya produjo. `OFFICIAL_NO_MEASURE` solo cuando una autoridad lo diga expresamente. No hacer una segunda base productiva ni cambiar estados fuera de su ámbito.

**N3:** ampliar contrato de tipos de vehículo/servicio **únicamente cuando** una norma aprobada lo exija (especial público, carga, otros motos), con cambios mínimos end-to-end B07→JSON→Flutter, migración/test cuando proceda, y geografía/exenciones/24h sólo si el motor necesita representar el caso correctamente. No equiparar categorías ni declarar `ALLOWED` por cobertura parcial.

**N4:** publicación humana por Laravel único publicador, manifest versionado y sincronización Drift **sobre reglas verificadas**, preservar último dataset válido y experiencias UX aprobadas; M3-X01 sintético se reutiliza sin reiniciarlo.

**N5:** QA regresión PHP/Flutter, CI sujeto a coste, QA Android real Xiaomi Mi A3/firma/JNI, permisos/festivos/zonas/23:00, privacidad y rollback, aprobación humana GO/NO-GO. Ningún municipio o clase sin evidencia se anunciará como cubierta. El objetivo final permanece **cobertura nacional**, pero no se falsea para acelerar.

## 7. Resultado de la revisión adversarial que origina V2 (no ejecuciones de Codex)

**VERDUGO — diez ataques a V1:** V01 fuentes docs no fusionadas P1; V02 N1 no equivale a cobertura nacional P1; V03 compilador histórico expuesto a escritura P1; V04 `analyze` B07 tiene efectos persistentes P0 potencial; V05 separar taxi y especial aprobado y reforzado; V06 nueve ámbitos agregados P1; V07 fuente externa no ley P1; V08 determinismo/overwrite parcial P1; V09 PR/CI coste/seguridad P1; V10 suites opcionales confundidas con integración P1.

**JUEZ — diez decisiones V2:** J01 fijar los 2 CSV a commit/blobs y extraer en binario; J02 llamar N1 conversión, no runtime nacional; J03 nuevo CLI stdlib aislado sin tocar compilador histórico; J04 prohibir invocación B07 con CSV externos y deferir puente; J05 tres pares existentes y tres categorías pendientes explícitas; J06 ninguna asignación DIVIPOLA nueva en N1; J07 31→55 con trazabilidad/raw/flags falsos; J08 directorio nuevo+atomicidad+2 hashes y validación negativa; J09 branch única y push condicionado a workflows/costo; J10 dos archivos, 12 pruebas de riesgo y ZIP único verificable. Ninguna decisión autoriza convertir el informe externo directamente en reglas vigentes.

**FIN DE LA ORDEN. EJECUTA N1 V2, no V1.** CÓDIGO REAL + PRUEBAS REALES + **UN ZIP**. NO MÁS AUDITORÍAS GENERALES HASTA RECIBIR LA EVIDENCIA. **DESPUÉS CONTINÚA CHATGPT DIRECTOR.**
