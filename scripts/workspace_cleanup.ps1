param(
    [Parameter(Mandatory)][string[]]$Paths,
    [switch]$Delete
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\')
$ledgerDir = Join-Path $root 'artifacts/current/consolidation'
New-Item -ItemType Directory -Path $ledgerDir -Force | Out-Null
$allowed = @(
    (Join-Path $root 'temp'), (Join-Path $root 'tmp'),
    (Join-Path $root 'mobile/build'), (Join-Path $root 'mobile/.dart_tool'),
    (Join-Path $root 'mobile/android/.gradle')
)
foreach ($inputPath in $Paths) {
    $path = (Resolve-Path -LiteralPath $inputPath).Path.TrimEnd('\')
    $inScope = $false
    foreach ($boundary in $allowed) {
        if ($path -eq $boundary -or $path.StartsWith($boundary + '\', [StringComparison]::OrdinalIgnoreCase)) { $inScope = $true }
    }
    if (!$inScope) { throw "Outside reviewed cleanup roots: $path" }
    $ancestor = $path
    while ($ancestor) {
        if ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Reparse point in parent path: $ancestor"
        }
        $ancestor = Split-Path -Parent $ancestor
    }
    $relative = $path.Substring($root.Length + 1).Replace('\', '/')
    $tracked = @(git -C $root ls-files -- $relative)
    if ($LASTEXITCODE -ne 0 -or $tracked.Count) { throw "Tracked content requires separate Git review: $path" }
    $item = Get-Item -LiteralPath $path -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse point: $path" }
    $queue = [Collections.Generic.Stack[string]]::new()
    [long]$bytes = 0
    $count = 0
    if ($item.PSIsContainer) { $queue.Push($path) }
    else { $bytes = $item.Length; $count = 1 }
    while ($queue.Count) {
        $directory = $queue.Pop()
        $dirItem = Get-Item -LiteralPath $directory -Force
        if ($dirItem.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse point: $directory" }
        foreach ($child in Get-ChildItem -LiteralPath $directory -Force) {
            if ($child.Name -eq '.git') { throw "Nested Git metadata: $($child.FullName)" }
            if ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse point: $($child.FullName)" }
            if ($child.PSIsContainer) { $queue.Push($child.FullName) }
            else {
                if ($child.Name -eq '.git') { throw "Registered worktree must be retired with Git: $($child.FullName)" }
                $bytes += $child.Length
                $count++
            }
        }
    }
    $row = [ordered]@{ time = (Get-Date).ToString('o'); path = $path; bytes = $bytes; files = $count; deleted = $false }
    if ($Delete) {
        Remove-Item -LiteralPath $path -Recurse -Force
        if (Test-Path -LiteralPath $path) { throw "Deletion incomplete: $path" }
        $row.deleted = $true
        ($row | ConvertTo-Json -Compress) | Add-Content -LiteralPath (Join-Path $ledgerDir 'deletions.jsonl')
    }
    [pscustomobject]$row
}
