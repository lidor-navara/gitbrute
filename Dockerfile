# Multi-stage build: compile the Go binary, then produce a minimal runtime image
FROM golang:1.21-alpine AS builder
WORKDIR /src

# copy go source
COPY . .

# Ensure modules enabled if go.mod exists. Build a static binary.
RUN apk add --no-cache git ca-certificates && \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags='-s -w' -o /gitbrute ./gitbrute.go

FROM alpine:3.18
RUN apk add --no-cache ca-certificates git
COPY --from=builder /gitbrute /usr/local/bin/gitbrute

WORKDIR /workdir
VOLUME ["/workdir"]
ENTRYPOINT ["/usr/local/bin/gitbrute"]
