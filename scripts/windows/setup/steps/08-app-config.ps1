function Copy-SetupConfigItem {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [switch]$DryRun
    )

    $item = Get-Item -LiteralPath $Source

    if ($item.PSIsContainer) {
        if ($DryRun) {
            Write-SetupInfo ("Would copy directory {0} to {1}" -f $Source, $Destination)
            return
        }

        New-Item -ItemType Directory -Force -Path $Destination | Out-Null
        foreach ($child in Get-ChildItem -LiteralPath $Source -Force) {
            Copy-Item -LiteralPath $child.FullName -Destination $Destination -Recurse -Force
        }
        return
    }

    if ($DryRun) {
        Write-SetupInfo ("Would copy file {0} to {1}" -f $Source, $Destination)
        return
    }

    Ensure-ParentDirectory -Path $Destination
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

function Install-VsCodeExtensions {
    param([switch]$DryRun)

    $extensionConfig = Read-JsonFile (Get-SetupConfigFile 'vscode/extensions.json')
    $codeCommand = Get-Command code -ErrorAction SilentlyContinue
    if (-not $codeCommand) {
        Write-SetupWarn 'VS Code CLI not found on PATH. Skipping extension installation.'
        return
    }

    foreach ($extension in @($extensionConfig.extensions)) {
        if ($DryRun) {
            Write-SetupInfo ("Would install VS Code extension {0}" -f $extension)
            continue
        }

        Invoke-SetupCommand -FilePath $codeCommand.Source -ArgumentList @('--install-extension', $extension)
    }
}

function Invoke-WindowsSetupAppConfig {
    param(
        [switch]$NonInteractive,
        [switch]$DryRun
    )

    $manifest = Read-JsonFile (Get-SetupDataFile 'app-configs.json')
    $linksManifest = Read-JsonFile (Get-SetupDataFile 'app-links.json')
    $apps = @($manifest.apps)

    if (-not $apps) {
        Write-SetupWarn 'No app configs are configured.'
        return
    }

    $selectionItems = $apps | ForEach-Object {
        [pscustomobject]@{
            Name = $_.name
            Description = $_.description
            AppConfig = $_
        }
    }

    $selectedApps = Select-SetupItems -Items $selectionItems -Prompt 'Select app configs to apply' -NonInteractive:$NonInteractive

    foreach ($selectedApp in $selectedApps) {
        $appConfig = $selectedApp.AppConfig
        $source = Resolve-SetupPath $appConfig.source
        $destination = Resolve-SetupEnvPath $appConfig.destination

        if (-not (Test-Path -LiteralPath $source)) {
            Write-SetupWarn ("Config source not found for {0}: {1}" -f $appConfig.name, $source)
            continue
        }

        Copy-SetupConfigItem -Source $source -Destination $destination -DryRun:$DryRun

        if ($appConfig.name -eq 'vscode') {
            Install-VsCodeExtensions -DryRun:$DryRun
        }

        $postInstallScriptProperty = $appConfig.PSObject.Properties['postInstallScript']
        if ($postInstallScriptProperty) {
            $postInstallScript = Resolve-SetupPath $postInstallScriptProperty.Value
            if (Test-Path -LiteralPath $postInstallScript) {
                & $postInstallScript -DryRun:$DryRun
            }
        }
    }

    if ($linksManifest.links) {
        Write-SetupInfo 'Related app links:'
        foreach ($link in $linksManifest.links) {
            Write-Host ("  - {0}: {1}" -f $link.name, $link.url)
        }
    }
}
