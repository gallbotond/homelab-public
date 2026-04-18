function Invoke-SetupCommand {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [switch]$IgnoreExitCode
    )

    $commandText = if ($ArgumentList.Count -gt 0) {
        "$FilePath $($ArgumentList -join ' ')"
    } else {
        $FilePath
    }

    Write-SetupInfo "Running: $commandText"
    & $FilePath @ArgumentList
    $exitCode = $LASTEXITCODE

    if (-not $IgnoreExitCode -and $exitCode -ne 0) {
        throw ("Command failed with exit code {0}: {1}" -f $exitCode, $commandText)
    }

    return $exitCode
}
