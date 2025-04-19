# Build the manager binary
FROM quay.io/zncdatadev/go-devel:1.24.1-kubedoop0.0.0-dev AS builder
ARG TARGETOS
ARG TARGETARCH
ARG LDFLAGS

WORKDIR /workspace
# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum
# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download

# Copy the go source
COPY cmd/csi_driver/main.go cmd/csi_driver/main.go
COPY api/ api/
COPY internal/ internal/
COPY pkg/ pkg/

# Build
# the GOARCH has not a default value to allow the binary be built according to the host where the command
# was called. For example, if we call make docker-build in a local env which has the Apple Silicon M1 SO
# the docker BUILDPLATFORM arg will be linux/arm64 when for Apple x86 it will be linux/amd64. Therefore,
# by leaving it empty we can ensure that the container and binary shipped on it will have the same platform.
RUN CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH} go build -a -ldflags "${LDFLAGS}" -o csi-driver cmd/csi_driver/main.go

FROM registry.access.redhat.com/ubi9/ubi-minimal:latest
RUN microdnf -y update \
    && microdnf install -y util-linux \
    && microdnf clean all \
    && rm -rf /var/cache/yum
WORKDIR /
COPY --from=builder /workspace/csi-driver .
USER 65532:65532

ENTRYPOINT ["/csi-driver"]
