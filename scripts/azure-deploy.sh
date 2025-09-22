#!/bin/bash

# ClemenTime Azure Deployment Script
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
    echo ""
    echo -e "${YELLOW}📝 Notes:${NC}"
    echo "• It may take a few minutes for the container to start"
    echo "• Check container logs: az container logs --resource-group $RESOURCE_GROUP --name $CONTAINER_GROUP"
    echo "• Monitor status: az container show --resource-group $RESOURCE_GROUP --name $CONTAINER_GROUP"
    echo ""

    # Clean up temporary files
    rm -f azure-container-deploy.json

else
    print_error "Deployment failed!"
    rm -f azure-container-deploy.json
    exit 1
fi

print_step "Checking container status..."

# Wait for container to be running
for i in {1..30}; do
    STATUS=$(az container show --resource-group "$RESOURCE_GROUP" --name "$CONTAINER_GROUP" --query "containers[0].instanceView.currentState.state" -o tsv 2>/dev/null || echo "Unknown")

    if [ "$STATUS" = "Running" ]; then
        print_success "Container is running!"
        break
    elif [ "$STATUS" = "Terminated" ]; then
        print_error "Container terminated unexpectedly"
        print_step "Fetching container logs..."
        az container logs --resource-group "$RESOURCE_GROUP" --name "$CONTAINER_GROUP"
        exit 1
    else
        print_step "Container status: $STATUS (attempt $i/30)"
        sleep 10
    fi
done

if [ "$STATUS" != "Running" ]; then
    print_warning "Container status check timed out. Check manually with:"
    echo "az container show --resource-group $RESOURCE_GROUP --name $CONTAINER_GROUP"
fi

print_success "Azure deployment script completed!"