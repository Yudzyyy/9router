# Reset 9Router - Full cleanup and reinitialize
# WARNING: This will delete all data!
# Usage: .\reset.ps1 [options]

param(
    [Parameter(Mandatory=$false)]
    [switch]$Full,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Colors
$colors = @{
    Red = 'Red'
    Yellow = 'Yellow'
    Green = 'Green'
    Cyan = 'Cyan'
}

function Write-Status {
    param([string]$Message, [string]$Color = 'Green')
    Write-Host "$(Get-Date -Format 'HH:mm:ss') [INFO] $Message" -ForegroundColor $Color
}

function Write-Error-Status {
    param([string]$Message)
    Write-Host "$(Get-Date -Format 'HH:mm:ss') [ERROR] $Message" -ForegroundColor Red
}

Write-Status "=== 9Router Reset Script ===" -Color Cyan
Write-Host ""
Write-Host "⚠️  WARNING: This will DELETE all data!" -ForegroundColor Yellow
Write-Host ""

if (-not $Force) {
    Write-Host "This will:" -ForegroundColor Yellow
    Write-Host "  • Stop all Docker containers" -ForegroundColor Yellow
    Write-Host "  • Delete all volumes (PostgreSQL data, Redis data)" -ForegroundColor Yellow
    Write-Host "  • Delete all Docker images" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Data will be PERMANENTLY DELETED. Continue? (type 'yes' to confirm)" -ForegroundColor Yellow
    $confirm = Read-Host
    
    if ($confirm -ne 'yes') {
        Write-Status "Reset cancelled."
        exit 0
    }
}

Write-Status "Starting reset..." -Color Red
Write-Host ""

# Step 1: Stop and remove containers, volumes
Write-Status "Step 1: Removing containers and volumes..."
docker-compose down -v --remove-orphans

if ($LASTEXITCODE -eq 0) {
    Write-Status "✓ Containers and volumes removed"
} else {
    Write-Error-Status "Failed to remove containers"
    exit 1
}

# Step 2: Remove images (if Full)
if ($Full) {
    Write-Status "Step 2: Removing Docker images..."
    
    # Get image names from docker-compose
    $images = @(
        '9router-app',
        'postgres:15-alpine',
        'redis:7-alpine'
    )
    
    foreach ($image in $images) {
        $removeCmd = docker image rm $image 2>&1
        if ($LASTEXITCODE -eq 0 -or $removeCmd -match "Deleted|Untagged") {
            Write-Status "  ✓ Removed image: $image"
        } else {
            Write-Status "  ~ Skipped image: $image (not found or in use)"
        }
    }
}

# Step 3: Clean up Docker
Write-Status "Step 3: Cleaning up Docker..."
$pruneOutput = docker system prune -f 2>&1
Write-Status "✓ Docker cleanup complete"

Write-Host ""
Write-Status "Reset complete!" -Color Green
Write-Host ""
Write-Status "Next steps:" -Color Cyan
Write-Host "  1. Verify volumes/images removed: docker volume ls, docker image ls"
Write-Host "  2. Restart stack: .\deploy.ps1"
Write-Host "  3. Re-configure providers in dashboard"
Write-Host ""
