# Publishing NPD Extension Container Images

This guide explains how to publish the NPD Extension container images to GitHub Container Registry (GHCR).

## Prerequisites

1. **GitHub Personal Access Token (PAT)** with the following scopes:
   - `write:packages` - To push container images
   - `read:packages` - To pull container images
   - `delete:packages` - To delete container images (optional)

2. **GitHub Container Registry Authentication**

## Setting Up Authentication

### Option 1: Using Personal Access Token

1. Create a GitHub Personal Access Token:
   - Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Generate new token with `write:packages` scope
   - Copy the token

2. Login to GHCR:
   ```bash
   echo "YOUR_PAT_TOKEN" | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
   ```

### Option 2: Using GitHub CLI

```bash
gh auth login
echo $GH_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
```

## Publishing Images

### Quick Publish

```bash
# Build and push all images
make docker-build-all
make docker-push-all
```

### Manual Publishing

```bash
# Build images
make docker-build-all

# Push individual images
docker push ghcr.io/dims/npd-ext/node-problem-detector:v0.1.0
docker push ghcr.io/dims/npd-ext/gpu-monitor:v0.1.0
```

### Multi-platform Publishing

```bash
# Build and push for multiple platforms
make docker-push-buildx-all
```

## Troubleshooting

### Permission Denied Error

**Error**: `permission_denied: The token provided does not match expected scopes`

**Solutions**:

1. **Check token scopes**: Ensure your PAT has `write:packages` scope
2. **Re-authenticate**:
   ```bash
   docker logout ghcr.io
   echo "YOUR_NEW_PAT" | docker login ghcr.io -u YOUR_USERNAME --password-stdin
   ```
3. **Verify repository ownership**: Make sure you own the `dims/npd-ext` namespace

### Repository Not Found

**Error**: `repository does not exist or may require 'docker login'`

**Solutions**:

1. **Create repository**: Push any image first to create the repository
2. **Check repository name**: Ensure the repository path matches your GitHub username
3. **Set repository visibility**: Make sure the repository is public or you have access

### Authentication Required

**Error**: `authentication required`

**Solutions**:

1. **Login to GHCR**:
   ```bash
   docker login ghcr.io
   ```
2. **Check stored credentials**:
   ```bash
   docker system info | grep Registry
   ```

## Repository Management

### Making Repository Public

1. Go to GitHub → Your repositories
2. Find the container image under "Packages"
3. Click on the package
4. Go to "Package settings"
5. Change visibility to "Public"

### Setting Repository Description

Add labels to your Dockerfile:

```dockerfile
LABEL org.opencontainers.image.source="https://github.com/dims/npd-ext"
LABEL org.opencontainers.image.description="Node Problem Detector with External Plugin Support"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.vendor="Kubernetes Community"
LABEL org.opencontainers.image.title="NPD External Plugin Extension"
```

### Repository Visibility

**Important**: Make sure your GitHub Container Registry packages are set to **public** visibility so they can be pulled without authentication:

1. Go to GitHub → Your profile → Packages
2. Click on the package (e.g., `npd-ext/node-problem-detector`)
3. Go to "Package settings"
4. Under "Danger Zone" → "Change package visibility" → Select "Public"
5. Repeat for all published packages

## Automated Publishing with GitHub Actions

Create `.github/workflows/publish.yml`:

```yaml
name: Publish Images

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Docker Buildx
      uses: docker/setup-buildx-action@v3

    - name: Login to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Build and push images
      run: |
        make docker-build-all
        make docker-push-all
```

## Verification

### Check Published Images

```bash
# List your published packages
gh api user/packages

# Check image details
docker manifest inspect ghcr.io/dims/npd-ext/node-problem-detector:v0.1.0

# Verify images work in Kubernetes
kubectl run test-npd --image=ghcr.io/dims/npd-ext/node-problem-detector:v0.1.0 --rm -it --restart=Never -- --help
kubectl run test-gpu --image=ghcr.io/dims/npd-ext/gpu-monitor:v0.1.0 --rm -it --restart=Never -- --help
```

### Test Image Pull

```bash
# Pull and test images
docker pull ghcr.io/dims/npd-ext/node-problem-detector:v0.1.0
docker pull ghcr.io/dims/npd-ext/gpu-monitor:v0.1.0

# Test running
docker run --rm ghcr.io/dims/npd-ext/node-problem-detector:v0.1.0 --help
docker run --rm ghcr.io/dims/npd-ext/gpu-monitor:v0.1.0 --help

# Test GPU monitor with NVIDIA runtime (requires nvidia-docker)
docker run --rm --gpus all ghcr.io/dims/npd-ext/gpu-monitor:v0.1.0 --socket=/tmp/test.sock --temp-threshold=85 --memory-threshold=95
```

### End-to-End Deployment Verification

After publishing, verify the images work in a real Kubernetes deployment:

```bash
# Deploy using published images
kubectl apply -f deployment/npd-ext-config.yaml
kubectl apply -f deployment/npd-ext-daemonset.yaml

# Check deployment status
kubectl get pods -n kube-system -l app=npd-ext

# Expected: 2/2 Running status
# Verify logs show successful external monitor connection
kubectl logs -n kube-system -l app=npd-ext -c node-problem-detector | grep "Connected to external monitor"
kubectl logs -n kube-system -l app=npd-ext -c gpu-monitor | grep "GPU Monitor listening"

# Check GPU conditions are added to nodes (on GPU nodes)
kubectl describe node <gpu-node-name> | grep GPU
```

## Custom Registry

To use a different registry or namespace:

```bash
# Build with custom registry
make docker-build-all REGISTRY=your-registry.com/your-namespace

# Push to custom registry
make docker-push-all REGISTRY=your-registry.com/your-namespace
```

## Security Best Practices

1. **Use least-privilege tokens**: Only grant necessary scopes
2. **Rotate tokens regularly**: Update PATs every 6-12 months
3. **Use organization secrets**: For shared repositories, use organization-level secrets
4. **Scan images**: Use `docker scout` or similar tools to scan for vulnerabilities
5. **Sign images**: Consider using `cosign` for image signing

## Image Lifecycle

### Updating Images

```bash
# Update version in Makefile
vim Makefile  # Change VERSION to new version

# Build and push new version
make docker-build-all
make docker-push-all
```

### Cleanup Old Images

```bash
# List all versions
gh api user/packages/container/npd-ext%2Fnode-problem-detector/versions

# Delete specific version (use with caution)
gh api -X DELETE user/packages/container/npd-ext%2Fnode-problem-detector/versions/VERSION_ID
```