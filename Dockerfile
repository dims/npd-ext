# Multi-stage Dockerfile for NPD Extension Module
# Copyright 2024 The Kubernetes Authors All rights reserved.

# Stage 1: Builder
FROM golang:1.25.3-bookworm AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y libsystemd-dev && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /gopath/src/k8s.io/npd-ext

# Copy source code
COPY . .

# Download dependencies
RUN go mod download && go mod tidy

# Build binaries for target architecture
ARG TARGETARCH
ENV GOARCH=${TARGETARCH}
ENV CGO_ENABLED=1

# Build both binaries
RUN make build-all-binaries

# Stage 2: Runtime
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        util-linux \
        bash \
        libsystemd-dev \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r npd && useradd -r -g npd npd

# Copy binaries from builder
COPY --from=builder /gopath/src/k8s.io/npd-ext/bin/node-problem-detector /node-problem-detector
COPY --from=builder /gopath/src/k8s.io/npd-ext/bin/gpu-monitor /gpu-monitor

# Copy example configurations
COPY --from=builder /gopath/src/k8s.io/npd-ext/examples/external-plugins/gpu-monitor/config.json /config/external-gpu-monitor.json

# Set permissions
RUN chmod +x /node-problem-detector /gpu-monitor

# Create directories for sockets and logs
RUN mkdir -p /var/run/npd /var/log/npd && chown npd:npd /var/run/npd /var/log/npd

# Expose socket directory as volume
VOLUME ["/var/run/npd"]

# Default entrypoint (can be overridden)
ENTRYPOINT ["/node-problem-detector"]
CMD ["--logtostderr", "--config.external-monitor=/config/external-gpu-monitor.json"]