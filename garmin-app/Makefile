# Makefile for Pédalons Garmin Connect IQ App

# SDK configuration - auto-detect if not set
# Check macOS location first, then Linux location
CIQ_HOME ?= $(shell ls -d "$(HOME)/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-"*/ 2>/dev/null | sort -r | head -1)
ifeq ($(CIQ_HOME),)
CIQ_HOME := $(shell ls -d $(HOME)/.Garmin/ConnectIQ/Sdks/connectiq-sdk-*/ 2>/dev/null | sort -r | head -1)
endif
# Developer key - check macOS location first, then Linux location
DEVELOPER_KEY ?= $(shell \
	if [ -f "$(HOME)/Library/Application Support/Garmin/ConnectIQ/developer_key" ]; then \
		echo "$(HOME)/Library/Application Support/Garmin/ConnectIQ/developer_key"; \
	elif [ -f "$(HOME)/.Garmin/ConnectIQ/developer_key" ]; then \
		echo "$(HOME)/.Garmin/ConnectIQ/developer_key"; \
	else \
		echo "$(HOME)/.Garmin/ConnectIQ/developer_key"; \
	fi)

# The same SDK as seen from the garmin-sdk-manager container, which mounts ~/.Garmin/ConnectIQ at
# /root/.Garmin/ConnectIQ: its directory name comes from CIQ_HOME, so the Docker targets follow
# whatever SDK is installed instead of naming one version (docs/LEDGER_*.md AUD-31, audit G6).
DOCKER_CIQ_HOME = /root/.Garmin/ConnectIQ/Sdks/$(notdir $(patsubst %/,%,$(CIQ_HOME)))

# Build tools
MONKEYC = $(CIQ_HOME)bin/monkeybrains.jar
# connectiq opens ConnectIQ.app on macOS, where there is no bin/simulator
SIMULATOR = $(CIQ_HOME)bin/connectiq
MONKEYDO = $(CIQ_HOME)bin/monkeydo

# Project configuration
PROJECT_NAME = Pedalons
MANIFEST = manifest.xml
JUNGLE = monkey.jungle
SOURCE_DIR = source
RESOURCE_DIR = resources

# Output directory
BIN_DIR = bin

# Supported devices (from manifest.xml, API 3.3.0+)
DEVICES = edge530 edge540 edge550 edge830 edge840 edge850 edge1030 edge1030bontrager edge1030plus edge1040 edge1050 edge1060 edgeexplore2 edgemtb

# Default device for single builds
DEVICE ?= edge1040

# Source files
SOURCES = $(wildcard $(SOURCE_DIR)/*.mc)
RESOURCES = $(wildcard $(RESOURCE_DIR)/**/*.xml)

.PHONY: all build build-all debug test clean simulator run help check-sdk

# Default target
all: build

# Check SDK is configured
check-sdk:
	@if [ -z "$(CIQ_HOME)" ]; then \
		echo "Error: Connect IQ SDK not found."; \
		echo "Set CIQ_HOME or install SDK to ~/.Garmin/ConnectIQ/Sdks/"; \
		exit 1; \
	fi
	@if [ ! -f "$(DEVELOPER_KEY)" ]; then \
		echo "Error: Developer key not found at $(DEVELOPER_KEY)"; \
		echo "Generate one with: make keygen"; \
		exit 1; \
	fi
	@echo "SDK: $(CIQ_HOME)"
	@echo "Key: $(DEVELOPER_KEY)"

# Build for default device
build: check-sdk $(BIN_DIR)
	@echo "Building $(PROJECT_NAME) for $(DEVICE)..."
	java -jar "$(MONKEYC)" \
		-o "$(BIN_DIR)/$(PROJECT_NAME)-$(DEVICE).prg" \
		-f "$(JUNGLE)" \
		-y "$(DEVELOPER_KEY)" \
		-d "$(DEVICE)" \
		-w

# Build for all supported devices
build-all: check-sdk $(BIN_DIR)
	@for device in $(DEVICES); do \
		echo "Building $(PROJECT_NAME) for $$device..."; \
		java -jar "$(MONKEYC)" \
			-o "$(BIN_DIR)/$(PROJECT_NAME)-$$device.prg" \
			-f "$(JUNGLE)" \
			-y "$(DEVELOPER_KEY)" \
			-d "$$device" \
			-w || exit 1; \
	done
	@echo "All builds complete!"

# Build debug version (includes debug symbols)
debug: check-sdk $(BIN_DIR)
	@echo "Building debug version for $(DEVICE)..."
	java -jar "$(MONKEYC)" \
		-o "$(BIN_DIR)/$(PROJECT_NAME)-$(DEVICE)-debug.prg" \
		-f "$(JUNGLE)" \
		-y "$(DEVELOPER_KEY)" \
		-d "$(DEVICE)" \
		-l 3

