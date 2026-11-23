# PicoRadar C22 V2 — handoff de cierre local

Fecha: 2026-11-22 (America/Bogota)

Base remota autorizada: `0fc292db2938744c40bf8d51a0503cbd3fec8562`

Rama remota única autorizada: `feat/platform-integral-national-20261122`

`main` confirmado al inicio: `e9ef37511df3110ffb0fc006ef06be781df432ac`

Commits de código integrados: `986bf8f`, `57bf545`
`HEAD_CODE=57bf545`; el SHA final documental y remoto se registra en `GITHUB_STATE.md` dentro del ZIP de retorno.

## Cambios

- `server/tests/Feature/AdminAppUsersTest.php`: nuevo recorrido SuperAdmin activo que usa PATCH para banear y otorgar Pro con payload sintético, verifica estado persistido, referencia/auditoría y revocación; confirma denegaciones para Admin, Commercial y SuperAdmin inactivo y ausencia de correo/pagos.
- `server/tests/Feature/CampaignPlanningTest.php`: amplía el trayecto de planificación para separar elegibilidad SERVER/MOBILE del envío real y comprobar catálogo público OFF/404 y ausencia de publicación.
- `codex/C22_LOCAL_RUNBOOK.md`: procedimiento condicionado para arrancar Laravel aislado solo después de demostrar que los paths de caché QA se resuelven en el proceso HTTP hijo.
- No se integró el cambio de prueba C1 sin commit porque el recorrido queda bloqueado antes del POST por un `ParseError` reproducible en `server/resources/views/admin/jurisdictions/show.blade.php`. No se modificaron vistas, motor, reglas, migrations, esquema, dependencias o configuración persistente.

## QA y gates

### A — Android

`A_ANDROID=PARTIAL`; `APP_LAUNCH=FAIL_REPRODUCIBLE`. APK C21 reutilizado: `co.picoradar.app.dev`, v1.0.1+2, 209315497 bytes, SHA-256 `556B17C5D4174552D9F556BC5BBCBF57FF33287BD82E01535C073FA98DE8C65F`. En el AVD Android API 35, `MainActivity` se inicia pero el proceso cae antes del primer frame; Logcat registra `ClassNotFoundException: io.flutter.plugins.GeneratedPluginRegistrant` y luego `SIGSEGV` en `libdartjni.so`. `apkanalyzer` confirmó que la clase no está definida en DEX. El `pub get` de C21 falló por soporte de symlinks y ese APK se generó con `--no-pub`, lo que sugiere un defecto del entorno de generación; no se demostró un arreglo seguro de fuente. No se recompiló. El reporte registra tres lanzamientos, incluidos dos fuera del plan inicial; se detuvo el AVD propio. Ninguna pantalla de producto fue observada y `UNKNOWN_UI=NOT_OBSERVED`.

### B — servidor local

`B_SERVER_HTTP=BLOCKED_ENV_PATH`; `SERVER_READY=NO`. Laravel `route:list` salió 0 y el proceso se abrió solo en loopback `127.0.0.1:53178`, pero las tres rutas HTTP devolvieron 500. La primera excepción fue `PackageManifest::write`: Laravel 13 trató `D:\...` como relativa al `basePath`; el prefijo añadido al runner no llegó al proceso PHP HTTP hijo. La escritura de prueba en ruta `\\?\D:\...` falló, por lo que no se reintentaron requests. No se probaron migraciones, auth positiva ni un defecto de producto. `artisan serve` se cerró y el puerto quedó sin listener. La limpieza de DB/runner/storage temporales y junction fue rechazada por el control automático; no se usó otra vía.

### C — Admin/editor/publicidad

`C_MVP=PARTIAL`; `C_METHODS=2/3`.

- C1 `test_editor_onboards_an_unassigned_municipality_and_saves_a_schema2_draft_without_publication`: bloqueado por `ParseError: unexpected token "endforeach"` al compilar la vista municipal. No se llegó al POST manipulado ON ni a probar persistencia OFF; queda `UNVERIFIED`.
- C2 `test_super_admin_manages_synthetic_accounts_by_patch_with_audit_and_other_roles_are_denied`: PASS, 1 método/29 aserciones. Se verificaron cambios PATCH `banned` y `pro`, persistencia, auditoría, revocación, denegaciones y ausencia de correos.
- C3 `test_commercial_can_read_planning_with_separate_server_mobile_and_off_states`: PASS, 1 método/23 aserciones. Planeación y proyección separadas; catálogo público OFF, HTTP de test 404, sin entrega real.

No se repitieron las pruebas históricas C19–C21. Logs y reporte de cada carril se incluyen en el ZIP C22. `git -c core.whitespace=cr-at-eol diff --check 0fc292d..HEAD` PASS para el delta funcional; no se hizo suite completa.

## Integridad y estado final

- Checkout original/WIP no intervenido; la rama local histórica `feat/platform-integral-national-20261122` que estaba en otro worktree no se movió. Candidato C22 lineal desde la base exacta; el remoto objetivo se validó antes del push y después con `ls-remote`.
- Sin APK nueva, instalación en teléfono, ADB USB, datos reales, cambios de motor/dataset/ley, servicios externos, Hostinger, `main`, PR #88, merge, release ni publicación.
- Decisión: `C22_PARTIAL`; `MAIN_BRIDGE=HOLD`; `LEGAL=NO_GO`; `RELEASE=NO_GO`.
- Próximos pasos concretos para el Director: (1) corregir y probar el registro/packaging de plugins Flutter en entorno permitido; (2) resolver el parseo de la vista jurisdicción y ejecutar solo C1; (3) definir runner aislado cuyo cache path absoluto funcione también en el hijo HTTP antes de intentar de nuevo B.

## Evidencia externa

La carpeta `D:\codex\_REPORTES\PicoRadar\C22-V2-20261122\` contiene informes y logs originales. Los archivos incluidos en el ZIP se sanitizan y manifiestan individualmente. El APK C21 no se duplica dentro del ZIP de 209 MB: su hash/versiones constan arriba y está preservado en `D:\codex\_REPORTES\PicoRadar\C21-V2-20261122\PICORADAR_C21_V2_RETORNO_UNICO.zip`.
