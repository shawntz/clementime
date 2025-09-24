#!/bin/bash

# ClemenTime Production Startup Script
# This script sets up environment variables for production deployment

echo "🚀 Starting ClemenTime in production mode..."

# Set production environment variables
export NODE_ENV=production
export PORT=${PORT:-8080}

# Set OAuth callback URL for production
# Update this to your actual domain
export GOOGLE_AUTH_CALLBACK_URL="${GOOGLE_AUTH_CALLBACK_URL:-https://your-domain.com/auth/google/callback}"

# Set secure cookie settings for production
export COOKIE_SECURE=true
export COOKIE_HTTPONLY=true
export COOKIE_SAMESITE=strict

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    echo "📁 Loading environment variables from .env file..."
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "⚠️  No .env file found. Make sure to set all required environment variables."
fi

echo "🔧 Environment Configuration:"
echo "  - NODE_ENV: $NODE_ENV"
echo "  - PORT: $PORT"
echo "  - GOOGLE_AUTH_CALLBACK_URL: $GOOGLE_AUTH_CALLBACK_URL"
echo "  - COOKIE_SECURE: $COOKIE_SECURE"

echo "🌐 Starting web server..."
npm run web
