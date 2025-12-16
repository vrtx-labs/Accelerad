# Create Scene Prerequisites for Regression Tests
param(
    [string]$BinDir = "build\bin\Release",
    [string]$SceneDir = "regression_test\scene"
)

Write-Host "=== Creating Scene Prerequisites ===" -ForegroundColor Cyan

$ProjectRoot = $PSScriptRoot
$BinPath = Join-Path $ProjectRoot $BinDir
$LibPath = Join-Path $ProjectRoot "build\lib"
$ScenePath = Join-Path $ProjectRoot $SceneDir
$OconvExe = Join-Path $BinPath "oconv.exe"

# Check if oconv exists
if (!(Test-Path $OconvExe)) {
    Write-Error "oconv.exe not found at: $OconvExe"
    Write-Host "Please build the project first or specify the correct BinDir parameter"
    exit 1
}

Write-Host "Found oconv.exe at: $OconvExe" -ForegroundColor Green

# Create scene directory if it doesn't exist
if (!(Test-Path $ScenePath)) {
    Write-Host "Creating scene directory: $ScenePath"
    New-Item -ItemType Directory -Path $ScenePath -Force | Out-Null
}

# Define scene files for VDS-4361 (located in im subdirectory)
$ImPath = Join-Path $ScenePath "im"
$VdsMatFile = Join-Path $ImPath "vds-4361.mat.rad"
$VdsWinMatFile = Join-Path $ImPath "vds-4361.winmat.rad"
$VdsSkyFile = Join-Path $ImPath "vds-4361.sky.rad"
$VdsSceneFile = Join-Path $ImPath "vds-4361.rad"
$OutputOct = Join-Path $ScenePath "out.oct"

# Check if input files exist
$MissingFiles = @()
if (!(Test-Path $VdsMatFile)) { $MissingFiles += "vds-4361.mat.rad" }
if (!(Test-Path $VdsWinMatFile)) { $MissingFiles += "vds-4361.winmat.rad" }
if (!(Test-Path $VdsSkyFile)) { $MissingFiles += "vds-4361.sky.rad" }
if (!(Test-Path $VdsSceneFile)) { $MissingFiles += "vds-4361.rad" }

if ($MissingFiles.Count -gt 0) {
    Write-Error "Missing required scene files in $ScenePath :"
    foreach ($file in $MissingFiles) {
        Write-Host "  - $file" -ForegroundColor Red
    }
    Write-Host "`nPlease ensure all VDS-4361 scene files are present before running this script."
    exit 1
}

Write-Host "All input files found" -ForegroundColor Green

# Set RAYPATH to find calculation files like skybright.cal
$env:RAYPATH = "$LibPath;."
Write-Host "RAYPATH set to: $env:RAYPATH" -ForegroundColor Green

# Generate octree file
Write-Host "`nGenerating octree file: out.oct" -ForegroundColor Yellow
Write-Host "Command: oconv.exe im\vds-4361.mat.rad im\vds-4361.winmat.rad im\vds-4361.sky.rad im\vds-4361.rad > out.oct"

# Change to scene directory to resolve relative paths
Push-Location $ScenePath

try {
    # Run oconv and redirect output to out.oct
    # Use cmd.exe for proper binary redirection
    cmd /c ""$OconvExe" im\vds-4361.mat.rad im\vds-4361.winmat.rad im\vds-4361.sky.rad im\vds-4361.rad > out.oct 2>&1"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "oconv.exe failed with exit code $LASTEXITCODE"
        exit 1
    }
    
    if (!(Test-Path "out.oct")) {
        Write-Error "Output file out.oct was not created"
        exit 1
    }
    
    $OctSize = (Get-Item "out.oct").Length
    Write-Host "SUCCESS: Created out.oct ($OctSize bytes)" -ForegroundColor Green
    Write-Host "Location: $OutputOct"
    
} finally {
    Pop-Location
}

Write-Host "`n=== Scene Prerequisites Created ===" -ForegroundColor Green
