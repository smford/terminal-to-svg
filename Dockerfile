# Build stage
FROM golang:1.26-alpine@sha256:738d1cf061836894ff6bb8c33881080ac66de8cf0586615012a0c8f592649cfa AS builder

WORKDIR /src

# Download dependencies first for caching
COPY go.mod go.sum ./
RUN go mod download

# Copy source
COPY . .

# Build statically linked binary
ARG TARGETOS TARGETARCH
RUN CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH:-amd64} \
    go build -ldflags="-s -w" -o /bin/termtosvg ./cmd/termtosvg

# Runtime stage
FROM alpine:3.24@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6

# Install ca-certificates and tzdata
RUN apk add --no-cache ca-certificates tzdata

# Create non-root user and home directory
RUN addgroup -S termtosvg && adduser -S termtosvg -G termtosvg && \
    mkdir -p /home/termtosvg && \
    chown -R termtosvg:termtosvg /home/termtosvg

COPY --from=builder /bin/termtosvg /usr/local/bin/termtosvg

USER termtosvg
WORKDIR /home/termtosvg

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD wget -q -O- http://127.0.0.1:8080/healthz || exit 1

ENTRYPOINT ["/usr/local/bin/termtosvg"]
CMD ["-serve-healthz", ":8080"]
