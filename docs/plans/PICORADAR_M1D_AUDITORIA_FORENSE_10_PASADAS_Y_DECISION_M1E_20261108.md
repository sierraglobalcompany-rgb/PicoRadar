# PicoRadar — Auditoría forense de M1D y decisión de causa raíz M1E

**Corte:** 2026-11-08 (Colombia). **Director:** ChatGPT. **Estado:** M1D `PARTIAL / BLOCKED_CONTRACT` aceptado como DIAGNÓSTICO; no como candidato ni autorización de publicación. **Release:** `NOT_APPROVED`. **Siguiente tarea autorizada, condicionada:** M1E focal; Codex ejecuta, director audita.

## 0. Identidad, procedencia y comprobación del paquete

**Archivo físico recibido:** `PICORADAR_M1D_LARAVEL_CANDIDATO_Y_EVIDENCIAS_UNICAS_20261107.zip`.

- SHA-256 del ZIP **recalculado:** `8bec41abe907bf63efeede6a0eefcf6908b7a26074624efd79c6e8a9c7b58f6f`.
- 10 entradas en ZIP: 8 evidencias, `MANIFEST.json` y `MANIFEST.sha256`. `ZipFile.testzip()` devuelve `None` (CRC PASS). Los 8 payload SHA-256/tamaños/CRC se contrastaron contra manifiesto; PASS.
- SHA-256 del `MANIFEST.json` **recalculado:** `1d1300b67124450327dcad15f761e1e05f1202dfb86fb4204b4e16543c2e9a1d` y coincide con `MANIFEST.sha256`.
- HEAD H4 `1b5badd9aafb7746ae9a904f0b1ba4903e83bf9c`; tree local declarado `dc2f2fdc5521af4cb4ad16969d76248b1e021688`. **No se recibió un checkout H4 ni los fixtures privados**: estos hashes fueron informados por Codex y no pueden ser reproducidos en este entorno.
- SHA del dataset H4 declarado `ce95abacc2968bc4267d3edaef6bf9320dba1d99d40daf56b6c7e7cc46e38341` y `composer.lock` declarado `7469b7eb9e72a79c92c69908ab22b7965fcb3e39019b1bbf6c6cb1c84423b983` (no se encuentran sus bytes en el ZIP).
- Estado checkout original anterior y posterior: HEAD `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`; 1 eliminación ya existente y 0 staged. La comparación de conteos no demuestra integridad de 101 WIP históricos; `WIP_CONTENT=NOT_VERIFIED`.

**Separación de fuentes:** el ZIP es evidencia de ejecución local reportada por Codex; el código remoto `recovery/20261019-modern` es evidencia independiente de arquitectura pero NO es el checkout H4; las páginas de Bogotá oficiales son corroboración externa legal, NO certificación de código ni permiso de circulación.

## 1. Diez pasadas (resultado independiente por control)

