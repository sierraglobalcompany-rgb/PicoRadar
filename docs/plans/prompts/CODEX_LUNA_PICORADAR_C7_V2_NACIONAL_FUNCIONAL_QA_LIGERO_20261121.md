# CODEX LUNA — PICORADAR C7 V2 · BANDEJA NACIONAL REAL + FUENTES OFICIALES + QA ANDROID/HTTPS + GITHUB

**EJECUTOR: CODEX LUNA. DIRECTOR: CHATGPT.** Fecha de corte: 21/11/2026, Colombia.  
**TASK_ID único:** `PICORADAR-C7-V2-IMPLEMENTACION-NACIONAL-20261121`. **Sustituye C7 original SI aún no se ejecuta.** No iniciar ambos ni un nuevo C7.1.  
**Objetivo:** terminar **al menos un recorrido funcional nuevo en runtime** y continuar los gates de lanzamiento sin perder trabajo en bloqueos externos. Ejecutar, no reauditar. **Resultado: UN SOLO ZIP LIGERO SIN APK NI CÓDIGO COMPLETO.**

## 0. Decisión del propietario: archivos ligeros y APK local

- **NO PEDIR, NO ADJUNTAR, NO COMPRIMIR Y NO RECONSTRUIR POR RUTINA LA APK C6.** El propietario la excluyó expresamente para ahorrar espacio; no enviar AAB, TAR, bundle, PDF pesado, código fuente completo, dumps, artefactos base64 ni ZIP anidados. No generar nuevamente paquetes de recuperación de 77 MB.
- APK DEV C6 compilada localmente (no QA de teléfono): `co.picoradar.app.dev`, `1.0.1+2`, firma de depuración v2, SHA-256 `245e285d86fa2057dd53870fc38141746b61342821012abd1f761857395fb639`. **Si se conserva localmente**, usarla únicamente allí. `APK_BUILD_PASS` es **reutilizado**, no un gate nuevo. Si no existe, registrar `APK_LOCAL_MISSING` y seguir.
- Un ZIP final de informes y *delta textual* objetivo **≤2 MiB**, tope **≤5 MiB** sin autorización expresa. Se adjunta ese ZIP a ChatGPT, no una ruta de Windows fingida como descarga.

## 1. Base exacta y hechos ya aprobados (NO repetir)

- GitHub canónico `sierraglobalcompany-rgb/PicoRadar`. **Código completo remoto en rama** `backup/picoradar-c6-source-20261120`: commit `bc1422c7198607850a49f4a294ed67316fed0805`, tree `2c0fd2e7a4ef8eed5b342101afb7320982d3c07c`, **1.882 blobs verificados**. Esta rama es root/source-only, **NO** descendiente de `main` ni merge-ready; no moverla.
- `main` observado por el director: `e9ef37511df3110ffb0fc006ef06be781df432ac` (verificar solo con una lectura al publicar si hace falta); PR #79 OPEN/DRAFT en otra base, **intocable**.
- C6: exportación CSV editorial y matriz de **33 departamentos y 1.104 municipios**, `NO_JURISDICTION`/`UNKNOWN`, versión editorial separada de release publicado; PHP 3 pruebas/41 aserciones y 8 regresiones/80 aserciones PASS. C5: Laravel 6 pruebas/98 aserciones y Flutter 3 tests PASS. C4: flujos del editor y widget PASS. C2: puente Laravel→Flutter `PASS_LOCAL`. **No repetir ninguno sin cambio relacionado.**
- `EVIDENCE_SCORE_BASE=61/100`; **esto NO es 61 % de la aplicación terminada**. Desarrollo histórico estimado 58 % y núcleo 83 %: **no medidos actualmente**. `LEGAL_NATIONAL_COMPLETION=NO_MEDIBLE` hasta definir jurisdicciones/categorías y fuentes normativas.
- WIP protegido: HEAD `182a8821bba688b28a6e223a1e956df748f7948b`, 43 rutas (18 M, 25 ??), todas intactas según C6. **No leer, modificar, borrar, resetear ni limpiar** ese checkout por esta tarea. No eliminar junction `server/vendor`, ni restaurar `scripts/tests/test_hostinger_installer_browser.ps1` de otro checkout.
- Producto: navegación exacta `Inicio · Garaje · Apps · Viaje · Conducir` (Apps al centro), sin cuenta, Flutter/Riverpod/Drift, Laravel control plane, motor local y OTA nacional, cero GPS continuo al servidor. **Publicidad, campañas públicas, pagos y premium OFF en Free 1.0**; tener modelos o interfaz editorial NO autoriza activarlos.

