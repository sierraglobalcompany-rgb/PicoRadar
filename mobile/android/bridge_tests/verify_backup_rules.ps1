$ErrorActionPreference = 'Stop'
$androidRoot = Split-Path $PSScriptRoot -Parent
$mainRoot = Join-Path $androidRoot 'app/src/main'
[xml]$manifest = Get-Content -LiteralPath (Join-Path $mainRoot 'AndroidManifest.xml') -Raw
$ns = [Xml.XmlNamespaceManager]::new($manifest.NameTable)
$ns.AddNamespace('android', 'http://schemas.android.com/apk/res/android')
$service = $manifest.SelectSingleNode('//service[@android:name=".wallet.DocumentPdfService"]', $ns)
if ($null -eq $service -or $service.GetAttribute('exported', $ns.LookupNamespace('android')) -ne 'false' -or
    $service.GetAttribute('isolatedProcess', $ns.LookupNamespace('android')) -ne 'true') {
    throw 'PDF service must be unexported and isolated.'
}
if ($manifest.manifest.application.GetAttribute('allowBackup', $ns.LookupNamespace('android')) -ne 'false') {
    throw 'Cloud backup must remain disabled.'
}
if ($null -eq $manifest.SelectSingleNode('//uses-permission[@android:name="android.permission.USE_BIOMETRIC"]', $ns)) {
    throw 'Biometric permission is missing.'
}

[xml]$oldRules = Get-Content -LiteralPath (Join-Path $mainRoot 'res/xml/wallet_backup_rules.xml') -Raw
[xml]$newRules = Get-Content -LiteralPath (Join-Path $mainRoot 'res/xml/wallet_data_extraction_rules.xml') -Raw
$scopes = @($oldRules.SelectSingleNode('/full-backup-content'),
    $newRules.SelectSingleNode('/data-extraction-rules/cloud-backup'),
    $newRules.SelectSingleNode('/data-extraction-rules/device-transfer'))
$sensitive = @(
    @('file', 'vehicle_documents/index_v1.prcf'),
    @('file', 'vehicle_documents/document.prcf'),
    @('root', 'app_flutter/vehicle_documents/document.prcf'),
    @('root', 'app_flutter/documents/document.prcf'),
    @('file', 'flutter_secure_storage/key'),
    @('root', 'app_flutter/flutter_secure_storage/key'),
    @('sharedpref', 'FlutterSecureStorage.xml'),
    @('sharedpref', 'FlutterSecureKeyStorage.xml'),
    @('sharedpref', 'FlutterSecureStorageConfig.xml'),
    @('sharedpref', 'FlutterSharedPreferences.xml'),
    @('sharedpref', 'picoradar_widget.xml'),
    @('file', 'datastore/FlutterSharedPreferences.preferences_pb'),
    @('root', 'app_flutter/picoradar.sqlite'),
    @('root', 'app_flutter/picoradar.sqlite-wal'),
    @('root', 'app_flutter/picoradar.sqlite-shm'),
    @('root', 'app_flutter/picoradar.sqlite-journal'),
    @('file', 'picoradar.sqlite'),
    @('database', 'picoradar.sqlite'),
    @('database', 'picoradar.sqlite-wal'),
    @('device_sharedpref', 'FlutterSecureStorage.xml')
)
$checks = 0
foreach ($scope in $scopes) {
    if ($null -eq $scope) { throw 'Missing backup/transfer scope.' }
    foreach ($entry in $sensitive) {
        $covered = $false
        foreach ($rule in $scope.SelectNodes('exclude')) {
            if ($rule.domain -ne $entry[0]) { continue }
            $rulePath = $rule.path.TrimEnd('/')
            if ($rulePath -eq '.' -or $entry[1] -eq $rulePath -or $entry[1].StartsWith($rulePath + '/')) {
                $covered = $true
                break
            }
        }
        if (-not $covered) { throw "Sensitive path not excluded in $($scope.Name): $($entry -join ':')" }
        $checks++
    }
}
Write-Output "PASS: $checks sensitive-path exclusions across legacy backup, cloud backup, and device transfer; isolated PDF manifest and biometrics."
