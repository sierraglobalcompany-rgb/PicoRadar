function Remove-PackageScratchDirectory {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][string] $ScratchRoot
    )

    $rootPath = [IO.Path]::GetFullPath($ScratchRoot).TrimEnd('\', '/')
    $targetPath = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    $tempPath = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
    $parentPath = [IO.Path]::GetDirectoryName($rootPath)
    $comparison = if ([IO.Path]::DirectorySeparatorChar -eq '\') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if (-not [string]::Equals($parentPath, $tempPath, $comparison) -or
        [IO.Path]::GetFileName($rootPath) -cnotmatch '^picoradar-hostinger-package-[0-9a-f]{32}$') {
        throw [ArgumentException]::new('Cleanup requires the generated package scratch directory directly inside TEMP.')
    }
    $prefix = $rootPath + [IO.Path]::DirectorySeparatorChar
    if (-not $targetPath.Equals($rootPath, $comparison) -and -not $targetPath.StartsWith($prefix, $comparison)) {
        throw [ArgumentException]::new('Cleanup target is outside its package scratch directory.')
    }

    for ($attempt = 0; $attempt -lt 5; $attempt++) {
        if (-not (Test-Path -LiteralPath $targetPath)) { return }
        $ancestors = @()
        $cursor = $targetPath
        while ($true) {
            $ancestors = @($cursor) + $ancestors
            if ($cursor.Equals($rootPath, $comparison)) { break }
            $cursor = [IO.Path]::GetDirectoryName($cursor)
        }
        foreach ($ancestor in $ancestors) {
            $item = Get-Item -LiteralPath $ancestor -Force
            if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                throw [ArgumentException]::new('Cleanup cannot traverse a file or reparse point inside package scratch.')
            }
        }
        try {
            [IO.Directory]::Delete($targetPath, $true)
            return
        } catch [IO.IOException] {
            if ($attempt -eq 4) { throw }
            Start-Sleep -Milliseconds (250 * ($attempt + 1))
        }
    }
}
