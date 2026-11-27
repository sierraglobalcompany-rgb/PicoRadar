Set-StrictMode -Version Latest

function ConvertTo-RecoveryPath([string]$Path) {
    return [IO.Path]::GetFullPath($Path).TrimEnd('\')
}

function Test-PicoRadarRecoveryMarker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Marker,
        [Parameter(Mandatory)][string]$ExpectedInstanceId,
        [Parameter(Mandatory)][string]$PhpExe,
        [string]$EditorialEntryMode
    )
    try {
        if ([string]$Marker.format -cne 'picoradar-local-process/1') { return [pscustomobject]@{ Valid=$false; Reason='MARKER_FORMAT' } }
        if ([string]$Marker.instanceId -cne $ExpectedInstanceId) { return [pscustomobject]@{ Valid=$false; Reason='INSTANCE_ID' } }
        $pidValue = 0
        if (-not [int]::TryParse([string]$Marker.pid, [ref]$pidValue) -or $pidValue -le 0) { return [pscustomobject]@{ Valid=$false; Reason='PID' } }
        $portValue = 0
        if (-not [int]::TryParse([string]$Marker.port, [ref]$portValue) -or $portValue -lt 1024 -or $portValue -gt 65535) { return [pscustomobject]@{ Valid=$false; Reason='PORT' } }
        $startTime = [DateTimeOffset]::MinValue
        $parsed = [DateTimeOffset]::TryParse([string]$Marker.startTimeUtc, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$startTime)
        if (-not $parsed -or $startTime.Offset -ne [TimeSpan]::Zero) { return [pscustomobject]@{ Valid=$false; Reason='START_TIME_UTC' } }
        if ((ConvertTo-RecoveryPath ([string]$Marker.executable)) -ine (ConvertTo-RecoveryPath $PhpExe)) { return [pscustomobject]@{ Valid=$false; Reason='EXECUTABLE' } }
        if ([string]$Marker.commandline_sha256 -cnotmatch '^[A-Fa-f0-9]{64}$') { return [pscustomobject]@{ Valid=$false; Reason='COMMANDLINE_HASH' } }
        $mode = [string]$Marker.mode
        if ($mode -cnotin @('C30_DEFAULT','EDITORIAL_QA')) { return [pscustomobject]@{ Valid=$false; Reason='MODE' } }
        if ($mode -ceq 'EDITORIAL_QA') {
            $entry = [string]$Marker.entry_mode
            if ([string]::IsNullOrWhiteSpace($EditorialEntryMode) -or $entry -cne $EditorialEntryMode) { return [pscustomobject]@{ Valid=$false; Reason='EDITORIAL_ENTRY_MODE' } }
        }
        return [pscustomobject]@{ Valid=$true; Reason='VALID'; Pid=$pidValue; Port=$portValue; Mode=$mode; StartTimeUtc=$startTime.ToUniversalTime().ToString('o') }
    } catch {
        return [pscustomobject]@{ Valid=$false; Reason='MARKER_PARSE' }
    }
}

function Get-PicoRadarRecoveryDecision {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Facts)
    if (-not [bool]$Facts.MarkerValid) { return [pscustomobject]@{ Action='BLOCK'; Reason='MARKER_INVALID' } }
    if (-not [bool]$Facts.InstanceMatches) { return [pscustomobject]@{ Action='BLOCK'; Reason='INSTANCE_MISMATCH' } }
    if (-not [bool]$Facts.LastPortMatches) { return [pscustomobject]@{ Action='BLOCK'; Reason='LAST_PORT_MISMATCH' } }
    foreach ($query in @('GetProcessQuery','CimQuery','ListenerQuery','ProcessInventoryQuery')) {
        if ([string]$Facts[$query] -cne 'PASS') { return [pscustomobject]@{ Action='BLOCK'; Reason=('QUERY_' + $query) } }
    }
    if ([bool]$Facts.PidPresent) { return [pscustomobject]@{ Action='BLOCK'; Reason='PID_PRESENT_OR_REUSED' } }
    if ([bool]$Facts.ListenerPresent) { return [pscustomobject]@{ Action='BLOCK'; Reason='LISTENER_PRESENT' } }
    if ([bool]$Facts.SlotWriterPresent) { return [pscustomobject]@{ Action='BLOCK'; Reason='SLOT_WRITER_PRESENT' } }
    if ([bool]$Facts.PhpServerAmbiguous) { return [pscustomobject]@{ Action='BLOCK'; Reason='PHP_SERVER_AMBIGUOUS' } }
    if ([bool]$Facts.DestinationExists) { return [pscustomobject]@{ Action='BLOCK'; Reason='STALE_DESTINATION_EXISTS' } }
    return [pscustomobject]@{ Action='ARCHIVE'; Reason='PROCESS_AND_LISTENER_ABSENT_TWICE' }
}

function Move-PicoRadarRecoveryMarker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$DestinationPath,
        [Parameter(Mandatory)][string]$ExpectedSha256
    )
    if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) { throw 'BLOCKED_MARKER_SOURCE_MISSING' }
    if (Test-Path -LiteralPath $DestinationPath) { throw 'BLOCKED_STALE_DESTINATION_EXISTS' }
    $before = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash
    if ($before -cne $ExpectedSha256) { throw 'BLOCKED_MARKER_HASH_CHANGED' }
    [IO.File]::Move($SourcePath, $DestinationPath)
    if (Test-Path -LiteralPath $SourcePath) { throw 'BLOCKED_MARKER_SOURCE_REMAINS' }
    if (-not (Test-Path -LiteralPath $DestinationPath -PathType Leaf)) { throw 'BLOCKED_MARKER_ARCHIVE_MISSING' }
    $after = (Get-FileHash -LiteralPath $DestinationPath -Algorithm SHA256).Hash
    if ($after -cne $ExpectedSha256) { throw 'BLOCKED_MARKER_ARCHIVE_HASH_MISMATCH' }
    return [pscustomobject]@{ DestinationPath=$DestinationPath; Sha256=$after }
}

Export-ModuleMember -Function Test-PicoRadarRecoveryMarker,Get-PicoRadarRecoveryDecision,Move-PicoRadarRecoveryMarker