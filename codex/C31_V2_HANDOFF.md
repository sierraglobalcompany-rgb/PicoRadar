# PicoRadar C31 V2 — handoff

## Status

`PARTIAL` — A y C pasan en QA local sintética. B_TLS está bloqueado por certificado inválido; la aceptación `PASS_SCOPED_LIVE_EDITOR_HTTPS` no se alcanzó. `MAIN_BRIDGE=HOLD`, `LEGAL=NO_GO`, `RELEASE=NO_GO`.

## Lote

`C31 V2 — editor nacional, publicación local y probe OTA HTTPS opt-in`

## Git

- Branch: `codex/c31-v2`.
- Base/HEAD remoto de `feat/platform-integral-national-20261122` verificado antes de commits: `4d4626c82a00d0f6ddfe1b9db8708e2b4eb1e9b8`.
- Commit funcional local: `a030f6fcc0ca4915c1a25beb2ab7cfe90bf7d56f` (`feat(c31): add isolated editorial QA and OTA probe`).
- Commit documental: se registrará externamente en el ZIP de retorno para evitar autorreferencia.
- Worktree: `D:\codex\_build\PicoRadar-C31-V2\repo`.
- `main` verificado: `e9ef37511df3110ffb0fc006ef06be781df432ac`; sin cambios.

## Resultado

- **A PASS:** `PrepareEditorial` validó el ID `5c2624b6-c48e-4e0a-8956-c09d33285725` y preparó solo geografía/jurisdicción sintéticas `CO/99/99999`, dataset restrictions schema2, consulta OFF, sin regla/release/publicación inicial. La allowlist se aplica una vez antes de servir estáticos o Laravel. En HTTP real: POST sin CSRF `419`, Editor intentando aprobar `403`, POST ajeno a allowlist `404`; el borrador, auditorías y estado de publicación quedaron idénticos antes/después.
- **C PASS:** el Editor importó schema2, revisó y confirmó un borrador OFF/partial. Un SuperAdmin distinto validó y aprobó, y luego publicó por separado. El release vivo `r1-7ed4e1cc9fe1`, revisión 1, se sirvió desde Laravel: manifest 424 bytes y payload 941 bytes. HTTP, almacenamiento y hashes SHA-256 coinciden. Los formularios reales crearon y actualizaron un segundo borrador; no cambió la publicación.
- **B PARTIAL:** el archivo Dart nuevo está formateado y `dart analyze` no reporta issues en la copia Android-only con lockfile conservado. La hoja TLS privada tiene SAN loopback pero EKU sin `serverAuth` (`EKU OIDs=none`); no se inició relay, no hubo petición HTTPS ni sync Flutter. No se hizo tercer intento de certificado.

## Archivos y áreas

- Modificados: `scripts/local/picoradar-local-qa.php`, `scripts/local/picoradar-local-qa.ps1`.
- Nuevos: prueba de allowlist; `codex/qa/c31/{README.md,editorial.php,editorial_test.php}`; `mobile/qa/c31/national_live_https_c31_test.dart`.
- Documentación viva: `docs/CURRENT.md`, `docs/operations/PicoRadar_LOCAL_QA.md`, este handoff.
- Sin cambios en `server/`, `mobile/lib/`, API, esquema, normas, motor, catálogos, dependencias o lockfiles.

## Pruebas ejecutadas

| Comando/flujo | Resultado |
|---|---|
| `php -l scripts/local/picoradar-local-qa.php` y `php -l codex/qa/c31/editorial.php` | PASS |
| `php scripts/local/tests/picoradar-local-qa-editorial-policy.php` | PASS, 30 casos |
| `php codex/qa/c31/editorial_test.php` | PASS, 38 aserciones |
| Parse de `scripts/local/picoradar-local-qa.ps1` | PASS |
| Flujo C31 real `--resume-confirmed` en loopback | PASS: A_HTTP, aprobación, publicación, bytes vivos, alta y edición manual |
| `dart format --output=none --set-exit-if-changed qa/c31/national_live_https_c31_test.dart` | PASS, 0 cambios |
| `dart analyze qa/c31/national_live_https_c31_test.dart` | PASS, `No issues found!` |
| `git diff --check` | PASS |
| Test Dart OTA vivo / suite completa / build APK | NOT_RUN: el gate TLS no permite iniciar el relay; builds y suites globales fuera del alcance |

## QA manual/local

- El PHP local escuchó solo `127.0.0.1:8892`; `/up` respondió 200. Editor y SuperAdmin usaron sesiones/cookies separadas.
- La primera ejecución pasó C_IMPORT_ANALYZE y C_CONFIRM_DRAFT y se detuvo en el parser de formulario por una expectativa incorrecta de action (`/edit` frente a `/admin/{id}`). Se corrigió el runner y se continuó desde el único borrador confirmado, sin repetir preparación/importación/confirmación.
- El postflight de solo lectura confirma: revisión 1, un release, una publicación/ítem, una importación y dos versiones sintéticas (versión 1 validada/publicada; versión 2 Draft). El release conserva jurisdicción OFF y cobertura partial.
- La instancia terminó `STOPPED`; el listener 8892 está ausente. El backup C30 original es 17.364 bytes, SHA-256 `C765EB04117DF3991EDB89C5DF17A9C007874889AC6D2DC7FAA3C1F0A13E95A5`.

## QA físico Android

`Not required by C31 scope` — sin Mi A3, ADB, build APK ni instalación.

## Datos, seguridad y dependencias

- Solo se escribió en el slot restaurado C31 con SQLite sintética. No hubo migración ni seed. C30 fuente, su backup, producción y datos reales permanecieron intactos.
- Passwords quedaron en archivos ACL privados y variables de proceso. Los logs entregados contienen rutas/estados/hashes, sin cookies ni credenciales. Certificados y claves privados no forman parte del repo o ZIP.
- Sin dependencias añadidas o cambiadas.

## Riesgos y bloqueos

- El material TLS generado no cumple EKU serverAuth. Por eso `B_TLS=BLOCKED_CERTIFICATE_PREFLIGHT`, `B_UPSTREAM=NOT_RUN`, `B_SYNC=NOT_RUN`, `B_UNKNOWN=NOT_RUN`. No se desactivó verificación TLS ni se usó una CA global.
- La publicación C31 es sintética y OFF/partial. No certifica legalidad, cobertura nacional, vigencia de reglas, MariaDB, HTTPS productivo ni OTA en un dispositivo.
- El retorno C31 ZIP contiene evidencia sanitizada, hashes y el estado remoto final; no contiene bases, backups, vendor, APK, certificados, contraseñas ni HTML crudo.

## Siguiente paso habilitado

Revisar el bloqueo B_TLS y acordar una generación TLS válida con EKU serverAuth antes de ejecutar el test OTA vivo una sola vez. No reutilizar la instancia actual como estado inicial ni repetir los gates C completados. No abrir release: `LEGAL=NO_GO`, `RELEASE=NO_GO`, `MAIN_BRIDGE=HOLD`.
