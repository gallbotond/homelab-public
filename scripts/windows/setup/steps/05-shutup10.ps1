function Invoke-WindowsSetupShutUp10 {
    param(
        [string]$Profile,
        [switch]$DryRun
    )

    $configPath = Get-SetupConfigFile (Join-Path 'shutup10' ("{0}.cfg" -f $Profile))
    if (-not (Test-Path -LiteralPath $configPath)) {
        throw "ShutUp10 profile not found: $configPath"
    }

    Write-SetupInfo ("Selected ShutUp10 profile: {0}" -f $configPath)
    Write-SetupWarn 'ShutUp10 execution is not wired yet because the automation path depends on the packaged executable you want to keep in repo or fetch at runtime.'

    if ($DryRun) {
        Write-SetupInfo 'Dry run: no ShutUp10 changes would be applied.'
    }
}
