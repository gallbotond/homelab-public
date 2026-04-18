function Select-SetupItems {
    param(
        [Parameter(Mandatory)]
        [object[]]$Items,
        [Parameter(Mandatory)]
        [string]$Prompt,
        [switch]$NonInteractive
    )

    if (-not $Items -or $Items.Count -eq 0) {
        return @()
    }

    if ($NonInteractive -or -not [Environment]::UserInteractive) {
        return $Items
    }

    for ($index = 0; $index -lt $Items.Count; $index++) {
        $item = $Items[$index]
        Write-Host ("{0,2}) {1} - {2}" -f ($index + 1), $item.Name, $item.Description)
    }

    $selection = Read-Host "$Prompt (comma-separated names or numbers, blank for all)"
    if ([string]::IsNullOrWhiteSpace($selection) -or $selection -eq 'all') {
        return $Items
    }

    $resolvedItems = foreach ($token in ($selection -split ',')) {
        $trimmedToken = $token.Trim()
        if (-not $trimmedToken) {
            continue
        }

        if ($trimmedToken -match '^[0-9]+$') {
            $selectedIndex = [int]$trimmedToken - 1
            if ($selectedIndex -ge 0 -and $selectedIndex -lt $Items.Count) {
                $Items[$selectedIndex]
                continue
            }
        }

        $match = $Items | Where-Object {
            $_.Name -eq $trimmedToken -or $_.Name -like "*$trimmedToken*"
        } | Select-Object -First 1

        if ($match) {
            $match
        } else {
            Write-SetupWarn "Ignoring unknown selection '$trimmedToken'."
        }
    }

    $dedupedItems = $resolvedItems | Group-Object Name | ForEach-Object { $_.Group[0] }
    if (-not $dedupedItems) {
        throw 'No valid selections were provided.'
    }

    return $dedupedItems
}
