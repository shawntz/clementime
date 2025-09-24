#!/bin/bash
# 🍊 ClemenTime - Docker Hub Deployment Script
# Deploys ClemenTime container from Docker Hub to Google Cloud Run

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
PROJECT_ID="${PROJECT_ID:-psych-10-admin-bots}"
SERVICE_NAME="${SERVICE_NAME:-clementime}"
REGION="${REGION:-us-west1}"
DOCKER_IMAGE="${DOCKER_IMAGE:-shawnschwartz/clementime:v1.0.0-gcloud}"
BUCKET_NAME="${BUCKET_NAME:-${SERVICE_NAME}-data-${PROJECT_ID}}"
MIN_INSTANCES="${MIN_INSTANCES:-1}" # Keep at least 1 instance for data persistence
MAX_INSTANCES="${MAX_INSTANCES:-10}"
CPU="${CPU:-1}"
MEMORY="${MEMORY:-1Gi}"

# Print banner
echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${PURPLE}🍊 ClemenTime - Docker Hub Deployment${NC}"
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

if ! command_exists gcloud; then
  print_error "gcloud CLI is not installed. Please install it from https://cloud.google.com/sdk/docs/install"
  exit 1
fi

if ! command_exists docker; then
  print_error "Docker is not installed. Please install it from https://docs.docker.com/get-docker/"
  exit 1
fi

print_success "All prerequisites are satisfied"

# Check Google Cloud authentication
print_step "🔐 Checking Google Cloud authentication..."

if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
  print_error "No active Google Cloud authentication found"
  echo "Please run: gcloud auth login"
  exit 1
fi

ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
print_success "Authenticated as: $ACTIVE_ACCOUNT"

# Set project
print_step "📋 Setting project to: $PROJECT_ID"
gcloud config set project "$PROJECT_ID" >/dev/null 2>&1
print_success "Project set to $PROJECT_ID"

# Enable required APIs
print_step "🔧 Enabling required Google Cloud APIs..."
gcloud services enable cloudbuild.googleapis.com --quiet
gcloud services enable run.googleapis.com --quiet
gcloud services enable artifactregistry.googleapis.com --quiet
gcloud services enable storage.googleapis.com --quiet
print_success "Required APIs enabled"

# Create Cloud Storage bucket for persistent data
print_step "📦 Setting up Cloud Storage for persistent data..."

if gsutil ls -b "gs://$BUCKET_NAME" >/dev/null 2>&1; then
  print_success "Storage bucket already exists: $BUCKET_NAME"
else
  print_step "Creating storage bucket: $BUCKET_NAME"
  gsutil mb -p "$PROJECT_ID" -l "$REGION" "gs://$BUCKET_NAME"
  print_success "Storage bucket created: $BUCKET_NAME"
fi

# Create initial directories in the bucket
gsutil -m mkdir -p "gs://$BUCKET_NAME/data" 2>/dev/null || true
gsutil -m mkdir -p "gs://$BUCKET_NAME/students" 2>/dev/null || true
gsutil -m mkdir -p "gs://$BUCKET_NAME/uploads" 2>/dev/null || true
print_success "Storage directories initialized"

# Check if config files exist
print_step "📦 Checking configuration files..."

if [ ! -f "config.yml" ]; then
  print_warning "config.yml not found in current directory"
  echo "Creating sample config.yml file..."
  cat >config.yml <<'EOF'
# Sample ClemenTime Configuration
course:
  name: "Psychology 10"
  term: "Fall 2024"
  department: "Psychology"

sections:
  - id: "section1"
    name: "Section 1"
    capacity: 20
    ta_email: "ta1@example.com"
  - id: "section2"
    name: "Section 2"
    capacity: 20
    ta_email: "ta2@example.com"

schedule:
  duration_minutes: 20
  buffer_minutes: 5
  start_time: "09:00"
  end_time: "17:00"
  days: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]

# Uncomment and configure for production:
# authorized_google_users:
#   - "admin@example.com"
#   - "ta1@example.com"
#   - "ta2@example.com"
EOF
  print_warning "Please edit config.yml with your actual configuration before proceeding"
fi

if [ ! -f ".env" ]; then
  print_warning ".env file not found in current directory"
  echo "Creating sample .env file..."
  cat >.env <<'EOF'
# ClemenTime Environment Variables
# Copy this file and fill in your actual values

# Google OAuth Configuration (required)
GOOGLE_CLIENT_ID=your_google_client_id_here
GOOGLE_CLIENT_SECRET=your_google_client_secret_here
GOOGLE_AUTH_CALLBACK_URL=https://your-domain.com/auth/google/callback

# Session Configuration (important for production)
SESSION_SECRET=your_secure_session_secret_here
SESSION_STORE=sqlite  # Use 'sqlite' for persistent sessions (recommended)

