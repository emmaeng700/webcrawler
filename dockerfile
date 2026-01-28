# syntax=docker/dockerfile:1

########################
# 1. Build stage
########################
FROM golang:1.24-alpine AS builder

# - CGO=0 + -s -w → static, tiny binary
ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

WORKDIR /app

# Copy go.* first to leverage Docker layer caching
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the source
COPY . .

# Unit-test fail-fast (optional but nice)
# RUN go test ./...

# Build the crawler
RUN go build -trimpath -ldflags="-s -w" -o crawler .

# 2. Run stage
FROM gcr.io/distroless/static:nonroot

WORKDIR /home/nonroot
COPY --from=builder /app/crawler .

# By default show help if no args
ENTRYPOINT ["./crawler"]
CMD ["https://blog.boot.dev", "10", "100"]
