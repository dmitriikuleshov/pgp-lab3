#include "helper_cuda.h"
#include <chrono>
#include <stdio.h>
#include <stdlib.h>

#define MAX_CLASSES 32

__constant__ double3 class_averages[MAX_CLASSES];

void *allocate_memory(size_t size) {
    void *data = malloc(size);

    if (data == NULL) {
        fprintf(stderr, "Failed to allocate memory\n");
        exit(EXIT_FAILURE);
    }

    return data;
}

__global__ void kernel(uchar4 *data, int pixel_count, int class_count) {
    int idx = blockDim.x * blockIdx.x + threadIdx.x;
    int offset = blockDim.x * gridDim.x;

    int pixel_class;

    double R_diff, G_diff, B_diff;
    double distance, min_distance;

    for (int i = idx; i < pixel_count; i += offset) {
        uchar4 p = data[i];

        pixel_class = 0;

        R_diff = p.x - class_averages[0].x;
        G_diff = p.y - class_averages[0].y;
        B_diff = p.z - class_averages[0].z;
        min_distance =
            R_diff * R_diff + G_diff * G_diff + B_diff * B_diff;

        for (int j = 1; j < class_count; j++) {
            R_diff = p.x - class_averages[j].x;
            G_diff = p.y - class_averages[j].y;
            B_diff = p.z - class_averages[j].z;
            distance = R_diff * R_diff + G_diff * G_diff + B_diff * B_diff;

            if (distance < min_distance) {
                min_distance = distance;
                pixel_class = j;
            }
        }

        data[i] = make_uchar4(p.x, p.y, p.z, pixel_class);
    }
}

void cpu_classify(uchar4 *data, uchar4 *result, int pixel_count,
                  double3 *averages, int class_count) {
    for (int i = 0; i < pixel_count; i++) {
        uchar4 pixel = data[i];
        int pixel_class = 0;

        double dr = pixel.x - averages[0].x;
        double dg = pixel.y - averages[0].y;
        double db = pixel.z - averages[0].z;
        double min_distance = dr * dr + dg * dg + db * db;

        for (int j = 1; j < class_count; j++) {
            dr = pixel.x - averages[j].x;
            dg = pixel.y - averages[j].y;
            db = pixel.z - averages[j].z;
            double distance = dr * dr + dg * dg + db * db;

            if (distance < min_distance) {
                min_distance = distance;
                pixel_class = j;
            }
        }

        pixel.w = pixel_class;
        result[i] = pixel;
    }
}

double run_cpu_test(uchar4 *data, uchar4 *result, int pixel_count,
                    double3 *averages, int class_count, int repeats) {
    volatile unsigned int checksum = 0;
    auto start = std::chrono::steady_clock::now();

    for (int repeat = 0; repeat < repeats; repeat++) {
        cpu_classify(data, result, pixel_count, averages, class_count);
        uchar4 pixel = result[repeat % pixel_count];
        checksum += pixel.x + pixel.y + pixel.z + pixel.w;
    }

    auto finish = std::chrono::steady_clock::now();

    return std::chrono::duration<double, std::milli>(finish - start).count() /
           repeats;
}

double run_gpu_test(uchar4 *dev_data, int pixel_count, int class_count,
                    int blocks, int threads, int repeats) {
    cudaEvent_t gpu_start, gpu_finish;
    checkCudaErrors(cudaEventCreate(&gpu_start));
    checkCudaErrors(cudaEventCreate(&gpu_finish));

    kernel<<<blocks, threads>>>(dev_data, pixel_count, class_count);
    checkCudaErrors(cudaGetLastError());
    checkCudaErrors(cudaDeviceSynchronize());

    checkCudaErrors(cudaEventRecord(gpu_start));
    for (int repeat = 0; repeat < repeats; repeat++) {
        kernel<<<blocks, threads>>>(dev_data, pixel_count, class_count);
        checkCudaErrors(cudaGetLastError());
    }
    checkCudaErrors(cudaEventRecord(gpu_finish));
    checkCudaErrors(cudaEventSynchronize(gpu_finish));

    float total_gpu_time_ms;
    checkCudaErrors(
        cudaEventElapsedTime(&total_gpu_time_ms, gpu_start, gpu_finish));

    checkCudaErrors(cudaEventDestroy(gpu_start));
    checkCudaErrors(cudaEventDestroy(gpu_finish));

    return total_gpu_time_ms / repeats;
}