# Build with the (:test) code and run the unit tests (native simulator started first)
test: check-sdk $(BIN_DIR)
	@echo "Running unit tests on $(DEVICE)..."
	java -jar "$(MONKEYC)" \
		-o "$(BIN_DIR)/$(PROJECT_NAME)-$(DEVICE)-test.prg" \
		-f "$(JUNGLE)" \
		-y "$(DEVELOPER_KEY)" \
		-d "$(DEVICE)" \
		--unit-test \
		-w
	@# monkeydo -t exits 1 even when every test passes: the verdict is its PASSED line
	"$(MONKEYDO)" "$(BIN_DIR)/$(PROJECT_NAME)-$(DEVICE)-test.prg" $(DEVICE) -t | tee "$(BIN_DIR)/test.log"
	@grep -q '^PASSED' "$(BIN_DIR)/test.log"

# Create output directory
$(BIN_DIR):
	mkdir -p $(BIN_DIR)

# Clean build artifacts
clean:
	rm -rf $(BIN_DIR)

# Start simulator (native - requires webkit2gtk-4.0)
simulator: check-sdk
	@echo "Starting simulator..."
	"$(SIMULATOR)" &

# Start simulator via Docker (for Ubuntu 24.04+)
simulator-docker:
	@echo "Starting simulator via Docker..."
	@xhost +local:docker 2>/dev/null || true
	docker run --rm -d \
		--ipc=host \
		--net=host \
		-e DISPLAY=$(DISPLAY) \
		-e NO_AT_BRIDGE=1 \
		-v /tmp/.X11-unix:/tmp/.X11-unix \
		-v $(HOME)/.Garmin/ConnectIQ:/root/.Garmin/ConnectIQ \
		--security-opt label=disable \
		garmin-sdk-manager \
		$(DOCKER_CIQ_HOME)/bin/simulator
	@sleep 2
	@echo "Simulator started"

# Run app in simulator (native - requires simulator to be running)
run: build
	@echo "Loading $(PROJECT_NAME) into simulator..."
	"$(MONKEYDO)" "$(BIN_DIR)/$(PROJECT_NAME)-$(DEVICE).prg" $(DEVICE)

# Run app in simulator via Docker (for Ubuntu 24.04+)
run-docker: build
	@echo "Loading $(PROJECT_NAME) into simulator via Docker..."
	docker run --rm \
		--net=host \
		-v $(HOME)/.Garmin/ConnectIQ:/root/.Garmin/ConnectIQ \
		-v $(PWD):/app \
		-w /app \
		garmin-sdk-manager \
		$(DOCKER_CIQ_HOME)/bin/monkeydo $(BIN_DIR)/$(PROJECT_NAME)-$(DEVICE).prg $(DEVICE)

# Generate developer key using OpenSSL
keygen:
	@if [ -f "$(DEVELOPER_KEY)" ]; then \
		echo "Developer key already exists at $(DEVELOPER_KEY)"; \
		echo "Delete it first if you want to regenerate."; \
		exit 1; \
	fi
	@echo "Generating developer key..."
	openssl genrsa -out "$(DEVELOPER_KEY).pem" 4096
	openssl pkcs8 -topk8 -inform PEM -outform DER \
		-in "$(DEVELOPER_KEY).pem" \
		-out "$(DEVELOPER_KEY)" \
		-nocrypt
	@echo "Developer key generated at $(DEVELOPER_KEY)"

# Package for Connect IQ Store (.iq file)
package: build-all
	@echo "Creating store package..."
	java -jar "$(MONKEYC)" \
		-o "$(BIN_DIR)/$(PROJECT_NAME).iq" \
		-f "$(JUNGLE)" \
		-y "$(DEVELOPER_KEY)" \
		-e \
		-w
	@echo "Package created: $(BIN_DIR)/$(PROJECT_NAME).iq"

# Help
help:
	@echo "Pédalons Garmin Connect IQ App Build System"
	@echo ""
	@echo "Usage: make [target] [DEVICE=device_id]"
	@echo ""
	@echo "Targets:"
	@echo "  build            Build for single device (default: edge1040)"
	@echo "  build-all        Build for all supported devices"
	@echo "  debug            Build debug version with symbols"
	@echo "  test             Run the unit tests (simulator started)"
	@echo "  clean            Remove build artifacts"
	@echo "  simulator        Start simulator (native)"
	@echo "  simulator-docker Start simulator via Docker (Ubuntu 24.04+)"
	@echo "  run              Build and load into simulator (native)"
	@echo "  run-docker       Build and load into simulator via Docker"
	@echo "  keygen           Generate developer key"
	@echo "  package          Create .iq package for store"
	@echo "  help             Show this help"
	@echo ""
	@echo "Supported devices:"
	@echo "  $(DEVICES)"
	@echo ""
	@echo "Examples:"
	@echo "  make build DEVICE=edge530"
	@echo "  make build-all"
	@echo "  make simulator-docker          # Start simulator first"
	@echo "  make run-docker DEVICE=edge1040  # Then load app"
