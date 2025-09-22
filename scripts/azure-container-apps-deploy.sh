#!/bin/bash

# ClemenTime Azure Container Apps Deployment Script
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
IMAGE_NAME="${AZURE_IMAGE_NAME:-shawnschwartz/clementime:latest}"

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
    print_error "config.yml not found. Please create it from config.example.yml"
    exit 1
fi

if [ ! -f ".env" ]; then
    print_error ".env file not found. Please create it from .env.example"
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
    echo -e "📱 App Name: ${BLUE}$CONTAINER_APP_NAME${NC}"
    echo -e "🌍 Environment: ${BLUE}$CONTAINER_APP_ENV${NC}"
    echo -e "📍 Resource Group: ${BLUE}$RESOURCE_GROUP${NC}"
    echo ""
    echo -e "${YELLOW}📝 Management Commands:${NC}"
    echo "• View logs: az containerapp logs show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP"
    echo "• Scale app: az containerapp update --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --min-replicas 2 --max-replicas 5"
    echo "• Get status: az containerapp show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP"
    echo ""

    # Health check
    print_step "Performing health check..."

    for i in {1..10}; do
        if curl -f "$APP_URL/health" &> /dev/null; then
            print_success "Health check passed! Application is responding"
            break
        else
            if [ $i -eq 10 ]; then
                print_warning "Health check failed after 10 attempts. App may still be starting up."
                print_step "Check app logs with: az containerapp logs show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP"
            else
                print_step "Health check attempt $i/10 failed, retrying in 30s..."
                sleep 30
            fi
        fi
    done

else
    print_error "Failed to retrieve application URL"
    exit 1
fi

print_success "Azure Container Apps deployment script completed!"