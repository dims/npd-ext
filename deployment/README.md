# NPD Extension Deployment Guide

This directory contains Docker and Kubernetes deployment configurations for the NPD Extension module, which provides external plugin support for Node Problem Detector with GPU monitoring capabilities.

## Overview

The NPD Extension module provides two main components:
1. **Node Problem Detector with External Monitor Support** - Enhanced NPD with external plugin architecture
2. **GPU Monitor Plugin** - External plugin for monitoring NVIDIA GPU health

## Container Images

The deployment creates two container images:

- `ghcr.io/dims/npd-ext/node-problem-detector:v0.1.0` - NPD with external monitor support
- `ghcr.io/dims/npd-ext/gpu-monitor:v0.1.0` - Standalone GPU monitor plugin

## Building Container Images

### Prerequisites

- Docker installed and running
- Go 1.25+ installed
- Access to push to your container registry

### Build Commands

```bash
# Build all binaries first
make build-all-binaries

# Build NPD container image
make docker-build

# Build GPU monitor container image
make docker-build-gpu

# Build both images
make docker-build-all

# Build for multiple platforms (requires docker buildx)
make docker-buildx-all

# Push images to registry
make docker-push-all
```

### Custom Registry

To use a different registry, override the REGISTRY variable:

```bash
# Use your own registry
make docker-build REGISTRY=your-registry.com/npd-ext
make docker-push REGISTRY=your-registry.com/npd-ext
```

## Deployment Options

### Option 1: Integrated Deployment (Recommended)

Single DaemonSet with NPD and GPU monitor as sidecar containers:

```bash
kubectl apply -f rbac.yaml
kubectl apply -f npd-ext-config.yaml
kubectl apply -f npd-ext-daemonset.yaml
```

**Features:**
- NPD and GPU monitor run in the same pod
- Shared Unix socket communication via emptyDir volume
- Simplified resource management
- Single RBAC configuration

### Option 2: Separate Deployments

Separate DaemonSets for NPD and GPU monitor:

```bash
kubectl apply -f rbac.yaml
kubectl apply -f npd-ext-config.yaml
kubectl apply -f npd-ext-separate.yaml
```

**Features:**
- Independent scaling and resource allocation
- GPU monitor only on GPU-enabled nodes
- Shared Unix socket via hostPath volume
- More granular control

### Option 3: Kustomize Deployment

Using Kustomize for configuration management:

```bash
kubectl apply -k .
```

## Configuration

### NPD Configuration

The NPD is configured via ConfigMap with two monitoring configurations:

- `kernel-monitor.json` - Basic kernel log monitoring
- `external-gpu-monitor.json` - External GPU plugin configuration

### GPU Monitor Configuration

Key configuration parameters in `external-gpu-monitor.json`:

```json
{
  "plugin": "external",
  "pluginConfig": {
    "socketPath": "/var/run/npd/npd-gpu-monitor.sock",
    "grpcTimeout": "10s",
    "reconnectInterval": "30s",
    "maxReconnectAttempts": 5
  }
}
```

## Node Selection

### GPU Nodes

The deployment includes node selectors for GPU-enabled nodes:

```yaml
nodeSelector:
  kubernetes.io/os: linux
  accelerator: nvidia  # For GPU-specific deployments
```

Adjust the node selector based on your cluster's GPU node labeling:

```bash
# Common GPU node labels
kubectl label nodes <gpu-node> accelerator=nvidia
kubectl label nodes <gpu-node> nvidia.com/gpu.present=true
kubectl label nodes <gpu-node> node.kubernetes.io/instance-type=gpu
```

## Resource Requirements

### NPD Container
- CPU: 10m (limit and request)
- Memory: 80Mi (limit and request)

### GPU Monitor Container
- CPU: 10m request, 50m limit
- Memory: 20Mi request, 50Mi limit
- GPU: 1 nvidia.com/gpu (for GPU access)

## Volume Mounts

