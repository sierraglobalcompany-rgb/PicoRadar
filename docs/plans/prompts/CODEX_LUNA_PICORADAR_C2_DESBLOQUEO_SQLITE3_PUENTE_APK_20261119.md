# CODEX LUNA — PICORADAR C2 · DESBLOQUEO SQLITE3, PUENTE LARAVEL→FLUTTER Y APK DEV CONDICIONAL

**EJECUTOR:** Codex Luna. **DIRECTOR:** ChatGPT. **Fecha de corte:** 19/11/2026, zona America/Bogota.  
**TASK_ID NUEVO Y ÚNICO:** `PICORADAR-N5R5R2-V2-C2-SQLITE3-VERTICAL-20261119`  
**ENTRADA DE TRABAJO:** este Markdown. **RETORNO OBLIGATORIO:** un solo ZIP final de evidencias, nunca informes dispersos.  
**OBJETIVO REAL:** cerrar el hook local `sqlite3` de Dart, ejecutar el puente con el mismo manifest/release publicado por Laravel y, si los recursos lo permiten, compilar una APK DEV del mismo árbol. No es auditoría del proyecto ni repetición de C1.

## 0. Decisiones CERRADAS — no reabrir

| Gate | Dato verificable del retorno C1 V2 | Acción C2 |
|---|---|---|
| `BASE_TREE=FINAL_TREE` | `859bb8bbdff769ec3504af407f4df27593b2efea`; C1 no modificó fuentes | REUSAR candidato existente, sin reconstruir R2, N4 o N5 |
| `PHP_FOCAL` | **53/53 pruebas, 592 aserciones, cero warnings PHPUnit y stderr vacío** (directo PHPUnit 12.5.33), informe/ZIP de C1 | **ACEPTAR PASS_SCOPED**; no repetir el mismo lote PHP salvo cambio causal |
| `FLUTTER_FOCAL` | 65 tests PASS en R2, sin cambios Dart posteriores | NO repetir focal |
| `FLUTTER_GLOBAL` | 3.365 PASS, 11 omitidos en R2 | NO repetir global ni análisis/formato por rutina |
| `SDK_COHERENCE` | Flutter `3.47.1`/Dart `3.13.1` activo. El hook `objective_c` se regeneró a SDK activo; **`sqlite3` aún compilado con Dart `3.13.7`** | Una cuarentena reversible acotada de `sqlite3` dentro del candidato aislado |
| `VERTICAL_SAME_BYTES` | Test abortó por `Invalid SDK hash` ANTES de aserciones | **Una nueva prueba del puente** después de regeneración `sqlite3`, no PASS si no corre |
| `APK_DEV` | RAM disponible 2,31 GiB frente al piso de seguridad adoptado de 6 GiB; no hubo Gradle | Un build DEV solo si hay margen actual ≥6 GiB, SDK coherente y pruebas esenciales verdes |
| `OTA_HTTPS` | No existe QA HTTPS real autorizado en C1 | PERMANECE `NOT_RUN_ENV`; loopback no sustituye HTTPS |
| `GITHUB_PRODUCT` / `RELEASE` | `HOLD_SECURITY` / `NO_GO` | NO push/merge/deploy/release, no Mi A3, no APK de distribución |

**ZIP fuente C1 recibido por Director y verificado directamente:** `PICORADAR_N5R5R2V2_C1_RETORNO_UNICO.zip`; SHA-256 `c1576801bbd9c5f13722e381839b2a1d34c8e8c5629a8ce69dd74382098e9af6`. 11 miembros; manifiesto 10/10 tamaños, hashes y CRC correctos. No copiar este ZIP dentro del nuevo ZIP.

