# PicoRadar — servidor local y respaldo QA C30

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
