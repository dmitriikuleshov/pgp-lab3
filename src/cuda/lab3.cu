#include "helper_cuda.h"
#include <stdio.h>
#include <stdlib.h>

#define MAX_CLASSES 32

__constant__ double3 class_averages[MAX_CLASSES];

void read_string(char *value) {
    if (scanf("%255s", value) != 1) {
        fprintf(stderr, "Failed to read string\n");
        exit(EXIT_FAILURE);
    }
}

int read_int() {
    int value;

    if (scanf("%d", &value) != 1) {
        fprintf(stderr, "Failed to read integer\n");
        exit(EXIT_FAILURE);
    }

    return value;
}

FILE *open_file(const char *file_name, const char *mode) {
    FILE *fp = fopen(file_name, mode);

    if (fp == NULL) {
        fprintf(stderr, "Failed to open file: %s\n", file_name);
        exit(EXIT_FAILURE);
    }

    return fp;
}

void read_file(void *data, size_t size, size_t count, FILE *fp) {
    if (fread(data, size, count, fp) != count) {
        fprintf(stderr, "Failed to read file\n");
        exit(EXIT_FAILURE);
    }
}

void write_file(const void *data, size_t size, size_t count, FILE *fp) {
    if (fwrite(data, size, count, fp) != count) {
        fprintf(stderr, "Failed to write file\n");
        exit(EXIT_FAILURE);
    }
}

void close_file(FILE *fp) {
    if (fclose(fp) != 0) {
        fprintf(stderr, "Failed to close file\n");
        exit(EXIT_FAILURE);
    }
}

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
        min_distance = R_diff * R_diff + G_diff * G_diff + B_diff * B_diff;

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

int main() {
    char input_file[256];
    char output_file[256];

    read_string(input_file);
    read_string(output_file);

    int w, h;

    FILE *fp = open_file(input_file, "rb");

    read_file(&w, sizeof(int), 1, fp);
    read_file(&h, sizeof(int), 1, fp);

    int pixel_count = w * h;
    uchar4 *data = (uchar4 *)allocate_memory(sizeof(uchar4) * pixel_count);

    read_file(data, sizeof(uchar4), pixel_count, fp);
    close_file(fp);

    int class_count = read_int();

    double3 averages[MAX_CLASSES];

    for (int j = 0; j < class_count; j++) {
        int sample_count = read_int();

        unsigned long long sum_r = 0;
        unsigned long long sum_g = 0;
        unsigned long long sum_b = 0;

        for (int i = 0; i < sample_count; i++) {
            int x = read_int();
            int y = read_int();

            uchar4 pixel = data[y * w + x];
            sum_r += pixel.x;
            sum_g += pixel.y;
            sum_b += pixel.z;
        }

        averages[j] = make_double3((double)sum_r / sample_count,
                                   (double)sum_g / sample_count,
                                   (double)sum_b / sample_count);
    }

    checkCudaErrors(cudaMemcpyToSymbol(class_averages, averages,
                                       sizeof(double3) * class_count));

    uchar4 *dev_data;

    checkCudaErrors(cudaMalloc(&dev_data, sizeof(uchar4) * pixel_count));
    checkCudaErrors(cudaMemcpy(dev_data, data, sizeof(uchar4) * pixel_count,
                               cudaMemcpyHostToDevice));

    kernel<<<256, 256>>>(dev_data, pixel_count, class_count);

    checkCudaErrors(cudaGetLastError());
    checkCudaErrors(cudaMemcpy(data, dev_data, sizeof(uchar4) * pixel_count,
                               cudaMemcpyDeviceToHost));

    checkCudaErrors(cudaFree(dev_data));

    fp = open_file(output_file, "wb");

    write_file(&w, sizeof(int), 1, fp);
    write_file(&h, sizeof(int), 1, fp);
    write_file(data, sizeof(uchar4), pixel_count, fp);

    close_file(fp);

    free(data);

    return 0;
}
