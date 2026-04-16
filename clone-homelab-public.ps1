#!/usr/bin/env pwsh
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptUrl = 'https://raw.githubusercontent.com/gallbotond/homelab-public/main/clone-homelab-public.ps1'
$repoUrl = 'https://github.com/gallbotond/homelab-public.git'
$repoName = 'homelab-public'
$targetRoot = Join-Path $HOME 'Git'
$targetDir = Join-Path $targetRoot $repoName

function Write-Log {
    param([string]$Message)
    Write-Host "[clone] $Message"
}

function Get-GitPath {
    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCommand) {
        return $gitCommand.Source
    }

    $candidatePaths = @(
        (Join-Path $env:ProgramFiles 'Git\cmd\git.exe'),
        (Join-Path $env:ProgramFiles 'Git\bin\git.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Git\cmd\git.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Git\bin\git.exe'),
        (Join-Path $env:LocalAppData 'Programs\Git\cmd\git.exe'),
        (Join-Path $env:LocalAppData 'Programs\Git\bin\git.exe')
    ) | Where-Object { $_ -and (Test-Path $_) }

    return $candidatePaths | Select-Object -First 1
}

function Refresh-ProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $pathParts = @($machinePath, $userPath) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    if ($pathParts.Count -gt 0) {
        $env:Path = ($pathParts -join ';')
    }
}

function Invoke-SelfRetry {
    if ($env:HOMELAB_PUBLIC_CLONE_RETRY -eq '1') {
        return $false
    }

    $shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        'pwsh'
    }
    elseif (Get-Command powershell -ErrorAction SilentlyContinue) {
        'powershell'
    }
    else {
        throw 'Could not find pwsh or powershell to relaunch the bootstrap script.'
    }

    Write-Log 'git was installed but is not available in this session. Retrying once in a new PowerShell session...'

    $retryCommand = "& { `
`$env:HOMELAB_PUBLIC_CLONE_RETRY = '1' `
irm '$scriptUrl' | iex `
}"

    & $shell -NoProfile -ExecutionPolicy Bypass -Command $retryCommand

    if ($LASTEXITCODE -ne 0) {
        throw 'The relaunched bootstrap script failed.'
    }

    return $true
}

function Ensure-Git {
    $gitPath = Get-GitPath
    if ($gitPath) {
        return $gitPath
    }

    Write-Log 'git not found. Installing git...'

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'winget is not available. Install git manually and rerun the script.'
    }

    & winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements | Out-Host

    Refresh-ProcessPath
    $gitPath = Get-GitPath

    if (-not $gitPath) {
        if (Invoke-SelfRetry) {
            return $null
        }

        throw 'Git was installed but git.exe is still not available after a retry. Open a new PowerShell session and rerun the script.'
    }

    return $gitPath
}

$gitPath = Ensure-Git
if (-not $gitPath) {
    return
}

New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null

if (Test-Path (Join-Path $targetDir '.git')) {
    Write-Log "Repository already exists. Pulling latest changes into $targetDir"
    & $gitPath -C $targetDir pull --ff-only
}
else {
    Write-Log "Cloning $repoUrl into $targetDir"
    & $gitPath clone $repoUrl $targetDir
}

Write-Log "Repository is ready at $targetDir"
