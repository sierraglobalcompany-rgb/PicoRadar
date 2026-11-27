$ErrorActionPreference='Stop'
$modulePath=Join-Path $PSScriptRoot '..\picoradar-local-qa-recovery.psm1'
Import-Module $modulePath -Force -ErrorAction Stop
$tempRoot=Join-Path $env:TEMP ('picoradar-recovery-fixtures-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($tempRoot)|Out-Null
$assertions=0
function Assert-True([bool]$Condition,[string]$Name){if(-not $Condition){throw ('FAIL '+$Name)};$script:assertions++}
try {
    $instanceId='5c2624b6-c48e-4e0a-8956-c09d33285725'
    $marker=[pscustomobject]@{format='picoradar-local-process/1';instanceId=$instanceId;pid=42764;startTimeUtc='2026-11-27T02:14:31.1722744Z';executable='C:\xampphp\php\php.exe';port=8892;commandline_sha256=('A'*64);mode='C30_DEFAULT';entry_mode=$null}
    $validation=Test-PicoRadarRecoveryMarker -Marker $marker -ExpectedInstanceId $instanceId -PhpExe 'C:\xampphp\php\php.exe'
    Assert-True $validation.Valid 'valid marker'
    $facts=@{MarkerValid=$true;InstanceMatches=$true;LastPortMatches=$true;GetProcessQuery='PASS';CimQuery='PASS';ListenerQuery='PASS';ProcessInventoryQuery='PASS';PidPresent=$false;ListenerPresent=$false;SlotWriterPresent=$false;PhpServerAmbiguous=$false;DestinationExists=$false}
    $decision=Get-PicoRadarRecoveryDecision -Facts $facts
    Assert-True ($decision.Action -eq 'ARCHIVE') 'dead valid marker archives'
    $invalid=Test-PicoRadarRecoveryMarker -Marker $marker -ExpectedInstanceId '00000000-0000-0000-0000-000000000001' -PhpExe 'C:\xampphp\php\php.exe'
    Assert-True (-not $invalid.Valid) 'mismatched instance rejected'
    $blockedCases=@(
        @{Name='live-or-reused pid';Field='PidPresent';Value=$true},
        @{Name='listener';Field='ListenerPresent';Value=$true},
        @{Name='slot writer';Field='SlotWriterPresent';Value=$true},
        @{Name='ambiguous PHP server';Field='PhpServerAmbiguous';Value=$true},
        @{Name='existing destination';Field='DestinationExists';Value=$true},
        @{Name='Get-Process query failure';Field='GetProcessQuery';Value='FAILED'},
        @{Name='CIM query failure';Field='CimQuery';Value='FAILED'},
        @{Name='listener query failure';Field='ListenerQuery';Value='FAILED'},
        @{Name='process inventory failure';Field='ProcessInventoryQuery';Value='FAILED'},
        @{Name='last-port mismatch';Field='LastPortMatches';Value=$false},
        @{Name='marker mismatch';Field='MarkerValid';Value=$false}
    )
    foreach($case in $blockedCases){$variant=@{}+ $facts;$variant[$case.Field]=$case.Value;$result=Get-PicoRadarRecoveryDecision -Facts $variant;Assert-True ($result.Action -eq 'BLOCK') $case.Name}
    $source=Join-Path $tempRoot 'process.json'
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes('synthetic marker bytes' + [Environment]::NewLine)
    [IO.File]::WriteAllBytes($source,$bytes)
    $expected=(Get-FileHash $source -Algorithm SHA256).Hash
    $target=Join-Path $tempRoot ('process.stale-'+[guid]::NewGuid().ToString('N')+'.json')
    $moved=Move-PicoRadarRecoveryMarker -SourcePath $source -DestinationPath $target -ExpectedSha256 $expected
    Assert-True (-not (Test-Path $source)) 'source removed by same-volume rename'
    Assert-True ((Get-FileHash $target -Algorithm SHA256).Hash -ceq $expected) 'archived bytes exact'
    $source2=Join-Path $tempRoot 'process2.json';[IO.File]::WriteAllBytes($source2,$bytes)
    $existing=Join-Path $tempRoot 'already-there.json';[IO.File]::WriteAllText($existing,'keep')
    $failed=$false;try{Move-PicoRadarRecoveryMarker -SourcePath $source2 -DestinationPath $existing -ExpectedSha256 $expected|Out-Null}catch{$failed=$true}
    Assert-True $failed 'existing destination refused'
    Assert-True ((Get-FileHash $source2 -Algorithm SHA256).Hash -ceq $expected) 'source intact on collision'
    $source3=Join-Path $tempRoot 'process3.json';[IO.File]::WriteAllBytes($source3,$bytes)
    $rejected=Join-Path $tempRoot 'missing-parent\process.stale.json'
    $failed=$false;try{Move-PicoRadarRecoveryMarker -SourcePath $source3 -DestinationPath $rejected -ExpectedSha256 $expected|Out-Null}catch{$failed=$true}
    Assert-True $failed 'rename rejected on absent parent'
    Assert-True ((Get-FileHash $source3 -Algorithm SHA256).Hash -ceq $expected) 'source intact on rename rejection'
    'PASS recovery guard fixtures='+$assertions+' external_processes=0'
} finally {
    if(Test-Path $tempRoot){Remove-Item -LiteralPath $tempRoot -Recurse -Force}
}