# Database Configuration
DATABASE_PATH=/tmp/data/clementime.db
SCHEDULER_DATABASE_PATH=/tmp/data/clementime.db

# Optional: Slack Integration
# SLACK_BOT_TOKEN=xoxb-your-slack-bot-token
# SLACK_APP_TOKEN=xapp-your-slack-app-token
# SLACK_SIGNING_SECRET=your-slack-signing-secret

# Optional: Google Drive Integration
# GOOGLE_DRIVE_FOLDER_ID=your-google-drive-folder-id
# GOOGLE_MEET_CLIENT_ID=your-google-meet-client-id
# GOOGLE_MEET_CLIENT_SECRET=your-google-meet-client-secret
# GOOGLE_REFRESH_TOKEN=your-google-refresh-token

# Optional: Service Account (for Google APIs)
# GOOGLE_SERVICE_ACCOUNT_KEY={"type":"service_account",...}
EOF
  print_warning "Please edit .env with your actual configuration before deploying"
  print_warning "Make sure to set proper OAuth callback URL for your domain"
fi

# Prepare environment variables for Cloud Run
print_step "🔒 Preparing environment variables..."

# Read .env file and create base64 encoded version
if [ -f ".env" ]; then
  ENV_BASE64=$(base64 -i .env)
  print_success ".env file encoded"
else
  print_error ".env file is required for deployment"
  exit 1
fi

# Read config.yml and create base64 encoded version
if [ -f "config.yml" ]; then
  CONFIG_BASE64=$(base64 -i config.yml)
  print_success "config.yml encoded"

  # Upload config.yml to Cloud Storage for persistent access
  gsutil cp config.yml "gs://$BUCKET_NAME/config.yml"
  print_success "config.yml uploaded to Cloud Storage"
else
  print_error "config.yml file is required for deployment"
  exit 1
fi

# Upload local data directory if exists
if [ -d "./data" ]; then
  print_step "⬆️  Uploading local data to Cloud Storage..."
  gsutil -m rsync -r ./data "gs://$BUCKET_NAME/data"
  print_success "Local data synchronized to Cloud Storage"
fi

# Deploy to Cloud Run
print_step "🚀 Deploying ClemenTime to Google Cloud Run..."

echo "📦 Configuration:"
echo "  - Docker Image: $DOCKER_IMAGE"
echo "  - Service Name: $SERVICE_NAME"
echo "  - Region: $REGION"
echo "  - Project: $PROJECT_ID"
echo "  - Storage Bucket: gs://$BUCKET_NAME"
echo "  - Min Instances: $MIN_INSTANCES"
echo "  - Max Instances: $MAX_INSTANCES"
echo "  - CPU: $CPU"
echo "  - Memory: $MEMORY"
echo ""

# Create service account for Cloud Storage access
SERVICE_ACCOUNT_NAME="${SERVICE_NAME}-storage-sa"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Create service account if it doesn't exist
if ! gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" >/dev/null 2>&1; then
  print_step "🔑 Creating service account for storage access..."
  gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
    --display-name="ClemenTime Storage Service Account"
  print_success "Service account created"
else
  print_success "Using existing service account: $SERVICE_ACCOUNT_EMAIL"
fi

# Grant storage permissions to service account
gsutil iam ch "serviceAccount:${SERVICE_ACCOUNT_EMAIL}:objectAdmin" "gs://$BUCKET_NAME"
print_success "Storage permissions configured"

# Deploy with Cloud Storage configuration (first deployment)
print_step "🚀 Deploying initial service..."
gcloud run deploy "$SERVICE_NAME" \
  --image="$DOCKER_IMAGE" \
  --platform=managed \
  --region="$REGION" \
  --allow-unauthenticated \
  --service-account="$SERVICE_ACCOUNT_EMAIL" \
  --set-env-vars="NODE_ENV=production" \
  --set-env-vars="ENV_BASE64=$ENV_BASE64" \
  --set-env-vars="CONFIG_BASE64=$CONFIG_BASE64" \
  --set-env-vars="STORAGE_BUCKET=$BUCKET_NAME" \
  --set-env-vars="USE_CLOUD_STORAGE=true" \
  --set-env-vars="SESSION_STORE=sqlite" \
  --set-env-vars="DATABASE_PATH=/tmp/data/clementime.db" \
  --set-env-vars="SCHEDULER_DATABASE_PATH=/tmp/data/clementime.db" \
  --set-env-vars="DATA_MOUNT_PATH=gs://$BUCKET_NAME/data" \
  --cpu="$CPU" \
  --memory="$MEMORY" \
  --min-instances="$MIN_INSTANCES" \
  --max-instances="$MAX_INSTANCES" \
  --timeout=300 \
  --concurrency=80 \
  --port=3000

