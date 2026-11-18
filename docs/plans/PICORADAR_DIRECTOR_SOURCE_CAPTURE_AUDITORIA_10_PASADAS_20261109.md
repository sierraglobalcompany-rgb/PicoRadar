# PICORADAR — DIRECTOR | Auditoría independiente M1-CAPTURA | 10 pasadas y decisión de rumbo

**Corte:** 2026-11-09, Colombia · **Director:** ChatGPT · **Objeto real:** ZIP físico recibido `PICORADAR_M1_CAPTURA_OFICIAL_EVIDENCIA_UNICA_20261109.zip`.

**Dictamen:** `SOURCE_CAPTURE_ACCEPTED_SCOPED` / `LEGAL_READY=0/5` / `RELEASE=NOT_APPROVED` / `PUBLISH_ALLOWED=NO`. Se **cierra esta ejecución**: no pedir M1-captura-C2, no repetir HTTP por diferencias de hash, 403 o HTML visor. Fuentes legales y geometrías incompletas permanecen en un carril de solicitudes oficiales, sin bloquear el avance técnico independiente.

## A. Identidad y verificación independiente

- ZIP de **1.083.498 bytes**, SHA-256 **`88bc276a2f9cbc63db104a7fc0380264831f268bedaace4a3afa7de4a5f1ea26`** calculado sobre bytes del archivo adjunto.
- `zipfile.testzip()=None` (24 miembros; CRC PASS). `MANIFEST.json`: **22/22** rutas cubiertas presentes, tamaños y SHA-256 recalculados correctos. `MANIFEST.sha256` coincide con SHA del propio `MANIFEST.json` (`7154c7b27e779a19f4b28e2219c9a7f027b499f3c8d5a9ecc315c1685d7d075e`).
- `CAPTURE_MANIFEST.json`: **11/11** miembros correctos por bytes/SHA-256: catálogo, mapeo y nueve snapshots, SHA de manifiesto `d9d554a64a24392a2b7ffddaafae2435af0ec1d9c1ee36f6eb4622f482ced5bc`.
- CSV reales: `input/SOURCE_CLAIM_MATRIX.csv`: **33 identificadores de afirmación únicos**, cinco filas de municipio×vehículo; **28** con URL y **5** sin URL. `CAPTURE_CATALOG.csv`: **12 URL únicas**. `CLAIM_TO_SNAPSHOT.csv`: **33** filas; enlaces/IDs, estados y hashes conservados sin errores de cruce.
- Capturas: **9 HTTP 200 guardadas**, **2 HTTP 403 sin cuerpos**, **1 host ArcGIS fuera de allowlist y sin conexión**. Nueve nombres de archivo por SHA coinciden con el SHA del contenido y longitud declarada. No se ejecutaron solicitudes de red durante la auditoría del director.
- Comparación de `body_bytes_captured_sha256_or_blank` con catálogo actual, parseando formato `bytes=N;sha256=...`: **6 MATCH / 3 DIFF / 3 NO_PRIOR**. La discrepancia de bytes NO demuestra por sí sola una modificación jurídica.
- Reproducción independiente: extraje solo `scripts/source_evidence_capture.py`, `scripts/tests/test_source_evidence_capture.py` y CSV a un directorio temporal aislado y ejecuté `PYTHONDONTWRITEBYTECODE=1 python -m unittest discover -s scripts/tests -p test_source_evidence_capture.py -v`. Resultado **13/13 PASS**, 0 errores. Es prueba offline focal; no acredita ejecución HTTP/TLS real ni Flutter/PHP/Android.

## B. Diez pasadas y hallazgos

| # | Control | Resultado | Dictamen y límite |
|---|---|---|---|
| 1 | Identidad de entrega y CRC | PASS | ZIP con peso, hash y 24 miembros comprobados. |
| 2 | Manifiesto de paquete | PASS | 22/22 archivos y hash del manifiesto recálculados. |
| 3 | Manifiesto de captura | PASS | 11/11 incluidos, 9 snapshots byte-a-byte válidos. |
| 4 | Claves y trazabilidad | PASS | 33 claims únicas, 12 URL, 28 enlaces con fuente y cinco sin URL, sin pérdidas. |
| 5 | Límites de red | PASS DEL ARTEFACTO | 9×200, 2×403 sin body, 1 host no permitido; no repetir ni eludir. La sesión HTTP se conoce por los logs/catálogos, no se reprodujo la conexión. |
| 6 | Hash previo frente a actual | PASS CONTABLE / JURÍDICO NO | 6 iguales, 3 distintos, 3 sin anterior. No atribuir las diferencias a cambio legal sin comparar texto sustantivo. |
| 7 | Pruebas del capturador | PASS FOCAL | 13/13 pruebas offline reproducidas; no son prueba E2E Flutter/Laravel ni garantía de seguridad de red universal. |
| 8 | Contenido jurídico de los HTML | **HALLAZGO DIRECTOR** | Bogotá Jurídica Decreto 652 contiene realmente texto de arts. 226–230 y cierre `PUBLÍQUESE Y CÚMPLASE`, aunque existe banner `Cargando el Contenido del Documento`; Decreto 657 también trae texto material. No refetchear por esa interpretación. Páginas advierten carácter informativo y vigencia sujeta a análisis. |
| 9 | Conservación de checkout, WIP y parche | PARCIAL HONESTO | Los logs PRE/POST consignan mismo HEAD/árbol y borrado histórico único. Parche de dos rutas sin aplicar. Los 101 WIP **NO VERIFICADOS**: no convertir log en certificación forense de cada archivo. |
| 10 | Leyes, plan, dirección | PASS CON LÍMITES | KISS+Ponytail, L2 antirruido, L3 causal, L4 diseño intacto, L5 no falsos verdes, L6 no ping-pong; M1-M4 y privacidad vigentes. Cerrar capturador, no crear sistema de scraping o agente nuevo. |

