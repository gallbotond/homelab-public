function Invoke-WindowsSetupWinget {
    param(
        [switch]$NonInteractive,
        [switch]$DryRun
    )

    $packagesManifest = Read-JsonFile (Get-SetupInstallerFile 'winget/packages.json')
    $manualManifest = Read-JsonFile (Get-SetupInstallerFile 'winget/manual-packages.json')
    $packages = @($packagesManifest.packages)

    if (-not $packages) {
        Write-SetupWarn 'No winget packages are configured.'
        return
    }

    $selectionItems = $packages | ForEach-Object {
        [pscustomobject]@{
            Name = $_.id
            Description = "{0} [{1}]" -f $_.name, $_.category
            Package = $_
        }
    }

    $selectedItems = Select-SetupItems -Items $selectionItems -Prompt 'Select winget packages' -NonInteractive:$NonInteractive
    $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetCommand) {
        Write-SetupWarn 'winget is not available. Skipping package installation.'
    }

    foreach ($selectedItem in $selectedItems) {
        $package = $selectedItem.Package
        $arguments = @(
            'install',
            '--id', $package.id,
            '--exact',
            '--accept-package-agreements',
            '--accept-source-agreements'
        )

        $packageSource = $package.PSObject.Properties['source']
        if ($packageSource) {
            $arguments += @('--source', $packageSource.Value)
        }

        if ($DryRun -or -not $wingetCommand) {
            Write-SetupInfo ("Would install {0} ({1})" -f $package.name, $package.id)
            continue
        }

        Invoke-SetupCommand -FilePath $wingetCommand.Source -ArgumentList $arguments
    }

    $manualPackages = @($manualManifest.packages)
    if ($manualPackages.Count -gt 0) {
        Write-SetupInfo 'Manual installs configured:'
        foreach ($manualPackage in $manualPackages) {
            Write-Host ("  - {0}: {1}" -f $manualPackage.name, $manualPackage.url)
            if ($manualPackage.notes) {
                Write-Host ("    {0}" -f $manualPackage.notes)
            }
        }
    }
}
