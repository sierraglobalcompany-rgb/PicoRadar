# PicoRadar — servidor local y respaldo QA C30

## Registro C33 V2 — OTA viva y panel MariaDB local

- El operador C31 recuperado vive en D:\codex\_build\PicoRadar-C33-V2\repo; el slot C31 sigue siendo D:\codex\_build\PicoRadar-C30-V2\runtime\instance-restored-c31-20261126, ID 5c2624b6-c48e-4e0a-8956-c09d33285725. En C33 el proceso y puerto obsoletos se comprobaron por separado y el marker se archivó íntegro como process.stale-5e72189220924324b8d2f9adc66eb530.json. No repetir recuperación ni ejecutar preparación editorial/publicación sobre este slot.
- El frente B usó origen MariaDB C32 D:\codex\_build\PicoRadar-C32-V2\db-candidate\private (64595) y destino C33 D:\codex\_build\PicoRadar-C33-V2\private\B (57305), versión 11.8.8, ambos solo en loopback y con ACL privada. El dump SQL y sus credenciales siguen fuera del repositorio y del ZIP. El backup cubre el catálogo lógico únicamente, no claves ni archivos de aplicación. La restauración ya ocurrió: no repetir sobre el destino ocupado ni ejecutar Migrate/bootstrap.
- Estado de cierre: origen y destino DB_STATUS=STOPPED, panel PANEL_STATE=STOPPED, puertos 8892, 8893, 64595 y 57305 cerrados. El destino conserva un usuario sintético SuperAdmin y audit_logs=157; el GET de la lista de usuarios generó un evento de auditoría de lectura. No se alteraron filas editoriales, reglas, releases ni publicaciones.
- Para consultar o reanudar las instancias existentes, los comandos exactos son:

      $repo = 'D:\codex\_build\PicoRadar-C33-V2\repo'
      $dbHelper = Join-Path $repo 'codex\qa\c32\mariadb-qa.ps1'
      $mariaDbRoot = 'C:\codex\_tool-cache\mariadb-11.8.8-winx64'
      $source = 'D:\codex\_build\PicoRadar-C32-V2\db-candidate\private'
      $target = 'D:\codex\_build\PicoRadar-C33-V2\private\B'
      & $dbHelper -Action Status -PrivateRoot $source -MariaDbRoot $mariaDbRoot
      & $dbHelper -Action Status -PrivateRoot $target -MariaDbRoot $mariaDbRoot
      & $dbHelper -Action Resume -PrivateRoot $source -MariaDbRoot $mariaDbRoot
      & $dbHelper -Action Resume -PrivateRoot $target -MariaDbRoot $mariaDbRoot
      & $dbHelper -Action Stop -PrivateRoot $target -MariaDbRoot $mariaDbRoot
      & $dbHelper -Action Stop -PrivateRoot $source -MariaDbRoot $mariaDbRoot

- Operación de panel; Prepare ya se ejecutó y no debe repetirse sobre esta DB, porque ya existe el SuperAdmin sintético. Smoke vuelve a consultar app-users y agrega otra auditoría de lectura.

      $panel = Join-Path $repo 'codex\qa\c33\mariadb-panel-qa.ps1'
      & $panel -Action Status -PrivateRoot $target -SourcePrivateRoot $source -MariaDbRoot $mariaDbRoot -Port 8893
      & $panel -Action Start -PrivateRoot $target -SourcePrivateRoot $source -MariaDbRoot $mariaDbRoot -Port 8893
      & $panel -Action Smoke -PrivateRoot $target -SourcePrivateRoot $source -MariaDbRoot $mariaDbRoot -Port 8893
      & $panel -Action Stop -PrivateRoot $target -SourcePrivateRoot $source -MariaDbRoot $mariaDbRoot -Port 8893

- Start permite archivar un marcador solo cuando dice STOPPED y las consultas confirmadas de PID/listeners no encuentran proceso ni puerto ocupado. Los listeners se enumeran con error fatal y se filtran en memoria para distinguir “puerto libre” de fallo del proveedor. El marker está ligado al router del worktree B original; para operar este estado privado usa D:\codex\_build\PicoRadar-C33-V2\worktrees\B, no el integrador repo.
- El backup/restore reutilizable está en codex/qa/c33/mariadb-catalog-backup.ps1. Backup emite el path privado de backup-manifest.json; Restore requiere ese path exacto y un destino nuevo y vacío. No copies el dump, manifest privado, client option files, APP_KEY, credencial sintética, sesiones o logs al checkout ni al retorno.
- El panel es QA Laravel local autenticada, solo loopback y con catálogo comercial apagado. No es editor productivo, certificación visual ni servicio definitivo. LEGAL=NO_GO, RELEASE=NO_GO, MAIN_BRIDGE=HOLD.

