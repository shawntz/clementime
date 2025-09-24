#!/bin/bash
# 🍊 ClemenTime - Local Build and Test Script
# Builds the Docker image locally using Dockerfile.gcloud for testing before deployment

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
DOCKER_IMAGE_NAME="clementime-gcloud-local"
DOCKER_TAG="latest"
LOCAL_PORT="3001"  # Use different port to avoid conflicts

# Print banner
echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${PURPLE}🍊 ClemenTime - Local Build and Test${NC}"
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

# Function to print warnings
print_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to print errors
print_error() {
  echo -e "${RED}❌ $1${NC}"
}

# Function to check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
print_step "📋 Checking prerequisites..."

if ! command_exists docker; then
  print_error "Docker is not installed. Please install it from https://docs.docker.com/get-docker/"
  exit 1
fi

print_success "Docker is available"

# Check if we have the required files
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

# Check for config files
print_step "📋 Checking configuration files..."

if [ ! -f "config.yml" ]; then
  print_warning "config.yml not found - will use default configuration"
  if [ -f "config.example.yml" ]; then
    print_step "Copying config.example.yml to config.yml..."
    cp config.example.yml config.yml
    print_success "config.yml created from example"
  fi
fi

if [ ! -f ".env" ]; then
  print_warning ".env file not found - will use environment defaults"
  print_warning "For production deployment, you'll need a proper .env file"
fi

# Build the Docker image
print_step "🔨 Building Docker image locally..."

echo "Building image: $DOCKER_IMAGE_NAME:$DOCKER_TAG"
echo "Using Dockerfile: Dockerfile.gcloud"
echo ""

# Build with progress output for amd64/linux platform (required for Google Cloud Run)
docker build --platform linux/amd64 -f Dockerfile.gcloud -t "$DOCKER_IMAGE_NAME:$DOCKER_TAG" . --progress=plain

print_success "Docker image built successfully"

# Show image info
print_step "📊 Image information..."
docker images "$DOCKER_IMAGE_NAME:$DOCKER_TAG"

# Ask if user wants to run the container
echo ""
print_step "🚀 Ready to test the container!"
echo ""
echo "You can now:"
echo "1. Run the container locally to test it"
echo "2. Push to Docker Hub for deployment"
echo "3. Deploy directly to Google Cloud Run"
echo ""

read -p "Do you want to run the container locally now? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
  print_step "🐳 Starting container locally..."
  
  # Stop any existing container with the same name
  docker stop clementime-test 2>/dev/null || true
  docker rm clementime-test 2>/dev/null || true
  
  # Run the container
  docker run -d \
    --name clementime-test \
    -p "$LOCAL_PORT:3000" \
    -e NODE_ENV=production \
    -e PORT=3000 \
    -e DATABASE_PATH=/tmp/data/clementime.db \
    -e SCHEDULER_DATABASE_PATH=/tmp/data/clementime.db \
    -e SESSION_STORE=sqlite \
    -e USE_CLOUD_STORAGE=false \
    "$DOCKER_IMAGE_NAME:$DOCKER_TAG"
  
  print_success "Container started successfully!"
  echo ""
  echo -e "${CYAN}📍 Local URL: ${GREEN}http://localhost:$LOCAL_PORT${NC}"
  echo -e "${CYAN}🔍 Health check: ${GREEN}http://localhost:$LOCAL_PORT/health${NC}"
  echo ""
  
  # Wait a moment for the container to start
  print_step "⏳ Waiting for container to start..."
  sleep 5
  
  # Check if container is running
  if docker ps | grep -q clementime-test; then
    print_success "Container is running!"
    
    # Test health endpoint
    print_step "🏥 Testing health endpoint..."
    if curl -f "http://localhost:$LOCAL_PORT/health" >/dev/null 2>&1; then
      print_success "Health check passed!"
    else
      print_warning "Health check failed - container might still be starting"
    fi
    
    echo ""
    echo -e "${CYAN}📋 Container management commands:${NC}"
    echo "View logs: docker logs clementime-test"
    echo "Stop container: docker stop clementime-test"
    echo "Remove container: docker rm clementime-test"
    echo "Shell into container: docker exec -it clementime-test sh"
    echo ""
    
  else
    print_error "Container failed to start"
    print_step "📋 Container logs:"
    docker logs clementime-test
    exit 1
  fi
fi

# Ask about pushing to Docker Hub
echo ""
read -p "Do you want to push this image to Docker Hub for deployment? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
  print_step "🐳 Pushing to Docker Hub..."
  
  # Get Docker Hub username
  read -p "Enter your Docker Hub username: " DOCKER_USERNAME
  
  if [ -z "$DOCKER_USERNAME" ]; then
    print_error "Docker Hub username is required"
    exit 1
  fi
  
  # Tag for Docker Hub
  DOCKER_HUB_IMAGE="$DOCKER_USERNAME/clementime:latest.gcloud"
  docker tag "$DOCKER_IMAGE_NAME:$DOCKER_TAG" "$DOCKER_HUB_IMAGE"
  
  print_step "Tagged image as: $DOCKER_HUB_IMAGE"
  
  # Login to Docker Hub
  print_step "🔐 Logging into Docker Hub..."
  docker login
  
  # Push the image
  print_step "⬆️  Pushing image to Docker Hub..."
  docker push "$DOCKER_HUB_IMAGE"
  
  print_success "Image pushed to Docker Hub successfully!"
  echo ""
  echo -e "${CYAN}📍 Docker Hub image: ${GREEN}$DOCKER_HUB_IMAGE${NC}"
  echo ""
  echo -e "${YELLOW}⚠️  Next steps for deployment:${NC}"
  echo "1. Update DOCKER_IMAGE in gcloud-deploy.sh to: $DOCKER_HUB_IMAGE"
  echo "2. Run: ./gcloud-deploy.sh"
  echo ""
fi

echo ""
echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🎉 Build and test complete!${NC}"
echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}📋 Summary:${NC}"
echo "✅ Docker image built: $DOCKER_IMAGE_NAME:$DOCKER_TAG"
if docker ps | grep -q clementime-test; then
  echo "✅ Container running locally: http://localhost:$LOCAL_PORT"
fi
echo ""
echo -e "${CYAN}🔧 Next steps:${NC}"
echo "1. Test your application locally if container is running"
echo "2. Make any necessary changes and rebuild if needed"
echo "3. Push to Docker Hub when ready for deployment"
echo "4. Run ./gcloud-deploy.sh to deploy to Google Cloud Run"
echo ""
