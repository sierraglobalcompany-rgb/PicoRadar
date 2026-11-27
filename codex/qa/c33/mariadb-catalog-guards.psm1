Set-StrictMode -Version Latest

function Assert-CatalogOnlyRows {
    param(
        [Parameter(Mandatory)][object[]]$Rows,
        [string[]]$AllowedNonEmpty = @('audit_logs','datasets','geographic_units','jurisdictions','jurisdiction_geographic_unit','migrations')
    )
    $unexpected = @($Rows | Where-Object { [int]$_.rows -gt 0 -and $_.table -notin $AllowedNonEmpty })
    if ($unexpected.Count -gt 0) { throw 'BLOCKED_NON_CATALOG_ROWS_PRESENT' }
    $unsupported = @($Rows | Where-Object { $_.engine -ne 'InnoDB' })
    if ($unsupported.Count -gt 0) { throw 'BLOCKED_NON_INNODB_TABLE' }
}

function Assert-DistinctMariaDbInstance {
    param([Parameter(Mandatory)][psobject]$Source,[Parameter(Mandatory)][psobject]$Target)
    foreach ($field in @('privateRoot','datadir','database','dbUser','pipeName','port')) {
        if ([string]$Source.$field -ieq [string]$Target.$field) { throw "BLOCKED_TARGET_IDENTITY_COLLISION_$field" }
    }
}

function Assert-BackupBytes {
    param([Parameter(Mandatory)][string]$ActualHash,[Parameter(Mandatory)][string]$ExpectedHash,[Parameter(Mandatory)][long]$ActualBytes,[Parameter(Mandatory)][long]$ExpectedBytes)
    if ($ActualBytes -le 0 -or $ActualBytes -ne $ExpectedBytes) { throw 'BLOCKED_BACKUP_SIZE_MISMATCH' }
    if ($ActualHash -notmatch '^[A-Fa-f0-9]{64}$' -or $ExpectedHash -notmatch '^[A-Fa-f0-9]{64}$' -or $ActualHash -ine $ExpectedHash) { throw 'BLOCKED_BACKUP_HASH_MISMATCH' }
}

Export-ModuleMember -Function Assert-CatalogOnlyRows,Assert-DistinctMariaDbInstance,Assert-BackupBytes