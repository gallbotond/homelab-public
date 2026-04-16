function Get-SetupRoot {
    return $script:WindowsSetupRoot
}

function Resolve-SetupPath {
    param([Parameter(Mandatory)][string]$RelativePath)
    return Join-Path (Get-SetupRoot) $RelativePath
}

function Resolve-SetupEnvPath {
    param([Parameter(Mandatory)][string]$Path)
    return [Environment]::ExpandEnvironmentVariables($Path)
}

function Ensure-ParentDirectory {
    param([Parameter(Mandatory)][string]$Path)

    $parent = Split-Path -Path $Path -Parent
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
}