| # | Control | Estado | Hallazgo, límite y decisión |
|---|---|---|---|
| 1 | Integridad ZIP | **PASS** | Hash externo y CRC de 10 entradas coinciden. El paquete es auténtico respecto al SHA suministrado, no prueba por sí mismo la veracidad de la ejecución. |
| 2 | Manifiesto | **PASS** | `MANIFEST.sha256` coincide y 8/8 payloads verifican SHA-256/bytes/CRC. No hay JSON candidato, coherente con `BLOCKED_CONTRACT`. |
| 3 | Identidad local, aislamiento y WIP | **PARTIAL** | HEAD/tree/estado reportados; H4 y los 101 contenidos WIP no reproducidos independientemente. No afirmar `PROTECTED_WIP_UNCHANGED=PASS` por un conteo. |
| 4 | Fuente legal Bogotá | **PASS FOCAL** | Portales oficiales noviembre particular y octubre taxi corroboran calendarios separados, horarios y carácter temporal. Falta revisar excepciones/perímetros para publicar. |
| 5 | Causa de bloqueo del validador | **CORROBORADA CON LÍMITE** | En H4 se informa que dos taxis (`...10-01`, `...10-07`) tienen igual prioridad/dígitos/legalValidFrom abierto, pero ventanas calendario disjuntas. En el validador remoto el fingerprint omite calendario y compara fechas legales. No poseemos bytes del validador H4 para reproducir exactamente el caso. |
| 6 | Pruebas reportadas | **PASS PARCIAL, NO FULL** | Validador 14/30 PASS, publicación 5/19 PASS, gate fail-closed 1/8 PASS = **20 pruebas, 57 aserciones**. Pipeline Bogotá: **1 ERROR, 5 aserciones**, no es PASS. Flutter/CDN `NOT_RUN`. |
| 7 | Seguridad del publicador | **PASS DE ALCANCE** | `RestrictionRuleVersionService`→`RestrictionPublicationService`→`DatasetReleaseValidator`→`DatasetPublisher`→`ManifestPublisher` existente. No segundo writer; no invocar `publish()` con BD/Storage reales. |
| 8 | Arquitectura KISS/Ponytail | **CORRECCIÓN DE RUMBO** | Causa raíz probable = detección de coexistencia temporal, no car/private ni carencia total de escritor. No borrar taxi, no duplicar Laravel, no añadir librerías/microservicios. Parche acotado solo si prueba roja y modelo H4 lo admiten. |
| 9 | Riesgos y no-regresión | **GATE PENDIENTE** | Se requieren casos de calendario disjunto (permitir), coincidente (rechazar), solapamiento parcial (rechazar), sin calendario (mantener comportamiento), medianoche/offset/fin inclusivo y consumidores Flutter. No ampliar validador sin delimitar. |
| 10 | Continuidad y anti-pingpong | **DECISIÓN CERRADA** | M1D se cierra diagnóstico, no se ejecuta M1D V3 ni se reabre M1C. Un único M1E focal en H4 con evidencia en un solo ZIP. GitHub PR #79 para continuidad documental; PR #71 y `main` protegidos. |

## 2. Causa raíz y decisión exacta

La versión remota comprobada de `server/app/Services/RestrictionContractValidator.php` (blob `737513dffd7cca19f2439d22ab0422e6f41cd008`) calcula una huella de `priority`, `weekdays`, `dateParity`, `digitPosition`, `digits`, `registrationOrigins`, `timeWindows`, `appliesOnHolidays` y compara rangos `validFrom`/`validUntil`. El informe M1D identifica que **H4 tiene semántica adicional**: límites calendarios por taxi y fechas legales `legalValidFrom`/`legalValidUntil`; no es legítimo trasladar una solución textual de PR71 a H4 sin leer y probar ese archivo local primero.

El 1 y 7 de octubre comparten dígitos restringidos `[5,6]`, pero son jornadas distintas. Un detector que ignora el calendario las trata falsamente como concurrentes. La reparación segura debe demostrar que **nunca coinciden los instantes efectivos** antes de descartar una alerta, y seguir rechazando conflictos cuando sí coinciden o se carece de evidencia suficiente.

**Decisión L1/L3:** autorizar a Codex una única reparación mínima de la comparación de solapamientos en el validador H4, **condicionada** a prueba RED reproducible, revisión de la semántica exacta del calendario en H4 y prueba de que no se relajan casos realmente conflictivos. No autorizar cambios de datos taxi, fuente, schema, `RestrictionPublicationService`, Flutter ni fechas TTL para evadir el problema. Si la causa exacta difiere, generar `DESIGN_DECISION_REQUIRED` y evidencia, NO introducir otro parche.

## 3. Contraste legal externo, con límites

