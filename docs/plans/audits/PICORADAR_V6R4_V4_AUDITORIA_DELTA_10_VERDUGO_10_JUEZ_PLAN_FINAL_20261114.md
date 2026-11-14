# PICO RADAR — V6R4 V4 AUDITORÍA DELTA, 10 VERDUGO + 10 JUEZ Y RUTA DE CIERRE

**Corte:** 14-nov-2026, Colombia. **Director:** ChatGPT. **Estado:** `AUDIT_DELTA_DONE / PRODUCT_RELEASE=NO_GO`. **Alcance:** entrega real V4 de Codex, NO reedición de auditorías de V5, V6R3, V6R4-V2/V3 ni censo nacional.

## 1. Cadena de custodia realmente comprobada

- ZIP recibido `PICORADAR_V6R4_V4_EVIDENCIA_UNICA.zip`, **85.178.865 bytes**, SHA-256 `6d24f095df4521210f28197e2452398056781d4e9db36b088d258664a89d37b2`; **48 entradas**, manifiesto CSV con **47/47 miembros externos al manifiesto** verificados contra tamaño/CRC32/SHA-256; CRC ZIP sin fallos; no duplicados ni rutas peligrosas.
- Bundle `GIT/full-final.bundle`, SHA-256 `dad16fccb97493add593bbacbd13edfb1db60219f14b445fd5e22141356639a1`: verificación Git `PASS`; clonado **de verdad** en entorno independiente, checkout limpio. `HEAD=15948a50332589ff3d1fb3157b6976809fe5a680`, tree `8e0b8cd1de0607e9baeeffcfac93c8f141afb67f`, padre `09b4f0a35fa6eae2192c88c83d2afe10133aabfe`. Solo **dos rutas** del último commit: `mobile/test/features/pico_placa/data/national_bulk_v6r3_ota_test.dart` y el nuevo `mobile/test/features/pico_placa/data/national_bulk_v6r4_widget_test.dart`.
- **F1 aprobado y no repetible sin delta:** OTA/Drift **2/2**, widget **1/1**, ambos tests y ambos analizadores exit 0; pruebas reales con DB y transporte local. Incluye secuencia V5→V6R3→V6R4, validación SHA y `last-good`, 14 autoridades, 33 DIVIPOLA, 21 coberturas parciales, 115 reglas, Garaje y preferencias preservados; consultas `UNKNOWN/STALE` y 18/19-nov Dosquebradas. El primer test UI RED fue expectativa de host `www`, ajustada al hostname de fuente y seguida por GREEN. Archivo Dart OTA completo conserva deuda de formato preexistente (`dart format --check` exit 1 tanto en base como V4); análisis funcional Dart exit 0. No reformat masivamente 642 líneas.
- **F2 parcialmente funcional:** MariaDB **10.4.32** QA temporal en `127.0.0.1:57206` validó `explicit_defaults_for_timestamp=ON`, SQL estricto, identidad/DB efímera, cierre del puerto y sentinel `RestrictionPublicationServiceTest` **6/6 tests, 25 assertions, exit 0**. Las otras seis clases completaron **33 tests, 113 assertions, exit 2**: siete `MissingAppKeyException` y cuatro fallos porque referencias de evidencias R2/G2 no estaban definidas. **El error anterior SQL 1067 ya no aparece.** No declarar admin completo.
- **F3** Android/Gradle **no ejecutado**. Host con RAM libre 9,51 GiB, commit libre 6,18 GiB, pagefile libre 3,37 GiB frente a configuración `-Xmx8G` y metaspace 4G. No APK, no Mi A3. No convertir el bloqueo de recursos en error de código.
- **F4:** el remoto GitHub **no contiene** el SHA V4 (consulta conector devolvió 422) ni rama V6R4; PR #79 y #71 continúan Draft. El bundle local sí contiene el HEAD. Se comprobó que `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a` (HEAD de PR71) es ancestro del V4 local y entre ambos hay **12 commits** y 126 rutas distintas, **29.036 líneas agregadas**. Se realizó búsqueda heurística READ_ONLY de patrones de secretos sobre líneas agregadas, sin coincidencias en esos patrones; **no equivale a certificado exhaustivo de publicación**. No push/merge.

