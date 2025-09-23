import { Storage, Bucket, File } from '@google-cloud/storage';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { execSync } from 'child_process';

export class CloudStorageService {
  private storage: Storage | null = null;
  private bucket: Bucket | null = null;
  private bucketName: string | null = null;
  private isEnabled: boolean;
  private localCache: Map<string, string> = new Map();

  constructor() {
    this.isEnabled = process.env.USE_CLOUD_STORAGE === 'true';
    this.bucketName = process.env.STORAGE_BUCKET || null;

    if (this.isEnabled && this.bucketName) {
      try {
        // Initialize Google Cloud Storage client
        // Will use Application Default Credentials (service account in Cloud Run)
        this.storage = new Storage();
        this.bucket = this.storage.bucket(this.bucketName);

        console.log(`☁️  Cloud Storage initialized with bucket: ${this.bucketName}`);
      } catch (error) {
        console.error('❌ Failed to initialize Cloud Storage:', error);
        this.isEnabled = false;
      }
    } else {
      console.log('📁 Using local file system (Cloud Storage disabled)');
    }
  }

  /**
   * Check if Cloud Storage is enabled and properly configured
   */
  isCloudStorageEnabled(): boolean {
    return this.isEnabled && this.bucket !== null;
  }

  /**
   * Read a file - from Cloud Storage if enabled, otherwise from local filesystem
   */
  async readFile(filePath: string): Promise<Buffer> {
    if (this.isCloudStorageEnabled() && this.bucket) {
      try {
        // Convert local path to cloud path
        const cloudPath = this.toCloudPath(filePath);
        console.log(`☁️  Reading from Cloud Storage: ${cloudPath}`);

        const file = this.bucket.file(cloudPath);
        const [contents] = await file.download();
        return contents;
      } catch (error) {
        console.error(`❌ Cloud Storage read failed for ${filePath}:`, error);
        throw error;
      }
    } else {
      // Read from local filesystem
      return fs.promises.readFile(filePath);
    }
  }

  /**
   * Synchronous read for cases where async isn't possible (like config loading)
   * Uses a cached download approach for Cloud Storage
   */
  readFileSync(filePath: string): Buffer {
    if (this.isCloudStorageEnabled() && this.bucket) {
      // For Cloud Storage, we need to use cached downloads from temp directory
      const cloudPath = this.toCloudPath(filePath);
      const cacheKey = `sync_${cloudPath}`;

      // Check if we have it cached
      if (this.localCache.has(cacheKey)) {
        const cachedPath = this.localCache.get(cacheKey)!;
        if (fs.existsSync(cachedPath)) {
          console.log(`📋 Reading cached file: ${cachedPath}`);
          return fs.readFileSync(cachedPath);
        }
      }

      // Try to download to temp and cache it
      try {
        const tempPath = path.join(os.tmpdir(), 'clementime-cache', cloudPath);
        const tempDir = path.dirname(tempPath);

        // Ensure temp directory exists
        if (!fs.existsSync(tempDir)) {
          fs.mkdirSync(tempDir, { recursive: true });
        }

        // Synchronously download using child_process (blocking but necessary)
        const bucketName = this.bucketName;

        try {
          // Use gsutil for sync download if available in container
          execSync(`gsutil cp "gs://${bucketName}/${cloudPath}" "${tempPath}"`, {
            stdio: 'pipe',
            timeout: 30000
          });

          this.localCache.set(cacheKey, tempPath);
          console.log(`☁️  Downloaded and cached: ${cloudPath} → ${tempPath}`);
          return fs.readFileSync(tempPath);
        } catch (gsutilError) {
          console.warn(`⚠️  gsutil download failed, trying alternative...`);
          throw new Error(`Could not download ${cloudPath} synchronously`);
        }
      } catch (error) {
        console.error(`❌ Sync Cloud Storage read failed for ${filePath}:`, error);
        throw error;
      }
    } else {
      // Read from local filesystem
      return fs.readFileSync(filePath);
    }
  }

