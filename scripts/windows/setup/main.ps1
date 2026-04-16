#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [string[]]$Step,
    [switch]$ListSteps,
    [switch]$NonInteractive,
    [switch]$DryRun,
    [string]$WinUtilProfile = 'default',
    [string]$ShutUpProfile = 'default'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:WindowsSetupRoot = $PSScriptRoot

. (Join-Path $PSScriptRoot 'lib/logging.ps1')
. (Join-Path $PSScriptRoot 'lib/paths.ps1')
. (Join-Path $PSScriptRoot 'lib/config.ps1')
. (Join-Path $PSScriptRoot 'lib/prompts.ps1')
. (Join-Path $PSScriptRoot 'lib/process.ps1')

$stepFiles = Get-ChildItem -Path (Join-Path $PSScriptRoot 'steps') -Filter '*.ps1' | Sort-Object Name
foreach ($stepFile in $stepFiles) {
    . $stepFile.FullName
}

function Resolve-StepSelection {
    param(
        [Parameter(Mandatory)]
        [object[]]$AvailableSteps,
        [string[]]$RequestedSteps
    )

    if (-not $RequestedSteps -or $RequestedSteps.Count -eq 0) {
        return $AvailableSteps
    }

    $resolved = foreach ($requestedStep in $RequestedSteps) {
        $match = $AvailableSteps | Where-Object {
            $_.Name -eq $requestedStep -or $_.Name -like "*$requestedStep*"
        } | Select-Object -First 1

        if (-not $match) {
            throw "Unknown step '$requestedStep'. Use -ListSteps to see valid values."
        }

        $match
    }

    return $resolved | Group-Object Name | ForEach-Object { $_.Group[0] }
}

$steps = @(
    [pscustomobject]@{
        Name = 'winget'
        Description = 'Install winget packages and list manual installs'
        Handler = { Invoke-WindowsSetupWinget -NonInteractive:$NonInteractive -DryRun:$DryRun }
    }
    [pscustomobject]@{
        Name = 'creds'
        Description = 'Review NAS credential pulls and clone selected repos'
        Handler = { Invoke-WindowsSetupCredentials -NonInteractive:$NonInteractive -DryRun:$DryRun }
    }
    [pscustomobject]@{
        Name = 'nas-mounts'
        Description = 'Connect configured NAS shares'
        Handler = { Invoke-WindowsSetupNasMounts -DryRun:$DryRun }
    }
    [pscustomobject]@{
        Name = 'winutil'
        Description = 'Run Chris Titus WinUtil with a chosen profile'
        Handler = { Invoke-WindowsSetupWinUtil -Profile $WinUtilProfile -DryRun:$DryRun }
    }
    [pscustomobject]@{
        Name = 'shutup10'
        Description = 'Run O&O ShutUp10++ with a chosen profile'
        Handler = { Invoke-WindowsSetupShutUp10 -Profile $ShutUpProfile -DryRun:$DryRun }
    }
    [pscustomobject]@{
        Name = 'wsl'
        Description = 'Enable WSL and related Windows features'
        Handler = { Invoke-WindowsSetupWsl -DryRun:$DryRun }
    }
    [pscustomobject]@{
        Name = 'docker'
        Description = 'Install Docker Desktop'
        Handler = { Invoke-WindowsSetupDocker -DryRun:$DryRun }
    }
    [pscustomobject]@{
        Name = 'app-config'
        Description = 'Copy app configs and run app-specific post steps'
        Handler = { Invoke-WindowsSetupAppConfig -NonInteractive:$NonInteractive -DryRun:$DryRun }
    }
    [pscustomobject]@{
        Name = 'jobs'
        Description = 'Deploy custom scripts and job definitions'
        Handler = { Invoke-WindowsSetupJobs -NonInteractive:$NonInteractive -DryRun:$DryRun }
    }
    [pscustomobject]@{
        Name = 'registry'
        Description = 'Apply custom registry changes from manifest'
        Handler = { Invoke-WindowsSetupRegistry -DryRun:$DryRun }
    }
)

if ($ListSteps) {
    $steps | ForEach-Object {
        Write-Host ("{0,-12} {1}" -f $_.Name, $_.Description)
    }
    return
}

$selectedSteps = if ($Step) {
    Resolve-StepSelection -AvailableSteps $steps -RequestedSteps $Step
} else {
    Select-SetupItems -Items $steps -Prompt 'Select setup steps to run' -NonInteractive:$NonInteractive
}

Write-SetupInfo ("Setup root: {0}" -f $script:WindowsSetupRoot)
if ($DryRun) {
    Write-SetupWarn 'Dry run enabled. Commands will be logged without changing the system.'
}

foreach ($selectedStep in $selectedSteps) {
    Write-SetupStep $selectedStep.Name
    & $selectedStep.Handler
}

Write-SetupInfo 'Windows setup run completed.'
