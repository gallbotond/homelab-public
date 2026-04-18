function Invoke-WindowsSetupWinUtil {
    param(
        [string]$Profile,
        [switch]$DryRun
    )

    $configPath = Get-SetupConfigFile (Join-Path 'winutil' ("{0}.json" -f $Profile))
    if (-not (Test-Path -LiteralPath $configPath)) {
        throw "WinUtil profile not found: $configPath"
    }

    Write-SetupInfo ("Selected WinUtil profile: {0}" -f $configPath)
    Write-SetupWarn 'WinUtil execution is not wired yet because the config invocation format needs to match the upstream tool version.'

    if ($DryRun) {
        Write-SetupInfo 'Dry run: no WinUtil changes would be applied.'
    }
}
