# Use Node.js 18 LTS as base image
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including tsx for running TypeScript directly)
RUN npm ci

# Copy source code and configuration
COPY src/ ./src/
COPY *.json ./
COPY config*.yml ./

# Create directories for runtime files
RUN mkdir -p /app/data /app/config /app/logs

# Set proper permissions
RUN chown -R node:node /app
USER node

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Start the application using tsx to run TypeScript directly
CMD ["npx", "tsx", "src/index.ts", "web"]