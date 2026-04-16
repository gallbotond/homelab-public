function Invoke-WindowsSetupCredentials {
    param(
        [switch]$NonInteractive,
        [switch]$DryRun
    )

    $credentialManifest = Read-JsonFile (Get-SetupDataFile 'creds-map.json')
    $repoManifest = Read-JsonFile (Get-SetupDataFile 'repos.json')

    Write-SetupWarn 'TrueNAS credential fetching is scaffolded only. The manifest is in place, but SMB pull logic is not wired yet.'
    Write-SetupInfo ("NAS source: \\{0}\{1}\{2}" -f $credentialManifest.nas.server, $credentialManifest.nas.share, $credentialManifest.nas.basePath)

    foreach ($artifact in @($credentialManifest.artifacts)) {
        $destination = Resolve-SetupEnvPath $artifact.destination
        Write-Host ("  - {0}: {1} -> {2}" -f $artifact.name, $artifact.source, $destination)
    }

    if ($credentialManifest.manualLinks) {
        Write-SetupInfo 'Manual credential and VPN links:'
        foreach ($link in $credentialManifest.manualLinks) {
            Write-Host ("  - {0}: {1}" -f $link.name, $link.url)
        }
    }

    $repositories = @($repoManifest.repositories)
    if (-not $repositories) {
        Write-SetupWarn 'No repositories are configured.'
        return
    }

    $selectionItems = $repositories | ForEach-Object {
        [pscustomobject]@{
            Name = $_.name
            Description = "{0} ({1})" -f $_.provider, $_.group
            Repository = $_
        }
    }

    $selectedRepositories = Select-SetupItems -Items $selectionItems -Prompt 'Select repositories to clone or update' -NonInteractive:$NonInteractive
    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCommand) {
        Write-SetupWarn 'git is not installed. Skipping repository operations.'
        return
    }

    $cloneRoot = Resolve-SetupEnvPath $repoManifest.defaultRoot
    New-Item -ItemType Directory -Force -Path $cloneRoot | Out-Null

    foreach ($selectedRepository in $selectedRepositories) {
        $repository = $selectedRepository.Repository
        $destination = Join-Path $cloneRoot $repository.name

        if ($DryRun) {
            if (Test-Path -LiteralPath (Join-Path $destination '.git')) {
                Write-SetupInfo ("Would update {0}" -f $repository.name)
            } else {
                Write-SetupInfo ("Would clone {0} into {1}" -f $repository.url, $destination)
            }
            continue
        }

        if (Test-Path -LiteralPath (Join-Path $destination '.git')) {
            Push-Location $destination
            try {
                Invoke-SetupCommand -FilePath $gitCommand.Source -ArgumentList @('pull', '--ff-only')
            } finally {
                Pop-Location
            }
        } else {
            Invoke-SetupCommand -FilePath $gitCommand.Source -ArgumentList @('clone', $repository.url, $destination)
        }
    }

    Write-SetupWarn 'If GitLab repositories require browser login or SSH setup, complete that before rerunning this step.'
}