bool check_results(uchar4 *cpu_result, uchar4 *gpu_result, int pixel_count) {
    for (int i = 0; i < pixel_count; i++) {
        if (cpu_result[i].x != gpu_result[i].x ||
            cpu_result[i].y != gpu_result[i].y ||
            cpu_result[i].z != gpu_result[i].z ||
            cpu_result[i].w != gpu_result[i].w) {
            fprintf(stderr,
                    "Result mismatch at pixel %d: CPU=(%d,%d,%d,%d), "
                    "GPU=(%d,%d,%d,%d)\n",
                    i, cpu_result[i].x, cpu_result[i].y, cpu_result[i].z,
                    cpu_result[i].w, gpu_result[i].x, gpu_result[i].y,
                    gpu_result[i].z, gpu_result[i].w);
            return false;
        }
    }

    return true;
}

void run_test(int w, int h, int class_count, int repeats) {
    int pixel_count = w * h;
    size_t image_size = sizeof(uchar4) * pixel_count;

    uchar4 *data = (uchar4 *)allocate_memory(image_size);
    uchar4 *cpu_result = (uchar4 *)allocate_memory(image_size);
    uchar4 *gpu_result = (uchar4 *)allocate_memory(image_size);

    for (int i = 0; i < pixel_count; i++) {
        int value = i % 256;
        data[i] = make_uchar4((37 * value + 17) % 256,
                              (73 * value + 29) % 256,
                              (109 * value + 43) % 256, 255);
    }

    double3 averages[MAX_CLASSES];

    for (int j = 0; j < class_count; j++) {
        averages[j] = make_double3((53 * j + 19) % 256,
                                   (97 * j + 31) % 256,
                                   (139 * j + 47) % 256);
    }

    double cpu_time_ms = run_cpu_test(data, cpu_result, pixel_count, averages,
                                      class_count, repeats);

    checkCudaErrors(cudaMemcpyToSymbol(
        class_averages, averages, sizeof(double3) * class_count));

    uchar4 *dev_data;

    checkCudaErrors(cudaMalloc(&dev_data, image_size));
    checkCudaErrors(
        cudaMemcpy(dev_data, data, image_size, cudaMemcpyHostToDevice));

    int configs[][2] = {
        {1, 32},   {32, 32},   {64, 128},
        {128, 256}, {256, 256}, {1024, 1024},
    };
    int configs_count = sizeof(configs) / sizeof(configs[0]);

    for (int i = 0; i < configs_count; i++) {
        int blocks = configs[i][0];
        int threads = configs[i][1];
        double gpu_time_ms = run_gpu_test(dev_data, pixel_count, class_count,
                                          blocks, threads, repeats);

        checkCudaErrors(cudaMemcpy(gpu_result, dev_data, image_size,
                                   cudaMemcpyDeviceToHost));

        if (!check_results(cpu_result, gpu_result, pixel_count)) {
            exit(EXIT_FAILURE);
        }

        printf("w=%d h=%d classes=%d blocks=%d threads=%d "
               "GPU=%.6f ms CPU=%.6f ms\n",
               w, h, class_count, blocks, threads, gpu_time_ms, cpu_time_ms);
    }

    checkCudaErrors(cudaFree(dev_data));

    free(data);
    free(cpu_result);
    free(gpu_result);
}

int main() {
    run_test(1024, 1024, 5, 50);
    run_test(4096, 4096, 5, 10);
    run_test(8192, 8192, 5, 3);

    return 0;
}
