# PicoRadar C32 V2 — handoff

## Estado

`PARTIAL`. B materializó y verificó el catálogo en MariaDB QA aislada. A corrigió el certificado TLS de laboratorio, pero no completó la prueba HTTP/Dart viva: el runner no capturó los GET requeridos y el operador C31 quedó con marcador obsoleto. `MAIN_BRIDGE=HOLD`, `LEGAL=NO_GO`, `RELEASE=NO_GO`.

## Git

- Branch local: `codex/c32-v2`.
- Base: `71c61ca1a591fdbe571ec771e95c769969951547`.
- Commit de utilidades: `956e001cdbd87d5db27fc774b7a636f26a1c9159` (`chore(c32): add isolated TLS and MariaDB QA helpers`).
- Commit documental final y estado remoto: registrados en `GITHUB_STATE.md` del retorno C32 para evitar autorreferencia.
- Destino remoto permitido: `feat/platform-integral-national-20261122`. `main=e9ef37511df3110ffb0fc006ef06be781df432ac` queda HOLD.
- El checkout C31 se mantuvo limpio en `71c61ca`; los artefactos de TLS, DB, credenciales y runtime quedaron fuera del repositorio.

## Resultado A — TLS/OTA C31

- A0 `PASS`: slot `5c2624b6-c48e-4e0a-8956-c09d33285725`, fixture Bogotá `2026-11-26`, SQLite 544.768 bytes SHA-256 `E0F8039A161A7133F0D3A4B2B9248DCCF98EC630FFB98B02BA7C2B2BF4D09A31`. Manifest 424 bytes SHA-256 `103BF15D43EE2D54FFD06A3B0A8685BFCD43F74F57C82162C8AA6454ED6FDDC8`; payload 941 bytes SHA-256 `A2CD478F2204A51AE1D80A045D70C56A55C54B5CD66B64881590DA379E6B620A`.
- A1 TLS `PASS`: OpenSSL 3.5.7; EKU serverAuth OID `1.3.6.1.5.5.7.3.1`, SAN IP loopback, CA:false, key usage, coincidencia de clave pública, cadena y propósito verificados; vigencia suficiente. Sin trust global ni bypass. El material permanece en el root privado.
- El operador C31 fue iniciado en modo lectura y el runner se detuvo tras superar su límite; no se capturaron ambos GET vivos ni el test Dart. PHP y el listener terminaron; `Status` posterior dio `BLOCKED_PROCESS_NOT_RUNNING` y quedó un marcador obsoleto. No se borró ni reconstruyó el marcador y no se reinició el slot.
- `A_LIVE_HTTP=PARTIAL`; relay/upstream, Dart sync, UNKNOWN, política relay y cleanup temporal `NOT_RUN_DEPENDENCY`; `A_STOP_PRESERVED=PARTIAL_STALE_MARKER`; C31 live HTTPS `PARTIAL`. No declarar OTA viva ni publicación nueva.

## Resultado B — MariaDB y catálogo

- Instancia privada MariaDB 11.8.8, DB `picoradar_c32_qa_c4133ea4cb`, usuario de aplicación limitado a esa DB, bind `127.0.0.1`, puerto QA `64595`, sin servicio Windows ni configuración global. Datadir y credenciales quedaron bajo ACL privada.
- Preflight Laravel/PDO/target/flags OFF PASS. Migración única: 26/26 `Ran`; dry-run y bootstrap único PASS: 1 país, 33 departamentos, 1.104 municipios, 73 jurisdicciones, 82 mappings, 288 registros RUNT (276 exactos + 12 alias), cero unmatched, ambiguos o errores. Reconciliación: cero códigos inválidos, padres rotos u orphan mappings; 5 jurisdicciones ON y 68 OFF administrativas.
- Dashboard real `NationalOperationsReadService::dashboard([])` PASS: 1.104 municipios, 73 asociados, 1.031 no asociados, 68 jurisdicciones OFF, 73 sin borrador, 0 drafts, 0 validated y 0 propuestas pendientes. Release `SIN RELEASE ACTUAL`; la página muestra 50 de 1.104, las métricas cubren el total.
- Dataset id 1 `restrictions` / `Restricciones`, schema 2, OFF, `current_version=NULL`, revisión 0. Cero releases, versiones de regla y publicaciones. La instancia se reanudó una vez con la acción `Resume` sin migrate/seed/bootstrap; consulta read-only comprobó schema2 y 1.104 municipios. Apagado normal posterior PASS, proceso ausente y puerto cerrado. DB local privada conservada.
- Los conteos y flags son administrativos/sintéticos y no certifican cobertura legal ni permiso de circulación. `LEGAL_CERTIFIED_THIS_BATCH=0`; DB destino final no certificada.

## Cambios

`codex/qa/c32/` añade un helper TLS efímero, helper MariaDB QA con verificación de identidad y `Resume` explícito sin migración, preparación guarded de schema2 y README único. También se actualizan `README.md`, `docs/CURRENT.md`, `docs/operations/PicoRadar_LOCAL_QA.md` y este handoff. No cambian código móvil/servidor, API, motor, reglas, catálogos fuente, esquema de producto, dependencias ni lockfiles.

## Verificaciones ejecutadas

- Parse PowerShell de ambos helpers: PASS; `php -l codex/qa/c32/prepare-schema2.php`: PASS.
- MariaDB: identidad/aislamiento, preflight, migraciones, dry-run, bootstrap, reconciliación, schema2, dashboard, reanudación de solo lectura y Stop: PASS dentro del alcance QA.
- TLS OpenSSL: EKU, SAN, CA:false, keyUsage, cadena, propósito, vigencia y public-key match: PASS.
- `git diff --check` y revisión de rutas/secretos de los archivos integrados: PASS. No suite completa; no se repitieron pruebas históricas.
- Test Flutter OTA, APK, ADB, teléfono, HTTP productivo, migración de DB real, Hostinger, PR y merge: no ejecutados.

## Siguiente decisión

El Director decide si se autoriza resolver por el operador existente el estado obsoleto de C31 o se conserva C31 bloqueado y se define otro mecanismo para obtener los GET y ejecutar una única prueba Dart viva. No modificar ni reconstruir el slot en esta corrida. B queda reutilizable como candidato local privado; no volver a migrar, bootstrapear ni crear schema2. No abrir producción ni release.

## Evidencia

`D:\codex\_REPORTES\PicoRadar\C32-V2-20261127\PICORADAR_C32_V2_RETORNO_UNICO.zip` contiene informe, matriz de gates, estado Git y evidencias saneadas; excluye DB/dump, claves, certificado, credenciales, APK, vendor y logs crudos.