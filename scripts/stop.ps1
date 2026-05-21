# Stop 9Router Docker Compose stack
# Usage: .\stop.ps1 [options]

param(
    [Parameter(Mandatory=$false)]
    [switch]$RemoveVolumes,
    
    [Parameter(Mandatory=$false)]
    [switch]$RemoveImages
)

# Colors
$colors = @{
    Green = 'Green'
    Cyan = 'Cyan'
    Yellow = 'Yellow'
}

function Write-Status {
    param([string]$Message, [string]$Color = 'Green')
    Write-Host "$(Get-Date -Format 'HH:mm:ss') [INFO] $Message" -ForegroundColor $Color
}

Write-Status "=== Stopping 9Router Stack ===" -Color Cyan

# Show what will be done
if ($RemoveVolumes) {
    Write-Host "  WARNING: Volumes (databases) will be DELETED!" -ForegroundColor Yellow
}
if ($RemoveImages) {
    Write-Host "  WARNING: Images will be DELETED!" -ForegroundColor Yellow
}

Write-Host ""

# Build docker-compose command
$cmd = @('docker-compose', 'down')

if ($RemoveVolumes) {
    Write-Status "Removing volumes..."
    $cmd += '-v'
}

if ($RemoveImages) {
    Write-Status "Removing images..."
    $cmd += '--rmi', 'all'
}

# Execute
Write-Status "Stopping containers..."
& @cmd

if ($LASTEXITCODE -eq 0) {
    Write-Status "✓ Stack stopped successfully"
} else {
    Write-Status "✗ Failed to stop stack" -Color Red
    exit 1
}

Write-Host ""
Write-Status "Status:" -Color Cyan
docker-compose ps

Write-Host ""
Write-Status "To restart: .\deploy.ps1"