## Registro C32 V2 — OTA C31 pendiente y catálogo MariaDB aislado

- Frente A reutilizó el slot sintético C31 solo después de validar identidad, fixture y hashes. El certificado efímero para `127.0.0.1` pasó EKU `serverAuth`, SAN IP, cadena/propósito y vigencia; no se instaló CA global. El operador arrancó, pero el runner se bloqueó antes de capturar los dos GET vivos y el test Dart. Se detuvo el proceso y se confirmó el puerto 8892 cerrado. El marcador C31 quedó obsoleto; no eliminar ni reconstruirlo ni repetir preparación/publicación en ese slot.
- Frente B usó exclusivamente `picoradar_c32_qa_c4133ea4cb`, MariaDB 11.8.8 con datadir privado y bind `127.0.0.1:64595`. Las 26 migraciones y el bootstrap fueron de una sola ejecución. El catálogo quedó conciliado; `restrictions` se preparó schema2/OFF, sin versión, releases, reglas o publicaciones. El dashboard devolvió métricas nacionales y `SIN RELEASE ACTUAL`. La instancia fue reanudada una vez para lectura y detenida normalmente; el puerto quedó cerrado. La DB/credenciales permanecen en el root privado, no en el checkout ni el ZIP.
- No es infraestructura productiva, certificación legal ni cobertura de reglas. No hay publicación vigente ni permiso de circulación derivado de estos conteos.
- Para ejecutar los helpers aprobados, sus precondiciones y límites, ver [codex/qa/c32/README.md](../../codex/qa/c32/README.md). No correr `Migrate`, bootstrap o schema2 de nuevo contra esta instancia ya materializada; preservar la DB privada como evidencia local.
- Estado final de C32: A PARTIAL, B PASS_SCOPED, `MAIN_BRIDGE=HOLD`, `LEGAL=NO_GO`, `RELEASE=NO_GO`. Detalle: [C32_V2_HANDOFF.md](../../codex/C32_V2_HANDOFF.md) y retorno único C32.

## Registro C31 V2 — editor nacional y publicación local

C31 añadió un modo editorial temporal para una instancia nueva, restaurada desde el backup C30 verificado. No reutilizó ni modificó la instancia fuente C30. El destino HTTP solo escuchó en `127.0.0.1`; su allowlist deja las rutas de lectura C30 y login, y habilita únicamente las mutaciones editoriales documentadas en el retorno C31. La autenticación, CSRF y Gates de Laravel permanecen activos.

### Estado de la instancia C31

- Candidato: `D:\codex\_build\PicoRadar-C31-V2\repo`, rama `codex/c31-v2`, base `4d4626c82a00d0f6ddfe1b9db8708e2b4eb1e9b8`.
- Slot de QA: `D:\codex\_build\PicoRadar-C30-V2\runtime\instance-restored-c31-20261126`, ID `5c2624b6-c48e-4e0a-8956-c09d33285725`.
- Datos aislados SQLite sintéticos. La geografía de prueba usa los códigos de ejemplo `99/99999`; la jurisdicción está deshabilitada y la cobertura se mantiene OFF/partial. No es un dato oficial ni habilita circulación.
- QA finalizó con una publicación sintética schema2 (revisión 1), una versión validada publicada y una versión manual en borrador. El slot quedó detenido; el puerto 8892 está cerrado. No volver a ejecutar `PrepareEditorial`, `--run` ni `--resume-confirmed` en este slot: el estado ya no es el inicial y no es idempotente como flujo completo.
- `D:\codex\_build\PicoRadar-C31-V2\private` contiene el credential file del Editor y material TLS local. No imprimir, copiar al checkout ni incluirlo en respaldos/ZIP. El certificado hoja generado no tiene EKU `serverAuth` y no se usó para levantar un relay.

