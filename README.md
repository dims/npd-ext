# NPD External Plugin Module

This is a standalone Go module containing Node Problem Detector with external plugin support. It was created by extracting and vendoring the necessary components from the main NPD repository.

## Overview

This module provides:
- **Complete NPD functionality** with external plugin support
- **Working node-problem-detector binary** with external monitor capabilities
- **GPU monitor example** as an external plugin
- **gRPC-based external plugin architecture** using Unix sockets
- **Comprehensive integration tests** validating the external plugin system

## What's Included

### Core NPD Components
- `pkg/types/` - Core NPD types and interfaces
- `pkg/problemdaemon/` - Problem daemon orchestration
- `pkg/problemdetector/` - Problem detection logic
- `pkg/exporters/` - Built-in exporters (K8s, Prometheus, Stackdriver)
- `pkg/util/` - Utility libraries including tomb pattern
- `cmd/nodeproblemdetector/` - Main NPD binary entry point

### External Plugin System
- `pkg/externalmonitor/` - External monitor proxy implementation
- `api/services/external/v1/` - gRPC protobuf definitions
- `examples/external-plugins/gpu-monitor/` - Complete GPU monitor example
- `test/external_monitor_integration_test.go` - Comprehensive tests

### Built-in Monitors (Optional)
- `pkg/systemlogmonitor/` - System log monitoring
- `pkg/systemstatsmonitor/` - System statistics monitoring
- `pkg/custompluginmonitor/` - Custom plugin support

## Architecture

```
External Plugin (gRPC) → ExternalMonitorProxy (implements Monitor interface)
                              ↓
                    ProblemDetector (orchestrates monitors)
                         ├→ Status aggregation
                         ├→ Error handling & reconnection
                         └→ Export distribution
                              ↓
                    Exporters (K8s, Prometheus, etc.)
```

## Building

### Prerequisites
- Go 1.24.6 or later
- Protocol Buffers compiler (`protoc`)
- `protoc-gen-go` and `protoc-gen-go-grpc` plugins

### Build Commands

```bash
# Build node-problem-detector with external plugin support
go build -buildvcs=false -o node-problem-detector ./cmd/nodeproblemdetector/

# Build GPU monitor example
go build -buildvcs=false -o gpu-monitor ./examples/external-plugins/gpu-monitor/

# Regenerate protobuf files (if needed)
./scripts/generate-protobuf.sh
```

## Testing

```bash
# Run integration tests
go test ./test/external_monitor_integration_test.go -v

# Verify all dependencies
go mod verify

# Run full test suite
go test ./...
```

## Usage

### Basic NPD with External Monitor

```bash
# Start NPD with external monitor config
./node-problem-detector \
  --config.external-monitor=/path/to/external-gpu-monitor.json \
  --logtostderr
```

### GPU Monitor Example

```bash
# Start GPU monitor (separate process)
./gpu-monitor \
  --socket-path=/var/run/npd-gpu-monitor.sock \
  --temp-threshold=85 \
  --memory-threshold=95.0
```

## Configuration

External monitor configuration example (`external-gpu-monitor.json`):

```json
{
    "plugin": "external",
    "pluginConfig": {
        "socketPath": "/var/run/npd-gpu-monitor.sock",
        "grpcTimeout": "10s",
        "reconnectInterval": "30s",
        "maxReconnectAttempts": 5
    },
    "invokeInterval": "30s",
    "bufferSize": 10,
    "source": "gpu-monitor",
    "metricsReporting": true,
    "conditions": [
        {
            "type": "GPUHung",
            "reason": "GPUIsHealthy",
            "message": "GPU is functioning properly"
        }
    ]
}
```

## Key Features

### External Plugin Architecture
- **gRPC communication** over Unix domain sockets
- **Robust error handling** with exponential backoff reconnection
- **Health checking** and automatic recovery
- **Configuration validation** with sane defaults
- **Transparent integration** with existing NPD interfaces

### GPU Monitor Example
- **NVIDIA GPU monitoring** using nvidia-smi
- **Temperature monitoring** with configurable thresholds
- **Memory usage tracking** with pressure detection
- **Health status reporting** to NPD
- **Production-ready** with proper error handling

### Production Features
- **Comprehensive logging** with structured output
- **Metrics integration** with NPD's problem metrics system
- **Resource management** with proper cleanup
- **Signal handling** for graceful shutdown
- **Container ready** with proper Dockerfiles

## Module Structure

```
k8s.io/npd-ext/
├── api/services/external/v1/          # gRPC protobuf definitions
├── cmd/
│   ├── nodeproblemdetector/           # Main NPD binary
│   └── options/                       # Command-line options
├── examples/external-plugins/
│   └── gpu-monitor/                   # GPU monitor example
├── pkg/
│   ├── externalmonitor/               # External plugin proxy
│   ├── types/                         # Core NPD types
│   ├── problemdaemon/                 # Problem orchestration
│   ├── problemdetector/               # Detection logic
│   ├── exporters/                     # Built-in exporters
│   └── util/                          # Utilities
├── scripts/                           # Build scripts
├── test/                              # Integration tests
├── go.mod                             # Module dependencies
└── README.md                          # This file
```

## Dependencies

This module vendors/reuses approximately:
- **~100 source files** from the original NPD codebase
- **250+ external dependencies** via go.mod
- **~69MB binary size** (similar to original NPD)

Key external dependencies:
- `google.golang.org/grpc` - gRPC communication
- `google.golang.org/protobuf` - Protocol buffer support
- `k8s.io/client-go` - Kubernetes API client
- `k8s.io/api` - Kubernetes API types
- `prometheus/*` - Metrics and monitoring
- `github.com/shirou/gopsutil` - System statistics

## Compatibility

- **API Compatible** with original NPD
- **Configuration Compatible** with existing NPD deployments
- **Drop-in Replacement** for NPD binary with external plugin support
- **Kubernetes Compatible** with existing NPD DaemonSets and configurations

## Development

To extend the external plugin system:

1. **Create new external monitor**: Implement the `ExternalMonitor` gRPC service
2. **Add plugin registration**: Update plugin initialization if needed
3. **Add configuration**: Define monitor-specific configuration schema
4. **Write tests**: Add integration tests for the new monitor
5. **Build and deploy**: Use existing build and deployment patterns

## License

This module inherits the Apache 2.0 license from the original Node Problem Detector project.