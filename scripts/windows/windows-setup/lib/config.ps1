function Resolve-LocalOverridePath {
    param([Parameter(Mandatory)][string]$Path)

    $directory = Split-Path -Path $Path -Parent
    $fileName = [IO.Path]::GetFileNameWithoutExtension($Path)
    $extension = [IO.Path]::GetExtension($Path)
    $localPath = Join-Path $directory ("{0}.local{1}" -f $fileName, $extension)

    if (Test-Path -LiteralPath $localPath) {
        return $localPath
    }

    return $Path
}

function Read-JsonFile {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }

    return $raw | ConvertFrom-Json -Depth 100
}

function Get-SetupDataFile {
    param([Parameter(Mandatory)][string]$FileName)
    $path = Resolve-SetupPath (Join-Path 'data' $FileName)
    return Resolve-LocalOverridePath -Path $path
}

function Get-SetupConfigFile {
    param([Parameter(Mandatory)][string]$RelativePath)
    return Resolve-SetupPath (Join-Path 'configs' $RelativePath)
}

function Get-SetupInstallerFile {
    param([Parameter(Mandatory)][string]$RelativePath)
    return Resolve-SetupPath (Join-Path 'installers' $RelativePath)
}
