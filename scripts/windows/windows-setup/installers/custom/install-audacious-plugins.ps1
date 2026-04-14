#!/usr/bin/env pwsh
[CmdletBinding()]
param([switch]$DryRun)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($DryRun) {
    Write-Host '[INF] Would review Audacious plugin plan from configs/audacious/plugins.json.' -ForegroundColor Cyan
    return
}

Write-Host '[WAR] Audacious plugin automation is not implemented yet. Use the plugin plan manifest to install the required plugins.' -ForegroundColor Yellow
