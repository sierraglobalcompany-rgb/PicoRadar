# CODEX LUNA — PICORADAR C2 V2 · DESBLOQUEO VERTICAL + AVANCE NACIONAL SIN PING-PONG

**ACTOR: CODEX LUNA (EJECUTAR). DIRECTOR: CHATGPT.**  
**Orden vigente:** `PICORADAR-N5R5R2-V2-C2-SQLITE3-VERTICAL-20261119` (**TASK_ID C2 sin cambiar**; V2 = revisión del mismo prompt, no crear C3 ni abrir dos ejecuciones).  
**Fecha de decisión:** 20/11/2026, `America/Bogota`.  
**Entrada:** ESTE `.md` físico; el candidato C1 ya existente en Windows y el ZIP C1 si el snapshot no está extraído. **No requiere el ZIP histórico perdido ni reconstruir N3/N4/N5.**  
**Entrega obligatoria:** **UN ÚNICO ZIP** `PICORADAR_N5R5R2V2_C2_RETORNO_UNICO.zip` + mensaje corto con ubicación, SHA-256, resultado, árbol y `NEXT=CHATGPT_DIRECTOR`. Ningún informe disperso.

> **Regla de concurrencia:** Si C2 anterior ya está ejecutándose, **NO lanzar V2** ni duplicar escritor. Si no comenzó, esta versión lo sustituye. `main`, PR #79, checkout protegido, servidores reales, APK pública y Xiaomi Mi A3 quedan intactos; `GITHUB_PRODUCT=HOLD_SECURITY`, `RELEASE=NO_GO`.

## 0. Semilla inmutable: qué está aprobado y qué no

| Contrato / evidencia | Estado heredado y decisión |
|---|---|
| **Código candidato** | Índice/árbol final C1 `859bb8bbdff769ec3504af407f4df27593b2efea`, **sin cambios de fuentes en C1**. Debe reutilizarse, no reconstruirse. |
| **PHP focal** | 53/53 pruebas, 592 assertions, **0 warnings en PHPUnit directo**, stderr vacío (C1). `PASS_SCOPED`, **NO volver a ejecutar por rutina**. Las 37 etiquetas WARN anteriores de Artisan no se reprodujeron en esa invocación; **no decir que se reparó Artisan** ni abrir incidente sin traza nueva. |
| **Flutter ya probado** | R2 V2: 65 focal PASS; 3.365 global PASS + 11 SKIP; analyze/formato PASS en el árbol R2 V2. **No repetir** si el código evaluado sigue igual. |
| **Único bloqueo técnico observable** | Puente Flutter no llegó a aserciones porque metadata de hook `sqlite3` usaba Dart `3.13.7` y Flutter activo `3.47.1`/Dart `3.13.1`. Hook `objective_c` ya se regeneró en C1: **no repetir esa reparación**. |
| **Snapshot Laravel de C1** | Release `59.273 B`, SHA-256 `9a230f167af82452276bbd505c6e3a69ce8406996e60c7baaf143e157979741e`; manifest `424 B`, SHA-256 `c19d611d255f0e360e284ac1e068e40d32a61006995c02f79b7488d8e936d9d0`. En ZIP C1 `QA_SNAPSHOT/`. Manifest dataset SHA = release SHA. Dataset `schemaVersion=2`; manifest `schemaVersion=1` es **otro contrato**, no defecto. Ocho jurisdicciones **LAB**, no cobertura nacional. |
| **APK y recursos** | No hay APK N4+N5 integrada. RAM libre medida en C1 = `2,31 GiB` (no valor actual), umbral conservador para Gradle adoptado = **6 GiB libres**; no forzar build ni matar procesos ajenos. |
| **WIP de origen** | En C1: HEAD/índice y 43 rutas WIP (18 modificadas, 25 sin seguimiento) iguales por conteos, **sin comparación byte a byte**. No afirmar `WIP_BYTES_PASS`; preservar eliminación preexistente `scripts/tests/test_hostinger_installer_browser.ps1`. |
| **HTTPS / GitHub / publicación** | HTTPS E2E no ejecutado, GitHub producto bajo `HOLD_SECURITY`, release `NO_GO`, Mi A3 sin intervención. PR #79 `OPEN/DRAFT` documental, no fusionar. |

