/*
 * cuda_compat.h - Compatibility definitions for CUDA 13.0 and OptiX SDK 6.5.0
 * 
 * This header provides missing functions and deprecated fields that were removed from CUDA 13.0
 * but are still expected by OptiX SDK 6.5.0 and legacy CUDA code
 */

#ifndef CUDA_COMPAT_H
#define CUDA_COMPAT_H

#include <cuda_runtime.h>

#ifdef __CUDACC__

// Define the missing functions that OptiX SDK 6.5.0 expects but CUDA 13.0 doesn't provide
__device__ __host__ static inline int float_as_int(float f)
{
    union { float f; int i; } u;
    u.f = f;
    return u.i;
}

__device__ __host__ static inline float int_as_float(int i) 
{
    union { float f; int i; } u;
    u.i = i;
    return u.f;
}

// Handle deprecated cudaDeviceProp fields that were removed in CUDA 13.0
// Use proper replacement APIs as documented in CUDA 13.0 release notes

// CUDA version detection with fallback
#ifdef CUDA_VERSION
#if CUDA_VERSION >= 13000
// Use CUDA 13.0+ replacement APIs
#define CUDA_COMPAT_ASSUME_13 1
#endif
#else
// CUDA_VERSION not defined, assume CUDA 13.0 for safety
#define CUDA_COMPAT_ASSUME_13 1
#endif

#if defined(CUDA_COMPAT_ASSUME_13) || (defined(CUDA_VERSION) && CUDA_VERSION >= 13000)

// Helper function to get device attribute safely
static inline int getCudaDeviceAttribute(int device, cudaDeviceAttr attr) {
    int value = 0;
    cudaError_t err = cudaDeviceGetAttribute(&value, attr, device);
    return (err == cudaSuccess) ? value : 0;
}

// CUDA 13.0 replacements using proper APIs:
// memoryClockRate -> cudaDeviceGetAttribute(cudaDevAttrMemoryClockRate)
#define GET_MEMORY_CLOCK_RATE(prop, device) getCudaDeviceAttribute(device, cudaDevAttrMemoryClockRate)

// clockRate -> cudaDeviceGetAttribute(cudaDevAttrClockRate) 
#define GET_CLOCK_RATE(prop, device) getCudaDeviceAttribute(device, cudaDevAttrClockRate)

// deviceOverlap -> use asyncEngineCount field instead
#define GET_DEVICE_OVERLAP(prop) ((prop).asyncEngineCount > 0)

// kernelExecTimeoutEnabled -> cudaDeviceGetAttribute(cudaDevAttrKernelExecTimeout)
#define GET_KERNEL_EXEC_TIMEOUT_ENABLED(prop, device) getCudaDeviceAttribute(device, cudaDevAttrKernelExecTimeout)

#else
// For older CUDA versions, access fields directly

// For older CUDA versions, access the fields normally (device parameter ignored)
#define GET_MEMORY_CLOCK_RATE(prop, device) ((prop).memoryClockRate)
#define GET_CLOCK_RATE(prop, device) ((prop).clockRate)
#define GET_DEVICE_OVERLAP(prop) ((prop).deviceOverlap)
#define GET_KERNEL_EXEC_TIMEOUT_ENABLED(prop, device) ((prop).kernelExecTimeoutEnabled)

#endif // CUDA version check

#endif // __CUDACC__

#endif // CUDA_COMPAT_H
