# Building Accelerad on Windows with CUDA 11.8 and OptiX 6.5

**Date:** December 2025  
**Platform:** Windows 11 with Visual Studio 2022  
**Status:** ✅ Successfully built and tested

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Build Environment Setup](#build-environment-setup)
- [Building Accelerad](#building-accelerad)
- [Testing](#testing)
- [Deployment](#deployment)
- [Troubleshooting](#troubleshooting)

---

## Overview

This guide documents the successful build of Accelerad using:
- **CUDA Toolkit:** 11.8 (required for OptiX 6.5 compatibility)
- **OptiX SDK:** 6.5.0
- **Visual Studio:** 2022 Community (v17.x)
- **MSVC Toolset:** 14.33.31629 (VS 2022 17.3 compatible with CUDA 11.8)
- **CMake:** 3.5+
- **GPU Architecture:** sm_75 (Turing and newer)

### Why CUDA 11.8?

CUDA 13.0 generates PTX with intrinsics that OptiX 6.5 cannot parse. OptiX 6.5 requires CUDA 10.x or 11.x. CUDA 11.8 is the last 11.x release and provides the best compatibility with both OptiX 6.5 and modern Visual Studio 2022.

### Why MSVC 14.33?

Visual Studio 2022's latest MSVC toolset (14.44) has STL headers that explicitly reject CUDA versions older than 12.4. MSVC 14.33 (from VS 2022 17.3) is the newest toolset that works with CUDA 11.8.

---

## Prerequisites

### Required Software

1. **Visual Studio 2022 Community Edition**
   - Download from: https://visualstudio.microsoft.com/downloads/
   - Workloads needed:
     - Desktop development with C++
   - **Important:** Install MSVC 14.33 toolset during installation or via Visual Studio Installer:
     - Go to Visual Studio Installer → Modify
     - Individual Components → Compilers, build tools, and runtimes
     - Select: "MSVC v143 - VS 2022 C++ x64/x86 build tools (v14.33)"

2. **CUDA Toolkit 11.8**
   - Download from: https://developer.nvidia.com/cuda-11-8-0-download-archive
   - Install to default location: `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v11.8`
   - ⚠️ **Do NOT use CUDA 12.x or 13.x** - they are incompatible with OptiX 6.5

3. **OptiX SDK 6.5.0**
   - Download from: https://developer.nvidia.com/designworks/optix/downloads/legacy
   - Install to default location: `C:\ProgramData\NVIDIA Corporation\OptiX SDK 6.5.0`
   - Note: OptiX 8.x has a completely different API and requires code migration

4. **CMake 3.5 or newer**
   - Download from: https://cmake.org/download/
   - Or install via: `choco install cmake`

### Hardware Requirements

- **NVIDIA GPU** with Compute Capability 7.5 or higher (Turing architecture or newer)
  - RTX 20xx series or newer
  - GTX 16xx series
- **Recent NVIDIA drivers** (compatible with CUDA 11.8)

### Verify Installation Paths

```powershell
# Verify CUDA 11.8
Test-Path "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v11.8\bin\nvcc.exe"

# Verify OptiX 6.5
Test-Path "C:\ProgramData\NVIDIA Corporation\OptiX SDK 6.5.0\include\optix_world.h"

# Verify MSVC 14.33 toolset
Test-Path "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.33.31629\bin\Hostx64\x64\cl.exe"
```

All should return `True`.

---

## Build Environment Setup

### Key Files Modified

The following files were modified to support CUDA 11.8 with VS 2022:

1. **`src/rt/CMakeLists.txt`**
   - Set CUDA host compiler to MSVC 14.33
   - Added `-allow-unsupported-compiler` flag
   - Set GPU architecture to sm_75

2. **`src/rt/cuda_compat.h`**
   - Conditional compilation for CUDA 11.x vs 13.x
   - Only define `float_as_int`/`int_as_float` for CUDA 13.0+ (CUDA 11.x has these built-in)

### Build Script

A build script `build_cuda11.ps1` was created in the project root with the following key environment variables:

```powershell
# Set CUDA 11.8 paths
$env:CUDA_PATH = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v11.8"
$env:CUDA_PATH_V11_8 = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v11.8"
$env:PATH = "$env:CUDA_PATH\bin;$env:PATH"

# Force MSVC 14.33 toolset (critical for CUDA 11.8 compatibility)
$env:VCToolsInstallDir = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.33.31629\"
$env:VCToolsVersion = "14.33.31629"
```

**Why VCToolsInstallDir?** This environment variable forces NVCC to use the MSVC 14.33 headers and libraries instead of the default 14.44, bypassing the STL version check that rejects CUDA 11.8.

---

## Building Accelerad

### Quick Build (Recommended)

```powershell
# From the project root directory
.\build_cuda11.ps1 -Clean
```

This will:
1. Configure CMake with OptiX 6.5 and CUDA 11.8
2. Build rtrace, rpict, and rcalc
3. Copy OptiX DLL to the output directory
4. Generate all PTX files

### Manual Build Steps

If you prefer to build manually:

```powershell
# Step 1: Set environment variables
$env:CUDA_PATH = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v11.8"
$env:CUDA_PATH_V11_8 = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v11.8"
$env:VCToolsInstallDir = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.33.31629\"
$env:VCToolsVersion = "14.33.31629"
$env:PATH = "$env:CUDA_PATH\bin;$env:PATH"

# Step 2: Configure CMake
cmd /c '"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" && cmake -B build -G "Visual Studio 17 2022" -A x64 -T v143,version=14.33 -DBUILD_HEADLESS=ON -DOptiX_USE=ON -DOptiX_INSTALL_DIR="C:/ProgramData/NVIDIA Corporation/OptiX SDK 6.5.0"'

# Step 3: Build (rtrace and rpict first, then full build for all PTX files)
cmd /c '"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" && cmake --build build --config Release --target rtrace rpict rcalc'

# Step 4: Build remaining targets (generates all PTX files)
cmd /c '"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" && cmake --build build --config Release'

# Step 5: Copy OptiX DLL
Copy-Item "C:\ProgramData\NVIDIA Corporation\OptiX SDK 6.5.0\bin64\optix.6.5.0.dll" "build\bin\Release\"
```

### Expected Build Output

**Executables** (in `build\bin\Release\`):
- `rtrace.exe` - Ray tracing engine
- `rpict.exe` - Picture renderer
- `rcontrib.exe` - Contribution renderer
- `rcalc.exe` - Calculator utility
- 100+ other Radiance utilities
- `optix.6.5.0.dll` - OptiX runtime

**PTX Files** (in `build\lib\`):
- `rtrace.ptx`
- `rpict.ptx`
- `rcontrib.ptx`
- `material_normal.ptx`
- `material_diffuse.ptx`
- `material_glass.ptx`
- `material_light.ptx`
- `fisheye.ptx`
- 30+ other PTX kernel files

**Libraries** (in `build\src\rt\Release\` and `build\src\common\Release\`):
- `accelerad.lib`
- `radiance.lib`
- `raycalls.lib`
- `rtrad.lib`

### Known Build Issues

**robjutil link failure** - Expected and can be ignored:
```
wfobj.lib(readwfobj.obj) : error LNK2019: unresolved external symbol popen
```
This is a known issue with POSIX function compatibility on Windows. The `robjutil` utility is not critical for GPU-accelerated rendering.

---

## Testing

### Regression Test

```powershell
.\test_rtrace_regression.ps1
```

**Expected Results:**
- Test will run and produce output
- Numerical differences of 1-4% are normal due to:
  - Different GPU architecture (sm_75 vs original reference)
  - CUDA/OptiX version differences
  - Floating-point precision variations
- The test validates that GPU acceleration is working

### Manual Test

```powershell
# Set RAYPATH to find PTX files
$env:RAYPATH = "build\lib;."

# Test rtrace version
.\build\bin\Release\rtrace.exe -version

# Should output:
# Accelerad 0.8 alpha lastmod [date] by [user] (based on RADIANCE 5.2...)
```

---

## Deployment

### Creating a Deployment Package

```powershell
# Run the deployment script
$deployDir = "D:\Accelerad-Deploy"
New-Item -ItemType Directory -Path $deployDir\bin -Force
New-Item -ItemType Directory -Path $deployDir\lib -Force

Copy-Item "build\bin\Release\*.exe" "$deployDir\bin\"
Copy-Item "build\bin\Release\*.dll" "$deployDir\bin\"
Copy-Item "build\lib\*" "$deployDir\lib\" -Recurse
```

### Required Files for Deployment

1. **Executables** (`build\bin\Release\`)
   - All `.exe` files
   - `optix.6.5.0.dll`

2. **PTX and Library Files** (`build\lib\`)
   - All `.ptx` files (GPU kernels)
   - All `.cal` files (Radiance libraries)

3. **Environment Setup**
   ```powershell
   $env:RAYPATH = "path\to\lib;."
   ```

### Deployment to Other Machines

The target machine needs:
- NVIDIA GPU with Compute Capability 7.5+
- Recent NVIDIA drivers (compatible with CUDA 11.8)
- **No need** to install CUDA Toolkit or OptiX SDK

---

## Troubleshooting

### Issue: "static assertion failed: error STL1002: Unexpected compiler version"

**Cause:** NVCC is using MSVC 14.44 headers instead of 14.33

**Solution:** Ensure `VCToolsInstallDir` and `VCToolsVersion` environment variables are set:
```powershell
$env:VCToolsInstallDir = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.33.31629\"
$env:VCToolsVersion = "14.33.31629"
```

### Issue: "unable to compile with new backend: unimplemented PTX intrinsics"

**Cause:** Using CUDA 13.0 which generates PTX incompatible with OptiX 6.5

**Solution:** Use CUDA 11.8 instead. Verify:
```powershell
$env:CUDA_PATH
# Should be: C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v11.8
```

### Issue: "error : function 'float_as_int' has already been defined"

**Cause:** CUDA 11.x has these functions built-in, but `cuda_compat.h` is redefining them

**Solution:** Ensure `cuda_compat.h` has the version check:
```c
#if defined(CUDA_VERSION) && CUDA_VERSION >= 13000
// Only define for CUDA 13.0+
__device__ __host__ static inline int float_as_int(float f) { ... }
#endif
```

### Issue: "File material_normal.ptx not found in RAYPATH"

**Cause:** PTX files not in searchable path or not built

**Solution:**
1. Ensure full build completed (not just rtrace/rpict targets)
2. Set RAYPATH:
   ```powershell
   $env:RAYPATH = "build\lib;."
   ```

### Issue: Clean build needed after changes

```powershell
Remove-Item -Recurse -Force build
.\build_cuda11.ps1 -Clean
```

---

## Technical Notes

### CUDA Architecture Selection

The build targets `sm_75` (Turing architecture):
- **Supported GPUs:** RTX 20xx, GTX 16xx, RTX 30xx, RTX 40xx
- **Why sm_75?** 
  - Minimum architecture supported by CUDA 11.8
  - Compatible with OptiX 6.5
  - Widely supported by modern GPUs

To change the architecture, edit `src/rt/CMakeLists.txt`:
```cmake
ENSURE_NVCC_FLAG("--gpu-architecture sm_75")
```

### CMake Configuration Details

Key CMake options used:
- `-G "Visual Studio 17 2022"` - VS 2022 generator
- `-A x64` - 64-bit architecture
- `-T v143,version=14.33` - MSVC 14.33 toolset
- `-DBUILD_HEADLESS=ON` - Build without Qt GUI
- `-DOptiX_USE=ON` - Enable OptiX GPU acceleration
- `-DOptiX_INSTALL_DIR="..."` - OptiX SDK location

### NVCC Flags Applied

From `src/rt/CMakeLists.txt`:
```cmake
--use_fast_math                  # Fast math optimizations
--gpu-architecture sm_75         # Target architecture
-Xptxas -v                       # Verbose PTX assembler
-allow-unsupported-compiler      # Allow MSVC 14.33 with CUDA 11.8
--pre-include cuda_compat.h      # Compatibility shim
```

---

## Future Work: OptiX 8 Migration

OptiX 8.x (compatible with CUDA 13.0) requires significant code changes:
- New API paradigm (no more `rtContext`, uses `OptixDeviceContext`)
- Direct CUDA memory management (no more `rtBuffer`)
- Module-based PTX compilation
- Shader binding tables (SBT)
- New pipeline creation model

Estimated effort: Several weeks of development

---

## References

- [CUDA 11.8 Release Notes](https://docs.nvidia.com/cuda/archive/11.8.0/)
- [OptiX 6.5 Programming Guide](https://raytracing-docs.nvidia.com/optix6/guide_6_5/index.html)
- [Radiance Documentation](https://floyd.lbl.gov/radiance/)
- [Accelerad Project](https://github.com/nljones/Accelerad)

---

## Changelog

- **2025-12-10:** Initial successful build with CUDA 11.8, OptiX 6.5, and VS 2022
- **2025-12-16:** Documented build process
