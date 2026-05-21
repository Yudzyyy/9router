# View Docker Compose logs for 9Router
# Usage: .\logs.ps1 [service] [options]

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('9router', 'postgres', 'redis', 'all')]
    [string]$Service = 'all',
    
    [Parameter(Mandatory=$false)]
    [switch]$Follow,
    
    [Parameter(Mandatory=$false)]
    [int]$Tail = 100,
    
    [Parameter(Mandatory=$false)]
    [switch]$Timestamps
)

# Colors
$colors = @{
    Green = 'Green'
    Cyan = 'Cyan'
}

function Write-Status {
    param([string]$Message, [string]$Color = 'Green')
    Write-Host "$(Get-Date -Format 'HH:mm:ss') [INFO] $Message" -ForegroundColor $Color
}

Write-Status "=== 9Router Docker Logs ===" -Color Cyan
Write-Status "Service: $Service | Follow: $Follow | Tail: $Tail | Timestamps: $Timestamps"
Write-Host ""

# Build docker-compose logs command
$cmd = @('docker-compose', 'logs')

# Add service if specified
if ($Service -ne 'all') {
    $cmd += $Service
}

# Add options
if ($Follow) {
    $cmd += '-f'
}

if ($Timestamps) {
    $cmd += '-t'
}

if ($Tail -gt 0) {
    $cmd += '--tail=' + $Tail
}

Write-Status "Running: $cmd" -Color Cyan
Write-Host ""

# Execute
& @cmd

# Display shortcuts
Write-Host ""
Write-Status "Tips:" -Color Cyan
Write-Host "  Follow logs:        .\logs.ps1 -Follow"
Write-Host "  View postgres logs: .\logs.ps1 postgres"
Write-Host "  Show last 50 lines: .\logs.ps1 -Tail 50"
Write-Host "  Include timestamps: .\logs.ps1 -Timestamps"
Write-Host "  Combine options:    .\logs.ps1 9router -Follow -Timestamps"
