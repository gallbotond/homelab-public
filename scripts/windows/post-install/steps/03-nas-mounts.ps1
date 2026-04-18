function Invoke-WindowsSetupNasMounts {
    param([switch]$DryRun)

    $manifest = Read-JsonFile (Get-SetupDataFile 'nas-shares.json')
    $shares = @($manifest.shares)

    if (-not $shares) {
        Write-SetupWarn 'No NAS shares are configured.'
        return
    }

    foreach ($share in $shares) {
        $driveName = $share.driveLetter.TrimEnd(':')
        $existingDrive = Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue

        if ($existingDrive) {
            Write-SetupInfo ("Drive {0}: already mapped to {1}" -f $driveName, $existingDrive.Root)
            continue
        }

        if ($DryRun) {
            Write-SetupInfo ("Would map {0}: to {1}" -f $driveName, $share.path)
            continue
        }

        New-PSDrive -Name $driveName -PSProvider FileSystem -Root $share.path -Persist -Scope Global | Out-Null
        Write-SetupInfo ("Mapped {0}: to {1}" -f $driveName, $share.path)
    }
}
