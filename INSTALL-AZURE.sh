#!/bin/bash

# ClemenTime Azure Deployment Installer
# This script sets up Azure deployment files in a directory

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
INSTALL_DIR=""
USE_CURRENT_DIR=false

# Function to show usage
show_usage() {
    echo -e "${BLUE}🍊 ClemenTime Azure Deployment Installer${NC}"
    echo "=========================================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -c, --current     Install in current directory (must be empty or git repo)"
    echo "  -d, --dir DIR     Install in specified directory (creates if not exists)"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -c                           # Install in current directory"
    echo "  $0 -d my-clementime-deployment  # Install in new directory"
    echo "  $0                              # Install in ./clementime-azure (default)"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--current)
            USE_CURRENT_DIR=true
            shift
            ;;
        -d|--dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

echo -e "${BLUE}🍊 ClemenTime Azure Deployment Installer${NC}"
echo "=========================================="

# Function to print colored output
print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Determine target directory
if [ "$USE_CURRENT_DIR" = true ]; then
    TARGET_DIR="$PWD"
    print_step "Installing in current directory: $TARGET_DIR"

    # Check if current directory is suitable
    if [ ! -d ".git" ] && [ "$(ls -A . 2>/dev/null | wc -l)" -gt 0 ]; then
        print_error "Current directory is not empty and not a git repository"
        echo "Please run in an empty directory or git repository, or use -d to specify a different directory"
        exit 1
    fi
elif [ -n "$INSTALL_DIR" ]; then
    TARGET_DIR="$INSTALL_DIR"
    print_step "Installing in specified directory: $TARGET_DIR"
else
    TARGET_DIR="clementime-azure"
    print_step "Installing in default directory: $TARGET_DIR"
fi

# Create target directory if it doesn't exist
if [ "$TARGET_DIR" != "$PWD" ]; then
    if [ ! -d "$TARGET_DIR" ]; then
        print_step "Creating directory: $TARGET_DIR"
        mkdir -p "$TARGET_DIR"
    fi

    # Change to target directory
    cd "$TARGET_DIR"
    print_success "Changed to directory: $TARGET_DIR"
fi

# Initialize git repository if not exists
if [ ! -d ".git" ]; then
    print_step "Initializing git repository..."
    git init
    print_success "Git repository initialized"
else
    print_success "Using existing git repository"
fi

# Get repository information
REPO_NAME=$(basename "$PWD")
print_step "Setting up Azure deployment for repository: $REPO_NAME"

# Create necessary directories
print_step "Creating directory structure..."

mkdir -p scripts
mkdir -p .github/workflows

print_success "Directory structure created"

# Create docker-compose.yml for Azure deployment
print_step "Creating docker-compose.yml..."

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  clementime:
    image: shawnschwartz/clementime:latest
    container_name: clementime-azure
    ports:
      - "3000:3000"
    environment:
      # Base64 encoded configuration (will be set via environment variables)
      - CONFIG_BASE64=${CONFIG_BASE64}
      - ENV_BASE64=${ENV_BASE64}

      # Direct environment variables for Azure
      - NODE_ENV=production
      - PORT=3000
      - DB_PATH=/app/data/clementime.db

      # Azure-specific settings
      - AZURE_DEPLOYMENT=true
      - WEBSITES_PORT=3000
      - WEBSITES_ENABLE_APP_SERVICE_STORAGE=false

    volumes:
      - clementime-data:/app/data
      - clementime-logs:/app/logs

    restart: unless-stopped

    # Health check for Azure Container Instances
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

    # Resource limits for Azure
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M

volumes:
  clementime-data:
    driver: local
  clementime-logs:
    driver: local

networks:
  default:
    driver: bridge
EOF

print_success "docker-compose.yml created"

# Create Azure Container Instance deployment script
print_step "Creating Azure Container Instance deployment script..."

cat > scripts/azure-deploy.sh << 'EOF'
#!/bin/bash

# ClemenTime Azure Deployment Script for Child Repository
# This script handles base64 encoding of config files and Azure deployment

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-clementime-rg}"
CONTAINER_GROUP="${AZURE_CONTAINER_GROUP:-clementime-container-group}"
LOCATION="${AZURE_LOCATION:-eastus}"
IMAGE_NAME="${AZURE_IMAGE_NAME:-shawnschwartz/clementime:latest}"

