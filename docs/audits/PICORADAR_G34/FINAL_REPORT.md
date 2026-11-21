# Informe final — PicoRadar G34 V2

**TASK_ID:** `PICORADAR-G34-GEOGRAFIA-Y-RESTRICCIONES-REALES-MULTICIUDAD-20261110`  
**RESULT:** `G34_PARTIAL_GEO_OR_LEGAL`  
**PRODUCT_RELEASE:** `NO`  
**NEXT:** `CHATGPT_DIRECTOR`

## Estado del candidato

- Rama: `feat/PICORADAR-G34-national-geo-multicity`.
- Base/HEAD local: `07d328a38b3b4cbbc00f1e473a6fabc852ccf449`.
- Árbol base: `8e4ba5778c697f5473bcf39b74f76af9243f85f8`.
- Bundle G2 existente: `D:\codex\_isolated\PICORADAR_G34_BOOTSTRAP_G2.bundle`; SHA-256 `ac25dd5acc275d7064f42774c4ce9a6492e545a3b67d87e16b48d8660f8e2e54`. `git bundle verify` confirmó historia completa y la referencia `feat/PICORADAR-G2-national-typed-engine` al HEAD esperado.
- No hay commit G34. Solo hay cambios locales en el candidato; el índice permanece sin cambios. No hubo APK, ADB, teléfono, commit, push, merge, publicación ni acceso a Hostinger.
- El prompt indica que las 101 rutas WIP no estaban montadas y ordena no afirmar que fueron inspeccionadas. No se montaron ni editaron; no se informa una comparación de hashes de esas rutas.
- La raíz externa C: recibió solo una consulta Git de estado de lectura durante la comprobación de continuidad; no se editaron archivos. El estado reportó la eliminación histórica documentada de `scripts/tests/test_hostinger_installer_browser.ps1`. No se repitió ni se modificó.

## Trabajo implementado

1. **Contrato `expiresAt`:** el cliente ahora admite la clave de envelope, valida valor/fecha/fecha calendario y rechaza vencimiento antes de borrar cobertura existente. PHP mantiene validación estricta y exige zona explícita solo para `expiresAt`; una fecha sin zona podía interpretarse con distintos husos en servidor y teléfono.
2. **Geografía DANE:** sidecar reproducible DIVIPOLA/MGN 2025 de puntos derivados WGS84, sin polígonos ni uso para resolver vías.
3. **Datos editoriales oficiales parciales:** tres JSON externos a tests. Cinco coberturas: Medellín carro/moto, Cartagena carro/moto y Manizales carro particular. Las cinco son `partial`; Cartagena termina el 10-dic mientras se resuelve la regla estacional del 11-dic.
4. **Aprobación editorial:** vista previa operativa, ruta POST protegida, Gate de Admin/SuperAdmin activo, segregación autor/revisor, motivo/evidencia, hashes y revisión vinculados a evento append-only, aprobación separada de publicación y barreras para `REVIEW_REQUIRED`/`complete`.
5. **Auditoría y tests:** matriz legal, auditoría DANE, conteos, auditoría editorial, oráculos independientes por fecha/dígito/horario y QA focal. No cambian API pública, motor, esquema de datos, dependencias, lockfiles ni catálogo público.

## Datos e integridad

| Artefacto | Tamaño | SHA-256 |
|---|---:|---|
| Sidecar DANE `dane_mgn_2025_reference_sidecar.json` | 3.805.412 B | `3a139c0d92619740e818cb2880e61bffc8d0e948f8422f9a9344ea9042b0825f` |
| Medellín `2026-11-medellin.json` | 10.007 B | `39d0509b0bd48e0106a94b4af690566331138b5d9a8c6648c6f094685d3c67f7` |
| Cartagena `2026-11-cartagena.json` | 10.880 B | `d8af221dadc7ba117ac12f9d898ae143ce81530b85a11cc9a561d8f669a3f3e9` |
| Manizales `2026-11-manizales.json` | 5.142 B | `46eda2e3160b94fff02c6875f2a2c77d730e206142793c928dc989eef5f78b48` |
| Catálogo público consultado sin cambios | — | `4e27a53c5861cba916834b195cdc0c71fc69ecc871893f1f8e9c28d37f5cb263` |

