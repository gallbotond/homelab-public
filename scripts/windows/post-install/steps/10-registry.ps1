function Invoke-WindowsSetupRegistry {
    param([switch]$DryRun)

    $manifest = Read-JsonFile (Get-SetupDataFile 'registry-changes.json')
    $changes = @($manifest.changes)

    if (-not $changes) {
        Write-SetupWarn 'No registry changes are configured.'
        return
    }

    foreach ($change in $changes) {
        if ($DryRun) {
            Write-SetupInfo ("Would set {0}::{1} = {2}" -f $change.path, $change.name, $change.value)
            continue
        }

        New-Item -Path $change.path -Force | Out-Null
        New-ItemProperty -Path $change.path -Name $change.name -PropertyType $change.type -Value $change.value -Force | Out-Null
        Write-SetupInfo ("Set {0}::{1}" -f $change.path, $change.name)
    }
}
