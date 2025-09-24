# 🍊 ClemenTime - Local Build and Test

This directory contains scripts to build and test the ClemenTime Docker image locally before deploying to Google Cloud Run.

## Scripts

### 1. `build-local.sh` - Simple Build

Builds the Docker image locally using `Dockerfile.gcloud`.

```bash
./build-local.sh
```

**Environment Variables:**

- `DOCKER_IMAGE_NAME` - Image name (default: `clementime-gcloud-local`)
- `DOCKER_TAG` - Image tag (default: `latest`)

### 2. `build-and-test-local.sh` - Interactive Build and Test

Builds the Docker image and optionally runs it locally with interactive prompts.

```bash
./build-and-test-local.sh
```

This script will:

1. Build the Docker image
2. Ask if you want to run it locally
3. Ask if you want to push to Docker Hub
4. Provide management commands

### 3. `test-local.sh` - Test Existing Image

Runs an already-built Docker image locally for testing.

```bash
./test-local.sh
```

**Environment Variables:**

- `DOCKER_IMAGE_NAME` - Image name (default: `clementime-gcloud-local`)
- `DOCKER_TAG` - Image tag (default: `latest`)
- `LOCAL_PORT` - Local port (default: `3001`)

## Quick Start

1. **Build the image:**

   ```bash
   ./build-local.sh
   ```

2. **Test locally:**

   ```bash
   ./test-local.sh
   ```

3. **Access the application:**

   - Application: http://localhost:3001
   - Health check: http://localhost:3001/health
   - Students page: http://localhost:3001/students

4. **When ready for deployment:**

   ```bash
   # Tag for Docker Hub
   docker tag clementime-gcloud-local:latest your-username/clementime:latest.gcloud

   # Push to Docker Hub
   docker push your-username/clementime:latest.gcloud

   # Deploy to Google Cloud Run
   ./gcloud-deploy.sh
   ```

## Container Management

### View logs:

```bash
docker logs clementime-test
```

### Follow logs in real-time:

```bash
docker logs -f clementime-test
```

### Stop container:

```bash
docker stop clementime-test
```

### Remove container:

```bash
docker rm clementime-test
```

### Shell into container:

```bash
docker exec -it clementime-test sh
```

## Testing

### Health Check:

```bash
curl http://localhost:3001/health
```

### Students API:

```bash
curl http://localhost:3001/api/students/files
```

### Upload CSV (example):

```bash
curl -X POST -F "csvFile=@your-file.csv" -F "sectionId=section_01" http://localhost:3001/api/students/upload
```

## Environment Variables

The test container runs with these environment variables:

- `NODE_ENV=production`
- `PORT=3000`
- `DATABASE_PATH=/tmp/data/clementime.db`
- `SCHEDULER_DATABASE_PATH=/tmp/data/clementime.db`
- `SESSION_STORE=sqlite`
- `USE_CLOUD_STORAGE=false`

## Troubleshooting

### Container won't start:

1. Check logs: `docker logs clementime-test`
2. Ensure port 3001 is not in use: `lsof -i :3001`
3. Try a different port: `LOCAL_PORT=3002 ./test-local.sh`

### Health check fails:

1. Wait a few more seconds for the container to fully start
2. Check logs for any startup errors
3. Verify the application is listening on port 3000 inside the container

### Build fails:

1. Ensure all required files exist:
   - `Dockerfile.gcloud`
   - `gcloud-startup.sh`
   - `package.json`
   - `src/` directory
2. Check Docker daemon is running
3. Ensure you have enough disk space

## File Structure

```
├── build-local.sh              # Simple build script
├── build-and-test-local.sh     # Interactive build and test
├── test-local.sh               # Test existing image
├── Dockerfile.gcloud           # Docker build file for Google Cloud
├── gcloud-startup.sh           # Startup script for Cloud Run
├── gcloud-deploy.sh            # Deploy to Google Cloud Run
└── LOCAL_BUILD_README.md       # This file
```