## 2. Decisión del director: 1 trabajo funcional obligatorio + 2 frentes que no bloquean

**NO PERMITIR `PARTIAL` de solo logs o pruebas si el entorno permite editar código PHP.** El C7 original tenía una salida sin código por falta de HTTPS/dispositivo. Ahora el **Frente A es obligatorio** e independiente de ambos. Se permite declaración `BLOCKED` únicamente con causa reproducible y evidencia, nunca omisión.

**Roles máximos:** `AGENTE_SERVER` (A: PHP/Blade/tests), `AGENTE_LEGAL` (B: investigación y borradores, solo lectura del código hasta que el integrador autorice una adición), `INTEGRADOR` (C Android/HTTPS y D GitHub). Si hay capacidad, A y B en paralelo **sin escribir los mismos archivos**, C con recursos separados; si no, ejecutar A→B→C→D secuencial. **Un único propietario del índice, de los commits, del push y del ZIP.** No poner dos agentes a escribir sobre un mismo checkout/`.dart_tool`/Gradle. Los subagentes entregan un parche y evidencia focal al integrador.

Crear **un clon aislado** de `backup/picoradar-c6-source-20261120` en `D:\codex\_isolated\...`, validar commit/tree una sola vez, crear nueva rama `feat/C7-national-review-20261121` descendiente exacta del commit C6. Consultar `AGENTS.md` y contratos de baseline pertinentes en esa copia; cumplir prioridad seguridad > baseline > arquitectura > flujos. No usar `main` como base ni materializar de nuevo el TAR C6. No ejecutar Actions.

## 3. FRENTE A — entregar nueva bandeja municipal operativa (IMPRESCINDIBLE)

**Brecha comprobada en el código C6:** `server/app/Http/Controllers/Admin/RestrictionRuleController.php::index` recorre **jurisdicciones existentes**, mientras `streamMunicipalityCoverage` del mismo controlador ya enumera **todos** los `GeographicUnit` con `level='municipality'` para el CSV. Por tanto, **los municipios sin jurisdicción aparecen en el CSV pero no tienen revisión interactiva equivalente**. Cerrar esta brecha, no volver a implementar el CSV.

**Implementación mínima A1/A2:**

1. Agregar una entrada visible **"Matriz municipal"** en la bandeja actual `server/resources/views/admin/restrictions/index.blade.php`, y una pantalla Blade compacta accesible **solo con `Gate::authorize('datasets.view')`**. Ruta GET nombrada p.ej. `admin.restrictions.municipalities`, registrada en `server/routes/web.php`, controlador actual `RestrictionRuleController` (no crear otro módulo, servicio ni modelo). Si existe ya una pantalla equivalente en el árbol candidato, extenderla sin duplicación y mostrar el diff que lo prueba.
2. Mostrar filas de municipios **con y sin jurisdicción**, código DIVIPOLA, departamento, nombre, jurisdicción existente, estado administrativo (`ACTIVE`/`INACTIVE`/`NO_JURISDICTION`), estado de evidencia (`VERIFIED`/`PARTIAL`/`STALE`/`UNKNOWN`) y **versión publicada solo cuando exista**. `UNKNOWN` **nunca equivale a `ALLOWED`** y el borrador nunca es release publicado. Las filas con múltiples jurisdicciones/categorías deben conservar su distinción o presentar una vista resumida inequívoca, sin perder cobertura.
3. Filtros reales GET: `q`, departamento, estado de gestión y estado de evidencia. **Paginación en servidor con orden estable, máximo 50 municipios por página**; no cargar 1.104 municipios con toda su descendencia en memoria ni crear N+1 masivo. Reutilizar los helpers y la semántica `coverageSummariesForVersion`, `unknownCoverage`, `publishedReleaseForVersion` y las relaciones `GeographicUnit::jurisdictions`, evitando una segunda fórmula de vigencia. Si no se puede mantener semántica con una sola consulta, preferir página **de municipios** y detalle on-demand simple, no hacer un refactor de arquitectura.
4. Acciones claras: visualizar solo para rol lector; ofrecer navegación **a las rutas de edición/revisión que ya existen** únicamente con permisos pertinentes. Prohibido crear norma, jurisdicción ficticia, aprobación o publicación automática al navegar. No modificar API pública, migraciones, motor Flutter, categorías, fuentes oficiales ni banderas comerciales.
5. QA **nuevo y causal**, no baterías globales: 2–4 pruebas focales que demuestren (a) `NO_JURISDICTION + UNKNOWN` visible/filtrable, (b) municipio con jurisdicción `INACTIVE`, (c) no filtración de release editorial, (d) denegación/ocultación de acciones cuando el rol no autoriza. Incluir prueba de paginación/búsqueda cuando sea el camino crítico. `php -l`, Pint focal y comandos con exit. Si una prueba falla, arreglar causa y **un** retry focal. Reutilizar el resultado C6 de exportación; no repetirlo.