echo -e "${BLUE}🍊 ClemenTime Azure Deployment Script${NC}"
echo "=================================================="

# Function to print colored output
print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if required files exist
print_step "Checking required configuration files..."

if [ ! -f "config.yml" ]; then
    print_error "config.yml not found. Please create it first"
    exit 1
fi

if [ ! -f ".env" ]; then
    print_error ".env file not found. Please create it first"
    exit 1
fi

print_success "Configuration files found"

# Base64 encode configuration files
print_step "Encoding configuration files to base64..."

CONFIG_BASE64=$(base64 -i config.yml | tr -d '\n')
ENV_BASE64=$(base64 -i .env | tr -d '\n')

# Validate base64 encoding
if [ -z "$CONFIG_BASE64" ] || [ -z "$ENV_BASE64" ]; then
    print_error "Failed to encode configuration files"
    exit 1
fi

print_success "Configuration files encoded successfully"

# Check Azure CLI
print_step "Checking Azure CLI..."

if ! command -v az &> /dev/null; then
    print_error "Azure CLI not found. Please install it: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    print_warning "Not logged in to Azure. Please run 'az login' first"
    exit 1
fi

print_success "Azure CLI ready"

# Get current Azure subscription
SUBSCRIPTION=$(az account show --query name -o tsv)
print_step "Using Azure subscription: $SUBSCRIPTION"

# Create resource group if it doesn't exist
print_step "Ensuring resource group exists: $RESOURCE_GROUP"

if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    print_step "Creating resource group: $RESOURCE_GROUP"
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    print_success "Resource group created"
else
    print_success "Resource group already exists"
fi

# Get the latest image tag from Docker Hub
print_step "Getting latest image tag from Docker Hub..."

LATEST_TAG=$(curl -s "https://registry.hub.docker.com/v2/repositories/shawnschwartz/clementime/tags/" | \
    jq -r '.results[].name' | \
    grep -E '^v[0-9]{4}\.[0-9]{2}\.[0-9]{2}rc[0-9]+$' | \
    sort -V | \
    tail -1)

if [ -n "$LATEST_TAG" ]; then
    IMAGE_NAME="shawnschwartz/clementime:$LATEST_TAG"
    print_step "Using latest RC tag: $LATEST_TAG"
else
    print_warning "No RC tags found, using latest tag"
    IMAGE_NAME="shawnschwartz/clementime:latest"
fi

# Deploy Azure Container Instance
print_step "Deploying ClemenTime to Azure Container Instances..."

cat > azure-container-deploy.json << EOF
{
    "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {},
    "variables": {},
    "resources": [
        {
            "type": "Microsoft.ContainerInstance/containerGroups",
            "apiVersion": "2021-09-01",
            "name": "$CONTAINER_GROUP",
            "location": "$LOCATION",
            "properties": {
                "containers": [
                    {
                        "name": "clementime",
                        "properties": {
                            "image": "$IMAGE_NAME",
                            "ports": [
                                {
                                    "port": 3000,
                                    "protocol": "TCP"
                                }
                            ],
                            "environmentVariables": [
                                {
                                    "name": "CONFIG_BASE64",
                                    "secureValue": "$CONFIG_BASE64"
                                },
                                {
                                    "name": "ENV_BASE64",
                                    "secureValue": "$ENV_BASE64"
                                },
                                {
                                    "name": "NODE_ENV",
                                    "value": "production"
                                },
                                {
                                    "name": "PORT",
                                    "value": "3000"
                                },
                                {
                                    "name": "AZURE_DEPLOYMENT",
                                    "value": "true"
                                }
                            ],
                            "resources": {
                                "requests": {
                                    "cpu": 1.0,
                                    "memoryInGB": 1.0
                                }
                            },
                            "volumeMounts": [
                                {
                                    "name": "data-volume",
                                    "mountPath": "/app/data"
                                }
                            ]
                        }
                    }
                ],
                "osType": "Linux",
                "restartPolicy": "Always",
                "ipAddress": {
                    "type": "Public",
                    "ports": [
                        {
                            "port": 3000,
                            "protocol": "TCP"
                        }
                    ],
                    "dnsNameLabel": "clementime-$(date +%s)"
                },
                "volumes": [
                    {
                        "name": "data-volume",
                        "emptyDir": {}
                    }
                ]
            }
        }
    ],
    "outputs": {
        "containerIPv4Address": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.ContainerInstance/containerGroups/', '$CONTAINER_GROUP')).ipAddress.ip]"
        },
        "containerFQDN": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.ContainerInstance/containerGroups/', '$CONTAINER_GROUP')).ipAddress.fqdn]"
        }
    }
}
EOF

