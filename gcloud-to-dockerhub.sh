#!/bin/bash
# 🍊 ClemenTime - Manual Push to Docker Hub Script
# Builds and pushes the current working version to Docker Hub immediately

set -e

DOCKER_IMAGE="${DOCKER_IMAGE:-shawnschwartz/clementime}"
TAG="${TAG:-gcloud-latest}"
LATEST_TAG="${LATEST_TAG:-latest.gcloud}"

echo "🏗️ Building and pushing current version to Docker Hub..."
echo "Image: $DOCKER_IMAGE:$TAG"

# Build tags array
TAGS="--tag $DOCKER_IMAGE:$TAG"

# Add latest.gcloud tag if we're using a versioned tag
if [[ "$TAG" != "gcloud-latest" ]]; then
  echo "📝 Also tagging as: $DOCKER_IMAGE:$LATEST_TAG"
  TAGS="$TAGS --tag $DOCKER_IMAGE:$LATEST_TAG"
fi

# Build and push multi-platform
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --file Dockerfile.gcloud \
  $TAGS \
  --push \
  .

echo "✅ Successfully pushed $DOCKER_IMAGE:$TAG to Docker Hub"
if [[ "$TAG" != "gcloud-latest" ]]; then
  echo "✅ Successfully pushed $DOCKER_IMAGE:$LATEST_TAG to Docker Hub"
fi
echo "🚀 Ready for deployment from your other repo!"