**Gate A = `PASS_NEW_RUNTIME`** solo si hay cambios runtime y se verifica la pantalla/ruta real. No aceptar simplemente un CSV nuevo, solo informe, ni tests de funciones existentes.

## 4. FRENTE B — avanzar cobertura normativa real sin afirmar certificación nacional

**Prioridad:** hasta **3 jurisdicciones relevantes: Medellín, Bogotá y Cali**, seleccionadas porque existen fuentes oficiales identificadas a fecha de decisión. La búsqueda de las fuentes **ya comenzó**: NO reiniciar investigación amplia, ni inventar normas. El trabajo es convertir hallazgos oficiales en **fichas editoriales utilizables y, cuando el acto completo lo permita, borradores tipados en entorno aislado**, nunca publicación automática.

Puntos de partida oficiales (URLs de descubrimiento, **NO** prueba por sí sola de cada excepción, perímetro, vehículo o acto completo):

- Medellín: Alcaldía, anuncio de rotación segundo semestre 2026, 24/07/2026: `https://www.medellin.gov.co/es/sala-de-prensa/noticias/la-nueva-rotacion-del-pico-y-placa-en-medellin-comenzara-a-regir-a-partir-del-lunes-3-de-agosto/` y ficha geográfica oficial que menciona **Decreto 1490/2026**: `https://www.medellin.gov.co/giscatalogacion/srv/api/records/2d9cb19a-e7c7-4e1d-8a38-fb055997b043`.
- Bogotá: portal oficial con calendario **16–22/11/2026** para particulares, taxis, especiales y carga: `https://bogota.gov.co/mi-ciudad/movilidad/2026-11/pico-y-placa-en-bogota-de-la-semana-del-16-al-22-de-noviembre-de-2026`. **Un calendario semanal no sustituye el acto normativo vigente ni acredita toda la ciudad/multimodalidad.** Investigar resolución/decreto de la autoridad SDM antes de elevar estado jurídico.
- Cali: Alcaldía, rotación segundo semestre 2026: `https://intranet.cali.gov.co/2026/07/01/pico-y-placa-rota-en-cali-para-el-segundo-semestre-de-2026/` y boletín oficial que indexa **Decreto 4112.010.20.0814 del 26/06/2026**: `https://web1.cali.gov.co/aplicaciones/boletin_publico/detalle_boletin.php?id=3434&num=103`. **Este último enlace puede bloquear acceso automatizado: no superar CAPTCHA ni inventar lectura del decreto.**

Por cada jurisdicción completar `LEGAL_PILOTS.csv` con municipio/código, autoridad y acto identificados, URL **oficial**, fecha, inicio/fin de vigencia, categoría, horario, dígitos/alternancia, excepciones y perímetro **SOLO si la fuente los dice inequívocamente**; `verified_at`, `stale_after`, partes desconocidas y estado editorial. Distinguir **página informativa** de **acto normativo íntegro**; sin éste, conservar `PARTIAL`/`UNKNOWN` y marcar campos `NO_CONFIRMADO`. Verificar si el archivo publicado y la versión previa local discrepan, **sin cambiarla automáticamente**.

**Entregable nuevo exigible** aunque la fuente íntegra falte: tres fichas de decisión con enlace oficial y brecha precisa; al menos un **borrador no publicado** en entorno aislado cuando haya evidencia jurídica suficiente para los campos que se carguen. No escribir restricciones inferidas ni subir PDFs/datos normativos pesados. Si no hay Internet o todas las fuentes son insuficientes, dejar tabla parcial con URLs y `NO_OFFICIAL_ACT_FULLTEXT`, e informar la limitación sin bloquear A.

Para reglas que puedan modelarse con el motor tipado existente, una prueba focal **solo de la nueva regla oficial** con fecha y categoría concreta; no repetir los 3.365 tests ni R2 Bogotá. Si la modalidad exige nueva semántica (ej. regional, carga o excepciones espaciales) **no codificarla en modo `ALLOWED` ni simplificarla**: documentar soporte ausente para el próximo lote, sin meter otra arquitectura.

