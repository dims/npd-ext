# Makefile for NPD External Plugin Module
# Copyright 2024 The Kubernetes Authors All rights reserved.

# Module information
MODULE := k8s.io/npd-ext
VERSION ?= v0.1.0
COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

# Docker settings
REGISTRY ?= ghcr.io/dims/npd-ext
NPD_IMAGE := $(REGISTRY)/node-problem-detector
GPU_MONITOR_IMAGE := $(REGISTRY)/gpu-monitor
DOCKER_PLATFORMS := linux/amd64,linux/arm64

# Note: Our Kubernetes manifests now use nvcr.io/nvidia/cuda:12.0.0-base-ubuntu22.04 directly
# for GPU monitoring, which eliminates the need for apt-install and provides reliable nvidia-smi.
# The GPU_MONITOR_IMAGE is still built for standalone deployments or custom configurations.

# Go build settings
GO := go
GOOS ?= $(shell go env GOOS)
GOARCH ?= $(shell go env GOARCH)
BUILD_FLAGS := -buildvcs=false
LDFLAGS := -ldflags "-w -s"

# Binary names
GPU_MONITOR_BINARY := gpu-monitor
NPD_BINARY := node-problem-detector
BINDIR := bin

# Source directories
EXTERNAL_MONITOR_PKG := ./pkg/externalmonitor
GPU_MONITOR_PKG := ./examples/external-plugins/gpu-monitor
NPD_PKG := ./cmd/nodeproblemdetector
API_DIR := ./api/services/external/v1

.PHONY: all build clean test lint fmt vet protobuf help deps docker-build docker-build-gpu docker-push docker-push-gpu docker-build-all docker-push-all

# Default target
all: build

## Build all binaries
build: deps $(BINDIR)/$(GPU_MONITOR_BINARY)

## Build all binaries including NPD with external monitor support
build-all-binaries: deps $(BINDIR)/$(GPU_MONITOR_BINARY) $(BINDIR)/$(NPD_BINARY)

