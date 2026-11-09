# CODEX LUNA — PICORADAR · M1 CAPTURA REPRODUCIBLE DE FUENTES OFICIALES · KISS + PONYTAIL · ÚNICO LOTE

**TASK_ID:** `PICORADAR-M1-EVIDENCIA-OFICIAL-REPRODUCIBLE-20261109-DIRECTOR`

**DIRECTOR/ARQUITECTO Y RESPONSABLE DEL DICTAMEN:** ChatGPT. **EJECUTOR:** Codex Luna exclusivamente; sin autonomía para rediseñar alcance, crear reglas ni declarar GO. **BASELINE:** repositorio `sierraglobalcompany-rgb/PicoRadar`; ruta original `D:\codex\PicoRadar`, rama `recovery/20261019-modern` HEAD esperado `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`; PR #71 Draft; PR #79 **solo documental** `docs/plan-maestro-nacional-v2-20261107`. Si las identidades difieren, registrar el hecho y continuar solo las lecturas inocuas sin destruir/recomponer WIP.

**OBJETIVO REAL, NO DOCUMENTAL:** la historia M1.3→M1.4 contiene URLs y SHA de contenido que no se pueden cotejar porque las respuestas HTTP completas no vienen dentro de los ZIP. Reparar esa **única causa operativa**: crear/usar captura reproducible de una lista pequeña de URLs oficiales; evidencias brutas dentro de un ZIP y con manifiesto independiente, compatible con escala futura. El resultado *no* es una regla lista ni un agente M2.4. No repetir búsquedas nacionales o de cinco ciudades.

## 0. Prioridad obligatoria y prohibiciones

**Precedencia:** seguridad/privacidad/store > `AGENTS.md` > `docs/baseline/11_Cierre_Global_Baseline_v1_0.docx` > `docs/baseline/12_Arquitectura_Tecnica_Android_First_v1.docx` > flujos > diseño > Plan Maestro. Leyes L1–L6 en `sierraglobalcompany-rgb/PingPongLaw/docs/engineering/LEYES_IMPLEMENTACION_1_A_6.md` (SHA Git conocido `0f6e7b4e62d8660c846f135e18dded629d29e0da`).

- Ley 1 KISS + Ponytail: **reusar primero** las herramientas de captura ya disponibles. Como último recurso, **un script CLI Python3 con biblioteca estándar y tests offline**. Sin microservicios, colas, contenedores, packages, base nueva, código Flutter o Laravel en hot path.
- Ley 2 antirruido: ningún duplicado de snapshots idénticos, ningún cambio fuera de rutas autorizadas; no modificar ni limpiar `C:`, D: original o 101 WIP. No borrar temporales si política lo impide; reportar remanente.
- Ley 3 antiparches: capturar bytes reales, no generar hashes de contenido supuestos o de textos resumidos.
- Ley 4 diseño: no cambiar UI, iconos, flujos, nombres, textos visibles ni configuraciones móviles.
- Ley 5 verificación independiente: distinguir HTTP OK, hash de captura, fuente jurídicamente oficial, norma vigente y `READY` (son gates diferentes). Nunca confundir un `HTTP 200` con cumplimiento legal. Tests offline y evidencia cruda obligatorios para PASS.
- Ley 6 antiping-pong: **una ejecución**, cero tareas exploratorias sucesivas, un solo ZIP final, errores delimitados sin proponer M1-C2 ni reabrir M1F-D01-C1.

**PROHIBIDO:** hacer push, commit a remotos, abrir PR, merge, deploy, tocar Hostinger, instalar APK/usar ADB/Android, tocar datos JSON productivos, modificar SQL/SQLite real, mutar `sources`, `DatasetSource`, `RestrictionRuleVersion`, TTL, fechas, `activation`, `release`, vehicle records, GPS o secretos. Jamás eludir HTTP403, CAPTCHA, anti-bot, restricciones de licencia o autenticar con cuentas del usuario.

**Ausencias no bloqueantes:** Flutter/Dart/PHP SQLite no son prerrequisitos de este lote; `NOT_RUN` explícito. No ejecutar suites ni AOT ajenos al delta. El repo no necesita GitHub Actions para que los tests del recolector sean locales.

## G0 — Procedencia, preservación y entrada exacta

