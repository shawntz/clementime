#!/bin/sh

# Google Cloud Run startup script to decode base64 environment variables
# This should be run before starting the main application

echo "Starting Google Cloud Run deployment setup..."

# Decode config YAML if provided
if [ ! -z "$CONFIG_BASE64" ]; then
  echo "Decoding config YAML..."
  echo "$CONFIG_BASE64" | base64 -d >/app/config.yml
  echo "Config YAML decoded and saved"
fi

# Decode .env file if provided and extract specific values we need
if [ ! -z "$ENV_BASE64" ]; then
  echo "Decoding .env file..."
  echo "$ENV_BASE64" | base64 -d >/app/.env.temp
  echo ".env file decoded"

  # Extract values we need from .env file (but don't override GOOGLE_AUTH_CALLBACK_URL if already set)
  export GOOGLE_CLIENT_ID=$(grep "^GOOGLE_CLIENT_ID=" /app/.env.temp | cut -d'=' -f2-)
  export GOOGLE_CLIENT_SECRET=$(grep "^GOOGLE_CLIENT_SECRET=" /app/.env.temp | cut -d'=' -f2-)
  # Only set GOOGLE_AUTH_CALLBACK_URL from .env if not already set by Cloud Run
  if [ -z "$GOOGLE_AUTH_CALLBACK_URL" ]; then
    export GOOGLE_AUTH_CALLBACK_URL=$(grep "^GOOGLE_AUTH_CALLBACK_URL=" /app/.env.temp | cut -d'=' -f2-)
  fi
  export SESSION_SECRET=$(grep "^SESSION_SECRET=" /app/.env.temp | cut -d'=' -f2-)
  export DATABASE_PATH=$(grep "^DATABASE_PATH=" /app/.env.temp | cut -d'=' -f2-)
  export SCHEDULER_DATABASE_PATH=$(grep "^SCHEDULER_DATABASE_PATH=" /app/.env.temp | cut -d'=' -f2-)

  # Extract Slack variables if they exist
  export SLACK_BOT_TOKEN=$(grep "^SLACK_BOT_TOKEN=" /app/.env.temp | cut -d'=' -f2-)
  export SLACK_APP_TOKEN=$(grep "^SLACK_APP_TOKEN=" /app/.env.temp | cut -d'=' -f2-)
  export SLACK_SIGNING_SECRET=$(grep "^SLACK_SIGNING_SECRET=" /app/.env.temp | cut -d'=' -f2-)

  # Extract Google Drive variables if they exist
  export GOOGLE_DRIVE_FOLDER_ID=$(grep "^GOOGLE_DRIVE_FOLDER_ID=" /app/.env.temp | cut -d'=' -f2-)
  export GOOGLE_MEET_CLIENT_ID=$(grep "^GOOGLE_MEET_CLIENT_ID=" /app/.env.temp | cut -d'=' -f2-)
  export GOOGLE_MEET_CLIENT_SECRET=$(grep "^GOOGLE_MEET_CLIENT_SECRET=" /app/.env.temp | cut -d'=' -f2-)
  export GOOGLE_REFRESH_TOKEN=$(grep "^GOOGLE_REFRESH_TOKEN=" /app/.env.temp | cut -d'=' -f2-)
  export GOOGLE_MEET_REFRESH_TOKEN=$(grep "^GOOGLE_MEET_REFRESH_TOKEN=" /app/.env.temp | cut -d'=' -f2-)

  # Clean up temp file
  rm -f /app/.env.temp
fi

# Decode service account JSON if provided
if [ ! -z "$GOOGLE_SERVICE_ACCOUNT_JSON" ]; then
  echo "Decoding Google service account JSON..."
  echo "$GOOGLE_SERVICE_ACCOUNT_JSON" | base64 -d >/app/service-account.json
  # Set both environment variables to the JSON content
  export GOOGLE_APPLICATION_CREDENTIALS=/app/service-account.json
  export GOOGLE_SERVICE_ACCOUNT_KEY="$(cat /app/service-account.json)"
  echo "Service account JSON decoded and set in environment"
fi

# Create data directory in /tmp (writable in Cloud Run)
mkdir -p /tmp/data
mkdir -p /tmp/logs
mkdir -p /tmp/data/students

# Create symlinks to make the data accessible from /app
ln -sf /tmp/data /app/data
ln -sf /tmp/logs /app/logs

# Set database path to use /tmp (writable in Cloud Run)
export DATABASE_PATH="/tmp/data/clementime.db"
export SCHEDULER_DATABASE_PATH="/tmp/data/clementime.db"

# Create an empty database file to ensure it exists
touch "$DATABASE_PATH"
chmod 666 "$DATABASE_PATH"

# Set PORT from Cloud Run environment or default to 3000
export PORT=${PORT:-3000}

echo "Google Cloud Run setup complete."
echo "Database path: $DATABASE_PATH"
echo "Directory permissions:"
ls -la /tmp/data/
echo "Starting application on port $PORT..."

# Start the application using the compiled JavaScript
exec node dist/index.js web

