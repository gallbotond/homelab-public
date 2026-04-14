#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$mainScript = Join-Path $PSScriptRoot 'main.ps1'

if (-not (Test-IsAdministrator)) {
    Write-Host '[WAR] Running without elevation. Admin-only steps will be skipped or fail.' -ForegroundColor Yellow
}

& $mainScript @RemainingArgs
