#!/usr/bin/env pwsh
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoUrl = 'https://github.com/gallbotond/homelab-public.git'
$repoName = 'homelab-public'
$targetRoot = Join-Path $HOME 'Git'
$targetDir = Join-Path $targetRoot $repoName

function Write-Log {
    param([string]$Message)
    Write-Host "[clone] $Message"
}

function Ensure-Git {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        return
    }

    Write-Log 'git not found. Installing git...'

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'winget is not available. Install git manually and rerun the script.'
    }

    & winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
}

Ensure-Git

New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null

if (Test-Path (Join-Path $targetDir '.git')) {
    Write-Log "Repository already exists. Pulling latest changes into $targetDir"
    & git -C $targetDir pull --ff-only
}
else {
    Write-Log "Cloning $repoUrl into $targetDir"
    & git clone $repoUrl $targetDir
}

Write-Log "Repository is ready at $targetDir"