### Precisiones nuevas verificadas en el código PHP (no constaban en la respuesta de Codex)

Las seis clases son `DatasetReleaseValidationTest.php`, `DatasetPublisherTest.php`, `RestrictionImportServiceTest.php`, `RestrictionNationalLabPublicationTest.php`, `DatasetAuthorizationTest.php`, `RestrictionSchemaV2LabRoundTripTest.php` bajo `server/tests/Feature/`.

**Cinco variables de evidencias reales (no solo tres):** `PICORADAR_R2_EVIDENCE_DIR` (lee `ACTUAL_R2_LARAVEL_RELEASE.json` con SHA exacto `c879a27ce3fc0ef983575a069e995c95c4f9a03fe2b5f89509386dfa8090d5e5`); `PICORADAR_G1_EVIDENCE_DIR` (salida G1); `PICORADAR_G2_EVIDENCE_DIR` (salida G2); `PICORADAR_G2_R2_RELEASE` (ruta al mismo JSON R2); `PICORADAR_G2_V3_EVIDENCE_DIR` (salida G2 V3). Además, `APP_KEY` sintética de proceso de prueba, no la clave real. **El R2 exacto no está en ninguno de los ZIP adjuntos de esta conversación**, por lo que no se puede declararlo disponible en Windows.

Los dos archivos `server/phpunit.xml` y `server/phpunit.mariadb.xml` apuntan respectivamente a SQLite y al puerto MySQL 3306 por defecto. Las pruebas V4 utilizaron una configuración temporal hacia puerto **57206**, ahora cerrada. Prohibido ejecutar `RefreshDatabase` con el XML equivocado o en un esquema no demostrablemente efímero.

## 2. Diez pasadas del VERDUGO — solo delta material

| Pase | Comprobación realizada | Hallazgo/amenaza | Decisión obligatoria |
|---|---|---|---|
| V01 | ZIP, CRC, tamaños, SHA y rutas | El informe decía 48 miembros; 47 son verificados por manifiesto, el último es el propio CSV | Custodia correcta, denominador explícito |
| V02 | `git bundle verify`, clon y HEAD/TREE/PARENT | GitHub no conoce `15948a5…`; solo ZIP salva el commit | Bundle protegido; no reset/clean ni nueva custodia |
| V03 | F1 stdout y GATES.csv | Tres casos terminan GREEN; red previo fue aserción de host, no motor | Cerrar F1, prohibir reejecución por rutina |
| V04 | Comparación git del último commit | Solo cambian dos tests; motor/datos/lockfiles iguales | No alterar código producto por fallo de arnés ya resuelto |
| V05 | Logs MariaDB + PHPUnit | `ends_at` ya no falla; 7 errores de APP_KEY | Inyectar APP_KEY aleatoria de QA sin guardarla/publicarla |
| V06 | Fuente de `RestrictionNationalLabPublicationTest.php` | Falta `G1_EVIDENCE_DIR`, no mencionada por Codex | Crear directorio QA local; no reenviar solo tres vars |
| V07 | Fuente de `RestrictionSchemaV2LabRoundTripTest.php` | Falta `G2_V3_EVIDENCE_DIR`, además del R2 input | Preparar cinco referencias; fixture exacto o bloqueo restringido |
| V08 | SHA literal R2 + ZIP adjuntos | Fixture R2 exacto no aportado; sustituir por V4 produciría PASS falso | Buscar solo en evidencias autorizadas con límite de alcance; no fabricar |
| V09 | Android gradle.properties + recursos | `-Xmx8G`/metaspace 4G frente a 3,37GiB pagefile libre | No build en el host mientras siga el gate de RAM/pagefile |
| V10 | GitHub PR79/PR71 + historia bundle | 12 commits aún no publicados, no 313 «nuevos»; scanner completo no demostrado | Revisar intervalo `PR71..HEAD`, push solo rama LAB tras seguridad y permisos |