### Hallazgo jurídico adicional independiente (no implicó nueva conexión)

Dentro de `snapshots/0c5864cceec8f0a5c54992a7a4460ba65046b02790b084ac7c326c43cbd8fa8c.html` (2.433.776 bytes, Bogotá Jurídica, Decreto 652), la extracción HTML contiene aproximadamente 647.246 caracteres de texto; aparecen **Artículo 226, 227, 228, 229 y 230**, referencias a modificatorios y firma/publicación. En `snapshots/b15980421c3f49477508afa7561c0849d3f674f6ebb9429c59ac61cf74aeec45.html` (Decreto 657) se observan texto de la modificación del artículo 229 y cierre. El mensaje `Cargando...` es parte del documento HTML, **no evidencia de ausencia del cuerpo**. No se certificó que estén todos los anexos ni la vigencia final aplicable a una fecha; ninguna fila cambia de estado.

En Medellín, `snapshots/bff21d3645551d75f7776515cdacde8d4a5363a6a91a60026e7778928b362f6f.html` es la ficha de GIS **en HTML**, no la geometría. Cartagena conserva dos `HTTP403_BLOCKED`; no se traspasa esta condición. La URL externa ArcGIS fue excluida por orden previa; no se transforma retrospectivamente en prueba de ausencia de geometría.

### Observación técnica para posible reutilización, SIN nuevo lote

El código hace `socket.getaddrinfo` para validar IP pública y luego `urllib.request` puede resolver nuevamente el host al abrir la conexión. La separación representa un posible riesgo de comprobación/uso (DNS TOCTOU) que **las 13 pruebas offline no descartan**. Puesto que el parche no se integró a producto ni se adoptó como servicio recurrente, se conserva como candidato **no aprobado para uso general**. No ordenar una segunda iteración de seguridad si no existe decisión de integrar ese script; eso sería nuevamente ping-pong.

## C. Criterio de alcance legal y cierre

`LEGAL_READY=0/5`, `PUBLISH_ALLOWED=NO`. Los snapshots prueban bytes recibidos de URL oficiales en un instante; no prueban todas las exenciones, modificaciones, mapas ni que los datos sigan técnicamente frescos. La fecha `staleAfter=2026-11-10T05:00:00Z` de Medellín es técnica, no vencimiento de decreto y **no se extiende**.

`OFFICIAL_DOCUMENT_REQUESTS.md` contiene **tres solicitudes NO enviadas** (Medellín: acto/Gaceta/capa; Bogotá: copia estática/ámbito; Cartagena: acto/anexos/permisos). Antes de pedir Bogotá de nuevo, verificar si el HTML de 652/657 ya satisface la necesidad documental del texto; solo pedir aquello que realmente falta (por ejemplo anexos/geo, certificación/modificaciones). No convertir estas solicitudes en órdenes de reiterar scraping; su seguimiento es carril externo.

## D. Estado remoto y plan de salida

Verificado vía GitHub: `PR #79` Draft branch `docs/plan-maestro-nacional-v2-20261107`, HEAD previo a este checkpoint `9abe49dc8e7c8e0313c5555bd233ad558ee45a9a`, solo docs; `PR #71` Draft base main HEAD `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`. El código fuente moderno en GitHub contiene componentes reales `DatasetPublisher`, `RestrictionPublicationService`, `DatasetSyncService`, `RestrictionStore`, pruebas PHPUnit y pruebas Flutter. Se confirmó que las pruebas Flutter existentes ya cubren **compilador Python→HTTP→Drift→motor** y que PHPUnit cubre publisher/rollback; **no repetir esas suites como supuestas funciones nuevas**.

**Siguiente objetivo funcional focal (sin violar dependencias M1/M2):** validar la interfaz real **bytes de publicación Laravel→manifiesto público→cliente Flutter**, con datos sintéticos aislados, reutilizando los tests existentes. Esto es **ensayo técnico de contrato M3, NO M3 DONE, NO aprobación de dataset real**. Se ejecuta una sola vez, con gates basados en SHA y reporte de BLOCKED_ENV si falta Flutter; no tocar C1 ni reabrir el lote de fuentes.

Plan Maestro M1 nacional sigue en progreso; M2 motor/agente lector sigue sujeto a sus aceptaciones; M3 integración no productiva puede avanzar en prueba sintética sin declarar M3 completo; M4 mantiene pendiente C1 Flutter/CI, 101 WIP, JNI/firma/QA Android físico, privacidad y GO humano. `RELEASE=NOT_APPROVED`.

**NEXT_ACTOR=CODEX_LUNA solo para tarea funcional focal autorizada; después CHATGPT_DIRECTOR para revisar un ZIP único.** No pedir más capturas por esta incidencia.