# Deploy the template
print_step "Deploying container instance..."

DEPLOYMENT_OUTPUT=$(az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file azure-container-deploy.json \
    --query 'properties.outputs' -o json)

if [ $? -eq 0 ]; then
    print_success "Deployment completed successfully!"

    # Extract outputs
    IP_ADDRESS=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.containerIPv4Address.value')
    FQDN=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.containerFQDN.value')

    echo ""
    echo "=================================================="
    echo -e "${GREEN}🎉 ClemenTime deployed successfully!${NC}"
    echo "=================================================="
    echo -e "📍 Public IP: ${BLUE}$IP_ADDRESS${NC}"
    echo -e "🌐 FQDN: ${BLUE}$FQDN${NC}"
    echo -e "🔗 URL: ${BLUE}http://$FQDN:3000${NC}"
    echo -e "🐳 Image: ${BLUE}$IMAGE_NAME${NC}"
    echo ""

    # Clean up temporary files
    rm -f azure-container-deploy.json

else
    print_error "Deployment failed!"
    rm -f azure-container-deploy.json
    exit 1
fi

print_success "Azure deployment script completed!"
EOF

chmod +x scripts/azure-deploy.sh
print_success "Azure Container Instance deployment script created"

# Create Azure Container Apps deployment script
print_step "Creating Azure Container Apps deployment script..."

cat > scripts/azure-container-apps-deploy.sh << 'EOF'
#!/bin/bash

# ClemenTime Azure Container Apps Deployment Script for Child Repository
# Alternative to Container Instances with better scaling and management

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-clementime-rg}"
CONTAINER_APP_ENV="${AZURE_CONTAINER_APP_ENV:-clementime-env}"
CONTAINER_APP_NAME="${AZURE_CONTAINER_APP_NAME:-clementime-app}"
LOCATION="${AZURE_LOCATION:-eastus}"

echo -e "${BLUE}🍊 ClemenTime Azure Container Apps Deployment Script${NC}"
echo "=============================================================="

# Function to print colored output
print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if required files exist
print_step "Checking required configuration files..."

if [ ! -f "config.yml" ]; then
    print_error "config.yml not found. Please create it first"
    exit 1
fi

if [ ! -f ".env" ]; then
    print_error ".env file not found. Please create it first"
    exit 1
fi

print_success "Configuration files found"

# Base64 encode configuration files
print_step "Encoding configuration files to base64..."

CONFIG_BASE64=$(base64 -i config.yml | tr -d '\n')
ENV_BASE64=$(base64 -i .env | tr -d '\n')

# Validate base64 encoding
if [ -z "$CONFIG_BASE64" ] || [ -z "$ENV_BASE64" ]; then
    print_error "Failed to encode configuration files"
    exit 1
fi

print_success "Configuration files encoded successfully"

# Check Azure CLI and Container Apps extension
print_step "Checking Azure CLI and Container Apps extension..."

if ! command -v az &> /dev/null; then
    print_error "Azure CLI not found. Please install it: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    print_warning "Not logged in to Azure. Please run 'az login' first"
    exit 1
fi

# Install Container Apps extension if not present
if ! az extension show --name containerapp &> /dev/null; then
    print_step "Installing Azure Container Apps extension..."
    az extension add --name containerapp
fi

print_success "Azure CLI and Container Apps extension ready"

# Get the latest image tag from Docker Hub
print_step "Getting latest image tag from Docker Hub..."

LATEST_TAG=$(curl -s "https://registry.hub.docker.com/v2/repositories/shawnschwartz/clementime/tags/" | \
    jq -r '.results[].name' | \
    grep -E '^v[0-9]{4}\.[0-9]{2}\.[0-9]{2}rc[0-9]+$' | \
    sort -V | \
    tail -1)

if [ -n "$LATEST_TAG" ]; then
    IMAGE_NAME="shawnschwartz/clementime:$LATEST_TAG"
    print_step "Using latest RC tag: $LATEST_TAG"