**Gate B:** `EDITORIAL_SOURCE_EVIDENCE` o `DRAFT_UNPUBLISHED_SOURCED`, **no** `NATIONAL_LEGAL_PASS`. No afirmar cobertura nacional = 1.104 ciudades.

## 5. FRENTE C — puertas Android y HTTPS, sin estancar A ni B

### Android — dispositivo y alternativa no destructiva

1. Consultar únicamente disponibilidad de APK **local** C6/hash y `adb devices -l` **read-only** una vez. **No usar teléfono del propietario, instalar, sobrescribir, desinstalar, borrar datos, actualizar firma ni cambiar conectividad sin autorización específica.** Existe antecedente de incompatibilidad de firma Mi A3: un `adb install -r` no está autorizado implícitamente por este prompt. Conservar el APK en host, nunca ZIP.
2. Si ya existe **emulador Android configurado y usable**, y ejecutar no requiere descargar gigabytes ni alterar dispositivo real, instalar allí la APK C6 **localmente** y probar inicio sin cuenta, cinco pestañas, ciudad con norma conocida vs `UNKNOWN`, reinicio de proceso, catálogos offline y ausencia de crash; sin datos personales. Informar `EMULATOR_PASS` **distinto de** `PHYSICAL_DEVICE_PASS` (emulador no acredita cámara/GPS/HUD ni compatibilidad física). No crear/descargar emulator nuevo ni compilar por rutina.
3. Si no hay emulador ni autorización para dispositivo, `PHYSICAL_DEVICE=BLOCKED_AUTHORIZATION/UNAVAILABLE`, `EMULATOR=UNAVAILABLE`; avanzar A/B/D. No preparar otra gran auditoría de entorno, no solicitar APK.

### HTTPS — no confundir con loopback

1. Si hay staging **ya autorizado, operativo y con dominio/certificado válidos**, hacer una sola prueba **real de red HTTPS**: validación TLS (sin `verify=false`), manifest, descarga, SHA, revisión de cache y fallback local; sin usar producción, sin subir credenciales ni secretos a ZIP. El consumo cliente completo solo `PASS` con evidencia cliente real.
2. Si no existe staging, **no prometer HTTPS real**. Si el proyecto ya tiene infraestructura de test TLS aislada/confiable, ejecutar **una** prueba de contrato a través de TLS local con CA efímera confiada explícitamente *solo dentro del test*; etiquetar `LOCAL_TLS_CONTRACT`, nunca `HTTPS_REAL`. **No agregar nueva infraestructura TLS** solo para puntuar; si no está lista, `HTTPS_REAL=BLOCKED_EXTERNAL` y continuar.
3. Mantener `RELEASE=NO_GO`. La ausencia de dispositivo/dominio no debe detener nuevo código A ni investigación B.

## 6. FRENTE D — cambios reales a GitHub, sin un merge peligroso

1. Integrar A y, si corresponde, B en una única rama `feat/C7-national-review-20261121`, descendiente de C6. **Nunca** actualizar o sobrescribir `backup/picoradar-c6-source-20261120`, `main` ni PR #79; no inventar ancestría entre ramas sin ancestro.
2. `git diff --check`; pruebas **solo tocadas**, estado limpio; revisión de secretos de diff y nuevos archivos con gitleaks ya disponible si está operativo. Si no hay escáner estándar, `SECRET_SCAN=BLOCKED_TOOL`; no afirmar `SECRET_SCAN_PASS` por grep. Nunca hacer push si hay secretos reales, datos personales o sospecha no resuelta. Revisar que el commit no incorpore artefactos, .env reales, APK, TAR, bundle, binarios privados ni caches.
3. Publicar **un solo push no forzado** a la nueva rama. Verificar commit/tree en remoto. **Si hay código nuevo probado y la rama de respaldo C6 es base visible, abrir PR DRAFT de C7 contra `backup/picoradar-c6-source-20261120`**, nunca `main`; no ejecutar GitHub Actions ni hacer merge. Si no se puede, reportar exactamente el bloqueante después de un intento causal, pero entregar delta texto pequeño en ZIP.
4. Actualizar el estado **en la misma rama** en **un documento corto** (`README_C7_HANDOFF.md` o equivalente) con commit, árbol, gates, evidencia legal, bloqueos reales, próximo macrobloque. Nada de 20 documentos recovery ni snapshot redundante.
5. **No equiparar respaldo remoto/PR Draft con integración productiva**: `MAIN_INTEGRATION=HOLD_COMPATIBILITY`. La futura estrategia de convergencia con `main` se decide después, sin forzar las ~838 diferencias y sin cambiar rama por defecto de GitHub.

