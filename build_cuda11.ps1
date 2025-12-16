# Build script for Accelerad with CUDA 11.8 and OptiX 6.5
# Usage: .\build_cuda11.ps1

param(
    [switch]$Clean = $false
)

Write-Host "=== Accelerad Build Script (CUDA 11.8 + OptiX 6.5) ===" -ForegroundColor Cyan

# Set CUDA path to 11.8
$env:CUDA_PATH = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v11.8"
$env:CUDA_PATH_V11_8 = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v11.8"
$env:PATH = "$env:CUDA_PATH\bin;$env:PATH"

# Use older MSVC 14.33 toolset compatible with CUDA 11.8
$env:VCToolsInstallDir = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.33.31629\"
$env:VCToolsVersion = "14.33.31629"

Write-Host "Using CUDA 11.8 at: $env:CUDA_PATH" -ForegroundColor Green

# Verify CUDA 11.8 is installed
if (!(Test-Path "$env:CUDA_PATH\bin\nvcc.exe")) {
    Write-Error "CUDA 11.8 not found at $env:CUDA_PATH"
    Write-Host "Please install CUDA 11.8 first"
    exit 1
}

# Clean build directory if requested
if ($Clean) {
    Write-Host "Cleaning build directory..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force "build" -ErrorAction SilentlyContinue
}

# Configure with CMake
Write-Host "Configuring with CMake..." -ForegroundColor Yellow
& cmd /c '"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" && cmake -B build -G "Visual Studio 17 2022" -A x64 -T v143,version=14.33 -DBUILD_HEADLESS=ON -DOptiX_USE=ON -DOptiX_INSTALL_DIR="C:/ProgramData/NVIDIA Corporation/OptiX SDK 6.5.0"'

if ($LASTEXITCODE -ne 0) {
    Write-Error "CMake configuration failed"
    exit 1
}

# Build rtrace and rpict
Write-Host "`nBuilding rtrace and rpict..." -ForegroundColor Yellow
& cmd /c '"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" && cmake --build build --config Release --target rtrace rpict rcalc'

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed"
    exit 1
}

# Copy OptiX DLL
Write-Host "`nCopying OptiX DLL..." -ForegroundColor Yellow
Copy-Item "C:\ProgramData\NVIDIA Corporation\OptiX SDK 6.5.0\bin64\optix.6.5.0.dll" "build\bin\Release\" -Force

Write-Host "`n=== Build Complete ===" -ForegroundColor Green
Write-Host "Executables are in: build\bin\Release\" -ForegroundColor Green
Write-Host "`nTo run regression test:" -ForegroundColor Cyan
Write-Host "  .\test_rtrace_regression.ps1" -ForegroundColor White