- Carros particulares Bogotá, 1–30 noviembre 2026: lunes a viernes 06:00–21:00; en días impares **circulan** terminadas 1–5 (se restringen 6–0); en días pares circulan 6–0 (se restringen 1–5). Festivos 2 y 16: regla regional de ingreso separada, no aplicar el patrón urbano como si fuera día laboral. Fuente: https://bogota.gov.co/mi-ciudad/movilidad/2026-11/pico-y-placa-bogota-vehiculos-particulares-1-30-de-noviembre-de-2026
- Taxi Bogotá octubre 2026: 05:30–21:00, lunes a sábado, no domingos/festivos, calendario diario 1–31 octubre; días 1 y 7 restringidos `[5,6]`. Fuente: https://bogota.gov.co/mi-ciudad/movilidad/movilidad-pico-y-placa-taxis-en-bogota-del-1-al-31-de-octubre-de-2026
- Taxi Bogotá noviembre **también tiene publicación propia**, por lo que hacer validar octubre NO equivale a dejar noviembre listo. Fuente: https://bogota.gov.co/mi-ciudad/movilidad/2026-11/pico-y-placa-para-taxis-en-bogota-del-1-al-30-de-noviembre-de-2026

## 4. Siguiente orden y pruebas obligatorias M1E

**TASK_ID:** `PICORADAR-M1E-CALENDAR-OVERLAP-VALIDATOR-KISS-20261108-DIRECTOR`. Es **nuevo lote causal**, no continuación disfrazada ni re-ejecución M1D. Comparar primero la implementación H4, priorizar `server/app/Services/RestrictionContractValidator.php` y el test unitario existente; autorizar como máximo las modificaciones focales previstas en la orden M1E. Crear RED con dos taxis H4 en 1/7-Oct y caso de mismo día realmente conflictivo. Ajustar el validador solo si ambos satisfacen la matriz de seguridad. En SQLite+Storage fake, repetir SOLO la cadena de validación/publicador con Bogotá noviembre; jamás enviar un release productivo. Pruebas `NOT_RUN` explícitas si Flutter/Dart no existen. No tocar Hostinger, dispositivos, original, WIP, `main`, PR71 ni PR79 desde Codex. Único ZIP de salida con manifiesto SHA/CRC, diff, pruebas reales, fuentes y decisión.

## 5. Ruta final de producto sin reiniciar fases

1. **M1E (causa raíz inmediata)**: eliminar falso conflicto demostrado, preservar conflictos reales, acreditar test y luego un intento candidato *offline* de Bogotá. No confundir PASS del validador con ciudad publicada.
2. **M1 cobertura nacional**: continuar investigación por autoridades y categorías con los 1.096 municipios no investigados en M1B, sin tratar `NOT_SEARCHED` como ausencia legal.
3. **M2 agente lector y motor**: agente propone con captura/frescura/fecha, revisión humana; Laravel existente valida/publica/retira/rollback. Sin otro backend, data lake ni motores por municipio.
4. **M3 integración**: manifiesto/CDN seguro, Flutter sincroniza dataset verificado, fallback offline y cámaras con respaldo ANSV; cuentas solo conforme a baseline.
5. **M4 gates finales**: reconciliar 101 WIP, CI real, Android/JNI/firma y QA físico, privacidad/seguridad/legales, rollback y autorización humana. `RELEASE=NOT_APPROVED` hasta evidencia real.

**Métricas honestas:** un candidato Bogotá no liquida cobertura nacional; 20 pruebas PHP no acreditan Flutter; un ZIP intacto no comprueba H4 ni los 101 WIP. Queda prohibido declarar `DONE` por intuición.

## 6. Leyes y siguiente actor

L1 KISS + Ponytail: cambio mínimo con causa probada. L2 antirruido: una sola fuente canónica y ningún duplicado. L3 antiparches: corregir conflicto temporal sin amputar taxi. L4 diseño: no alterar UX/UI ni mensajes verdes ante incertidumbre. L5 verificación independiente: pruebas reproducidas, SHA y no falsos PASS. L6 antipingpong: Codex ejecuta orden cerrada una vez y devuelve **un solo ZIP**, ChatGPT decide tras auditar.

**SIGUE CODEX LUNA — M1E CONDICIONADO; después ChatGPT. No release.**