else
    print_warning "No RC tags found, using latest tag"
    IMAGE_NAME="shawnschwartz/clementime:latest"
fi

# Get current Azure subscription
SUBSCRIPTION=$(az account show --query name -o tsv)
print_step "Using Azure subscription: $SUBSCRIPTION"

# Create resource group if it doesn't exist
print_step "Ensuring resource group exists: $RESOURCE_GROUP"

if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    print_step "Creating resource group: $RESOURCE_GROUP"
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    print_success "Resource group created"
else
    print_success "Resource group already exists"
fi

# Create Container Apps environment if it doesn't exist
print_step "Ensuring Container Apps environment exists: $CONTAINER_APP_ENV"

if ! az containerapp env show --name "$CONTAINER_APP_ENV" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    print_step "Creating Container Apps environment: $CONTAINER_APP_ENV"
    az containerapp env create \
        --name "$CONTAINER_APP_ENV" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION"
    print_success "Container Apps environment created"
else
    print_success "Container Apps environment already exists"
fi

# Create or update the container app
print_step "Deploying ClemenTime Container App..."

if az containerapp show --name "$CONTAINER_APP_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    print_step "Updating existing container app: $CONTAINER_APP_NAME"

    az containerapp update \
        --name "$CONTAINER_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --image "$IMAGE_NAME" \
        --set-env-vars \
            "CONFIG_BASE64=secretref:config-base64" \
            "ENV_BASE64=secretref:env-base64" \
            "NODE_ENV=production" \
            "PORT=3000" \
            "AZURE_DEPLOYMENT=true" \
        --secrets \
            "config-base64=$CONFIG_BASE64" \
            "env-base64=$ENV_BASE64" \
        --cpu 1.0 \
        --memory 2.0Gi \
        --min-replicas 1 \
        --max-replicas 3
else
    print_step "Creating new container app: $CONTAINER_APP_NAME"

    az containerapp create \
        --name "$CONTAINER_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --environment "$CONTAINER_APP_ENV" \
        --image "$IMAGE_NAME" \
        --target-port 3000 \
        --ingress 'external' \
        --env-vars \
            "CONFIG_BASE64=secretref:config-base64" \
            "ENV_BASE64=secretref:env-base64" \
            "NODE_ENV=production" \
            "PORT=3000" \
            "AZURE_DEPLOYMENT=true" \
        --secrets \
            "config-base64=$CONFIG_BASE64" \
            "env-base64=$ENV_BASE64" \
        --cpu 1.0 \
        --memory 2.0Gi \
        --min-replicas 1 \
        --max-replicas 3
fi

# Get the app URL
print_step "Retrieving application URL..."

APP_URL=$(az containerapp show \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "properties.configuration.ingress.fqdn" \
    --output tsv)

if [ -n "$APP_URL" ]; then
    APP_URL="https://$APP_URL"
    print_success "Deployment completed successfully!"

    echo ""
    echo "=============================================================="
    echo -e "${GREEN}🎉 ClemenTime Container App deployed successfully!${NC}"
    echo "=============================================================="
    echo -e "🔗 URL: ${BLUE}$APP_URL${NC}"
    echo -e "🐳 Image: ${BLUE}$IMAGE_NAME${NC}"
    echo -e "📱 App Name: ${BLUE}$CONTAINER_APP_NAME${NC}"
    echo ""
else
    print_error "Failed to retrieve application URL"
    exit 1
fi

print_success "Azure Container Apps deployment script completed!"
EOF

chmod +x scripts/azure-container-apps-deploy.sh
print_success "Azure Container Apps deployment script created"

# Create GitHub Actions workflow for automated deployment
print_step "Creating GitHub Actions workflow..."

cat > .github/workflows/azure-deploy.yml << 'EOF'
name: ☁️ Deploy ClemenTime to Azure

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:
    inputs:
      deployment_type:
        description: 'Deployment type'
        required: true
        default: 'container-instances'
        type: choice
        options:
        - container-instances
        - container-apps

env:
  AZURE_RESOURCE_GROUP: clementime-rg
  AZURE_LOCATION: eastus

