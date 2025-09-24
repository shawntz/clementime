#!/bin/bash
# 🍊 ClemenTime - Local Test Script
# Runs the locally built Docker image for testing

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
LOCAL_PORT="${LOCAL_PORT:-3001}"
CONTAINER_NAME="clementime-test"

# Print banner
echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${PURPLE}🍊 ClemenTime - Local Test${NC}"
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

# Check if image exists
print_step "📦 Checking if Docker image exists..."

if ! docker images | grep -q "$DOCKER_IMAGE_NAME.*$DOCKER_TAG"; then
  print_error "Docker image $DOCKER_IMAGE_NAME:$DOCKER_TAG not found"
  echo "Please run ./build-local.sh first to build the image"
  exit 1
fi

print_success "Docker image found: $DOCKER_IMAGE_NAME:$DOCKER_TAG"

# Stop any existing container
print_step "🛑 Stopping any existing test container..."

if docker ps -a | grep -q "$CONTAINER_NAME"; then
  docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
  docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
  print_success "Existing container stopped and removed"
else
  print_success "No existing container found"
fi

# Run the container
print_step "🐳 Starting test container..."

docker run -d \
  --name "$CONTAINER_NAME" \
  -p "$LOCAL_PORT:3000" \
  -e NODE_ENV=production \
  -e PORT=3000 \
  -e DATABASE_PATH=/tmp/data/clementime.db \
  -e SCHEDULER_DATABASE_PATH=/tmp/data/clementime.db \
  -e SESSION_STORE=sqlite \
  -e USE_CLOUD_STORAGE=false \
  "$DOCKER_IMAGE_NAME:$DOCKER_TAG"

print_success "Container started successfully!"

# Wait for container to start
print_step "⏳ Waiting for container to start..."
sleep 5

# Check if container is running
if docker ps | grep -q "$CONTAINER_NAME"; then
  print_success "Container is running!"
  
  # Test health endpoint
  print_step "🏥 Testing health endpoint..."
  if curl -f "http://localhost:$LOCAL_PORT/health" >/dev/null 2>&1; then
    print_success "Health check passed!"
  else
    print_warning "Health check failed - container might still be starting"
    print_step "📋 Container logs:"
    docker logs "$CONTAINER_NAME" --tail 20
  fi
  
  echo ""
  echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}🎉 Test container is running!${NC}"
  echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "${CYAN}📍 URLs:${NC}"
  echo -e "  Application: ${GREEN}http://localhost:$LOCAL_PORT${NC}"
  echo -e "  Health check: ${GREEN}http://localhost:$LOCAL_PORT/health${NC}"
  echo -e "  Students page: ${GREEN}http://localhost:$LOCAL_PORT/students${NC}"
  echo ""
  echo -e "${CYAN}📋 Container management:${NC}"
  echo "  View logs: docker logs $CONTAINER_NAME"
  echo "  Follow logs: docker logs -f $CONTAINER_NAME"
  echo "  Stop container: docker stop $CONTAINER_NAME"
  echo "  Remove container: docker rm $CONTAINER_NAME"
  echo "  Shell into container: docker exec -it $CONTAINER_NAME sh"
  echo ""
  echo -e "${CYAN}🔧 Testing commands:${NC}"
  echo "  Test health: curl http://localhost:$LOCAL_PORT/health"
  echo "  Test students API: curl http://localhost:$LOCAL_PORT/api/students/files"
  echo ""
  
else
  print_error "Container failed to start"
  print_step "📋 Container logs:"
  docker logs "$CONTAINER_NAME"
  exit 1
fi
