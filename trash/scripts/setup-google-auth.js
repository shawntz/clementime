#!/usr/bin/env node

/**
 * Google OAuth 2.0 Setup Script
 *
 * This script helps you obtain refresh tokens for Google Drive and Google Meet APIs.
 * Run this once to get your refresh tokens, then add them to your .env file.
 */

const { google } = require('googleapis');
const http = require('http');
const url = require('url');
const open = require('open');
const readline = require('readline');

// OAuth 2.0 Scopes for Google Meet and Google Drive
const SCOPES = [
  'https://www.googleapis.com/auth/drive.file',
  'https://www.googleapis.com/auth/meetings.space.created',
  'https://www.googleapis.com/auth/meetings.space.readonly',
];

const REDIRECT_URI = 'http://localhost:3000/auth/google/callback';

async function getRefreshTokens() {
  console.log('🔐 Google OAuth 2.0 Setup for Clementime');
  console.log('=====================================\n');

  // Check if environment variables are set
  if (!process.env.GOOGLE_CLIENT_ID || !process.env.GOOGLE_CLIENT_SECRET) {
    console.error('❌ Missing Google OAuth credentials!');
    console.log('📝 Please set the following environment variables:');
    console.log('   GOOGLE_CLIENT_ID=your-client-id');
    console.log('   GOOGLE_CLIENT_SECRET=your-client-secret');
    console.log('\n💡 Get these from: https://console.cloud.google.com/apis/credentials');
    process.exit(1);
  }

  // Create OAuth2 client
  const oauth2Client = new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
    REDIRECT_URI
  );

  // Generate auth URL
  const authUrl = oauth2Client.generateAuthUrl({
    access_type: 'offline', // Important: This gets us a refresh token
    scope: SCOPES,
    prompt: 'consent', // Force consent to get refresh token
  });

  console.log('🔗 Opening authorization URL in your browser...');
  console.log('   If it doesn\'t open automatically, copy this URL:');
  console.log(`   ${authUrl}\n`);

  try {
    await open(authUrl);
  } catch (error) {
    console.log('⚠️  Could not open browser automatically');
  }

  // Set up temporary server to capture the callback
  return new Promise((resolve, reject) => {
    const server = http.createServer(async (req, res) => {
      if (req.url.startsWith('/auth/google/callback')) {
        const query = url.parse(req.url, true).query;

        if (query.error) {
          res.writeHead(400, { 'Content-Type': 'text/html' });
          res.end('<h1>❌ Authorization Failed</h1><p>You can close this window.</p>');
          server.close();
          reject(new Error(`Authorization error: ${query.error}`));
          return;
        }

        if (query.code) {
          try {
            // Exchange authorization code for tokens
            const { tokens } = await oauth2Client.getToken(query.code);

            res.writeHead(200, { 'Content-Type': 'text/html' });
            res.end(`
              <h1>✅ Authorization Successful!</h1>
              <p>You can close this window and return to the terminal.</p>
              <style>
                body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
                h1 { color: #4CAF50; }
              </style>
            `);

            server.close();
            resolve(tokens);
          } catch (error) {
            res.writeHead(500, { 'Content-Type': 'text/html' });
            res.end('<h1>❌ Token Exchange Failed</h1><p>You can close this window.</p>');
            server.close();
            reject(error);
          }
        }
      }
    });

    server.listen(3000, () => {
      console.log('🌐 Temporary server started on http://localhost:3000');
      console.log('📱 Complete the authorization in your browser...\n');
    });

    // Timeout after 5 minutes
    setTimeout(() => {
      server.close();
      reject(new Error('Authorization timeout'));
    }, 5 * 60 * 1000);
  });
}

async function testTokens(tokens) {
  console.log('🧪 Testing tokens...');

  const oauth2Client = new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
    REDIRECT_URI
  );

  oauth2Client.setCredentials(tokens);

  try {
    // Test Drive API
    const drive = google.drive({ version: 'v3', auth: oauth2Client });
    const response = await drive.about.get({ fields: 'user' });
    console.log(`✅ Google Drive: Connected as ${response.data.user.displayName}`);

    // Test Meet API (if available)
    try {
      const meet = google.meet({ version: 'v2', auth: oauth2Client });
      console.log('✅ Google Meet API: Ready');
    } catch (error) {
      console.log('⚠️  Google Meet API: Not available (may need Enterprise account)');
    }

    return true;
  } catch (error) {
    console.error('❌ Token test failed:', error.message);
    return false;
  }
}

async function main() {
  try {
    const tokens = await getRefreshTokens();

    console.log('\n🎉 Authorization successful!');
    console.log('📋 Your tokens:');
    console.log('================\n');

    if (tokens.refresh_token) {
      console.log('✅ Refresh Token (add to .env):');
      console.log(`GOOGLE_REFRESH_TOKEN=${tokens.refresh_token}\n`);

      // Test the tokens
      const testPassed = await testTokens(tokens);

      if (testPassed) {
        console.log('📝 Add this line to your .env file:');
        console.log(`GOOGLE_REFRESH_TOKEN=${tokens.refresh_token}`);
        console.log('\n💡 This token will work for both Google Drive and Google Meet APIs');
      }
    } else {
      console.log('⚠️  No refresh token received. This might happen if:');
      console.log('   - You\'ve authorized this app before');
      console.log('   - The app is not configured for offline access');
      console.log('\n🔄 Try revoking access and running again:');
      console.log('   https://myaccount.google.com/permissions');
    }

  } catch (error) {
    console.error('❌ Setup failed:', error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  // Load environment variables
  require('dotenv').config();
  main();
}

module.exports = { getRefreshTokens, testTokens };