**Dos archivos del MISMO snapshot publicado por Laravel en C1:**
- `QA_SNAPSHOT/PHP_G2_V3_REAL_LAB_RELEASE.json`: 59.273 bytes, SHA-256 `9a230f167af82452276bbd505c6e3a69ce8406996e60c7baaf143e157979741e`, `schemaVersion=2`, 8 jurisdicciones de laboratorio, una sintética con `coverage=partial`.
- `QA_SNAPSHOT/PHP_G2_V3_REAL_LAB_MANIFEST.json`: 424 bytes, SHA-256 `c19d611d255f0e360e284ac1e068e40d32a61006995c02f79b7488d8e936d9d0`. Su entrada `datasets.restrictions.sha256` coincide con el release. **El `schemaVersion=1` del MANIFEST es distinto del `schemaVersion=2` del DATASET: no son el mismo esquema y NO se declara defecto por esa diferencia.**

**Límites de evidencia:** C1 observó HEAD, índice y 43 rutas WIP iguales al inicio/cierre (18 modificadas/25 untracked), pero **no recalculó ni comparó contenido byte a byte**. El fingerprint `A132937B...` es una referencia del reporte R2, no una prueba nueva C1. No reetiquetar como `SOURCE_WIP_BYTES_PASS`. El checkout protegido y `D:\codex\PicoRadar` son estrictamente lectura; preservar la eliminación rastreada preexistente de `scripts/tests/test_hostinger_installer_browser.ps1`.

## 1. Guardas técnicas y arquitectura inmutables

- Leer `AGENTS.md` y solo las secciones de baseline aplicables a la acción; NO volver a auditar/reinterpretar todo el repositorio. Cumplir **L1 KISS/Ponytail, L2 Antirruido, L3 Antiparches, L4 UX humana, L5 Verificación independiente, L6 Antiping-pong**.
- **Un Flutter/Riverpod/Drift, un Laravel monolítico y un motor nacional de restricciones**. Datos por autoridad, municipio, tipo/servicio vehicular, fecha/día/hora, dígitos, paridad y vigencia en datasets actualizables. No crear motor por ciudad, no modificar reglas oficiales para conseguir PASS. Ausencia de cobertura = `UNKNOWN/STALE`, jamás `ALLOWED` implícito.
- Barra UI aprobada `Inicio · Garaje · Apps · Viaje · Conducir`, Apps al centro. Free 1.0 anónima, cuenta voluntaria; Super Admin/admin separados. No subir placas, VIN, documentos, GPS/rutas personales ni fotos a servidor por defecto. Publicidad/marketing/SMTP/monetización real OFF. Catálogos, editor manual y modalidad OFF conservan demás jurisdicciones.
- Prohibido borrar cachés globales, alterar SDK compartido, `flutter clean`, `dart pub cache repair`, actualizar paquetes/lock por comodidad, borrar bases, hacer `reset/clean/stash` del checkout fuente, detener procesos ajenos o escribir en `.git/index` de origen. Nada de GitHub Actions comerciales.
- No ejecutar subagentes Flutter/Gradle que compitan por la misma `.dart_tool` o RAM. Con 2,31 GiB libres reportados, **un solo proceso Dart/Flutter**. Un subagente de lectura puramente documental es opcional, pero no debe retrasar el desbloqueo.

## 2. Macrobloque ejecutable — secuencia C2 (sin ping-pong)

### Paso A — Ubicar y validar el candidato aislado en UNA pasada

1. Localizar **solo** el candidato aislado de C1 bajo `D:\codex\_isolated\PICORADAR-N5R5R2-20261119*` o la ruta exacta registrada por C1. No buscar por todo el disco ni usar GitHub `main` como código base.
2. Verificar en ese candidato, **sin cambiar su índice**, `git write-tree` = `859bb8bbdff769ec3504af407f4df27593b2efea` y `git diff --name-only` = vacío. Si hay cambios nuevos o candidato distinto, **no aplicar reparaciones a ciegas**: distinguir proceso concurrente de estado perdido, reportar evidencia y continuar solo operaciones independientes seguras.
3. Comprobar que `mobile/.dart_tool` y `mobile/.dart_tool/hooks_runner` sean **directorios locales ordinarios**, no symlinks/junctions/reparse points. Verificar el Flutter explícito usado por C1: `D:\codex\_tool-cache\flutter-3.47.1\flutter\bin\flutter.bat`; su Dart integrado 3.13.1; el `pubspec.lock` no debe cambiar (SHA-256 esperado `e86ada9d658800b3c47bcfb1f8743d3ff14ce75fac1b81bc040b16ccfb03a41b`). No usar por accidente Flutter 3.47.9 / Dart 3.13.7.
4. Conservar Git HEAD/índice/WIP de fuente sin escritura; si está disponible, obtener **fingerprint actualizado de metadatos y contenido de las 43 rutas** de forma solo lectura y sin incluir sus bytes privados en el ZIP. Si cuesta más que el desbloqueo, informar `SOURCE_WIP_BYTES=NOT_VERIFIED` sin falsos positivos.