### Comprobar y cerrar el proceso

Solo lectura y detención del proceso de esa instancia, con identidad PID/ID/puerto validada por el operador:

```powershell
$repo = 'D:\codex\_build\PicoRadar-C31-V2\repo'
$qa = Join-Path $repo 'scripts\local\picoradar-local-qa.ps1'
$common = @{
    RepoRoot = $repo
    RuntimeHome = 'D:\codex\_build\PicoRadar-C30-V2\runtime'
    InstanceRoot = 'D:\codex\_build\PicoRadar-C30-V2\runtime\instance-restored-c31-20261126'
    PrivateRoot = 'D:\codex\_build\PicoRadar-C30-V2\private'
    KeyFile = 'D:\codex\_build\PicoRadar-C30-V2\private\instance-a.app-key'
    PasswordFile = 'D:\codex\_build\PicoRadar-C30-V2\private\operator.qa.password'
    EditorialPrivateRoot = 'D:\codex\_build\PicoRadar-C31-V2\private'
    ExpectedInstanceId = '5c2624b6-c48e-4e0a-8956-c09d33285725'
    PhpExe = 'C:\xampphp\php\php.exe'
    ReportRoot = 'D:\codex\_REPORTES\PicoRadar\C31-V2-20261126'
    Port = 8892
}
& $qa -Action Status @common
& $qa -Action Stop @common
```

La detención exitosa quedó seguida por un nuevo `Status=STOPPED` y comprobación de listener ausente. El postflight se capturó con PDO SQLite `mode=ro` y `PRAGMA query_only=ON` en `C_POSTFLIGHT_SNAPSHOT.json` del retorno C31.

### Gates y límites

- `A_TOOL/A_SCOPE/A_ALLOWLIST/A_PREP/A_HTTP=PASS`; el POST sin CSRF respondió 419, el Editor recibió 403 al intentar aprobar y el POST fuera de allowlist respondió 404. No hubo cambio de estado con esas denegaciones.
- `C_IMPORT_ANALYZE/C_CONFIRM_DRAFT/C_APPROVAL/C_PUBLISH/C_LIVE_BYTES/C_MANUAL_CREATE/C_MANUAL_UPDATE=PASS`. Manifest y payload servidos por Laravel coincidieron byte por byte y por SHA-256 con el almacenamiento activo. La modificación manual afectó solo al segundo borrador, no al release publicado.
- `B_CLIENT_STATIC=PASS` (formato y análisis focal Dart). `B_TLS=BLOCKED_CERTIFICATE_PREFLIGHT`: EKU sin `serverAuth`; por tanto `B_UPSTREAM/B_SYNC/B_UNKNOWN=NOT_RUN`. No se desactivó la validación TLS y no hubo tercer intento de generación.
- No se hizo APK/build/ADB, Mi A3, Hostinger, producción, cambios de motor/API/esquema/dependencias ni QA legal. `MAIN_BRIDGE=HOLD`, `LEGAL=NO_GO`, `RELEASE=NO_GO`.
- El flujo detallado, los logs saneados y la decisión están en el ZIP único C31 V2 y en `codex/C31_V2_HANDOFF.md`. El snapshot SQLite no se comparte como archivo de base de datos.

## Alcance

Este operador inicia PicoRadar Laravel local con fixture sintético y SQLite persistente, y respalda/restaura esa instancia. Es solo QA local: no certifica MariaDB, datos reales, publicación, OTA Laravel, producción ni lanzamiento. No ejecuta `migrate` ni `seed` al reabrir o restaurar.

## Rutas de esta instalación

- Checkout aislado: `D:\codex\_build\PicoRadar-C30-V2\repo`
- Datos fuente: `D:\codex\_build\PicoRadar-C30-V2\runtime\instance-a`
- Slot restaurado actual: `D:\codex\_build\PicoRadar-C30-V2\runtime\instance-restored`
- Clave y contraseña sintéticas: carpeta privada `D:\codex\_build\PicoRadar-C30-V2\private` (no imprimir ni copiar a respaldos).
- ZIP operativo privado: `D:\codex\_build\PicoRadar-C30-V2\private\picoradar-c30-instance-a.zip`.
- PHP CLI: `C:\xampphp\php\php.exe` 8.5.8. Las extensiones SQLite y PATH se fijan solo en el proceso.