## 7. Aceptación, tiempo, no ping-pong y métricas

Orden estricto de utilidad: **A runtime funcional → B fuentes legales → C gates reales si alcanzables → D push/PR y evidencias**. Agentes paralelos solo si RAM/discos permiten; no arrancar compilación pesada junto a PHP/Flutter. No esperar a HTTPS/dispositivo para ejecutar A.

**Gates:**
- `A_MUNICIPAL_UI=PASS_NEW_RUNTIME` requiere navegación humana real, filtros/estado/roles y tests causales. Si falla, `FAIL` con salida, no `PASS_SCOPED` sin comportamiento.
- `B_LEGAL=EDITORIAL_SOURCE_EVIDENCE/DRAFT_UNPUBLISHED_SOURCED/PARTIAL_OFFICIAL/BLOCKED_SOURCE`; *no se aprueba norma por noticia sin acto íntegro*.
- `C_ANDROID=EMULATOR_PASS/PHYSICAL_DEVICE_PASS/BLOCKED_EXTERNAL`; nunca confundir emulador con físico, ni APK build con QA.
- `C_HTTPS=PASS_REAL_HTTPS/LOCAL_TLS_CONTRACT/BLOCKED_EXTERNAL`; no confundir TLS local con servidor público.
- `D_GITHUB=BRANCH_AND_DRAFT_PR_PASS/BRANCH_ONLY_PASS/HOLD_SECURITY/HOLD_AUTH`; rama y commit remoto verificados.
- `ADS_PAYMENTS_PREMIUM=OFF`, `MAIN_INTEGRATION=HOLD_COMPATIBILITY`, `RELEASE=NO_GO` salvo aprobaciones externas posteriores explícitas.

**Reintentos:** inicial + máximo **uno causal por error corregible**, no `flutter clean`, no global cache purge, no instalar herramientas masivas ni tocar protected WIP. No ejecutar suites globales históricas (PHP 53, Flutter 3.365, C2/C3/C4/C5/C6) sin modificación relacionada. No documentar que se ejecutó lo que solo se reutilizó.

**Progreso medido en dos columnas:**
1. `EVIDENCE_SCORE=61/100` antes; cambiar solo un criterio de la rúbrica original si su gate nuevo realmente pasó. La rúbrica original C6 es: motor 7/14, legal 0/12, editor 12/12, permisos 9/9, publicación 11/11, OTA 5/10, Drift 7/7, UX 5/6, campañas 5/5, integración GitHub 0/4, HTTPS 0/5, Android/QA 0/5. **No regalar puntos** por UI de editor ya al máximo o por APK compilada anteriormente.
2. `DELIVERED_FUNCTIONS`: contar nuevas funciones runtime, flujos comprobados, jurisdicciones con **acto jurídico íntegro**, borradores no publicados, dispositivo probado, HTTPS real y commit nuevo remoto. **NO calcular un porcentaje global de producto sin un inventario de funcionalidades/denominador firmado**. La estimación heredada del 58 % no se actualiza por inercia.

## 8. Cierre liviano obligatorio: un solo ZIP y NINGUNA APK

