# Accelerad Deployment Guide

## Required Files for Running Accelerad

To run Accelerad on another machine or in a different location, you need:

### 1. Executables (from `build\bin\Release\`)
- `rtrace.exe`
- `rpict.exe`
- `rcontrib.exe`
- All other `.exe` files you plan to use
- `optix.6.5.0.dll` (OptiX runtime)

### 2. PTX Files (from `build\lib\`)
All `.ptx` files, including:
- `rtrace.ptx`
- `rpict.ptx`
- `rcontrib.ptx`
- `material_normal.ptx`
- `material_diffuse.ptx`
- `material_glass.ptx`
- `material_light.ptx`
- `fisheye.ptx`
- And all other `.ptx` files

### 3. Library Files (from `build\lib\`)
All `.cal` and other library files

### 4. Environment Setup

Set the `RAYPATH` environment variable to point to your lib directory:
```powershell
$env:RAYPATH = "C:\path\to\your\lib;."
```

Or add it permanently:
```powershell
[Environment]::SetEnvironmentVariable("RAYPATH", "C:\path\to\your\lib;.", "User")
```

## Recommended Directory Structure

```
Accelerad\
├── bin\
│   ├── rtrace.exe
│   ├── rpict.exe
│   ├── rcontrib.exe
│   ├── optix.6.5.0.dll
│   └── ... (other executables)
└── lib\
    ├── rtrace.ptx
    ├── rpict.ptx
    ├── material_normal.ptx
    └── ... (all PTX and CAL files)
```

Then set: `RAYPATH=lib;.`

## Quick Deployment Script

```powershell
# Create deployment directory
$deployDir = "D:\Accelerad-Deploy"
New-Item -ItemType Directory -Path $deployDir\bin -Force
New-Item -ItemType Directory -Path $deployDir\lib -Force

# Copy executables and DLLs
Copy-Item "build\bin\Release\*.exe" "$deployDir\bin\"
Copy-Item "build\bin\Release\*.dll" "$deployDir\bin\"

# Copy PTX and library files
Copy-Item "build\lib\*" "$deployDir\lib\" -Recurse

Write-Host "Deployment ready at: $deployDir"
Write-Host "Set RAYPATH=$deployDir\lib;."
```

## GPU Requirements

The target machine must have:
- NVIDIA GPU with Compute Capability 7.5 or higher
- Recent NVIDIA drivers (compatible with CUDA 11.8)
- No need to install CUDA toolkit or OptiX SDK (runtime is included)