**ZIP C1 identificador** `PICORADAR_N5R5R2V2_C1_RETORNO_UNICO.zip`, SHA-256 `c1576801bbd9c5f13722e381839b2a1d34c8e8c5629a8ce69dd74382098e9af6`; ZIP tiene 11 miembros, 10 entradas manifest verificadas. **No adjuntarlo de vuelta dentro del nuevo ZIP**. Esta orden **no transporta código**, porque el candidato está en el mismo host. Si el candidato ya no existe, una sola búsqueda restringida y diagnóstico; no iniciar reconstrucción histórica en este lote.

### Leyes y guardas del producto

- Respetar `AGENTS.md`, baseline aplicable, L1 KISS/Ponytail, L2 antirruido, L3 antiparches, L4 diseño humano, L5 verificación independiente, L6 antiping-pong. ChatGPT Director decide cambios sustantivos; Codex ejecuta y presenta evidencia verificable.
- Arquitectura: **un motor nacional tipado** `schemaVersion=2`, Flutter/Riverpod/Drift y **un Laravel** (sin segundo motor por ciudad). Editor manual por autoridad, municipio, modalidad, clase/servicio, días, dígitos, franjas, paridad, vigencia y fuentes; datos ordinarios por manifest/datasets OTA sin APK por ciudad. Sin cobertura válida = `UNKNOWN/STALE/CONFLICT`, nunca permiso implícito; sin convertir catálogos en normas verificadas.
- UI aprobada: `Inicio · Garaje · Apps · Viaje · Conducir` con **Apps en el centro**. Sin login obligatorio, Super Admin separado, cuentas voluntarias. Placas/VIN/documentos/GPS/rutas privados se quedan locales salvo autorización explícita del titular. Campañas, publicidad, correos reales, telemetría y marketing **OFF** en Free 1.0. Catálogos CDA/aseguradoras hash/rollback/fallback, y suspensión de una modalidad no elimina otras.
- **Prohibido** `reset/clean/stash` del origen, `flutter clean`, borrar cachés generales, cambiar SDK global, actualizar `pubspec.lock`/dependencias sin causa, sobrescribir reportes anteriores, reactivar Ads/SMTP, GitHub Actions de pago, push/merge/deploy, GitHub `main`, firma release, ADB o Mi A3. No imprimir PII, credenciales, tokens ni contenido de secretos en logs.

## 1. Ejecución cerrada por gates — orden corta y causal

### A · Integridad del candidato (una vez, solo lectura sobre origen)

1. Localizar SOLO en la ruta exacta citada en el informe C1 o `D:\codex\_isolated\PICORADAR-N5R5R2-20261119*`. Si hay más de un candidato, escoger el que exhiba árbol exacto + metadatos de C1; **no fusionar candidatos ni borrar nada**.
2. En el **candidato aislado**, confirmar `git write-tree` = `859bb8bbdff769ec3504af407f4df27593b2efea`, `git diff --name-only` vacío y `pubspec.lock` SHA-256 `e86ada9d658800b3c47bcfb1f8743d3ff14ce75fac1b81bc040b16ccfb03a41b`. Un `git write-tree` verificado acredita el índice, no pruebas runtime. Registrar almacenamiento de objetos/alternates usado para que el árbol no dependa de una variable desaparecida. **No reescribir el índice** en el preflight.
3. Detectar rutas `mobile/.dart_tool` y `mobile/.dart_tool/hooks_runner` físicas ordinarias, NO symlink/junction/reparse point. Usar explicitamente `D:\codex\_tool-cache\flutter-3.47.1\flutter\bin\flutter.bat` + Dart **3.13.1**. Si ese ejecutable real falta, `SDK_UNAVAILABLE` para el frente Flutter; continuar el frente independiente B, sin descargar otra versión al azar.
4. Observación WIP fuente SOLO lectura: HEAD, índice y resumen de 43 rutas, con huella de contenido **si es viable**, sin copiar bytes privados al ZIP. Si no se verifican bytes, `SOURCE_WIP_BYTES=NOT_VERIFIED`, sin forzar la comprobación ni tocar origen.