### Paso B — Un único remedio causal del hook `sqlite3` local

**Hecho demostrado:** en C1 la regeneración reversible de `objective_c` funcionó; el siguiente fallo fue `sqlite3` por metadatos compilados con Dart 3.13.7. **No repitas la cuarentena de `objective_c` si ya está bien.**

1. Localiza exactamente `mobile/.dart_tool/hooks_runner/sqlite3` (si el paquete real se llama distinto, usa el nombre real demostrado por el log, no una ruta inventada). Confirma que exista bajo el candidato, sea directorio ordinario y que su metadata o `stderr` invoque SDK anterior. No tocar `sqlite3` del caché PUB global ni el paquete en `pubspec.lock`.
2. Antes de moverlo, genera un inventario con **rutas relativas, bytes, SHA-256** de sus archivos y su número total; registra SDK/metadata anterior. **No meter sus 10+ MB de binarios en el ZIP final.**
3. Crea `mobile/.dart_tool/_picoradar_c2_quarantine/` (área local ignorada, **fuera** de `hooks_runner`). Mueve **solo** el directorio del hook verificado a un nombre nuevo único dentro de ese directorio; operación reversible y sin destruir evidencia. No mover un symlink, ni sobreescribir destino, ni intervenir otro árbol. Si falta el directorio o ya es coherente con el Dart activo, **no lo muevas**.
4. Ejecuta con el **mismo** Flutter/Dart 3.13.1 una sola invocación funcional del test de puente del Paso C, permitiendo que el runner regenere el hook. Comprueba metadata regenerada, `stderr`, `exit code` y prueba real.
5. **Límite explícito de reintento:** si aparece *otro* hook con el MISMO `Invalid SDK hash`, registra nombre, origen/versión y ruta antes de decidir. Está permitido corregir **a lo sumo UN hook local adicional**, solo si se comprueba exactamente la misma causa y el mismo aislamiento seguro; después, **UNA última invocación del puente**. Ante un fallo diferente o incongruencia de SDK, parar este frente como `PARTIAL_ENV` y NO transformar el código del motor para hacerlo verde. Nunca iniciar un bucle de limpiar/reintentar hooks.

