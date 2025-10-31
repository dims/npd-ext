# Makefile for NPD External Plugin Module
# Copyright 2024 The Kubernetes Authors All rights reserved.

# Module information
MODULE := k8s.io/npd-ext
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

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

.PHONY: all build clean test lint fmt vet protobuf help deps npd-with-external

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

## Build Docker image
docker-build:
	@echo "Building Docker image..."
	docker build -t $(MODULE):$(VERSION) -f examples/external-plugins/gpu-monitor/Dockerfile .

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