jobs:
  # Deploy to Azure Container Instances (default)
  deploy-container-instances:
    name: 🐳 Deploy to Container Instances
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && (github.event_name == 'push' || (github.event_name == 'workflow_dispatch' && github.event.inputs.deployment_type == 'container-instances'))
    environment: azure

    steps:
    - name: 📥 Checkout code
      uses: actions/checkout@v4

    - name: 🔑 Azure Login
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}

    - name: 🔧 Prepare configuration files
      run: |
        # Create config.yml from secrets or use default
        if [ -n "${{ secrets.CONFIG_YML_BASE64 }}" ]; then
          echo "${{ secrets.CONFIG_YML_BASE64 }}" | base64 -d > config.yml
        else
          echo "Warning: No CONFIG_YML_BASE64 secret found. Using default configuration."
          cat > config.yml << EOF
        course:
          name: "Production Course"
          term: "Current Term"
          total_students: 100
          instructor: "System Admin"
        organization:
          domain: "production.edu"
          timezone: "America/Los_Angeles"
        terminology:
          facilitator_label: "TA"
          participant_label: "Student"
        scheduling:
          exam_duration_minutes: 15
          buffer_minutes: 5
          start_time: "09:00"
          end_time: "17:00"
          excluded_days: [Saturday, Sunday]
          schedule_frequency_weeks: 2
          break_duration_minutes: 5
        sections: []
        google_meet:
          calendar_invites_enabled: false
          recording_settings:
            auto_recording: true
            save_to_drive: true
        notifications:
          reminder_days_before: [7, 3, 1]
          reminder_time: "09:00"
          include_meet_link: true
          include_location: true
          ta_summary_enabled: true
          ta_summary_time: "08:00"
        admin_users: []
        authorized_google_users: []
        web_ui:
          navbar_title: "ClemenTime Production"
          server_base_url: "https://clementime-production.azurewebsites.net"
        EOF
        fi

        # Create .env from secrets or use default
        if [ -n "${{ secrets.ENV_BASE64 }}" ]; then
          echo "${{ secrets.ENV_BASE64 }}" | base64 -d > .env
        else
          echo "Warning: No ENV_BASE64 secret found. Using minimal configuration."
          cat > .env << EOF
        NODE_ENV=production
        PORT=3000
        DB_PATH=/app/data/clementime.db
        AZURE_DEPLOYMENT=true
        EOF
        fi

    - name: ☁️ Deploy to Azure Container Instances
      run: |
        ./scripts/azure-deploy.sh

  # Deploy to Azure Container Apps (optional)
  deploy-container-apps:
    name: 📱 Deploy to Container Apps
    runs-on: ubuntu-latest
    if: github.event_name == 'workflow_dispatch' && github.event.inputs.deployment_type == 'container-apps'
    environment: azure

    steps:
    - name: 📥 Checkout code
      uses: actions/checkout@v4

    - name: 🔑 Azure Login
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}

    - name: 🔧 Prepare configuration files
      run: |
        # Create config.yml from secrets or use default
        if [ -n "${{ secrets.CONFIG_YML_BASE64 }}" ]; then
          echo "${{ secrets.CONFIG_YML_BASE64 }}" | base64 -d > config.yml
        else
          echo "Warning: No CONFIG_YML_BASE64 secret found. Using default configuration."
          cat > config.yml << EOF
        course:
          name: "Production Course"
          term: "Current Term"
          total_students: 100
          instructor: "System Admin"
        organization:
          domain: "production.edu"
          timezone: "America/Los_Angeles"
        terminology:
          facilitator_label: "TA"
          participant_label: "Student"
        scheduling:
          exam_duration_minutes: 15
          buffer_minutes: 5
          start_time: "09:00"
          end_time: "17:00"
          excluded_days: [Saturday, Sunday]
          schedule_frequency_weeks: 2
          break_duration_minutes: 5
        sections: []
        google_meet:
          calendar_invites_enabled: false
          recording_settings:
            auto_recording: true
            save_to_drive: true
        notifications:
          reminder_days_before: [7, 3, 1]
          reminder_time: "09:00"
          include_meet_link: true
          include_location: true
          ta_summary_enabled: true
          ta_summary_time: "08:00"
        admin_users: []
        authorized_google_users: []
        web_ui:
          navbar_title: "ClemenTime Production"
          server_base_url: "https://clementime-production.azurewebsites.net"
        EOF
        fi

        # Create .env from secrets or use default
        if [ -n "${{ secrets.ENV_BASE64 }}" ]; then
          echo "${{ secrets.ENV_BASE64 }}" | base64 -d > .env
        else
          echo "Warning: No ENV_BASE64 secret found. Using minimal configuration."
          cat > .env << EOF
        NODE_ENV=production
        PORT=3000
        DB_PATH=/app/data/clementime.db
        AZURE_DEPLOYMENT=true
        EOF
        fi

    - name: 📱 Deploy to Azure Container Apps
      run: |
        ./scripts/azure-container-apps-deploy.sh
