# Cloud Storage Integration for ClemenTime

## Overview

ClemenTime now supports Google Cloud Storage for persistent data storage when deployed to Google Cloud Run. This solves the problem of ephemeral storage in Cloud Run containers.

## Features Added

### 1. **Automatic Cloud Storage Detection**
- Detects when running in Cloud Run via `USE_CLOUD_STORAGE=true` environment variable
- Automatically switches between local filesystem and Cloud Storage

### 2. **Database Persistence**
- SQLite database is backed up to Cloud Storage every 5 minutes
- Database is restored from Cloud Storage on container startup
- Ensures data persists across container restarts

### 3. **File Operations**
- All file operations (read, write, delete) work transparently with both local and cloud storage
- CSV uploads are saved to Cloud Storage when enabled
- File tree viewer shows Cloud Storage contents when deployed

### 4. **Configuration Management**
- `config.yml` is loaded from Cloud Storage when available
- Section mappings are stored in both database and Cloud Storage
- Automatic sync between local and cloud storage

## Environment Variables

```bash
# Enable Cloud Storage integration
USE_CLOUD_STORAGE=true

# Specify the Google Cloud Storage bucket name
STORAGE_BUCKET=clementime-data-psych-10-admin-bots

# Optional: specify data mount path
DATA_MOUNT_PATH=gs://bucket-name/data
```

## Deployment

The updated `gcloud-deploy.sh` script now:

1. **Creates a Cloud Storage bucket** for persistent data
2. **Sets up a service account** with appropriate permissions
3. **Uploads local data** to the bucket during deployment
4. **Configures environment variables** for Cloud Storage
5. **Sets min instances to 1** to maintain warm containers

### Deploy Command
```bash
./gcloud-deploy.sh
```

### After Deployment

Manage your data using gsutil:

```bash
# View files in storage
gsutil ls -r gs://clementime-data-psych-10-admin-bots

# Download database backup
gsutil cp gs://clementime-data-psych-10-admin-bots/data/clementime.db ./backup.db

# Upload CSV files
gsutil cp students.csv gs://clementime-data-psych-10-admin-bots/uploads/

# Sync local data to cloud
gsutil -m rsync -r ./data gs://clementime-data-psych-10-admin-bots/data
```

## Architecture

```
┌──────────────────────┐
│   Cloud Run          │
│  ┌────────────────┐  │
│  │  ClemenTime    │  │         ┌─────────────────┐
│  │  Application   │◄─┼────────►│  Cloud Storage  │
│  └────────────────┘  │         │                 │
│  ┌────────────────┐  │         │  ├── config.yml │
│  │  /tmp (temp)   │  │         │  ├── data/      │
│  │  └── cache     │  │         │  ├── uploads/   │
│  └────────────────┘  │         │  └── students/  │
└──────────────────────┘         └─────────────────┘
```

## Code Components

### 1. **CloudStorageService** (`src/utils/cloud-storage.ts`)
- Main service for handling Cloud Storage operations
- Provides unified API for both local and cloud storage
- Handles file operations, syncing, and caching

### 2. **DatabaseService Updates** (`src/database/index.ts`)
- Downloads database from Cloud Storage on startup
- Periodic backups to Cloud Storage every 5 minutes
- Automatic database path resolution

### 3. **WebServer Updates** (`src/web/server.ts`)
- Cloud Storage file tree viewer
- CSV upload to Cloud Storage
- Async initialization for Cloud Storage

### 4. **ConfigLoader Updates** (`src/utils/config-loader.ts`)
- Loads config.yml from Cloud Storage when available
- Falls back to local config if cloud not available

## Benefits

1. **Data Persistence**: All data persists across container restarts and scaling events
2. **Automatic Backups**: Database and files are automatically backed up to Cloud Storage
3. **Scalability**: Multiple container instances can share the same data
4. **Cost Effective**: Only pay for storage used, no need for persistent disks
5. **Easy Management**: Use gsutil commands to manage data directly

## Testing

Run the test script to verify Cloud Storage integration:

```bash
# Test with local filesystem (default)
node test-cloud-storage.js

# Test with Cloud Storage (requires GCP credentials)
USE_CLOUD_STORAGE=true STORAGE_BUCKET=your-bucket node test-cloud-storage.js
```

## Troubleshooting

### Issue: Files not persisting
- Check that `USE_CLOUD_STORAGE=true` is set
- Verify the service account has proper permissions
- Check Cloud Run logs for storage errors

### Issue: Database not loading
- Ensure database exists in Cloud Storage
- Check that database backup is running (every 5 minutes)
- Verify `/tmp` directory has write permissions

### Issue: Config not loading
- Check that config.yml is uploaded to Cloud Storage
- Verify bucket name is correct in environment variables
- Check service account permissions

## Migration from Local to Cloud

1. Upload existing data to Cloud Storage:
   ```bash
   gsutil -m rsync -r ./data gs://your-bucket/data
   gsutil cp config.yml gs://your-bucket/config.yml
   ```

2. Deploy with new configuration:
   ```bash
   ./gcloud-deploy.sh
   ```

3. Verify data is accessible:
   ```bash
   gsutil ls gs://your-bucket/
   ```

## Security Considerations

- Service account has minimal required permissions (Storage Object Admin)
- Data is encrypted at rest in Cloud Storage
- Access is controlled via IAM policies
- No public access to storage bucket