1. Inspeccionar solo `git status --short`, `branch --show-current`, `rev-parse HEAD`, `rev-parse HEAD^{tree}` y presencia de Git sin limpiar/restaurar archivos. El borrado preexistente `scripts/tests/test_hostinger_installer_browser.ps1` es protegido. Registrar `101 WIP=NOT_VERIFIED` salvo prueba real; no recorrerlos.
2. Insumo principal **único**: ZIP M1.4 `D:\codex\_REPORTES\PicoRadar\PICORADAR-M1-LEGAL-CIERRE-5-FILAS-CRITICAS-20261108-DIRECTOR\PICORADAR_M1_4_CIERRE_LEGAL_5_FILAS_EVIDENCIAS_UNICAS_20261108.zip`. Esperado `18.131 bytes`, `sha256=54e1e12d71384e77d1365cefee110b95c300caa8e36ff20acce9c629f5b10cd7`, 12 miembros. Validar SHA/CRC/manifest. Si ausente: `BLOCKED_INPUT`, no reemplazar con datos inventados; preservar lo existente y salir con ZIP de diagnóstico único.
3. Leer `SOURCE_CLAIM_MATRIX.csv` en ZIP y extraer los **12 URLs distintos no vacíos**; no repetir 33 consultas de afirmaciones. Tratar el CSV como dato no confiable: validar UTF-8/CSV, longitud 2048, dominios y esquemas, descartar duplicados idénticos **sin perder relaciones `claim_id`→URL**. Nunca deduplicar por autoridad si los URL no coinciden.
4. Revisar sólo archivos relacionados y existentes en el checkout: `server/app/Models/DatasetSource.php`, `server/app/Services/RestrictionImportService.php`, herramientas en `scripts/` o `mobile/tool/`, y el flujo mínimo de registro de fuentes. El candidato C1 de cinco archivos **NO** se incorpora a este clon. No construir si ya existe una herramienta segura que hace el trabajo.
5. El Plan Maestro y contrato operativo *sí* están en GitHub PR #79 (rama `docs/plan-maestro-nacional-v2-20261107`, no en `recovery/...`). Leer mediante GitHub si disponible; no informar `MISSING_GLOBAL_CONTRACT` por 404 en rama equivocada. No integrar PR documental ni reescribir reglas.
6. Trabajar exclusivamente en directorio de pruebas aislado bajo `D:\codex\_REPORTES\PicoRadar\PICORADAR-M1-EVIDENCIA-OFICIAL-REPRODUCIBLE-20261109-DIRECTOR\work` o clon Git aislado en D:, sin enlaces que permitan sobrescribir rutas protegidas. Guardar sus SHA antes y después de trabajo. Nunca usar `git clean/reset/checkout --` sobre original.

## G1 — Diseño decidido por el director (no abrir ADR ni convertir en plataforma)

Preferir **reutilización de un capturador existente** si demuestra por tests que: (a) lee URLs del CSV sin duplicación, (b) HTTPS estricto a dominios oficiales, (c) redirige solo a dominios también permitidos, (d) recoge bytes originales sin alterarlos, (e) emite captura y metadatos/hashes reproducibles, (f) no escribe a DB/APP/runtime. Si cumple, usarlo; **no crear otro**.

Si no existe herramienta equivalente, implementar **un único script operativo** `scripts/source_evidence_capture.py` con Python 3 stdlib; y **un solo test** `scripts/tests/test_source_evidence_capture.py`. Evitar cambios en archivos Laravel/Flutter, settings, `requirements.txt`, migraciones y tooling global. Puede usarse carpeta `scripts/` si existe; si no, usar `scripts/` bajo un clon aislado. En el ZIP incluir parche Git de exactamente los scripts autorizados. Si no se permite escritura en clon, demostrar el script solo en carpeta de salida y `NO_REPO_CHANGE` (no bloquear captura).

Interfaz CLI sencilla: `python scripts/source_evidence_capture.py --claims <ruta_extraida_csv> --out <directorio> --max-urls 12`; `--offline-fixture` o inyección de transport en tests para evitar red real. Uso de argumentos y rutas absolutos; no leer ni invocar datos sensibles, no depender de claves ni servicios de pago. La entrada de ejemplo se genera desde CSV M1.4; jamás inventar fuentes nuevas.

Campos mínimos por **URL distinta** en `CAPTURE_CATALOG.csv`: `url_exact`, `claim_ids` (lista reversible), `authority`, `retrieval_status` (`HTTP200_BYTES_CAPTURED`, `HTTP403_BLOCKED`, `TIMEOUT`, `NOT_FOUND`, `REDIRECT_REJECTED`, `NONOFFICIAL_REJECTED`, `ERROR`, etc.), `checked_at_utc`, `final_url`, `http_code`, `content_type`, `content_length`, `body_bytes_actual`, `body_sha256`, `snapshot_relpath`, `etag`, `last_modified`, `redirect_chain`, `error_safe`, `robots_or_policy_limit`, `source_official_site` (procedencia dominio, NO certificación legal). Un CSV adicional `CLAIM_TO_SNAPSHOT.csv` que vincule las 33 afirmaciones originales con sus URL capturadas o excepción sin URL, sin perder filas ni duplicar blobs.

