#!/bin/bash
# 🍊 ClemenTime - Simple Local Build Script
# Builds the Docker image locally using Dockerfile.gcloud

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
DOCKER_IMAGE_NAME="${DOCKER_IMAGE_NAME:-clementime-gcloud-local}"
DOCKER_TAG="${DOCKER_TAG:-latest}"

# Print banner
echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${PURPLE}🍊 ClemenTime - Local Build${NC}"
echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
echo ""

# Function to print step headers
print_step() {
  echo -e "${CYAN}$1${NC}"
}

# Function to print success messages
print_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

# Function to print errors
print_error() {
  echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
print_step "📋 Checking prerequisites..."

if ! command -v docker >/dev/null 2>&1; then
  print_error "Docker is not installed. Please install it from https://docs.docker.com/get-docker/"
  exit 1
fi

print_success "Docker is available"

# Check required files
print_step "📦 Checking required files..."

if [ ! -f "Dockerfile.gcloud" ]; then
  print_error "Dockerfile.gcloud not found in current directory"
  exit 1
fi

if [ ! -f "gcloud-startup.sh" ]; then
  print_error "gcloud-startup.sh not found in current directory"
  exit 1
fi

if [ ! -f "package.json" ]; then
  print_error "package.json not found in current directory"
  exit 1
fi

print_success "All required files found"

# Build the Docker image
print_step "🔨 Building Docker image..."

echo "Building image: $DOCKER_IMAGE_NAME:$DOCKER_TAG"
echo "Using Dockerfile: Dockerfile.gcloud"
echo ""

# Build with progress output for amd64/linux platform (required for Google Cloud Run)
docker build --platform linux/amd64 -f Dockerfile.gcloud -t "$DOCKER_IMAGE_NAME:$DOCKER_TAG" . --progress=plain

print_success "Docker image built successfully"

# Show image info
print_step "📊 Image information..."
docker images "$DOCKER_IMAGE_NAME:$DOCKER_TAG"

echo ""
echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🎉 Build complete!${NC}"
echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}📋 Image details:${NC}"
echo "Name: $DOCKER_IMAGE_NAME:$DOCKER_TAG"
echo ""
echo -e "${CYAN}🔧 Next steps:${NC}"
echo "1. Test locally: docker run -p 3001:3000 $DOCKER_IMAGE_NAME:$DOCKER_TAG"
echo "2. Tag for Docker Hub: docker tag $DOCKER_IMAGE_NAME:$DOCKER_TAG your-username/clementime:latest.gcloud"
echo "3. Push to Docker Hub: docker push your-username/clementime:latest.gcloud"
echo "4. Deploy to Google Cloud: ./gcloud-deploy.sh"
echo ""