  /**
   * Write a file - to Cloud Storage if enabled, otherwise to local filesystem
   */
  async writeFile(filePath: string, content: Buffer | string): Promise<void> {
    if (this.isCloudStorageEnabled() && this.bucket) {
      try {
        const cloudPath = this.toCloudPath(filePath);
        console.log(`☁️  Writing to Cloud Storage: ${cloudPath}`);

        const file = this.bucket.file(cloudPath);
        const buffer = Buffer.isBuffer(content) ? content : Buffer.from(content);

        await file.save(buffer, {
          metadata: {
            contentType: this.getContentType(filePath)
          }
        });

        // Also write to local /tmp for immediate access
        const tempPath = this.toTempPath(filePath);
        await this.ensureDirectoryExists(path.dirname(tempPath));
        await fs.promises.writeFile(tempPath, buffer);

      } catch (error) {
        console.error(`❌ Cloud Storage write failed for ${filePath}:`, error);
        throw error;
      }
    } else {
      // Write to local filesystem
      await this.ensureDirectoryExists(path.dirname(filePath));
      await fs.promises.writeFile(filePath, content);
    }
  }

  /**
   * Check if a file exists
   */
  async fileExists(filePath: string): Promise<boolean> {
    if (this.isCloudStorageEnabled() && this.bucket) {
      try {
        const cloudPath = this.toCloudPath(filePath);
        const file = this.bucket.file(cloudPath);
        const [exists] = await file.exists();
        return exists;
      } catch (error) {
        console.error(`❌ Cloud Storage exists check failed for ${filePath}:`, error);
        return false;
      }
    } else {
      return fs.existsSync(filePath);
    }
  }

  /**
   * List files in a directory
   */
  async listFiles(directoryPath: string): Promise<string[]> {
    if (this.isCloudStorageEnabled() && this.bucket) {
      try {
        const cloudPrefix = this.toCloudPath(directoryPath);
        const [files] = await this.bucket.getFiles({
          prefix: cloudPrefix,
          delimiter: '/'
        });

        return files.map(file => file.name);
      } catch (error) {
        console.error(`❌ Cloud Storage list failed for ${directoryPath}:`, error);
        return [];
      }
    } else {
      if (!fs.existsSync(directoryPath)) return [];
      return fs.readdirSync(directoryPath);
    }
  }

  /**
   * Delete a file
   */
  async deleteFile(filePath: string): Promise<void> {
    if (this.isCloudStorageEnabled() && this.bucket) {
      try {
        const cloudPath = this.toCloudPath(filePath);
        console.log(`☁️  Deleting from Cloud Storage: ${cloudPath}`);

        const file = this.bucket.file(cloudPath);
        await file.delete();

        // Also delete from local /tmp if exists
        const tempPath = this.toTempPath(filePath);
        if (fs.existsSync(tempPath)) {
          await fs.promises.unlink(tempPath);
        }
      } catch (error) {
        console.error(`❌ Cloud Storage delete failed for ${filePath}:`, error);
        throw error;
      }
    } else {
      if (fs.existsSync(filePath)) {
        await fs.promises.unlink(filePath);
      }
    }
  }

  /**
   * Create a directory (for local filesystem only, Cloud Storage doesn't need this)
   */
  async createDirectory(directoryPath: string): Promise<void> {
    if (!this.isCloudStorageEnabled()) {
      await this.ensureDirectoryExists(directoryPath);
    }
    // Cloud Storage doesn't require explicit directory creation
  }

  /**
   * Download a file from Cloud Storage to a temporary location
   */
  async downloadToTemp(cloudPath: string): Promise<string> {
    if (!this.isCloudStorageEnabled() || !this.bucket) {
      throw new Error('Cloud Storage is not enabled');
    }

    const tempPath = path.join(os.tmpdir(), 'clementime', cloudPath);
    await this.ensureDirectoryExists(path.dirname(tempPath));

    try {
      const file = this.bucket.file(cloudPath);
      await file.download({ destination: tempPath });
      console.log(`☁️  Downloaded ${cloudPath} to ${tempPath}`);
      return tempPath;
    } catch (error) {
      console.error(`❌ Failed to download ${cloudPath}:`, error);
      throw error;
    }
  }