EOF

print_success "GitHub Actions workflow created"

# Create example configuration files
print_step "Creating example configuration files..."

cat > config.example.yml << 'EOF'
# ClemenTime Configuration for Azure Deployment
# Copy this to config.yml and customize for your needs

course:
  name: "Your Course Name"
  term: "Fall 2024"
  total_students: 100
  instructor: "Professor Name"

organization:
  domain: "youruniversity.edu"
  timezone: "America/Los_Angeles"

terminology:
  facilitator_label: "TA"
  participant_label: "Student"

scheduling:
  exam_duration_minutes: 15
  buffer_minutes: 5
  start_time: "09:00"
  end_time: "17:00"
  excluded_days:
    - Saturday
    - Sunday
  schedule_frequency_weeks: 2
  break_duration_minutes: 5

sections:
  - id: "section_01"
    ta_name: "TA Name"
    ta_email: "ta@university.edu"
    location: "Room 101"
    preferred_days:
      - Monday
      - Wednesday
    students:
      - name: "Student Name"
        email: "student@university.edu"
        slack_id: "U12345678"

google_meet:
  calendar_invites_enabled: false
  recording_settings:
    auto_recording: true
    save_to_drive: true

notifications:
  reminder_days_before: [7, 3, 1]
  reminder_time: "09:00"
  include_meet_link: true
  include_location: true
  ta_summary_enabled: true
  ta_summary_time: "08:00"

admin_users:
  - "U12345678"  # Your Slack ID

authorized_google_users:
  - "your-email@university.edu"

web_ui:
  navbar_title: "Session Scheduler"
  server_base_url: "https://your-azure-url.azurecontainerapps.io"
EOF

cat > .env.example << 'EOF'
# Environment Variables for ClemenTime Azure Deployment
# Copy this to .env and fill in your actual values

# Production settings
NODE_ENV=production
PORT=3000
DB_PATH=/app/data/clementime.db

# Azure deployment flag
AZURE_DEPLOYMENT=true

# Google OAuth (required for dashboard and calendar features)
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
GOOGLE_MEET_REFRESH_TOKEN=your-refresh-token

# Session security
SESSION_SECRET=your-random-session-secret

# Slack integration (required for notifications)
SLACK_BOT_TOKEN=xoxb-your-bot-token
SLACK_APP_TOKEN=xapp-your-app-token
SLACK_SIGNING_SECRET=your-signing-secret

# Optional: Facilitator mapping (JSON format)
# FACILITATOR_MAPPING={"ta1@university.edu":{"slack_id":"U12345","google_email":"ta1@gmail.com"}}
EOF

print_success "Example configuration files created"

# Create README for the child repo
print_step "Creating deployment README..."

cat > README.md << EOF
# ClemenTime Azure Deployment

This repository contains the Azure deployment configuration for ClemenTime.

## Quick Start

