#include <cuda_runtime.h>
#include <stdio.h>

int main() {
    int runtimeVersion, driverVersion;
    cudaError_t rtResult, drvResult;
    
    printf("Testing CUDA version detection...\n");
    
    rtResult = cudaRuntimeGetVersion(&runtimeVersion);
    printf("cudaRuntimeGetVersion() returned %d, version = %d\n", rtResult, runtimeVersion);
    
    drvResult = cudaDriverGetVersion(&driverVersion);
    printf("cudaDriverGetVersion() returned %d, version = %d\n", drvResult, driverVersion);
    
    if (rtResult == cudaSuccess && runtimeVersion > 0) {
        printf("CUDA Runtime version: %d.%d.%d\n", 
               runtimeVersion / 1000, (runtimeVersion % 100) / 10, runtimeVersion % 10);
    } else {
        printf("CUDA Runtime not available (error %d)\n", rtResult);
    }
    
    if (drvResult == cudaSuccess && driverVersion > 0) {
        printf("CUDA Driver version: %d.%d.%d\n", 
               driverVersion / 1000, (driverVersion % 100) / 10, driverVersion % 10);
    } else {
        printf("CUDA Driver not available (error %d)\n", drvResult);
    }
    
    // Try to get device count
    int deviceCount;
    cudaError_t devResult = cudaGetDeviceCount(&deviceCount);
    printf("cudaGetDeviceCount() returned %d, count = %d\n", devResult, deviceCount);
    
    return 0;
}