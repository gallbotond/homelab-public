function Invoke-WindowsSetupJobs {
    param(
        [switch]$NonInteractive,
        [switch]$DryRun
    )

    $manifest = Read-JsonFile (Get-SetupDataFile 'jobs.json')
    $jobs = @($manifest.jobs)

    if (-not $jobs) {
        Write-SetupWarn 'No jobs are configured.'
        return
    }

    $selectionItems = $jobs | ForEach-Object {
        [pscustomobject]@{
            Name = $_.name
            Description = $_.description
            Job = $_
        }
    }

    $selectedJobs = Select-SetupItems -Items $selectionItems -Prompt 'Select custom jobs to deploy' -NonInteractive:$NonInteractive

    foreach ($selectedJob in $selectedJobs) {
        $job = $selectedJob.Job
        $source = Resolve-SetupPath $job.source
        $destination = Resolve-SetupEnvPath $job.destination

        if (-not (Test-Path -LiteralPath $source)) {
            Write-SetupWarn ("Job source not found: {0}" -f $source)
            continue
        }

        Copy-SetupConfigItem -Source $source -Destination $destination -DryRun:$DryRun
        if ($DryRun) {
            Write-SetupInfo ("Would deploy job: {0}" -f $job.name)
        } else {
            Write-SetupInfo ("Job deployed: {0}" -f $job.name)
        }

        if ($job.registrationHint) {
            Write-Host ("  Registration: {0}" -f $job.registrationHint)
        }
    }
}
