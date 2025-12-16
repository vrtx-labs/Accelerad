# Ambient Bounce Bug in Accelerad rpict

## Summary
When using `-ab` (ambient bounces) parameter with values greater than 2, `rpict.exe` fails with an OptiX validation error related to missing `seed_buffer` variable in the point cloud closest hit program.

## Bug Details

### Error Message
```
rpict: internal - Variable not found (Details: Function "_rtContextValidate" caught exception: 
Variable "Unresolved reference to variable seed_buffer from 
_Z30closest_hit_normal_point_cloudRK13IntersectData22PerRayData_point_cloud" 
not found in scope)
(D:\Projects\Accelerad\src\rt\optix_util.c:107)
```

### Reproduction Steps
1. Run rpict with `-ab 3` and other advanced parameters:
```powershell
rpict.exe -vf vds-4361.vp -x 1280 -y 720 -vh 90 -vv 58.75 `
  -av 1 1 1 -ab 3 -aa 0.25 -ar 256 -ad 256 -as 256 `
  -dc 1 -dt 0 -ds 0 -dj 0 -ss 8.0 out.oct > output.hdr
```

2. Error occurs during OptiX context validation after geometry build
3. Output file is only 527 bytes (header only, no image data)

### Working Configurations
- `-ab 0`: No ambient calculation (works)
- `-ab 1`: Single bounce (works)  
- `-ab 2`: Two bounces (works)
- `-ab 3` or higher: **FAILS** with OptiX validation error
- `-ab 3 -i` (irradiance mode): **WORKS** ✅ - Bug does NOT affect irradiance mode!

### Test Results
From `test_rpict_regression.ps1`:

**Test 1 (8629 scene, `-ab 2`)**: ✅ PASS
- Generates level 0 and level 1 ambient records
- Output: 97,151 bytes
- Time: ~1.09 seconds

**Test 2 (VDS-4361, default params)**: ✅ PASS  
- No ambient calculation
- Output: 66,925 bytes
- Time: ~1.07 seconds

**Test 3 (VDS-4361, `-ab 3`)**: ❌ FAIL
- OptiX validation error
- Output: 527 bytes (header only)
- Time: ~1.09 seconds (fails immediately after geometry build)

**Test 4 (VDS-4361, `-ab 3 -i` irradiance)**: ✅ PASS
- Irradiance mode with 3 ambient bounces
- Output: 2,150 KB
- Time: ~50 seconds
- **Important**: Bug does NOT affect irradiance mode!

## Root Cause Analysis

### Primary Issue: Missing Variable Declaration
The OptiX CUDA program `closest_hit_normal_point_cloud` references the variable `seed_buffer` but this variable is not declared or bound in the OptiX context when ambient bounce levels exceed 2.

**Affected File**: `src/rt/point_cloud_normal.cu`  
**Function**: `closest_hit_normal_point_cloud`

### When Does This Occur?
The bug manifests when:
1. Ambient calculation is enabled (`-ab > 0`)
2. Ambient bounces parameter is greater than 2 (`-ab > 2`)
3. **Radiance mode is active** (NOT irradiance mode `-i`)
4. OptiX attempts to validate the context before launching kernels
5. The point cloud ray type is registered (happens at level 2+)

**Critical Finding**: The bug does NOT occur in irradiance mode (`-i`), suggesting the issue is specific to the **radiance ray generation entry point**, not the ambient calculation itself.

### Why `-ab 2` Works But `-ab 3` Fails
Looking at the ambient calculation logic in `src/rt/optix_radiance.c:378-386`:

```c
/* Check if irradiance cache is used */
ambient_flags = (ambacc > FTINY && ambounce > 0 && ambdiv > 0) ? AMBIENT_REQUESTED : 0u;
if (ambient_flags && nambvals == 0u) {
    ambient_flags |= AMBIENT_CALCULATION_NEEDED;
    ray_type_count = RAY_TYPE_COUNT;  // Includes point cloud ray type
    entry_point_count = ENTRY_POINT_COUNT;
} else {
    ray_type_count = RAY_TYPE_COUNT - (ambient_flags ? 2 : 3);  // Excludes point cloud
    entry_point_count = 1u;
}
```

The point cloud programs are only registered when `RAY_TYPE_COUNT` includes all ray types. At higher ambient levels (3+), additional OptiX programs/variables must be available.

## Secondary Issue: Off-By-One Error in Ambient Levels

