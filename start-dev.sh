#!/bin/bash

# ClemenTime Development Startup Script
# This script sets up environment variables for local development

echo "🚀 Starting ClemenTime in development mode..."

# Set development environment variables
export NODE_ENV=development
export PORT=3000

# Set OAuth callback URL for local development
export GOOGLE_AUTH_CALLBACK_URL="http://localhost:3000/auth/google/callback"

# Set cookie security for development (less secure but works with HTTP)
export COOKIE_SECURE=false
export COOKIE_HTTPONLY=true
export COOKIE_SAMESITE=lax

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    echo "📁 Loading environment variables from .env file..."
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "⚠️  No .env file found. Using default development settings."
    echo "   Copy .env.example to .env and configure your credentials."
fi

# Check if port is available
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null ; then
    echo "❌ Port $PORT is already in use. Killing existing process..."
    lsof -ti:$PORT | xargs kill -9
    sleep 2
fi

echo "🔧 Environment Configuration:"
echo "  - NODE_ENV: $NODE_ENV"
echo "  - PORT: $PORT"
echo "  - GOOGLE_AUTH_CALLBACK_URL: $GOOGLE_AUTH_CALLBACK_URL"
echo "  - COOKIE_SECURE: $COOKIE_SECURE"

echo "🌐 Starting web server..."
npm run web
