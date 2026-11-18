# PICORADAR — Dirección M3-X01: auditoría forense de BLOCKED_ENV, diez pasadas y continuación causal

**Corte:** 2026-11-09 COT. **Director:** ChatGPT. **Ejecución:** Codex Luna. **Único TASK_ID:** `PICORADAR-M3-X01-LARAVEL-MANIFEST-FLUTTER-CONTRACT-20261109-DIRECTOR`.

## 0. Alcance, evidencia y distinción de hechos

**Evidencia recibida:** `PICORADAR_M3_X01_CONTRATO_LARAVEL_FLUTTER_EVIDENCIA_UNICA_20261109.zip`, tamaño **12.642 bytes**, SHA-256 `fd7c1218dab5af0e1d495ac2b456f7006a53aec09935128e7bd3dcbbaecffce9`. Auditoría local independiente sobre los bytes del ZIP: **16 entradas CRC PASS**, 14/14 payload en `MANIFEST.json` tamaño y SHA PASS; checksum de `MANIFEST.json` PASS. Archivos `SYNTHETIC_BYTES_MANIFEST.json` y `PROVENANCE.csv` muestran `NOT_RUN`, no releases v1/v2 fabricados. `AUDIT_10.csv` contiene diez controles, pero cuatro NOT_RUN y uno PARTIAL; `GATES.csv` 16 filas, siete NOT_RUN y otros bloqueos. `CONTRACT_MATRIX.csv`: 12 conceptos, 9 etiquetados PASS **estático**, 3 UNKNOWN. `SOURCE_HASHES.csv`: 20 rutas SHA declaradas, sin bytes originales de esas 20 rutas adjuntos al ZIP; no presentarlas como hashes reproducidos contra código local por el director.

**Evidencia sobre entorno desde Codex, NO comprobación remota del equipo por el director:** PHP 8.5.8, Composer 2.10.2, PDO general disponible sin `pdo_sqlite` ni `sqlite3`, `flutter` no resuelto en el proceso, `vendor/autoload.php` y `package_config.json` presentes. El supuesto log `TEST_COMMANDS_AND_RAW_OUTPUT.log` **no incluye el transcript crudo**, y explica que es un resumen observado. No se puede elevar a prueba independiente de inexistencia física de todo SDK. Git PRE/POST indicado igual en `recovery/20261019-modern`, HEAD `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`, tree `04a01f15475dd25fbcd40597120e6e44722b0504`; borrado histórico `D scripts/tests/test_hostinger_installer_browser.ps1`; **101 WIP no enumerados/hasheados**.

**Contraste GitHub independiente:** `server/phpunit.xml` usa `DB_CONNECTION=sqlite`, `DB_DATABASE=:memory:`. `server/composer.json` exige PHP `^8.3`; `mobile/pubspec.yaml` exige Dart `^3.13.1`. `docs/CURRENT.md` declara **3.253 PASS / 11 SKIP** de suite móvil ejecutada localmente en octubre, lo cual justifica localizar el SDK histórico, pero no demuestra dónde está hoy. `server/app/Services/RestrictionPublicationService.php`, `DatasetPublisher.php`, `ManifestPublisher.php`, `mobile/lib/core/sync/dataset_sync_service.dart` y tests ya implementan el contrato independiente; no recrear motores. Las leyes L1–L6 permanecen en `sierraglobalcompany-rgb/PingPongLaw` blob `0f6e7b4e62d8660c846f135e18dded629d29e0da`.

## 1. Diez pasadas — control, resultado y corrección

| Pasada | Qué hice | Resultado | Consecuencia directiva |
|---|---|---|---|
| 01 Integridad | Leí 16 miembros, `testzip`, manifiesto y checksum SHA-256 por archivo | **PASS** | Aceptar evidencia de empaquetado; no aprobar M3 |
| 02 Resultados reales | Reconcilié `GATES.csv`, `AUDIT_10.csv`, `SYNTHETIC_BYTES_MANIFEST` | **BLOCKED confirmado** | Ningún gate de puente ejecutado; cero releases y cero tests |
| 03 Identidad del checkout | Contrasté PRE/POST del ZIP con el SHA remoto y estado de PR | **PASS documental / WIP NOT_VERIFIED** | No tocar borrado histórico ni 101 WIP; falta inspección física independiente |
| 04 Contrato estático | Comparé 12 conceptos con Laravel/Flutter, distinguiendo 9 `PASS` estáticos y 3 `UNKNOWN` | **PARTIAL** | `NO_DELTA_NEEDED` y `BRIDGE_PASS` prohibidos |
| 05 PHP mínimo | Comprobé `phpunit.xml` SQLite in-memory, PHP `^8.3` y documentación PHP oficial | **CAUSA DIRECTA** | `pdo_sqlite` sí imprescindible; `sqlite3` aislado no necesariamente imprescindible; no migrar pruebas a MariaDB |
| 06 Flutter mínimo | Contrasté `flutter not found` con Dart `^3.13.1` y suite móvil histórica | **HIPÓTESIS no agotada** | PATH actual ausente ≠ SDK inexistente en todo D:/ o perfil; búsqueda única acotada |
| 07 Alternativas y seguridad | Contrasté instalación Windows PHP/Flutter con fuentes oficiales y política de preservación | **ALTERNATIVA AISLADA** | Solo un paquete oficial por herramienta si hace falta, checksum real, sin PATH/php.ini permanente ni admin |
| 08 Reutilización KISS | Inspeccioné servicios y pruebas de cada extremo | **PASS de diseño** | No nuevo módulo productivo ni parche al motor; mismo M3-X01 |
| 09 Riesgo de falsos PASS | Revisé caso `last-good`, fixture `NOT_RUN`, transcripciones y fuentes sin bytes | **Riesgo de QA** | Solo PASS de PHP + Flutter + mismos bytes + caso corrupto permite `BRIDGE_PASS_SCOPED` |
| 10 Continuidad y antiping-pong | Comparé PR79 documental, PR71, ley L6 y orden vigente | **CORREGIR RUMBO** | Recuperar entorno **una vez dentro del mismo TASK_ID**, ejecutar bridge si se habilita y entregar UN ZIP, sin C2 |

