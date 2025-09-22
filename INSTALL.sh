#!/bin/bash

# ClemenTime Quick Install Script
# This script downloads the necessary files to run ClemenTime from Docker Hub

set -e

REPO_URL="https://raw.githubusercontent.com/shawntz/clementime/main"
FILES_TO_DOWNLOAD=(
  "clementime"
  "docker-compose.yml"
  "config.example.yml"
  ".env.example"
  "README.md"
  "gcloud-deploy.sh"
  "gcloud-startup.sh"
)

echo "🍊 Installing ClemenTime..."
echo ""

# Create clementime directory
mkdir -p clementime
cd clementime

# Download each file
for file in "${FILES_TO_DOWNLOAD[@]}"; do
  echo "📥 Downloading $file..."
  curl -fsSL "$REPO_URL/$file" -o "$file"
done

# Make clementime script executable
chmod +x clementime

# Create data directory
mkdir -p data

echo ""
echo "✅ ClemenTime installed successfully!"
echo ""
echo "📝 Next steps:"
echo "1. Copy .env.example to .env and add your credentials"
echo "2. Copy config.example.yml to config.yml and customize"
echo "3. Run: ./clementime start"
echo ""
echo "📚 For full documentation, visit:"
echo "   https://github.com/shawntz/clementime"