### NPD Container
- `/var/log` (hostPath, read-only) - System logs
- `/dev/kmsg` (hostPath, read-only) - Kernel messages
- `/etc/localtime` (hostPath, read-only) - Timezone
- `/config` (ConfigMap, read-only) - Monitor configurations
- `/var/run/npd` (emptyDir/hostPath) - Unix socket communication

### GPU Monitor Container
- `/var/run/npd` (emptyDir/hostPath) - Unix socket communication
- `/usr/bin/nvidia-smi` (hostPath, read-only) - NVIDIA utilities

## Security

### NPD Container
- Runs as root (required for system log access)
- Privileged mode enabled
- hostNetwork and hostPID enabled

### GPU Monitor Container
- Runs as non-root user (npd:npd, UID 1000)
- No privileged access required
- GPU device access via resource limits

## Monitoring and Health Checks

### NPD Health Check
- HTTP endpoint: `http://127.0.0.1:20256/healthz`
- Probe interval: 60 seconds
- Timeout: 3 seconds

### GPU Monitor Health Check
- Built-in gRPC health checking
- Automatic reconnection on failures
- Exponential backoff on connection errors

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n kube-system -l app=npd-ext
kubectl describe pod -n kube-system <pod-name>
```

### Check Logs
```bash
# NPD logs
kubectl logs -n kube-system <pod-name> -c node-problem-detector

# GPU monitor logs
kubectl logs -n kube-system <pod-name> -c gpu-monitor
```

### Check Socket Communication
```bash
# Exec into NPD container
kubectl exec -n kube-system <pod-name> -c node-problem-detector -- ls -la /var/run/npd/

# Check socket file
kubectl exec -n kube-system <pod-name> -c node-problem-detector -- test -S /var/run/npd/npd-gpu-monitor.sock && echo "Socket exists"
```

### Check GPU Access
```bash
# Verify GPU visibility in monitor container
kubectl exec -n kube-system <pod-name> -c gpu-monitor -- nvidia-smi -L
```

### Common Issues

1. **Socket Permission Errors**
   - Ensure emptyDir volume is properly mounted
   - Check that both containers have access to `/var/run/npd`

2. **GPU Not Detected**
   - Verify NVIDIA device plugin is installed
   - Check node labels for GPU identification
   - Ensure `nvidia.com/gpu` resource is available

3. **NPD Not Starting**
   - Check ConfigMap is properly mounted
   - Verify JSON configuration syntax
   - Check hostPath volume permissions

4. **Connection Timeouts**
   - Increase `grpcTimeout` in external monitor config
   - Check `reconnectInterval` and `maxReconnectAttempts`
   - Verify GPU monitor is running and socket exists

## Customization

### Adding More External Monitors

To add additional external monitors:

1. **Update ConfigMap** - Add new monitor configurations
2. **Update DaemonSet** - Add new sidecar containers
3. **Update NPD command** - Add new `--config.external-monitor` flags

### Custom Monitor Configurations

Create custom monitor configurations by modifying the ConfigMap:

```yaml
data:
  my-custom-monitor.json: |
    {
      "plugin": "external",
      "pluginConfig": {
        "socketPath": "/var/run/npd/my-custom-monitor.sock",
        "grpcTimeout": "15s"
      },
      "conditions": [
        {
          "type": "MyCustomCondition",
          "reason": "MyCustomReason",
          "message": "Custom monitoring condition"
        }
      ]
    }
```

## Registry Configuration

### Using Private Registries

Update the image references in the manifests:

```yaml
containers:
- name: node-problem-detector
  image: your-registry.com/npd-ext/node-problem-detector:v1.0.0
- name: gpu-monitor
  image: your-registry.com/npd-ext/gpu-monitor:v1.0.0
```

### Registry Authentication

For private registries, create image pull secrets:

```bash
kubectl create secret docker-registry npd-ext-registry \
  --docker-server=your-registry.com \
  --docker-username=your-username \
  --docker-password=your-password \
  --namespace=kube-system

# Add to DaemonSet spec
spec:
  template:
    spec:
      imagePullSecrets:
      - name: npd-ext-registry
```