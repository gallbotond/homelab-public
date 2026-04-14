#!/usr/bin/env pwsh
[CmdletBinding()]
param([switch]$DryRun)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
if (-not $wingetCommand) {
    Write-Host '[WAR] winget is not available. Docker Desktop install skipped.' -ForegroundColor Yellow
    return
}

if ($DryRun) {
    Write-Host '[INF] Would install Docker Desktop via winget.' -ForegroundColor Cyan
    return
}

& $wingetCommand.Source install --id Docker.DockerDesktop --exact --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -ne 0) {
    throw 'Docker Desktop installation failed.'
}
