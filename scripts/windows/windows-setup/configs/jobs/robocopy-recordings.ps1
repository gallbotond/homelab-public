#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [string]$Source = "${env:USERPROFILE}\Videos",
    [string]$Destination = "\\truenas-scale\Recordings"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$arguments = @(
    $Source,
    $Destination,
    '/MIR',
    '/R:2',
    '/W:5',
    '/FFT',
    '/Z',
    '/XA:SH'
)

& robocopy @arguments
$exitCode = $LASTEXITCODE
if ($exitCode -gt 7) {
    throw "Robocopy failed with exit code $exitCode"
}