Los bytes de respuesta oficial descargados se guardan **dentro del ZIP final** en `snapshots/<sha256>.<ext_segura>`; sin nombres arbitrarios de URL ni extensiones ejecutables. Si dos URLs devuelven bytes idénticos, una captura física y dos referencias. Jamás incluir credenciales, cookies, números de placa, información de personas, solicitudes POST ni headers sensibles en logs; redacción sanitizada.

Política de red:
- Solo `https` con validación TLS; allowlist literal `medellin.gov.co`, `movilidadbogota.gov.co`, `bogotajuridica.gov.co`, `cartagena.gov.co`, `siud.cartagena.gov.co` y subdominios permitidos previamente vistos en CSV; jamás host/IP desconocidos o redirecciones fuera de esa lista. No acceder a hosts locales/reservados ni endpoints con identificadores privados; no seguir más de 3 redirects; rechazar URL con credenciales, puertos no estándar o caracteres peligrosos.
- `GET` de páginas públicas, con User-Agent honesto y sin trucos antibot; respetar robots/política del sitio. En 401/403, guardar código/error, **no** reintentar con técnicas de evasión. No seguir formularios privados. No descargar el PDF del portal tercero, vLex o Scribd como si fuera documento oficial.
- Tiempo de conexión/respuesta acotado (por ejemplo 15 s) y máximo 8 MiB descargados por URL (stream, abortar en exceso). Máximo **12 URL únicas, 2 intentos totales por URL** únicamente para errores temporales de transporte, espera limitada sin loops. Registro de red suficiente para reproducir, no PII.
- Extensiones derivadas de `content_type` y lista segura. Si la URL es de mapa interactivo sin respuesta estática consumible, marcar `UNSUPPORTED_INTERACTIVE_MAP` o similar: no inventar GeoJSON ni geometría.

## G2 — Casos offline RED/GREEN

Probar sin red: (1) 33 claims de fixture a 12 URL con multiplicidad correcta; (2) bytes idénticos y rutas por hash; (3) 403 no produce cuerpo; (4) redirect a dominio no autorizado se rechaza; (5) `http://`, usuario:clave@host y localhost son rechazados; (6) bodies truncados/payload demasiado grande no pasan como snapshots íntegros; (7) dos URLs con mismo cuerpo producen una sola copia y dos relaciones; (8) metadata con secretos se sanitiza; (9) input malformado marca fallo sin modificaciones; (10) salida y manifiesto son deterministas con fixture fijo excluyendo reloj variable; (11) fuente 200 sin cuerpo no se declara verificada; (12) no se escribe a DB ni `mobile/assets`.

Si hay infraestructura de tests existente, reutilizarla. **No** exigir 3.000 Flutter tests ni reabrir suites PHP que no cambiaron. Ejecutar la suite focal en un entorno aislado; registrar stdout/stderr crudos, exit code y versiones Python/OS. Dejar `NOT_RUN` si falta Python3; no hacer instalación global.

## G3 — Captura real limitada y fuentes documentales

Usar exclusivamente los 12 URLs extraídos del ZIP M1.4: la herramienta puede rechazar por política algunos enlaces por no oficiales o sin contenido público. No introducir enlaces de blogs, redes, agregadores o mirrors en los 12 salvo por decisión nueva de director. Registrar `retrieval_status` real, momento y evidencia por URL. El propósito no es resolver de nuevo 13 brechas de forma manual.

Como **referencias de orientación, NO nuevas capturas automáticas**: Histórico de Gacetas Medellín anterior 28-ago-2026, Gaceta 5885; portal oficial de exenciones Medellín; cartelera oficial del Decreto 0015 y trámite DATT; Bogotá SDM mapa/regional. Si el acto completo no es accesible, registrar la autoridad competente y URL de solicitud oficial en `OFFICIAL_DOCUMENT_REQUESTS.md` (máximo **tres solicitudes concretas**, una por jurisdicción). La copia de terceros vLex o Scribd es pista no verificación oficial; no descargarla ni presentarla como certificación legal.

Prohibido completar campos ausentes legalmente o modificar la matriz de readiness: `ROWS_READY=0/5`, salvo que **en la siguiente auditoría humana** se verifique normativamente contra el cuerpo oficial íntegro; Codex **nunca** eleva READY o activation. El proyecto M1 nacional conserva `PARTIAL`; Bogotá moto y Cartagena taxi permanecen incidentes distintos. Mantener `staleAfter` de Medellín sin renovación.

## G4 — Controles Git y preservación