Referencia técnica para esta operación, sin imponer nuevas dependencias: [documentación Dart de depuración de hooks](https://dart.googlesource.com/native/+/refs/heads/main/pkgs/hooks/doc/debugging.md) y [contrato de caché de hooks](https://pub.dev/documentation/hooks/latest/hooks/build.html). Ambas distinguen artefactos generados por paquete del código fuente y del caché global.

### Paso C — Puente de bytes reales Laravel → Flutter (solo después de B)

1. **Reutilizar** el snapshot exacto de C1, ya producido por la publicación Laravel. Buscar una sola vez en la salida del candidato C1 o en `D:\codex\_REPORTES\PicoRadar\N5R5R2-V2-C1\PICORADAR_N5R5R2V2_C1_RETORNO_UNICO.zip`. Si existe el ZIP, extraer **únicamente** los dos miembros `QA_SNAPSHOT/*.json` a un directorio de pruebas nuevo dentro de `_REPORTES`, nunca sobre la fuente, y validar los dos SHA completos indicados arriba. No regenerar PHP/Artisan si los archivos verdaderos están disponibles.
2. Si ni los archivos ni ese ZIP están disponibles, permitir **UNA sola regeneración por el test/servicio Laravel real `RestrictionSchemaV2LabRoundTripTest.php`** a un directorio aislado, registrar los SHA *nuevos* de la MISMA ejecución; no afirmar que sus hashes coinciden con C1, ni crear un JSON manual. Solo este caso justifica un test PHP adicional.
3. El manifest debe declarar SHA del release real. Confirmar que el dataset sigue en `schemaVersion=2`, que el caso sintético es parcial y que cobertura ausente no se convierte en permiso implícito. **No convertir 8 jurisdicciones de laboratorio en «cobertura nacional»**.
4. Localizar en `mobile/test/` el test real `restriction_g2_same_bytes_test.dart` con `git ls-files`; no inventar su ruta. Definir `PICORADAR_G2_V3_EVIDENCE_DIR` apuntando al directorio de esos dos JSON y ejecutar una sola vez el **test Flutter existente** con el Flutter 3.47.1 explícito y `--no-pub` si las dependencias locales están resueltas. Capturar comando, salida, exit code, aserciones y fingerprint de los dos archivos. No crear un test sintético que salte el importador real.
5. **Gate `VERTICAL_SAME_BYTES=PASS_LOCAL_LOOPBACK`** únicamente si Flutter inicia, ejecuta aserciones del test real sobre los bytes Laravel, verifica hash/rollback/last-good/offline y retorna 0. Si falla código, reproducir, aplicar el **arreglo mínimo y pruebas causales** en el candidato aislado; si falla ambiente, `PARTIAL_ENV` con ruta/salida exacta. Un `PASS` del manifest solo NO es PASS de puente. HTTPS, firma, Mi A3 y publicación son gates distintos.

### Paso D — Continuidad de producto y APK DEV, sin falso progreso

1. Si C y SDK quedan verdes, comprobar de nuevo RAM disponible una sola vez. **Si RAM libre <6 GiB, no ejecutar Gradle**. No se permite finalizar informando que “falta APK” sin indicar el recurso exacto y el siguiente requisito físico; tampoco detener procesos de otros proyectos.
2. Si RAM libre ≥6 GiB y hay espacio en el disco donde realmente compila Gradle, hacer **UN build Android DEV** del `FINAL_TREE` (nunca release), con paquete/versionCode/certificado público/SHA/bytes. Si el build falla, diagnosticar causa puntual; corrección mínima con tests causales y **a lo sumo un reintento** si el fallo es de entorno corregible, sin limpiar cachés globales. No usar/instalar sobre Xiaomi Mi A3 ni ADB.
3. Si bridge vuelve a quedar `PARTIAL_ENV` o APK `BLOCKED_RESOURCE`, **no abrir otro R2 ni volver a emitir C1**. Documenta las acciones, decide qué parte independiente queda lista (por ejemplo, integración Laravel y snapshot SHA) y devuelve ZIP útil con el diagnóstico único. No inventar cambios de publicidad/Super Admin/editor para “mostrar avance”: sus contratos PHP ya pasaron. El siguiente gate tras APK será OTA HTTPS real + QA de migración/actualización en dispositivo autorizado + seguridad de publicación.
4. **No ampliar catálogo jurídico nacional durante esta reparación ambiental**: la expansión nacional requiere fuentes oficiales, ámbitos claros y editor existente. Queda pendiente editorial, no es excusa para publicar una APK con cobertura falsa. No activar anuncios, correos ni campañas para elevar porcentajes.

## 3. Evidencia y entrega ÚNICA

Generar en ruta nueva de reportes `D:\codex\_REPORTES\PicoRadar\N5R5R2-V2-C2\PICORADAR_N5R5R2V2_C2_RETORNO_UNICO.zip` (si la ruta exacta está libre; nunca sobrescribir el ZIP C1). Contenido mínimo:

- `FINAL_REPORT.md`: base y árbol final 40 hex, cambios de código sí/no, Dart/Flutter exactos, estado sqlite3 anterior/posterior, bytes snapshot y veredicto del puente, memoria/disco/build; **siguiente actor = CHATGPT_DIRECTOR**. Distinguir `PASS_LOCAL_LOOPBACK`, `PASS_SCOPED`, `NOT_RUN_ENV`, `PARTIAL_ENV`, `FAIL_CODE`, `BLOCKED_RESOURCE` y `NO_GO`. No repetir narrativas históricas.
- `GATES.csv`: `SOURCE_WIP`, `INTEGRATED_TREE`, `PHP_FOCAL_REUSED`, `SDK_SQLITE3`, `VERTICAL_SAME_BYTES`, `APK_DEV`, `OTA_HTTPS`, `NATIONAL_LEGAL_COVERAGE`, `GITHUB_PRODUCT`, `RELEASE`, con estado y evidencia por gate; fecha/comando de cualquier test nuevo y hash de código evaluado.
- `QA_LOGS/sdk_sqlite3.txt` (rutas sanitizadas, inventario SHA/size/count, metadata, cambio, error o resultado), `QA_LOGS/vertical.txt` (ruta/command/assertions/código de salida), `QA_LOGS/android_resource.txt` (RAM/Gradle/decisión/resultado), `QA_LOGS/source_wip.txt` (alcance de preservación real).
- `MANIFEST.csv`: path, bytes, SHA-256 y CRC32 de **todos los demás miembros** del ZIP; comprobar antes de entregar; SHA-256 del ZIP final por fuera.
- `RECOVERY_C2.patch` **solo si hubo cambios en fuentes**, delta binario `859bb8bbdff769ec3504af407f4df27593b2efea → FINAL_TREE`; verificar `git apply --cached --check` en clon aislado sobre base exacta y que incluya archivos nuevos relevantes. No empaquetar la caché, la cuarentena, binarios hook, Git, credenciales ni datos privados.
- APK DEV **solo si nueva y compilada**, con hash; nunca agregar APK vieja. Si snapshot de C1 se reutilizó sin alteración, guardar **solo hashes/rutas/log** y no duplicar los 59 KB salvo necesidad probatoria justificada.

**QA tras fix de código:** correr SOLO pruebas del archivo/contrato cambiado, `flutter analyze` y formato sobre `lib/test` si hubo cambios Dart; suite global 3365 y focal 65 siguen como historial previo, NO declararlas nuevas. Si se modifican servidor+cliente, pruebas del delta y puente sobre FINAL_TREE son indispensables.

**Coordinación**: UN dueño del índice y del ZIP. Subagentes no obligatorios: en el host presionado por RAM, preferir ejecución secuencial. Ningún writer paralelo del mismo árbol ni caches. No `push`, `merge`, `deploy`, `reset`, `clean`, `stash` ni `force`. Un solo ZIP y una síntesis corta por chat.

## 4. Qué pasa después (no ejecutarlo ahora)

**Si C2 pasa puente:** Director abre solo gate siguiente de HTTPS real, seguridad del repositorio, firma/actualización Android y cobertura editorial oficial por modalidad.  
**Si C2 vuelve a encontrar hook/SDK incoherente:** Director decide reubicar build en host con recursos o fijar una sola versión Dart/Flutter para todo el proyecto, sin nuevos intentos ciegos; Codex entrega diagnóstico reutilizable.  
**Si APK no se puede compilar por <6 GiB libres:** estado `BLOCKED_RESOURCE`; cerrar el lote con puente y plan exacto de recursos, NO crear “C3 de auditoría”.

**Progreso heredado (estimación, no cálculo):** app integral ~58 %, núcleo técnico ~83 %; motor ~90 %, servidor ~85 %, editor manual ~75 %, Super Admin ~60 %, anuncios/aliados ~45 %, Android/release ~35 %. No incrementar sin nuevos gates y denominador medido. Cobertura oficial de toda Colombia sin porcentaje verificable.

# 🔴🔴🔴 SIGUE: CODEX LUNA — EJECUTAR C2, NO VOLVER A C1 — UN ZIP ÚNICO 🔴🔴🔴

**DESPUÉS DEL ZIP C2 SIGUE: CHATGPT DIRECTOR.**
