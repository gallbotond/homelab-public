function Invoke-WindowsSetupWsl {
    param([switch]$DryRun)

    $features = @(
        'Microsoft-Windows-Subsystem-Linux',
        'VirtualMachinePlatform'
    )

    foreach ($feature in $features) {
        if ($DryRun) {
            Write-SetupInfo ("Would enable Windows feature: {0}" -f $feature)
            continue
        }

        Invoke-SetupCommand -FilePath 'dism.exe' -ArgumentList @(
            '/online',
            '/enable-feature',
            "/featurename:$feature",
            '/all',
            '/norestart'
        )
    }

    Write-SetupWarn 'A reboot may be required after enabling WSL features.'
}
