#!/usr/bin/env bash
set -euo pipefail

# build.sh - builds the docker image for gitbrute
IMAGE_NAME="${IMAGE_NAME:-gitbrute:latest}"
DOCKER="${DOCKER:-docker}"

if ! command -v "$DOCKER" >/dev/null 2>&1; then
  echo "Error: '$DOCKER' not found in PATH." >&2
  exit 2
fi

echo "Building image ${IMAGE_NAME}..."
"$DOCKER" build -t "${IMAGE_NAME}" .

echo "Built ${IMAGE_NAME}"