1. **Configure your deployment:**
   \`\`\`bash
   cp config.example.yml config.yml
   cp .env.example .env
   # Edit both files with your settings
   \`\`\`

2. **Deploy to Azure:**
   \`\`\`bash
   # Login to Azure
   az login

   # Deploy using Container Instances (recommended for simple deployments)
   ./scripts/azure-deploy.sh

   # OR deploy using Container Apps (recommended for production)
   ./scripts/azure-container-apps-deploy.sh
   \`\`\`

## Deployment Options

### Container Instances
- Simple, single-container deployment
- Fixed resources (1 CPU, 1GB RAM)
- Public IP with DNS name
- Good for testing and small deployments

### Container Apps
- Managed container service with auto-scaling
- 1-3 replicas based on load
- HTTPS ingress with custom domains
- Better for production deployments

## GitHub Actions

This repo includes automated deployment via GitHub Actions:

1. **Set up secrets** in your repository settings:
   - \`AZURE_CREDENTIALS\`: Service principal credentials (JSON)
   - \`CONFIG_YML_BASE64\`: Base64 encoded config.yml (optional)
   - \`ENV_BASE64\`: Base64 encoded .env (optional)

2. **Push to main branch** to trigger automatic deployment

3. **Manual deployment** via workflow dispatch with deployment type selection

## Configuration

### Required Files

- \`config.yml\`: Course and system configuration
- \`.env\`: Environment variables and secrets

### Azure Setup

1. **Create service principal:**
   \`\`\`bash
   az ad sp create-for-rbac --name "clementime-deployment" --role contributor \\
       --scopes /subscriptions/YOUR_SUBSCRIPTION_ID --sdk-auth
   \`\`\`

2. **Set GitHub secret \`AZURE_CREDENTIALS\`** with the JSON output

## Image Versions

The deployment scripts automatically use the latest RC-tagged image from Docker Hub:
- Format: \`shawnschwartz/clementime:v{yyyy}.{mm}.{dd}rc{x}\`
- Falls back to \`latest\` if no RC tags are found

## Management

### View Logs
\`\`\`bash
# Container Instances
az container logs --resource-group clementime-rg --name clementime-container-group

# Container Apps
az containerapp logs show --name clementime-app --resource-group clementime-rg
\`\`\`

### Scale Container Apps
\`\`\`bash
az containerapp update --name clementime-app --resource-group clementime-rg \\
    --min-replicas 2 --max-replicas 5
\`\`\`

### Update Deployment
Simply run the deployment script again with new configuration:
\`\`\`bash
# Update config.yml and .env, then redeploy
./scripts/azure-deploy.sh
\`\`\`

## Troubleshooting

1. **Configuration errors**: Verify config.yml and .env files are correctly formatted
2. **Azure authentication**: Ensure you're logged in with \`az login\`
3. **Deployment failures**: Check Azure portal for detailed error messages
4. **Health check failures**: Verify the application starts correctly by checking container logs

For more detailed documentation, see the parent repository.
EOF

print_success "Deployment README created"

# Create .gitignore to protect sensitive files
print_step "Creating .gitignore..."

cat > .gitignore << 'EOF'
# ClemenTime deployment files
config.yml
.env
*.log

# Azure deployment artifacts
azure-container-deploy.json

# Node modules (if running locally)
node_modules/

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# IDE files
.vscode/
.idea/
*.swp
*.swo
*~
EOF

print_success ".gitignore created"

# Final instructions
echo ""
echo "================================================================"
echo -e "${GREEN}🎉 Azure deployment setup completed successfully!${NC}"
echo "================================================================"
echo ""
echo -e "${YELLOW}📋 Next steps:${NC}"
echo "1. Copy and customize configuration files:"
echo "   cp config.example.yml config.yml"
echo "   cp .env.example .env"
echo ""
echo "2. Login to Azure:"
echo "   az login"
echo ""
echo "3. Deploy to Azure:"
echo "   ./scripts/azure-deploy.sh                    # Container Instances"
echo "   ./scripts/azure-container-apps-deploy.sh     # Container Apps"
echo ""
echo -e "${YELLOW}🔐 For GitHub Actions (optional):${NC}"
echo "1. Create Azure service principal:"
echo "   az ad sp create-for-rbac --name \"clementime-deployment\" --role contributor \\"
echo "       --scopes /subscriptions/YOUR_SUBSCRIPTION_ID --sdk-auth"
echo ""
echo "2. Add the JSON output as AZURE_CREDENTIALS secret in GitHub"
echo ""
echo -e "${YELLOW}📁 Files created:${NC}"
echo "• docker-compose.yml                          # Docker Compose configuration"
echo "• scripts/azure-deploy.sh                     # Container Instances deployment"
echo "• scripts/azure-container-apps-deploy.sh      # Container Apps deployment"
echo "• .github/workflows/azure-deploy.yml          # GitHub Actions workflow"
echo "• config.example.yml                          # Configuration template"
echo "• .env.example                                # Environment variables template"
echo "• README.md                                   # Deployment documentation"
echo "• .gitignore                                  # Git ignore rules"
echo ""
echo -e "${GREEN}✨ Your deployment repository is now ready for Azure!${NC}"
echo ""
if [ "$USE_CURRENT_DIR" != true ]; then
    echo -e "${BLUE}📂 Your files are in: $(pwd)${NC}"
fi