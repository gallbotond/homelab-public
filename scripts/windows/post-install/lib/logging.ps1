function Write-SetupInfo {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "[INF] $Message" -ForegroundColor Cyan
}

function Write-SetupWarn {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "[WAR] $Message" -ForegroundColor Yellow
}

function Write-SetupError {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "[ERR] $Message" -ForegroundColor Red
}

function Write-SetupStep {
    param([Parameter(Mandatory)][string]$Name)
    Write-Host "`n==> $Name" -ForegroundColor Green
}