Conteos DANE: 33 departamentos, 1.104/1.104 códigos de municipio conciliados; 8.420 centros (1.104 clase 1 y 7.316 clase 2); 8.420 puntos con rol `derived_centroid_reference_only`. La capa municipal adicional incluye 18 áreas no municipalizadas y una isla, que no se cuentan como municipios. No se resuelven vías.

## Gates G341–G352

| Gate | Estado | Evidencia/pendiente |
|---|---|---|
| G341 | `PARTIAL` | HEAD/tree y bundle G2 exactos verificados. WIP históricos no montados por instrucción; sin inspección ni afirmación de hashes. Candidato permanece sobre G2 sin commit G34. |
| G342 | `PARTIAL` | PHP 6/31 y código/test Dart actualizados; sin SDK Flutter no se pudo ejecutar el test Dart de last-good ni schema1. |
| G343 | `PARTIAL` | 33/1.104 conciliados y conteos CLAS verificados con espejo oficial; host primario falló HTTP 500 dos veces. |
| G344 | `PASS` acotado | CRS WGS84, padres, códigos y rol centroidal verificados; no se usa el punto para vías/excepciones. |
| G345 | `PARTIAL` | Cinco pares documentados con fuentes oficiales. PDF primario de Manizales no accesible; Cartagena tiene regla especial futura que requiere confirmación; ámbitos/exenciones/corredores quedan parciales. |
| G346 | `PASS` | Tres propuestas analizadas, confirmadas y validadas en DB/Storage fake; Cartagena/Manizales solo activadas en jurisdicciones fake; catálogo público hash idéntico, cero release G34. |
| G347 | `BLOCKED` | No disponible el payload R2 exacto `c879a27...d5e5`; no se comparan 7/12, las cinco jurisdicciones legacy, Bogotá ni el resultado 8/14. No se usó sustituto. |
| G348 | `PASS` acotado | HTTP→Gate→servicio→AuditLog→publish probado con DB/Storage fake; dos actores, SHA/revisión/fuentes, negativos, rollback y `complete` cerrado. No es aprobación legal ni publicación real. |
| G349 | `BLOCKED` | No se generó release/manifest del dataset G34 ni import Flutter; sin SHA PHP→Flutter atribuible. El parser fuente actual acepta schema 1 y 2; no se dispone del binario cliente V1 histórico para demostrar su rechazo/last-good. |
| G350 | `PARTIAL` | Datos permanecen parciales y los centroides no autorizan. Sin engine Flutter no se ejecutaron oráculos de permisos, corredor, calendario o `UNKNOWN`. |
| G351 | `PARTIAL` | PHP, Pint, lint y Python focales pasan. Flutter/Dart no disponible; la clase schema2 completa queda con 3 casos bloqueados por sus precondiciones R2/evidencia. |
| G352 | `PARTIAL` | Bundle G2 verificado. Sin commit G34 no se crea bundle nuevo ni se restaura una entrega G34. El ZIP parcial incluye diff, bundle base, manifiestos y extracción comprobada; no satisface cierre completo de release. |

## Bloqueos que requieren resolución

1. Proveer el payload R2 real con SHA `c879a27ce3fc0ef983575a069e995c95c4f9a03fe2b5f89509386dfa8090d5e5` y su contexto de test previamente validado; los tests exigen ese contenido y no admiten R4 ni `co-g2-synthetic` como sustituto.
2. Ejecutar en un entorno con Flutter/Dart las pruebas de parser/import/last-good, formato, analyze, suite requerida y controles de motor que dependen del dataset raíz.
3. Resolver documentalmente el alcance/efectos del Decreto 0357 de Manizales y la regla estacional Cartagena 11-dic-2026–22-ene-2027, y verificar vías/excepciones antes de cualquier afirmación completa.

El parser fuente del candidato acepta `schemaVersion` 1 y 2 por el contrato G2. La verificación de rechazo corresponde al binario cliente V1 histórico del prompt y no se afirma desde el código fuente actual. No se modificó ese contrato porque el mismo lote exige validar schema2 en el parser actual.

El paquete contiene trabajo local recuperable, no un producto liberable. Sin publicación, instalación, intervención de dispositivos ni cambios de los checkouts operativos.