## 3. Diez pasadas del JUEZ — refutación y decisión mínima

| Pase | Alternativa sometida a juicio | Decisión y motivo |
|---|---|---|
| J01 | «Rehacer V6R4» | Rechazada: ya existe HEAD, tree, bundle y pruebas del delta |
| J02 | «Correr Flutter de nuevo» | Rechazada sin cambio runtime/fixture: F1 ya da 2+1 PASS |
| J03 | «Cambiar migración `ends_at`» | Rechazada: instancia MariaDB con opción temporal prueba que el SQL 1067 anterior no persiste |
| J04 | «Usar APP_KEY real» | Rechazada: basta clave Laravel temporal sintética; preserva secretos |
| J05 | «Crear nuevo R2 a partir de V4» | Rechazada: se exige SHA exacto y semántica histórica de 7 jurisdicciones/12 coberturas |
| J06 | «Bloquear todos los PHP si falta R2» | Rechazada: cuatro clases y caso G2 no dependiente pueden ejecutarse independientemente |
| J07 | «Repetir 33 tests ciegamente sin preflight» | Rechazada: primero comprobar cinco variables, clave, DB y SHA; una ejecución por bloque apto |
| J08 | «Forzar Gradle o bajar umbral por urgencia» | Rechazada: no modificar criterios ni memoria del equipo; pasar el build a host apto gratis cuando exista |
| J09 | «Push de 313 commits sin auditar» | Rechazada: base PR71 es ancestro, solo 12 nuevos; revisar esos 12 y diff completo antes de rama pública |
| J10 | «Terminar app = 1.104 municipios legales ahora» | Rechazada: el motor es nacional, la activación por datos exige fuente y ámbito; el lanzamiento requiere runtime, admin, OTA controlada y QA Android sin falsas coberturas |

## 4. Decisión del director y ruta crítica

1. **No repetir F0/F1.** HEAD `15948a503…` se conserva; 14/33/21/115 son **LAB**, todos `partial`; seis HOLD históricos nacionales subsisten. Dosquebradas tiene calendario oficial de 28-sep, pero festivos/ámbito/exenciones no probados; no promover a permiso personal.
2. **Siguiente macrobloque de Codex = solo F2+F4, F3 condicional.** Preparar APP_KEY sintética y cinco variables, R2 con SHA exacto si existe, MariaDB QA efímera e identidad verificable; ejecutar una vez seis clases si están todos los insumos. Si falta R2, ejecutar cuatro clases independientes y un caso G2 sin R2; marcar los dependientes BLOQUEADOS POR EVIDENCIA, no FAIL PRODUCTO. Cerrar DB/puerto. Inspeccionar 12 commits nuevos para decidir push de **rama LAB** sin merge.
3. **Android:** revalidar memoria solo si cambió el host/recursos. Si persiste 3,37 GiB pagefile libre, mantener `BLOCKED_HOST_RESOURCE`; no editar `gradle.properties` ni degradar los umbrales anteriores. Obtener build y QA física más adelante en host apto y con autorización específica.
4. **Producto V1 final:** Laravel admin/preview/aprobación/publisher de snapshot **completo** para fuentes aprobadas, firma SHA/version/revisión y rollback; Flutter OTA en Android real, preservando Garaje/usuarios/offline; QA físico de firma y recursos; autorización de release. Luego expansión de datos nacionales en el mismo schema2 sin APK por jurisdicción. Política oficial: boletín municipal/departamental suficiente **para campos explícitos**, jamás inferir festivos/perímetro/exenciones. `UNKNOWN/STALE` frente a lagunas.
5. **No pingpong:** un ZIP de Codex con logs del único delta nuevo, tabla de gates y bundle recuperable; no anexos dispersos. Si una dependencia imprescindible está ausente, documentar el bloqueo exacto y seguir tareas seguras, sin reauditoría general.

**NEXT_ACTOR=CODEX_LUNA_IF_IDLE. AFTER=CHATGPT_DIRECTOR_DELTA_REVIEW. PRODUCT_RELEASE=NO_GO.**
