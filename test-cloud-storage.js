#!/usr/bin/env node

// Test Cloud Storage Integration

// Set environment variables to simulate Cloud Run
process.env.USE_CLOUD_STORAGE = 'false'; // Set to 'true' to test with real Cloud Storage
process.env.STORAGE_BUCKET = 'test-bucket';

const { cloudStorage } = require('./dist/utils/cloud-storage');

async function test() {
  console.log('🧪 Testing Cloud Storage Integration');
  console.log('====================================');

  console.log(`Cloud Storage Enabled: ${cloudStorage.isCloudStorageEnabled()}`);
  console.log(`Database Path: ${cloudStorage.getDatabasePath()}`);

  if (cloudStorage.isCloudStorageEnabled()) {
    console.log('☁️  Cloud Storage is enabled');
    console.log(`Bucket: ${process.env.STORAGE_BUCKET}`);

    try {
      // Test file operations
      const testContent = 'Hello from Cloud Storage test!';
      await cloudStorage.writeFile('test.txt', testContent);
      console.log('✅ File write successful');

      const exists = await cloudStorage.fileExists('test.txt');
      console.log(`✅ File exists check: ${exists}`);

      if (exists) {
        const content = await cloudStorage.readFile('test.txt');
        console.log(`✅ File read successful: ${content.toString()}`);

        await cloudStorage.deleteFile('test.txt');
        console.log('✅ File delete successful');
      }
    } catch (error) {
      console.error('❌ Test failed:', error.message);
    }
  } else {
    console.log('📁 Using local filesystem (Cloud Storage disabled)');
    console.log('Set USE_CLOUD_STORAGE=true to test Cloud Storage');
  }
}

test().catch(console.error);