## Build GPU monitor binary
$(BINDIR)/$(GPU_MONITOR_BINARY): $(wildcard examples/external-plugins/gpu-monitor/*.go) $(wildcard pkg/externalmonitor/*.go) $(wildcard api/services/external/v1/*.go)
	@echo "Building $(GPU_MONITOR_BINARY)..."
	@mkdir -p $(BINDIR)
	$(GO) build $(BUILD_FLAGS) $(LDFLAGS) -o $(BINDIR)/$(GPU_MONITOR_BINARY) $(GPU_MONITOR_PKG)

## Build NPD binary with external monitor support
$(BINDIR)/$(NPD_BINARY): deps $(wildcard cmd/nodeproblemdetector/*.go) $(wildcard cmd/options/*.go) $(wildcard pkg/externalmonitor/*.go)
	@echo "Building $(NPD_BINARY) with external monitor support..."
	@echo "Note: This builds NPD with our external monitor plugin included"
	@mkdir -p $(BINDIR)
	$(GO) build $(BUILD_FLAGS) $(LDFLAGS) -o $(BINDIR)/$(NPD_BINARY) $(NPD_PKG)

## Run tests
test: deps
	@echo "Running tests..."
	$(GO) test -v ./pkg/... ./examples/...

## Run Go vet
vet: deps
	@echo "Running go vet..."
	$(GO) vet ./pkg/... ./examples/...

## Format Go code
fmt:
	@echo "Formatting Go code..."
	$(GO) fmt ./pkg/... ./examples/...

## Run golangci-lint (requires golangci-lint to be installed)
lint:
	@echo "Running golangci-lint..."
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run ./pkg/... ./examples/...; \
	else \
		echo "golangci-lint not found. Install with: go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest"; \
	fi

## Generate protobuf files
protobuf:
	@echo "Generating protobuf files..."
	./scripts/generate-protobuf.sh

## Download and tidy dependencies
deps:
	@echo "Downloading dependencies..."
	$(GO) mod download
	$(GO) mod tidy

## Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BINDIR)
	$(GO) clean -cache

## Install binaries to GOPATH/bin
install: build
	@echo "Installing binaries..."
	$(GO) install $(BUILD_FLAGS) $(LDFLAGS) $(GPU_MONITOR_PKG)

## Build for multiple platforms (GPU monitor only)
build-all: deps
	@echo "Building GPU monitor for multiple platforms..."
	@mkdir -p $(BINDIR)
	GOOS=linux GOARCH=amd64 $(GO) build $(BUILD_FLAGS) $(LDFLAGS) -o $(BINDIR)/$(GPU_MONITOR_BINARY)-linux-amd64 $(GPU_MONITOR_PKG)
	GOOS=linux GOARCH=arm64 $(GO) build $(BUILD_FLAGS) $(LDFLAGS) -o $(BINDIR)/$(GPU_MONITOR_BINARY)-linux-arm64 $(GPU_MONITOR_PKG)
	GOOS=darwin GOARCH=amd64 $(GO) build $(BUILD_FLAGS) $(LDFLAGS) -o $(BINDIR)/$(GPU_MONITOR_BINARY)-darwin-amd64 $(GPU_MONITOR_PKG)
	GOOS=darwin GOARCH=arm64 $(GO) build $(BUILD_FLAGS) $(LDFLAGS) -o $(BINDIR)/$(GPU_MONITOR_BINARY)-darwin-arm64 $(GPU_MONITOR_PKG)

## Build NPD Docker image with external monitor support
docker-build: build-all-binaries
	@echo "Building NPD Docker image with external monitor support..."
	docker build -t $(NPD_IMAGE):$(VERSION) .

## Build GPU monitor Docker image
docker-build-gpu: $(BINDIR)/$(GPU_MONITOR_BINARY)
	@echo "Building GPU monitor Docker image..."
	@echo "Note: Uses nvcr.io/nvidia/cuda:12.0.0-base-ubuntu22.04 base image with pre-installed nvidia-smi"
	docker build -t $(GPU_MONITOR_IMAGE):$(VERSION) -f Dockerfile.gpu-monitor .

## Build all Docker images
docker-build-all: docker-build docker-build-gpu

## Build NPD image for multiple platforms
docker-buildx:
	@echo "Building NPD image for multiple platforms..."
	docker buildx build --platform $(DOCKER_PLATFORMS) -t $(NPD_IMAGE):$(VERSION) .

## Build GPU monitor image for multiple platforms
docker-buildx-gpu:
	@echo "Building GPU monitor image for multiple platforms..."
	docker buildx build --platform $(DOCKER_PLATFORMS) -t $(GPU_MONITOR_IMAGE):$(VERSION) -f Dockerfile.gpu-monitor .

## Build all images for multiple platforms
docker-buildx-all: docker-buildx docker-buildx-gpu

## Push NPD Docker image
docker-push: docker-build
	@echo "Pushing NPD Docker image..."
	docker push $(NPD_IMAGE):$(VERSION)

## Push GPU monitor Docker image
docker-push-gpu: docker-build-gpu
	@echo "Pushing GPU monitor Docker image..."
	docker push $(GPU_MONITOR_IMAGE):$(VERSION)

## Push all Docker images
docker-push-all: docker-push docker-push-gpu

## Push images for multiple platforms
docker-push-buildx: docker-buildx
	@echo "Pushing NPD image for multiple platforms..."
	docker buildx build --platform $(DOCKER_PLATFORMS) --push -t $(NPD_IMAGE):$(VERSION) .

## Push GPU monitor for multiple platforms
docker-push-buildx-gpu: docker-buildx-gpu
	@echo "Pushing GPU monitor image for multiple platforms..."
	docker buildx build --platform $(DOCKER_PLATFORMS) --push -t $(GPU_MONITOR_IMAGE):$(VERSION) -f Dockerfile.gpu-monitor .

## Push all images for multiple platforms
docker-push-buildx-all: docker-push-buildx docker-push-buildx-gpu

## Show module information
info:
	@echo "Module: $(MODULE)"
	@echo "Version: $(VERSION)"
	@echo "Commit: $(COMMIT)"
	@echo "Build Date: $(BUILD_DATE)"
	@echo "Go Version: $(shell $(GO) version)"
	@echo "GOOS: $(GOOS)"
	@echo "GOARCH: $(GOARCH)"

## Verify module integrity
verify: deps
	@echo "Verifying module..."
	$(GO) mod verify

## List all targets
help:
	@echo "Available targets:"
	@echo ""
	@grep -E '^##' $(MAKEFILE_LIST) | sed 's/##//g' | sort