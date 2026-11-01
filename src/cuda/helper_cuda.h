#ifndef COMMON_HELPER_CUDA_H_
#define COMMON_HELPER_CUDA_H_

#pragma once

#include <cuda_runtime.h>
#include <stdio.h>
#include <stdlib.h>

#define checkCudaErrors(call)                                                  \
    do {                                                                       \
        cudaError_t res = call;                                                \
        if (res != cudaSuccess) {                                              \
            fprintf(stderr, "ERROR in %s:%d. Message: %s\n", __FILE__,         \
                    __LINE__, cudaGetErrorString(res));                        \
            exit(EXIT_FAILURE);                                                \
        }                                                                      \
    } while (0)

#endif