### B · Carriles concurrentes SIN competir por cachés ni RAM (máximo 2 agentes)

**Dueño único:** Codex integrador controla el índice Git del candidato, correcciones, builds, manifiesto y ZIP final. Nadie más escribe en ese índice. 

- **Carril 1 (principal): Flutter / SDK / puente**, pasos C y D; **un solo proceso Dart/Flutter a la vez**. No lanzarlo en paralelo con Gradle.
- **Carril 2 (opcional, bajo costo): verificación de entrega nacional y seguridad**, **solo lectura** del árbol y datasets, sin GitHub push, ni PHP tests repetidos ni instalación de dependencias. Subagente puede: (i) preparar **`NATIONAL_COVERAGE_MATRIX.csv`** únicamente de registros/fuentes locales realmente existentes, separando `VERIFIED_OFFICIAL`, `PARTIAL`, `UNKNOWN`, `STALE` y `NO_RESTRICTION_EXPLICITLY_VERIFIED` solo si la evidencia lo respalda; si el repositorio carece de un atributo, no inventarlo; (ii) revisar **solo el delta que eventualmente se pretendería publicar** para detectar rutas o credenciales potencialmente sensibles, sin emitir valores, y generar `GITHUB_SECURITY_GATE.md` con hallazgos, estado `REVIEW_REQUIRED` o `NOT_VERIFIED` (nunca certificar todo el historial por inspeccionar el delta). Es **preparación de cierre**, no auditoría global del proyecto. Si la memoria o el aislamiento no permiten paralelismo, ejecutarlo **secuencialmente tras el puente**. No debe retrasar C ni justificar un segundo ZIP.

**Fallo sin bucle:** si un carril queda bloqueado por ambiente, el otro continúa solo cuando sea independiente y seguro. **Ningún subagente instala paquetes, actualiza ramas, modifica cachés o reinicia procesos ajenos.** No crear múltiples agentes para «parecer más avanzado».

### C · Resolver `sqlite3` sin repetir `objective_c`

1. Verificar que el error corresponde al hook **local exacto** `mobile/.dart_tool/hooks_runner/sqlite3` (si el log demuestra otro nombre, ajustar al nombre probado, no suponer). Confirmar su ubicación real dentro del candidato, metadatos Dart 3.13.7 y que no es symlink/junction. **Si ya está regenerado con el SDK activo, no moverlo**.
2. Inventariar archivos relativos, tamaños y SHA-256; guardar solo el CSV de inventario, **no binarios**. Mover **únicamente** esa carpeta de hook a `mobile/.dart_tool/_picoradar_c2_quarantine/` con nombre único no existente; ruta de destino local ignorada y reversible. **No borrar la carpeta**, no mover otros hooks, no modificar `.pub-cache`, `flutter` global ni `pubspec.lock`.
3. Ejecutar **UNA VEZ** el test real existente del puente desde D, con el Flutter **3.47.1** explícito (sin `flutter clean`, sin `pub get` si las dependencias están resueltas). Capturar stdout/stderr/exit code, metadata post-run y si las aserciones realmente empezaron.
4. Si vuelve a salir `Invalid SDK hash` en **otro** hook local, se admite **a lo sumo uno adicional**, con idéntica evidencia+cuarentena, y **una última ejecución** del puente. Si falla por otra causa, no seguir limpiando ni actualizar Flutter: clasificar `FAIL_CODE` o `PARTIAL_ENV` según traza, y resolver **solo un defecto de código reproducido** si está dentro del alcance del puente. No repetir la ejecución indefinidamente.