# Get service URL
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region="$REGION" --format="value(status.url)")
print_success "Initial deployment complete. Service URL: $SERVICE_URL"

# Update .env file with correct callback URL
print_step "🔧 Updating OAuth callback URL..."
if [ -f ".env" ]; then
  # Update existing .env file
  sed -i.bak "s|GOOGLE_AUTH_CALLBACK_URL=.*|GOOGLE_AUTH_CALLBACK_URL=$SERVICE_URL/auth/google/callback|" .env
  # Re-encode the updated .env file
  ENV_BASE64=$(base64 -i .env)
  print_success "Updated .env file with correct callback URL"
else
  print_warning "No .env file found - OAuth callback URL will need to be set manually"
fi

# Redeploy with updated environment variables
if [ -f ".env" ]; then
  print_step "🔄 Redeploying with updated OAuth configuration..."
  gcloud run deploy "$SERVICE_NAME" \
    --image="$DOCKER_IMAGE" \
    --platform=managed \
    --region="$REGION" \
    --allow-unauthenticated \
    --service-account="$SERVICE_ACCOUNT_EMAIL" \
    --set-env-vars="NODE_ENV=production" \
    --set-env-vars="ENV_BASE64=$ENV_BASE64" \
    --set-env-vars="CONFIG_BASE64=$CONFIG_BASE64" \
    --set-env-vars="STORAGE_BUCKET=$BUCKET_NAME" \
    --set-env-vars="USE_CLOUD_STORAGE=true" \
    --set-env-vars="SESSION_STORE=sqlite" \
    --set-env-vars="DATABASE_PATH=/tmp/data/clementime.db" \
    --set-env-vars="SCHEDULER_DATABASE_PATH=/tmp/data/clementime.db" \
    --set-env-vars="DATA_MOUNT_PATH=gs://$BUCKET_NAME/data" \
    --set-env-vars="GOOGLE_AUTH_CALLBACK_URL=$SERVICE_URL/auth/google/callback" \
    --cpu="$CPU" \
    --memory="$MEMORY" \
    --min-instances="$MIN_INSTANCES" \
    --max-instances="$MAX_INSTANCES" \
    --timeout=300 \
    --concurrency=80 \
    --port=3000
  print_success "Redeployed with updated OAuth configuration"
fi

# Set IAM policy to allow unauthenticated access
print_step "🔐 Setting IAM policy for public access..."
gcloud run services add-iam-policy-binding "$SERVICE_NAME" \
  --region="$REGION" \
  --member="allUsers" \
  --role="roles/run.invoker" \
  --quiet

print_success "IAM policy configured"

print_success "ClemenTime deployed successfully!"

echo ""
echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🎉 Deployment Complete!${NC}"
echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}📍 Service URL: ${GREEN}$SERVICE_URL${NC}"
echo -e "${CYAN}📦 Storage Bucket: ${GREEN}gs://$BUCKET_NAME${NC}"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: Configure Google OAuth${NC}"
echo "1. Go to: https://console.cloud.google.com/apis/credentials"
echo "2. Select your OAuth 2.0 Client ID"
echo "3. Add this Authorized redirect URI:"
echo -e "   ${GREEN}$SERVICE_URL/auth/google/callback${NC}"
echo "4. Save the changes"
echo ""
echo -e "${CYAN}✅ OAuth callback URL automatically configured in deployment${NC}"
echo ""
echo -e "${CYAN}🔧 Storage Features:${NC}"
echo "✅ Persistent data storage in Cloud Storage bucket"
echo "✅ SQLite session store (persistent sessions)"
echo "✅ Automatic sync between local and cloud storage"
echo "✅ File uploads saved to Cloud Storage"
echo "✅ Database backups in Cloud Storage"
echo ""
echo -e "${CYAN}📂 Managing Cloud Storage Data:${NC}"
echo "View files: gsutil ls -r gs://$BUCKET_NAME"
echo "Download database: gsutil cp gs://$BUCKET_NAME/data/clementime.db ./backup.db"
echo "Upload CSV: gsutil cp your-file.csv gs://$BUCKET_NAME/uploads/"
echo "Sync local to cloud: gsutil -m rsync -r ./data gs://$BUCKET_NAME/data"
echo ""
echo -e "${CYAN}🔍 To view logs:${NC}"
echo "gcloud run services logs read $SERVICE_NAME --region=$REGION --limit=50"
echo ""
echo -e "${CYAN}🔄 To update the deployment:${NC}"
echo "1. Update your .env or config.yml files"
echo "2. Re-run this script"
echo ""
echo -e "${CYAN}🗑️  To delete the service and storage:${NC}"
echo "gcloud run services delete $SERVICE_NAME --region=$REGION"
echo "gsutil -m rm -r gs://$BUCKET_NAME  # Delete storage bucket"
echo ""
echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
