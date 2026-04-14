function Invoke-WindowsSetupDocker {
    param([switch]$DryRun)

    $installerPath = Get-SetupInstallerFile 'custom/install-docker-desktop.ps1'
    & $installerPath -DryRun:$DryRun
}