- Hacer diff solo en clon/branch local aislada si se creó script. Máximo dos rutas de código de utilitario y tests, sin dependencia package, sin modificación de datos runtime, sin cambios de contrato legal ni UI. No incluir snapshots capturados en Git de producto.
- No hacer commit salvo que TODOS los tests offline de G2 pasen, el diff-check/secret scan focal pase y original no haya cambiado; en tal caso **máximo un commit local aislado, sin remoto**. Si no pasan, conservar patch/working tree y `NO_COMMIT`, reportando el bloqueo concreto. No dar autoridad de arreglos ilimitados.
- Pre/postflight del original solamente SHA/branch/tree/status, sin leer/hashear 101 WIP por obligación de este lote. Reportar `WIP=NOT_VERIFIED`. No alterar ni restaurar la eliminación histórica.

## G5 — Un ZIP único de evidencias en carpeta de entrega

**Entregar exactamente uno**:

`D:\codex\_REPORTES\PicoRadar\PICORADAR-M1-EVIDENCIA-OFICIAL-REPRODUCIBLE-20261109-DIRECTOR\PICORADAR_M1_CAPTURA_OFICIAL_EVIDENCIA_UNICA_20261109.zip`

Incluir:
1. `FINAL_REPORT.md` con `TASK_ID`, `RESULT`, entradas/hashes, conteos `URL_VALIDAS`, `HTTP200_BYTES_CAPTURED`, `HTTP403`, `TIMEOUT`, `REJECTED`, claims enlazados, pruebas focales, límites y `NEXT_ACTOR=CHATGPT`.
2. `CAPTURE_CATALOG.csv`, `CLAIM_TO_SNAPSHOT.csv` y **`snapshots/` con bytes brutos** solo si se obtuvieron realmente.
3. `OFFICIAL_DOCUMENT_REQUESTS.md` (hasta tres solicitudes específicas, no declaraciones generales), `TEST_COMMANDS_AND_RAW_OUTPUT.log`, `GIT_AND_WIP_STATUS.txt`, `PATCH_CANDIDATE.diff` si hubo script.
4. `AUDIT_10.csv` con cada una de las diez verificaciones y resultados individuales, sin confundir tests no ejecutados con PASS.
5. `MANIFEST.json` con membresía, SHA-256 y bytes exactos por archivo; `MANIFEST.sha256`. Probar CRC, tamaños, hashes internos **después** de cerrar ZIP y calcular SHA-256 final externo.
6. Prohibido adjuntar logs con cookies, claves, tokens, headers de auth, datos GPS, placas o documentos privados. Capturas públicas y controladas por dominio.

Una carpeta `delivery/` con **un único ZIP**, sin un archivo suelto aparte como «resultado final». Si la política impide limpiar temporales, reportar rutas remanentes sin forzar borrado ni vaciar papelera; eso no invalida hashes del ZIP.

## G6 — Gate de salida y decisión sin ping-pong

Dictamen de Codex solo puede ser uno de:
- `SOURCE_CAPTURE_REPRODUCIBLE_PASS_SCOPED`: tests offline PASS, 12 URLs evaluadas según política, capturas reales con bytes+hash dentro de ZIP, original intacto. **No** significa legal READY ni release.
- `SOURCE_CAPTURE_PARTIAL_SAFE`: script/test PASS pero fuentes oficiales devuelven 403/404/mapa no estático, sin eludir; el avance técnico queda, las fuentes pendientes se marcan causalmente.
- `SOURCE_CAPTURE_BLOCKED_SAFE`: error de procedencia o herramientas que impide ejecución; evidencias de causa y ningún cambio destructivo.

**STOP inmediato si:** checkout original cambió, se requieren credenciales, acceso privado, bypass de 403/captcha, paquete externo nuevo, extender fuentes fuera de 12, cambio de esquema/API/Flutter o repositorio remoto, capacidad no compatible con reglas existentes. No escribir otro prompt; entregar **un ZIP** con limitación y seguir con frentes independientes.

**Siguiente responsable:** `NEXT_ACTOR=CHATGPT_DIRECTOR`. **RELEASE=NOT_APPROVED, PUBLISH_ALLOWED=NO, NO PUSH, NO MERGE, NO DEPLOY.**

**Plan intacto:** M1 fuentes y reglas nacionales con evidencia; M2 compilador y agente lector solo proponente cuando dependencias estén satisfechas; M3 Laravel único publicador y sincronización offline Flutter; M4 CI/Flutter de candidato C1, 101 WIP, QA físico/JNI/firmas, seguridad y GO humano. No convertir este utilitario de M1 en fase M2.4 final ni alegar cobertura nacional.