  /**
   * Sync local directory with Cloud Storage
   */
  async syncFromCloud(localDir: string, cloudPrefix: string): Promise<void> {
    if (!this.isCloudStorageEnabled() || !this.bucket) {
      console.log('📁 Cloud sync skipped (using local filesystem)');
      return;
    }

    try {
      console.log(`☁️  Syncing from Cloud Storage: ${cloudPrefix} → ${localDir}`);

      const [files] = await this.bucket.getFiles({
        prefix: cloudPrefix
      });

      for (const file of files) {
        const relativePath = file.name.replace(cloudPrefix, '');
        const localPath = path.join(localDir, relativePath);

        await this.ensureDirectoryExists(path.dirname(localPath));
        await file.download({ destination: localPath });
      }

      console.log(`✅ Synced ${files.length} files from Cloud Storage`);
    } catch (error) {
      console.error('❌ Cloud sync failed:', error);
      throw error;
    }
  }

  /**
   * Sync local directory to Cloud Storage
   */
  async syncToCloud(localDir: string, cloudPrefix: string): Promise<void> {
    if (!this.isCloudStorageEnabled() || !this.bucket) {
      console.log('📁 Cloud sync skipped (using local filesystem)');
      return;
    }

    try {
      console.log(`☁️  Syncing to Cloud Storage: ${localDir} → ${cloudPrefix}`);

      const files = await this.getAllFiles(localDir);

      for (const filePath of files) {
        const relativePath = path.relative(localDir, filePath);
        const cloudPath = path.join(cloudPrefix, relativePath).replace(/\\/g, '/');

        const file = this.bucket.file(cloudPath);
        await file.save(await fs.promises.readFile(filePath), {
          metadata: {
            contentType: this.getContentType(filePath)
          }
        });
      }

      console.log(`✅ Synced ${files.length} files to Cloud Storage`);
    } catch (error) {
      console.error('❌ Cloud sync failed:', error);
      throw error;
    }
  }

  /**
   * Get database path - returns temp path for Cloud Run, local path otherwise
   */
  getDatabasePath(): string {
    if (this.isCloudStorageEnabled()) {
      // In Cloud Run, use /tmp for SQLite database
      const tempDbPath = '/tmp/clementime.db';

      // Ensure directory exists
      const dbDir = path.dirname(tempDbPath);
      if (!fs.existsSync(dbDir)) {
        fs.mkdirSync(dbDir, { recursive: true });
      }

      return tempDbPath;
    } else {
      // Local development or non-cloud deployment
      return process.env.DATABASE_PATH || path.join(process.cwd(), 'data', 'clementime.db');
    }
  }

  // Helper methods

  private toCloudPath(localPath: string): string {
    // Convert local file path to cloud storage path
    if (localPath.startsWith('/app/')) {
      return localPath.substring(5).replace(/\\/g, '/');
    }
    if (localPath.startsWith('/tmp/')) {
      return localPath.substring(5).replace(/\\/g, '/');
    }
    // Remove any absolute path prefix and use relative path
    const relativePath = localPath.replace(process.cwd() + '/', '');
    return relativePath.replace(/\\/g, '/');
  }

  private toTempPath(filePath: string): string {
    // Convert to a path in /tmp for local caching
    const relativePath = this.toCloudPath(filePath);
    return path.join('/tmp', relativePath);
  }

  private async ensureDirectoryExists(dir: string): Promise<void> {
    if (!fs.existsSync(dir)) {
      await fs.promises.mkdir(dir, { recursive: true });
    }
  }

  private getContentType(filePath: string): string {
    const ext = path.extname(filePath).toLowerCase();
    const contentTypes: Record<string, string> = {
      '.json': 'application/json',
      '.csv': 'text/csv',
      '.txt': 'text/plain',
      '.yml': 'text/yaml',
      '.yaml': 'text/yaml',
      '.db': 'application/x-sqlite3',
      '.html': 'text/html',
      '.js': 'application/javascript',
      '.css': 'text/css'
    };
    return contentTypes[ext] || 'application/octet-stream';
  }

  private async getAllFiles(dir: string, files: string[] = []): Promise<string[]> {
    const items = await fs.promises.readdir(dir, { withFileTypes: true });

    for (const item of items) {
      const fullPath = path.join(dir, item.name);
      if (item.isDirectory()) {
        await this.getAllFiles(fullPath, files);
      } else {
        files.push(fullPath);
      }
    }

    return files;
  }
}

// Singleton instance
export const cloudStorage = new CloudStorageService();