### D · Puente real Laravel → Flutter / Drift, con los MISMOS bytes de C1

1. Reutilizar exactamente `QA_SNAPSHOT/PHP_G2_V3_REAL_LAB_RELEASE.json` y `QA_SNAPSHOT/PHP_G2_V3_REAL_LAB_MANIFEST.json` de los reportes C1. Si faltan extraídos, una única extracción del ZIP C1 **a directorio QA aislado**, validar tamaño+SHA de ambos. Si falta también el ZIP, una sola regeneración por publicador/test Laravel real, hashes nuevos y evidencia; **no crear JSON manual ni afirmar que son los hashes C1**.
2. Verificar que `datasets.restrictions.sha256` del manifest = SHA real del release, `schemaVersion=2` en dataset, y que la cobertura `partial` sintética no se transforma en permiso general. El dataset de ocho jurisdicciones es LAB y **no** demuestra cobertura colombiana completa.
3. Ubicar el test real `restriction_g2_same_bytes_test.dart` a través de `git ls-files`; leer sus aserciones antes de etiquetar qué comprueba. `PICORADAR_G2_V3_EVIDENCE_DIR` debe apuntar **solo** al directorio QA donde están los dos JSON íntegros. Ejecutar el test Flutter real con `--no-pub` cuando aplique; registrar ruta, SDK, argumentos, hashes del snapshot, aserciones efectivamente ejecutadas y exit code. **No crear un test de fachada ni importar manualmente una respuesta precocinada para simular Laravel**.
4. `VERTICAL_SAME_BYTES=PASS_LOCAL` **solo** si el test realmente arranca, ejecuta aserciones relevantes del importador/consumidor Flutter sobre los bytes del publicador Laravel y termina 0. Informar por separado `ROLLBACK_LAST_GOOD`, `OFFLINE`, `MIGRATION_DRIFT` según las **aserciones que existen y corrieron**; no dar PASS a lo que no se midió. Si el test solo prueba hash/lectura, no afirmar rollback, offline o HTTP/HTTPS completo. Una ejecución localhost/archivo es **LOCAL**, nunca `HTTPS_E2E`.
5. Si surge un fallo **de código** reproducido: corregir en el candidato aislado (un único integrador), prueba focal causal correspondiente y, si toca Dart, `flutter analyze` y formato sobre `lib/test` afectados. Sin cambios de código: no repetir 65 tests focales ni la global 3.365. No alterar normas legales para hacer verde.

### E · APK DEV solo si el ambiente la permite

1. **Después** del puente, medir RAM libre **actual**, almacenamiento útil en el volumen donde compila Gradle y SDK/JDK/firma DEV configurados; registrar números exactos. **Si RAM libre <6 GiB, NO lanzar Gradle** y marcar `APK_DEV=BLOCKED_RESOURCE`. No liberar RAM matando procesos ajenos ni ejecutar compilaciones concurrentes.
2. Con RAM ≥6 GiB, Flutter/SDK coherente y tests esenciales verdes, **una única compilación DEV** del **árbol final**. Registrar comando, variante, versión, applicationId, SHA del APK, tamaño, certificado público/fingerprint y resultado. A lo sumo un reintento por error causal reparable sin reestructurar el ambiente. No llamar a esto release ni instalar en Mi A3.
3. Si C/D quedan bloqueados y la RAM sigue baja, **no detener el lote con otro informe vacío**: entregar matriz nacional y evaluación de seguridad del delta si fueron posibles, descripción reproducible del bloqueo y una sola propuesta concreta para el próximo gate de entorno. No inventar código ni duplicar pruebas ya verdes.

## 2. Retorno **ÚNICO** y verificable: un ZIP, no diez paquetes

Crear `D:\codex\_REPORTES\PicoRadar\N5R5R2-V2-C2\PICORADAR_N5R5R2V2_C2_RETORNO_UNICO.zip` sin sobrescribir ZIP anteriores. **ZIP pequeño**, sin los 59 KB del snapshot si basta con hashes, excepto si la reproducción exige sus bytes. Contenido:

- `FINAL_REPORT.md`: `TASK_ID`, herramientas/versiones, `SOURCE_TREE`/`BASE_TREE`/`FINAL_TREE` de 40 hex, prueba SDK/bridge, aserciones reales, causas de bloqueo, APK sí/no, si hubo archivos cambiados y siguiente actor ChatGPT Director. Resumen en lenguaje claro de **lo que implementaste**; si no se implementó código, escribirlo sin maquillaje.
- `GATES.csv`: `PHP_FOCAL_REUSED`, `FLUTTER_GLOBAL_REUSED`, `SOURCE_WIP`, `SOURCE_WIP_BYTES`, `SDK_SQLITE3`, `VERTICAL_SAME_BYTES`, `ROLLBACK_LAST_GOOD`, `OFFLINE`, `MIGRATION_DRIFT`, `APK_DEV`, `GITHUB_SECURITY`, `NATIONAL_LEGAL_COVERAGE`, `OTA_HTTPS`, `RELEASE`, cada uno con `PASS_SCOPED/PASS_LOCAL/NOT_RUN_ENV/PARTIAL_ENV/FAIL_CODE/BLOCKED_RESOURCE/REVIEW_REQUIRED/NO_GO` y evidencia identificable.
- `QA_LOGS/sdk_sqlite3.txt`, `QA_LOGS/vertical_same_bytes.txt`, `QA_LOGS/resources_build.txt`, `QA_LOGS/source_wip.txt`, con comandos, exit codes y errores **sanitizados**; logs compactos, no raw secrets.
- `NATIONAL_COVERAGE_MATRIX.csv` y `GITHUB_SECURITY_GATE.md` **solo si realmente se pudo hacer el carril 2**; dejar evidencia de inputs, conteos y limitaciones. No marcar `VERIFIED_OFFICIAL` sin fuente y ámbito validado; no publicar material privado en GitHub.
- `RECOVERY_C2.patch` **solo si cambian fuentes**; del índice base exacto `859bb8bbdff769ec3504af407f4df27593b2efea` al árbol final. Verificar integridad del parche (`--binary` cuando corresponda), que el árbol de destino coincide y que no incluye secretos. **Los cambios de caché/hook no son cambios del producto y NO necesitan parche artificial.**
- **Solo si se construyó**: APK DEV nueva (nunca vieja), hash/tamaño/certificado en informe. Mantener el ZIP único, si la APK lo hace grande es aceptable, pero nunca duplicarla.
- `MANIFEST.csv` con path, bytes, SHA-256, CRC32 de todos los otros miembros (sin autocitar el propio manifest). Validar ZIP CRC + manifiesto + SHA ZIP final; reportar SHA en respuesta. **Solo ese ZIP**, no rutas ni archivos sueltos como entregas.

**Prohibido**: commits al repositorio original, push/merge a GitHub producto, deploy, `reset/clean`, borrar o regenerar datos privados, activar anuncios o SMTP. El hecho de que PR #79 siga Draft **no autoriza** integrar la rama documental con `main`. Mantener `HOLD_SECURITY` hasta resolución real del historial y una autorización expresa.

## 3. Exit criteria y trabajo que sí acerca al 100 %

**Cierre C2 técnico (sin falsear release):** a) `SDK_SQLITE3=PASS` + puente real `PASS_LOCAL`; b) si RAM lo permite, APK DEV derivada del árbol exacto; c) evidencia de riesgos editoriales y seguridad preparada. Si el SDK o memoria siguen bloqueados, C2 puede cerrar `PARTIAL_ENV` con avances independientes **documentados**, pero no declarar el producto listo ni producir otro C2 por rutina.

**Gate siguiente tras C2 (Director, no en este lote):** OTA **HTTPS real** servidor/CDN con el mismo dataset, firma DEV/release bajo autorización, migración Drift/upgrade, QA física Mi A3 sin pérdida de vehículos, seguridad histórica GitHub y habilitación de distribución. La **cobertura nacional oficial** se amplía por lote de fuentes institucionales y modalidades, sin inferir permisos en ciudades sin norma validada; catálogo geográfico ≠ cobertura legal.

