#!/bin/bash
# 🍊 ClemenTime - Manual Push to Docker Hub Script
# Builds and pushes the current working version to Docker Hub immediately

set -e

DOCKER_IMAGE="${DOCKER_IMAGE:-shawnschwartz/clementime}"
# TAG="${TAG:-latest}"
TAG="${gcloud}"

echo "🏗️ Building and pushing current version to Docker Hub..."
echo "Image: $DOCKER_IMAGE:$TAG"

# Build and push multi-platform
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --file Dockerfile.gcloud \
  --tag "$DOCKER_IMAGE:$TAG" \
  --push \
  .

echo "✅ Successfully pushed $DOCKER_IMAGE:$TAG to Docker Hub"
echo "🚀 Ready for deployment from your other repo!"

