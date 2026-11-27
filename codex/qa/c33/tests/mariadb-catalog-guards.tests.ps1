$ErrorActionPreference = 'Stop'
$module = Join-Path $PSScriptRoot '..\mariadb-catalog-guards.psm1'
Import-Module $module -Force
$assertions = 0
function Assert-Pass([scriptblock]$Action) { & $Action; $script:assertions++ }
function Assert-Blocked([scriptblock]$Action,[string]$Code) {
    $blocked = $false
    try { & $Action } catch { if ($_.Exception.Message -eq $Code -or $_.Exception.Message.StartsWith("$Code`_")) { $blocked = $true } else { throw } }
    if (-not $blocked) { throw "EXPECTED_$Code" }
    $script:assertions++
}
$baseRows = @(
    [pscustomobject]@{table='migrations';engine='InnoDB';rows=26},
    [pscustomobject]@{table='geographic_units';engine='InnoDB';rows=1138},
    [pscustomobject]@{table='jurisdictions';engine='InnoDB';rows=73},
    [pscustomobject]@{table='jurisdiction_geographic_unit';engine='InnoDB';rows=82},
    [pscustomobject]@{table='datasets';engine='InnoDB';rows=1},
    [pscustomobject]@{table='audit_logs';engine='InnoDB';rows=156},
    [pscustomobject]@{table='users';engine='InnoDB';rows=0}
)
Assert-Pass { Assert-CatalogOnlyRows $baseRows }
Assert-Blocked { Assert-CatalogOnlyRows @($baseRows + [pscustomobject]@{table='app_users';engine='InnoDB';rows=1}) } 'BLOCKED_NON_CATALOG_ROWS_PRESENT'
Assert-Blocked { Assert-CatalogOnlyRows @($baseRows + [pscustomobject]@{table='odd';engine='MyISAM';rows=0}) } 'BLOCKED_NON_INNODB_TABLE'
$source = [pscustomobject]@{privateRoot='C:\src';datadir='C:\src\data';database='source_db';dbUser='source_user';pipeName='source_pipe';port=64595}
$target = [pscustomobject]@{privateRoot='D:\target';datadir='D:\target\data';database='target_db';dbUser='target_user';pipeName='target_pipe';port=57305}
Assert-Pass { Assert-DistinctMariaDbInstance $source $target }
foreach($field in @('privateRoot','datadir','database','dbUser','pipeName','port')) {
    $collision = $target.PSObject.Copy(); $collision.$field = $source.$field
    Assert-Blocked { Assert-DistinctMariaDbInstance $source $collision } "BLOCKED_TARGET_IDENTITY_COLLISION_$field"
}
Assert-Pass { Assert-BackupBytes ('a'*64) ('A'*64) 100 100 }
Assert-Blocked { Assert-BackupBytes ('a'*64) ('b'*64) 100 100 } 'BLOCKED_BACKUP_HASH_MISMATCH'
Assert-Blocked { Assert-BackupBytes ('a'*64) ('a'*64) 99 100 } 'BLOCKED_BACKUP_SIZE_MISMATCH'
"PASS mariadb C33 guards assertions=$assertions no_processes=true"