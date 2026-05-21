# 9Router Deployment Script for Windows PowerShell
# Deploys 9Router with PostgreSQL and Redis via Docker Compose

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('dev', 'prod')]
    [string]$Environment = 'dev',
    
    [Parameter(Mandatory=$false)]
    [switch]$Rebuild,
    
    [Parameter(Mandatory=$false)]
    [switch]$NoHealthCheck
)

# Colors for output
$colors = @{
    Green = 'Green'
    Yellow = 'Yellow'
    Red = 'Red'
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

function Write-Warning-Status {
    param([string]$Message)
    Write-Host "$(Get-Date -Format 'HH:mm:ss') [WARNING] $Message" -ForegroundColor Yellow
}

# Main deployment logic
Write-Status "=== 9Router Deployment Script ===" -Color Cyan
Write-Status "Environment: $Environment"
Write-Status "Rebuild: $Rebuild"

# Check if Docker is running
Write-Status "Checking Docker daemon..."
try {
    $dockerVersion = docker --version
    Write-Status "✓ Docker found: $dockerVersion"
} catch {
    Write-Error-Status "Docker is not installed or not running. Please install Docker Desktop."
    exit 1
}

# Check if Docker Compose is available
Write-Status "Checking Docker Compose..."
try {
    $composeVersion = docker-compose --version
    Write-Status "✓ Docker Compose found: $composeVersion"
} catch {
    Write-Warning-Status "docker-compose CLI not found. Trying 'docker compose'..."
    try {
        $composeVersion = docker compose version
        Write-Status "✓ Docker Compose (plugin) found: $composeVersion"
    } catch {
        Write-Error-Status "Docker Compose is not available. Please install Docker with Compose support."
        exit 1
    }
}

# Verify environment file exists
$envFile = if ($Environment -eq 'prod') { '.env.prod' } else { '.env.local' }
if (-not (Test-Path $envFile)) {
    Write-Error-Status "Environment file '$envFile' not found."
    Write-Status "Please create $envFile based on .env.example"
    exit 1
}

Write-Status "✓ Using environment: $envFile"

# Check Ollama connectivity (pre-flight check)
Write-Status "Checking Ollama connectivity at 10.15.17.190:11434..."
try {
    $ollamaCheck = curl.exe -s -m 5 "http://10.15.17.190:11434/api/tags"
    if ($LASTEXITCODE -eq 0) {
        Write-Status "✓ Ollama is reachable"
    } else {
        Write-Warning-Status "Ollama at 10.15.17.190:11434 is not responding. Continue anyway? (Y/n)"
        $continue = Read-Host
        if ($continue -eq 'n') { exit 1 }
    }
} catch {
    Write-Warning-Status "Could not check Ollama. Network issue or tool not available. Continuing..."
}

# Rebuild images if requested
if ($Rebuild) {
    Write-Status "Rebuilding Docker images..." -Color Cyan
    docker-compose build --no-cache
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Status "Failed to build Docker images."
        exit 1
    }
    Write-Status "✓ Images rebuilt"
}

# Stop existing containers
Write-Status "Stopping existing containers..." -Color Cyan
docker-compose down
if ($LASTEXITCODE -ne 0) {
    Write-Warning-Status "Failed to stop containers (they may not exist)."
}

# Start new containers
Write-Status "Starting Docker Compose stack..." -Color Cyan
docker-compose up -d

if ($LASTEXITCODE -ne 0) {
    Write-Error-Status "Failed to start Docker Compose stack."
    docker-compose logs
    exit 1
}

Write-Status "✓ Docker Compose stack started"

# Wait for services to be ready
Write-Status "Waiting for services to be healthy..." -Color Cyan
$maxAttempts = 30
$attempt = 0

while ($attempt -lt $maxAttempts) {
    $attempt++
    $psOutput = docker-compose ps --format "json" | ConvertFrom-Json
    
    $allHealthy = $true
    foreach ($service in $psOutput) {
        $status = $service.Status
        if ($status -notmatch 'healthy|running') {
            $allHealthy = $false
            Write-Status "  Waiting for $($service.Service)... ($status)" -Color Yellow
        }
    }
    
    if ($allHealthy) {
        Write-Status "✓ All services are healthy"
        break
    }
    
    Start-Sleep -Seconds 2
}

if ($attempt -ge $maxAttempts) {
    Write-Warning-Status "Services took too long to be ready. Checking logs..."
    docker-compose logs
}

# Verify database initialization
Write-Status "Verifying database..." -Color Cyan
$dbCheck = docker-compose exec -T postgres psql -U 9router -d 9router -c "SELECT COUNT(*) FROM organizations" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Status "✓ Database is initialized and accessible"
} else {
    Write-Warning-Status "Database check failed. Run migrations manually if needed."
}

# Health checks (if not disabled)
if (-not $NoHealthCheck) {
    Write-Status "Running health checks..." -Color Cyan
    
    # Check 9Router API
    Write-Status "  Checking 9Router API..."
    $healthCheck = curl.exe -s -m 5 "http://localhost:20128/health" | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($healthCheck.status -eq 'ok') {
        Write-Status "  ✓ 9Router API is responding"
    } else {
        Write-Warning-Status "  9Router API check failed. It may still be starting up."
    }
    
    # Check dashboard
    Write-Status "  Dashboard will be available at: http://localhost:20128/dashboard"
}

# Display port information
Write-Status "=== Deployment Complete ===" -Color Cyan
Write-Status "Services running:" -Color Cyan
Write-Host ""
Write-Host "  9Router Dashboard:" -ForegroundColor Cyan
Write-Host "    URL: http://localhost:20128/dashboard" -ForegroundColor Green
if ($Environment -eq 'dev') {
    Write-Host "    Password: admin123 (from .env.local)"
} else {
    Write-Host "    Password: Check INITIAL_PASSWORD in .env.prod"
}

Write-Host ""
Write-Host "  9Router API:" -ForegroundColor Cyan
Write-Host "    Endpoint: http://localhost:20128/v1" -ForegroundColor Green
Write-Host "    Type: OpenAI-compatible" -ForegroundColor Green

Write-Host ""
Write-Host "  Database:" -ForegroundColor Cyan
Write-Host "    Host: localhost" -ForegroundColor Green
Write-Host "    Port: 5432" -ForegroundColor Green
Write-Host "    Database: 9router" -ForegroundColor Green
Write-Host "    User: 9router" -ForegroundColor Green

Write-Host ""
Write-Host "  Redis:" -ForegroundColor Cyan
Write-Host "    Host: localhost" -ForegroundColor Green
Write-Host "    Port: 6379" -ForegroundColor Green

Write-Host ""
Write-Status "Next steps:" -Color Cyan
Write-Host "  1. Open browser: http://localhost:20128/dashboard"
Write-Host "  2. Login with default credentials"
Write-Host "  3. Change password immediately"
Write-Host "  4. Configure providers (Kiro, OpenAI, etc.)"
Write-Host "  5. Set up API key for CLI tools"
Write-Host ""
Write-Status "Useful commands:" -Color Cyan
Write-Host "  View logs:     .\scripts\logs.ps1"
Write-Host "  Stop services: .\scripts\stop.ps1"
Write-Host "  Reset all:     .\scripts\reset.ps1 -Full"
Write-Host ""
Write-Status "For help, see docs/README.md or docs/DOCKER.md" -Color Cyan