## Comandos

Ejecutar en PowerShell. `Init` es únicamente para un root nuevo; si ya existe `instance.json`, no lo inicializa otra vez.

```powershell
$repo = 'D:\codex\_build\PicoRadar-C30-V2\repo'
$qa = Join-Path $repo 'scripts\local\picoradar-local-qa.ps1'
$backup = Join-Path $repo 'scripts\local\picoradar-backup-qa.ps1'
$runtime = 'D:\codex\_build\PicoRadar-C30-V2\runtime'
$source = Join-Path $runtime 'instance-a'
$archive = 'D:\codex\_build\PicoRadar-C30-V2\private\picoradar-c30-instance-a.zip'

& $qa Init -RepoRoot $repo -RuntimeHome $runtime -InstanceRoot $source
& $qa Status -RepoRoot $repo -RuntimeHome $runtime -InstanceRoot $source
& $qa Start -RepoRoot $repo -RuntimeHome $runtime -InstanceRoot $source
& $qa Stop -RepoRoot $repo -RuntimeHome $runtime -InstanceRoot $source
& $backup Backup -InstanceRoot $source -Archive $archive
& $backup Restore -InstanceRoot $source -Archive $archive -RestoreRoot (Join-Path $runtime 'instance-restored')
& $qa Start -RepoRoot $repo -RuntimeHome $runtime -InstanceRoot (Join-Path $runtime 'instance-restored')
& $qa Stop -RepoRoot $repo -RuntimeHome $runtime -InstanceRoot (Join-Path $runtime 'instance-restored')
```

El primer `Init` crea la clave y el password sintéticos una sola vez bajo la ACL privada. Para respaldos siguientes usa un nombre ZIP nuevo; la herramienta nunca sobrescribe. Cada restauración necesita un directorio nuevo, directo bajo `runtime`, con nombre `instance-restored` o `instance-restored-<sufijo>` (solo letras ASCII, números, guion y guion bajo). Ejemplo:

```powershell
$restore = Join-Path $runtime ('instance-restored-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
& $backup Restore -InstanceRoot $source -Archive $archive -RestoreRoot $restore
& $qa Start -RepoRoot $repo -RuntimeHome $runtime -InstanceRoot $restore
& $qa Stop -RepoRoot $repo -RuntimeHome $runtime -InstanceRoot $restore
```

Antes de respaldar, detén el servidor. Solo el proceso propio validado por PID, hora de inicio, ejecutable, línea de comandos, ID de instancia y listener loopback puede detenerse. Los comandos de respaldo fallan cerrados si hay proceso o estado dudoso. El servidor solo escucha en `127.0.0.1`.

El respaldo incluye `data/picoradar.sqlite` y archivos regulares de `storage/app/private` y `storage/app/public`; omite claves, password, sesiones, runtime, cachés y logs. Límites de restauración: 1 GiB y 10.000 archivos, verificados por bytes leídos. Restore crea ID nuevo, valida hashes/SQLite/migraciones, no pisa un destino y no ejecuta miembros del ZIP.

## Compatibilidad y recuperación

El marcador conserva el HEAD del código de origen. Se permite una revisión descendiente solo cuando es ancestro Git, el árbol versionado `server/` coincide exactamente y no hay cambios rastreados o archivos no rastreados bajo `server/`. De lo contrario, Backup/Restore bloquea con `CODE_HEAD_MISMATCH`; no actualices el marcador a mano.

La misma APP_KEY QA debe estar disponible fuera del ZIP en el `KeyFile` privado configurado. Sin ella, no se certifica recuperación de valores cifrados de la app. El password sintético del operador también se conserva fuera del respaldo. La herramienta no cifra ni firma el ZIP y no prueba autenticidad frente a un atacante con capacidad de modificarlo.

Para el retorno C30, el origen y la restauración se verificaron y quedaron detenidos. El backup actual es privado y no forma parte del ZIP entregable. Cuatro residuos temporales propios TLS (`c30-loopback-ca.pem`, `c30-loopback-chain.pem`, `c30-loopback-chain-fixed.pem`, `c30-loopback-leaf.key.pem`) permanecen en la carpeta privada: el borrado recibió rechazo de la política del entorno y no se intentó eludirla. No los copies al repo ni al ZIP.