Even when the OptiX bug is fixed, there's a semantic issue with ambient bounce counting.

### Current Behavior
With `-ab 3`, only levels 0, 1, and 2 are generated (3 levels total, not 4).

### Expected Behavior  
With `-ab 3`, levels 0, 1, 2, and 3 should be generated (4 levels total).

### Code Location
`src/rt/ambient.c:315-316`:

```c
if (rdepth >= ambounce)
    goto dumbamb;
```

**Problem**: The comparison `>=` stops computation when `rdepth` equals `ambounce`, but it should allow computation AT that level.

**Fix**: Change to `if (rdepth > ambounce)`

### Historical Context
This was changed in commit `5ad5b2ec4` (Aug 20, 1991) from `>` to `>=`:
```
-  if (rdepth > ambounce)
+  if (rdepth >= ambounce)
```

The commit message: "made ambient value weighting and levels more incremental"

This change causes `-ab N` to produce only N bounces (levels 0 through N-1) instead of N+1 levels (0 through N).

## Impact

### User Impact
- Users cannot render with more than 2 ambient bounces in current rpict
- Renders requiring high-quality indirect illumination fail
- Workaround: Use older `accelerad_rpict.exe` (dated April 2019) or limit to `-ab 2`

### Affected Components
- `rpict.exe` (current build)
- OptiX ambient calculation pipeline
- Point cloud ray tracing for ambient levels 3+

## Files Involved

### Primary (OptiX Bug)
- `src/rt/point_cloud_normal.cu` - Missing seed_buffer reference
- `src/rt/optix_radiance.c` - Context setup and variable binding
- `src/rt/optix_ambient.c` - Ambient cache creation

### Secondary (Off-By-One)
- `src/rt/ambient.c:315` - Bounce limit check

## Proposed Solution

### Fix 1: Declare seed_buffer in Point Cloud Programs
Ensure `seed_buffer` is properly declared and accessible in all OptiX programs that need random number generation, particularly `closest_hit_normal_point_cloud`.

**In `src/rt/point_cloud_normal.cu`**:
Add proper buffer declaration at the top of the file or ensure it's included from the appropriate header.

### Fix 2: Bind seed_buffer for All Entry Points
**In `src/rt/optix_radiance.c`**:
Ensure `seed_buffer` is bound to the context regardless of entry point count:

```c
// Around line 415-420 in createContext()
createBuffer2D(*context, RT_BUFFER_INPUT, RT_FORMAT_UNSIGNED_INT, width, height, &seed_buffer);
// ... existing seed initialization ...
applyContextObject(*context, "rnd_seeds", seed_buffer);
```

Verify this buffer is accessible to point cloud ray types.

### Fix 3: Correct Off-By-One Error
**In `src/rt/ambient.c:315`**:
```c
// Change from:
if (rdepth >= ambounce)
    goto dumbamb;

// To:
if (rdepth > ambounce)
    goto dumbamb;
```

## Testing

### Regression Test
Modified `test_rpict_regression.ps1` to include Test 3 for both executables:

```powershell
# Test 3: VDS-4361 with advanced parameters  
# Now runs for BOTH rpict and accelerad_rpict
-ab 3 -aa 0.25 -ar 256 -ad 256 -as 256 -dc 1 -dt 0 -ds 0 -dj 0 -ss 8.0
```

### Expected After Fix
1. Test 3 should pass for both executables
2. With `-ab 3`, ambient levels 0, 1, 2, and 3 should be generated
3. Output file should be similar size to Test 2 (~66KB for VDS-4361 scene)

## Version Information
- **Broken**: `rpict.exe` built Dec 16, 2025
- **Working**: `accelerad_rpict.exe` built Apr 15, 2019 (works up to `-ab 2`)
- **OptiX**: 6.8.7
- **CUDA**: 12.6.0  
- **GPU**: NVIDIA GeForce RTX 4090
- **Build**: Windows, Release configuration

## References
- Original issue discovered in: `test_rpict_regression.ps1:135`
- Test command that triggers bug: Test 3 in regression suite
- OptiX error handler: `src/rt/optix_util.c:107`
- Ambient calculation: `src/rt/ambient.c`, `src/rt/optix_ambient.c`
- OptiX setup: `src/rt/optix_radiance.c`

## Status
- **Discovered**: Dec 16, 2025
- **Documented**: Dec 16, 2025  
- **Status**: OPEN
- **Priority**: HIGH (blocks renders with `-ab > 2`)
