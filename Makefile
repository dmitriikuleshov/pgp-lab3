NVCC := /usr/local/cuda/bin/nvcc
NVCC_FLAGS := -Werror cross-execution-space-call -lm -O2

SRC_DIR := src/cuda
BUILD_DIR := build
REPORT_DIR := report

SHREK_IMAGE := $(REPORT_DIR)/shrek/shrek.png
SHREK_INPUT_DATA := data/in/shrek.data
SHREK_OUTPUT_DATA := data/out/shrek.data
SHREK_CLASSES_IMAGE := $(REPORT_DIR)/shrek/shrek_classes.png
SHREK_INPUT := data/in/shrek.txt

TARGETS := \
	$(BUILD_DIR)/lab3 \
	$(BUILD_DIR)/benchmark

.PHONY: all clean report benchmark

all: $(TARGETS) report

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/lab3: $(SRC_DIR)/lab3.cu | $(BUILD_DIR)
	@echo "  NVCC      $@"
	@$(NVCC) $(NVCC_FLAGS) $< -o $@

$(BUILD_DIR)/benchmark: $(SRC_DIR)/benchmark.cu | $(BUILD_DIR)
	@echo "  NVCC      $@"
	@$(NVCC) $(NVCC_FLAGS) $< -o $@

benchmark: $(BUILD_DIR)/benchmark
	@echo "  BENCHMARK $(REPORT_DIR)/benchmark_results.txt"
	@$(BUILD_DIR)/benchmark > $(REPORT_DIR)/benchmark_results.txt

$(SHREK_INPUT_DATA): $(SHREK_IMAGE) src/convert/png2data.py
	@echo "  PNG2DATA  $@"
	@mkdir -p data/in
	@uv run python src/convert/png2data.py "$<" "$@"

$(SHREK_OUTPUT_DATA): $(SHREK_INPUT_DATA) $(SHREK_INPUT) $(BUILD_DIR)/lab3
	@echo "  CLASSIFY  $@"
	@mkdir -p data/out
	@$(BUILD_DIR)/lab3 < $(SHREK_INPUT)

$(SHREK_CLASSES_IMAGE): $(SHREK_OUTPUT_DATA) src/convert/data2classes.py
	@echo "  DATA2PNG  $@"
	@uv run python src/convert/data2classes.py "$<" "$@"

report: $(SHREK_CLASSES_IMAGE) benchmark
	@echo "  TYPST     $(REPORT_DIR)/report.pdf"
	@typst compile --font-path /mnt/c/Windows/Fonts \
		$(REPORT_DIR)/report.typ \
		$(REPORT_DIR)/report.pdf

clean:
	@echo "  CLEAN"
	@rm -rf $(BUILD_DIR)
	@rm -f $(REPORT_DIR)/report.pdf
	@rm -f $(REPORT_DIR)/benchmark_results.txt
	@rm -f $(SHREK_INPUT_DATA)
	@rm -f $(SHREK_OUTPUT_DATA)
	@rm -f $(SHREK_CLASSES_IMAGE)