**Observación de autocrítica:** el prompt M3-X01 V2 exigía detenerse tras un único chequeo de `php -m` / `flutter --version` y no dejaba recuperar herramientas con seguridad. La orden no era errónea al evitar falsos PASS, pero produjo un resultado administrativamente previsible. La solución NO es otra revisión estática; es una **única recuperación acotada y reversible** del entorno de QA, seguida en la misma ejecución por el bridge.

## 2. Decisión y gates

**Resultado del ZIP anterior:** `M3_X01_BLOCKED_ENV`, ACEPTADO COMO BLOQUEO (no defecto de aplicación). **La tarea M3-X01 sigue abierta, pero NO nace otra fase**, y la revisión autorizada es **V2.1 en la misma ruta y mismo TASK_ID**. `NEXT_ACTOR=CODEX_LUNA` únicamente para G0R una vez y luego G1–G6, con autoría del director ChatGPT.

- **Ruta preferida:** localizar Flutter SDK ya presente y la DLL `php_pdo_sqlite` del PHP compatible; usar rutas absolutas, `PATH`/`php -d` efímeros y copia de QA desde commit fijo, sin tocar C:/Windows/php.ini global.
- **Ruta secundaria:** paquete Flutter ZIP oficial del archivo estable y/o PHP Windows oficial, checksum SHA-256 obtenido de la misma fuente oficial y validado, extraído únicamente bajo `D:\codex\_toolchains\PicoRadar-M3X01`; un intento por herramienta, no instaladores globales. Si esto no es posible por política, disco o red, STOP sin evasiones.
- **Si ambos disponibles:** ejecutar prueba de 2 releases sintéticos reales por `RestrictionPublicationService` Laravel → manifests y payloads exactos → Flutter HTTP loopback/Drift → negativa de v2 corrupta sobre v1 instalada. NO manipular manifest. No probar ni aprobar C1 schema2 mediante este schema1.
- **Si solo uno disponible:** ejecutar únicamente subtests factibles y etiquetar `PARTIAL_ENV`; sin `BRIDGE_PASS` ni tercer prompt. Si ninguno, `BLOCKED_ENV` causal verificable; pasar al director, no crear M3-X01-C2.
- **Entregable:** un ZIP exclusivo, `ENV_COMMANDS_RAW.log`, versiones/ABI/hash oficial de las herramientas, PROVENANCE, bytes v1/v2 si se generaron, pruebas con códigos de salida, gates `NOT_RUN`, Git PRE/POST, manifiesto/CRC/SHA y `NEXT_ACTOR=CHATGPT_DIRECTOR`. No commits/push/merge/despliegue, sin tocar datos personales.

## 3. Ruta de finalización que NO cambia

**M1:** seguir cobertura nacional a partir de autoridades y actos oficiales, 0/5 reglas jurídicas READY; `UNKNOWN/STALE` no es permitido circular. **M2:** reutilizar motor/compilador y agente lector/proponente sin publicación autónoma. **M3:** prueba actual de contrato real schema1, después control de rollback y sincronización Laravel↔Flutter completo, sin declarar DONE prematuro. **M4:** C1 schema2 pendiente, 101 WIP, JNI, QA física Android, firma, seguridad, privacidad y autorización humana.

**GitHub:** PR documental #79 Draft contra `recovery/20261019-modern`; PR #71 Draft contra main histórico sin cambios productivos. Al actualizar esta decisión, cambiar solo docs del PR79 con lease SHA. **RELEASE=NOT_APPROVED, PUBLISH_ALLOWED=NO**.

## 4. Fuentes oficiales de herramienta

- PHP Windows PDO SQLite: https://www.php.net/manual/en/pdo.installation.php ; https://www.php.net/manual/en/pdo-sqlite.installation.php
- PHP Windows SQLite3: https://www.php.net/manual/en/sqlite3.installation.php
- Flutter SDK oficial: https://docs.flutter.dev/install/archive ; https://docs.flutter.dev/install/manual

Estas fuentes son información general para escoger herramientas; **no prueban** que haya binarios específicos instalados en el equipo del usuario.