param(
    [ValidateSet('preflight', 'prepare', 'start', 'status', 'stop')]
    [string] $Mode = 'status',
    [string] $DataRoot = (Join-Path $PSScriptRoot '..\temp\VIAJE_MOTOR_LOCAL_REAL\osrm'),
    [string] $Image = 'ghcr.io/project-osrm/osrm-backend:v5.27.1',
    [string] $PbfUrl = 'https://download.geofabrik.de/south-america/colombia-latest.osm.pbf',
    [int] $Port = 5001,
    [string] $Memory = '4g'
)

$ErrorActionPreference = 'Stop'
$container = 'picoradar-osrm-pilot'
$pbf = Join-Path $DataRoot 'colombia-latest.osm.pbf'
$osrm = Join-Path $DataRoot 'colombia-latest.osrm'
$metadataDir = Join-Path $DataRoot 'metadata'
$metadata = Join-Path $metadataDir 'source.json'

function Write-JsonFile($Path, $Value) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    $Value | ConvertTo-Json -Depth 8 | Set-Content -Path $Path -Encoding UTF8
}

function Test-PortFree($Port) {
    return -not (Test-NetConnection -ComputerName 127.0.0.1 -Port $Port -InformationLevel Quiet)
}

function Get-HeaderValue($Headers, $Name) {
    $line = $Headers | Where-Object { $_ -match "^${Name}:" } | Select-Object -Last 1
    if (-not $line) {
        return ''
    }
    return ($line -replace "^${Name}:\s*", '').Trim()
}

function Show-Preflight {
    $disk = Get-PSDrive -Name ([System.IO.Path]::GetPathRoot((Resolve-Path .).Path).Substring(0, 1))
    $os = Get-CimInstance Win32_OperatingSystem
    docker --version
    docker info --format 'docker_cpus={{.NCPU}} docker_memory_bytes={{.MemTotal}}'
    [pscustomobject]@{
        dataRoot = $DataRoot
        port = $Port
        portFree = Test-PortFree $Port
        freeDiskBytes = $disk.Free
        freePhysicalMemoryKb = $os.FreePhysicalMemory
        container = (docker ps -a --filter "name=$container" --format '{{.Names}} {{.Image}} {{.Status}} {{.Ports}}')
    } | Format-List
}

if ($Mode -eq 'preflight') {
    Show-Preflight
    exit 0
}

if ($Mode -eq 'stop') {
    $existing = docker ps -a --filter "name=$container" --format '{{.Names}}'
    if ($existing -contains $container) {
        docker stop $container | Out-Null
        docker rm $container | Out-Null
    }
    exit 0
}

if ($Mode -eq 'prepare') {
    New-Item -ItemType Directory -Force -Path $DataRoot, $metadataDir | Out-Null
    $head = & curl.exe -L -I $PbfUrl
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not read Geofabrik PBF headers.'
    }
    $effectiveUrl = ($head | Where-Object { $_ -match '^Location:' } | Select-Object -Last 1) -replace '^Location:\s*', ''
    if ([string]::IsNullOrWhiteSpace($effectiveUrl)) {
        $effectiveUrl = $PbfUrl
    }
    if (-not (Test-Path $pbf)) {
        & curl.exe -L $PbfUrl -o $pbf
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not download Geofabrik PBF.'
        }
    }
    $sha = (Get-FileHash -Algorithm SHA256 $pbf).Hash.ToLowerInvariant()
    docker pull $Image
    $imageDigest = docker image inspect $Image --format '{{range .RepoDigests}}{{.}}{{end}}'
    Write-JsonFile $metadata @{
        pbfUrl = $PbfUrl
        effectivePbfUrl = $effectiveUrl.Trim()
        pbfFile = 'colombia-latest.osm.pbf'
        pbfSha256 = $sha
        sourceLastModified = Get-HeaderValue $head 'Last-Modified'
        sourceContentLength = Get-HeaderValue $head 'Content-Length'
        sourceEtag = Get-HeaderValue $head 'ETag'
        osrmImage = $Image
        osrmImageDigest = $imageDigest
        dockerMemoryLimit = $Memory
        preparedAt = (Get-Date).ToString('o')
        attribution = 'OSRM; OpenStreetMap contributors'
    }
    if (-not (Test-Path $osrm)) {
        docker run --rm --cpus 4 --memory $Memory -v "${DataRoot}:/data" $Image osrm-extract -p /opt/car.lua /data/colombia-latest.osm.pbf
    }
    if (-not (Test-Path (Join-Path $DataRoot 'colombia-latest.osrm.partition'))) {
        docker run --rm --cpus 4 --memory $Memory -v "${DataRoot}:/data" $Image osrm-partition /data/colombia-latest.osrm
    }
    if (-not (Test-Path (Join-Path $DataRoot 'colombia-latest.osrm.cell_metrics'))) {
        docker run --rm --cpus 4 --memory $Memory -v "${DataRoot}:/data" $Image osrm-customize /data/colombia-latest.osrm
    }
    Get-Content $metadata
    exit 0
}

if ($Mode -eq 'start') {
    if (-not (Test-Path (Join-Path $DataRoot 'colombia-latest.osrm.cell_metrics'))) {
        throw 'OSRM graph is missing. Run prepare first.'
    }
    if (-not (Test-PortFree $Port)) {
        throw "127.0.0.1:$Port is not free."
    }
    $existing = docker ps -a --filter "name=$container" --format '{{.Names}}'
    if ($existing -contains $container) {
        docker rm -f $container | Out-Null
    }
    docker run -d --name $container --cpus 4 --memory $Memory -p "127.0.0.1:${Port}:5000" -v "${DataRoot}:/data" $Image osrm-routed --algorithm mld /data/colombia-latest.osrm
    exit 0
}

if ($Mode -eq 'status') {
    Show-Preflight
    if (Test-Path $metadata) {
        Get-Content $metadata
    }
    exit 0
}