**Porcentajes heredados de planificación (NO métricas medidas):** app integral **≈58 %**, núcleo técnico **≈83 %**; motor 90 %, servidor 85 %, editor nacional 75 %, OTA 60 %, Super Admin 60 %, cuentas 65 %, publicidad 45 %, Android/release 35 %. **No incrementarlos por logs o documentación**. Elaborar tabla de gates con denominador observable en futuros cierres; la cobertura legal colombiana no tiene porcentaje demostrable.

## 4. Autocontrol del Director: 10 VERDUGO + 10 JUEZ del PROMPT C2 (no reejecutar estas 20 revisiones en Codex)

| Pasada | VERDUGO — riesgo contrastado | Decisión y prueba mínima |
|---|---|---|
| V01 | Lanzar C2 dos veces | Mismo TASK_ID; reemplazo solo si original no arrancó. |
| V02 | Perder WIP original | Fuente lectura y C1 no certifica comparación de bytes; no tocar checkout. |
| V03 | Usar árbol equivocado | Requerir `859bb8bb...` exacto en índice aislado. |
| V04 | Recaer en ZIP perdido R1 | C2 reutiliza candidato y snapshot C1; sin búsqueda global. |
| V05 | Borrar caches o mezclar SDK | Solo hook local con inventario/quarantine y Dart 3.13.1. |
| V06 | Bucle de hooks inválidos | Máximo dos hooks locales nuevos y dos invocaciones del puente. |
| V07 | Dar PASS sin aserciones | `VERTICAL_SAME_BYTES` exige test real iniciado y assertions. |
| V08 | Confundir schema1 manifest con schema2 dataset | Contratos separados; verificar SHA y fuente real. |
| V09 | Compilar con RAM 2,31 GiB | Medición actual y piso 6 GiB; ningún Gradle bajo piso. |
| V10 | Publicar código o reglas inseguras | `HOLD_SECURITY`, UNKNOWN/STALE y ads OFF. |

| Pasada | JUEZ — alternativa examinada | Sentencia útil |
|---|---|---|
| J01 | Volver a ejecutar 53 PHP / 3.365 Flutter | Rechazada: ya PASARON en árbol sin cambios. |
| J02 | Crear C3 antes del bridge | Rechazada: C2 V2 es ajuste del mismo lote. |
| J03 | Lanzar tres workers Flutter/Gradle | Rechazada por cachés compartidas y memoria. |
| J04 | Subagente de solo lectura backend/seguridad | Aprobado si aislado y liviano; no bloquea C2. |
| J05 | Rehacer motor por ciudad | Rechazada: un schema2 y OTA existente. |
| J06 | Tomar ocho jurisdicciones LAB como cobertura | Rechazada: solo fixtures. |
| J07 | Tratar PHP WARNING Artisan como defecto reparado | Rechazada: PHPUnit cero warnings no prueba Artisan; gate acotado. |
| J08 | Afirmar rollback y Drift por pasar hash | Rechazada: solo estado cubierto por aserciones reales. |
| J09 | Subir integración a GitHub para «avanzar» | Rechazada: seguridad pendiente; doc sí, producto no. |
| J10 | Cortar el lote sin nada por RAM/SDK | Rechazada: continuar evidencia independiente segura y entregar ZIP útil. |

**Autocontrol completado de diseño documental; NO son 20 suites de software ni una certificación funcional.** No pedir a Codex repetirlo. Una sola ejecución, evidencias causales, y siguiente relevo.

# 🔴🔴🔴 SIGUE: CODEX LUNA — EJECUTAR C2 V2 Y ENTREGAR UN ZIP ÚNICO 🔴🔴🔴

**DESPUÉS DEL ZIP C2 SIGUE: CHATGPT DIRECTOR.**