Directorio local: `D:\codex\_REPORTES\PicoRadar\C7-V2-20261121\`, archivo **`PICORADAR_C7V2_RETORNO_UNICO_LIGERO.zip`**. Incluir solo:

- `FINAL_REPORT.md` (máximo ~120 líneas): resultado directo, archivos runtime nuevos, capacidades disponibles, evidencia nueva, lugar de código remoto, bloqueos, NEXT.
- `GATES.csv`: exacto `PASS`, `REUSED`, `NOT_RUN`, `BLOCKED`, causa, prueba/URL y `next_action`.
- `LEGAL_PILOTS.csv`: a lo sumo 3 ciudades, URLs oficiales, verificaciones y campos no confirmados; no PDF descargado.
- `CODE_DIFF.csv` y `C7_DELTA.patch` **solo si hubo modificaciones**, generados desde C6, textos sin credenciales; no incluir source tree.
- `QA/` logs **focales** sanitizados: comandos/exit/resultado, ADB solo información no sensible, TLS solo si se verificó, resultados de tests. **NO incluir APK**, ni siquiera como adjunto anidado; `QA/APK_IDENTITY.txt` solo identidad/hashes y disponibilidad local.
- `MANIFEST.csv`: cada archivo distinto de manifiesto con tamaño, SHA-256, CRC32; validar CRC de ZIP, hashes y recuento; imprimir SHA-256 ZIP final.

**No adjuntar README de recuperación múltiple, no TAR, Git bundle, ZIP anidado, screenshots con placas, `.env`, cuentas, datos GPS ni trazas de host sensible.** Si el patch supera 5 MiB, no truncarlo para ocultar cambios: en ZIP solo diffstat + SHA/ref remoto y explicar la excepción; fuente verificable permanece en rama GitHub.

**Respuesta final de Codex en una línea:**  
`TASK_ID | RESULT | NEW_RUNTIME_FILES | A_MUNICIPAL_UI | B_LEGAL | C_ANDROID | C_HTTPS | D_GITHUB | COMMIT | PR | RELEASE | ZIP_PATH | ZIP_SHA256 | NEXT=CHATGPT_DIRECTOR`.

## 9. Auditoría diferencial realizada por CHATGPT DIRECTOR (NO repetir en Codex)

### Diez pasadas como VERDUGO: problema detectado → corrección del C7 original

| # | Defecto/fallo potencial | Corrección aplicada |
|---|---|---|
| V1 | Todo puede quedar `BLOCKED_EXTERNAL` sin código nuevo | A municipal con cambio runtime obligatorio e independiente |
| V2 | QA de Mi A3 sin autorización de instalación | Preflight solo lectura; no instalación física sin autorización específica |
| V3 | Mezcla QA en emulador con dispositivo físico | Estados y pruebas separadas |
| V4 | HTTPS sobre loopback presentado como HTTPS público | Puertas `LOCAL_TLS_CONTRACT` y `PASS_REAL_HTTPS` separadas |
| V5 | 3 pilotos sin enlaces concretos vuelven a búsqueda circular | Se aportan URLs oficiales de inicio Medellín/Bogotá/Cali |
| V6 | Noticia de prensa tratada como norma íntegra | `ACT_FULLTEXT` y evidencia de campos obligatorios antes de borrador validado |
| V7 | 1.104 municipios exportables pero no revisables en UI | Página municipal paginada con estados y permisos |
| V8 | Reescritura de regla de vigencia produce falsos positivos | Reutilizar los helpers C6 y distinguir editorial/publicado |
| V9 | GitHub backup confundido con integración a main | Rama hija C7 y PR Draft contra backup C6; `main` HOLD |
| V10 | ZIP con APK o fuente completa consume espacio del usuario | ZIP de evidencias y delta de texto ≤2 MiB objetivo |

### Diez pasadas como JUEZ: decisión, fundamento y alcance de aceptación

| # | Contraste adversarial | Decisión justificada |
|---|---|---|
| J1 | ¿Un CSV nuevo repetiría C6? | No: una pantalla interactiva es funcionalidad distinta y verificable |
| J2 | ¿Consultar todos los municipios es costoso? | Paginar en servidor y usar carga acotada por página, no 1.104 joins completos |
| J3 | ¿La ruta expone roles? | `datasets.view` para lectura y permisos existentes para acciones de cambio |
| J4 | ¿UNKNOWN equivale a no restricción? | No: la UI debe mostrar desconocimiento, sin recomendación de circular |
| J5 | ¿Los pilotos acreditan país entero? | No; su denominador es tres fuentes candidatas, legal nacional no medido |
| J6 | ¿El artículo semanal Bogotá equivale a decreto? | No; registrar la brecha normativa expresamente |
| J7 | ¿Podemos ignorar Android sin perder avance? | Si no hay autorización física, sí, porque A se entrega; emulador opcional |
| J8 | ¿Una prueba local TLS es HTTPS real? | No, solo contrato local; staging público exige URL y validación real |
| J9 | ¿Push a rama raíz vuelve el código mergeable con main? | No, C7 deriva de backup y solo crea PR revisable contra él |
| J10 | ¿Debemos actualizar 58 % histórico ahora? | No; medir funciones runtime y gates, conservar evidencia 61/100 sin inflar |

**Esta auditoría ya está realizada. Codex ejecuta el trabajo, no reinicia auditorías 10×10 ni solicita un prompt de preflight.**

# 🔴🔴🔴 QUIÉN SIGUE: CODEX LUNA — EJECUTAR C7 V2, ENTREGAR UN ZIP ÚNICO LIGERO SIN APK 🔴🔴🔴

**DESPUÉS DEL ZIP SIGUE: CHATGPT DIRECTOR.**
