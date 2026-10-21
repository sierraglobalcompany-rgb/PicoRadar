$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$matrixPath = Join-Path $root 'docs/post_c11/INVENTARIO_ACCIONES_POST_C11.csv'
$diffPath = Join-Path $root 'docs/post_c11/INVENTARIO_ACCIONES_POST_C11_DIFF.csv'
$rows = @(Import-Csv -LiteralPath $matrixPath)

if ($rows.Count -ne 189) {
    throw "Expected 189 matrix rows, found $($rows.Count)."
}

$identityFields = @('modulo_id', 'pantalla_ruta', 'accion_control', 'origen_acceso')
$identities = @($rows | ForEach-Object {
    $row = $_
    ($identityFields | ForEach-Object { [string] $row.$_ }) -join '|'
})
if (@($identities | Group-Object | Where-Object Count -gt 1).Count -ne 0) {
    throw 'Matrix action identities must be unique.'
}

function Find-Row([string] $Module, [string] $Action) {
    $matches = @($rows | Where-Object {
        $_.modulo_id -eq $Module -and $_.accion_control -eq $Action
    })
    if ($matches.Count -ne 1) {
        throw "Expected one row for $Module/$Action, found $($matches.Count)."
    }
    return $matches[0]
}

function Assert-Access(
    [string] $Module,
    [string] $Action,
    [string] $Lite,
    [string] $Complete,
    [string] $Pro
) {
    $row = Find-Row $Module $Action
    if ($row.acceso_lite_propuesto -ne $Lite) {
        throw "$Module/$Action Lite expected '$Lite', found '$($row.acceso_lite_propuesto)'."
    }
    if ($row.acceso_completo_propuesto -ne $Complete) {
        throw "$Module/$Action Completo expected '$Complete', found '$($row.acceso_completo_propuesto)'."
    }
    if ($row.acceso_pro_propuesto -ne $Pro) {
        throw "$Module/$Action Pro expected '$Pro', found '$($row.acceso_pro_propuesto)'."
    }
}

Assert-Access 'inicio' 'Seleccionar vehiculo' 'invitacion cerrable' 'permitido' 'permitido'
Assert-Access 'pico' 'Programar aviso' 'no disponible' 'permitido' 'permitido'
Assert-Access 'pico' 'Cambiar anticipacion' 'no disponible' 'permitido' 'permitido'
Assert-Access 'ajustes' 'Configurar notificaciones' 'no disponible' 'permitido' 'permitido'
Assert-Access 'mantenimiento' 'Recordatorios por fecha' 'no disponible' 'opt-in' 'opt-in'

foreach ($action in @(
    'Configurar Pico',
    'Configurar SOAT',
    'Configurar Tecnomecanica',
    'Configurar Seguro',
    'Configurar Impuestos',
    'Presentacion enriquecida',
    'Alarma',
    'Probar alerta'
)) {
    Assert-Access 'alertas' $action 'no disponible' 'permitido' 'permitido'
}

$changeCampaign = 'Cambiar campa' + [char]0x00F1 + 'a'
foreach ($action in @('Carrusel de aliados', $changeCampaign, 'Conocer demo')) {
    Assert-Access 'inicio' $action 'permitido' 'permitido' 'no disponible (sin publicidad)'
}
Assert-Access 'inicio' 'Quiero ser aliado' 'permitido' 'permitido' 'permitido'
Assert-Access 'seguro_asistencia' 'Banner demo' 'invitacion de registro' 'permitido' 'no disponible (sin publicidad)'
Assert-Access 'compra_venta' 'Cambiar banner' 'invitacion de registro' 'permitido' 'no disponible (sin publicidad)'

foreach ($row in @($rows | Where-Object modulo_id -eq 'admin')) {
    Assert-Access 'admin' $row.accion_control 'solo administrador' 'solo administrador' 'solo administrador'
}
foreach ($row in @($rows | Where-Object modulo_id -eq 'api')) {
    Assert-Access 'api' $row.accion_control 'endpoint publico o autenticado' 'endpoint publico o autenticado' 'endpoint publico o autenticado'
}

$forbiddenLite = @($rows | Where-Object {
    $_.acceso_lite_propuesto -like 'permitido colectivo*' -or
    $_.acceso_lite_propuesto -like 'backend compartido*'
})
if ($forbiddenLite.Count -ne 0) {
    throw 'Lite access still contains contradictory collective/backend wording.'
}

$diffRows = @(Import-Csv -LiteralPath $diffPath)
if (@($diffRows | Where-Object { $_.campo -like 'acceso_*_propuesto' }).Count -eq 0) {
    throw 'The changed-cell diff does not include access corrections.'
}

Write-Output 'PASS: the 189-row mode matrix is coherent and its access changes are recorded.'
