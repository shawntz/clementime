# Cloudflare R2 Setup Guide

This guide will walk you through setting up Cloudflare R2 for storing oral exam recordings.

## Prerequisites

- A Cloudflare account (free tier available)
- Admin access to your Clementime instance

## Step 1: Create a Cloudflare Account

1. Go to [cloudflare.com](https://www.cloudflare.com)
2. Sign up for a free account if you don't have one
3. Verify your email address

## Step 2: Enable R2 Storage

1. Log in to your [Cloudflare Dashboard](https://dash.cloudflare.com)
2. In the left sidebar, click **R2**
3. Click **Purchase R2 Plan** (don't worry - free tier includes 10GB storage)
4. Accept the terms and enable R2

## Step 3: Create an R2 Bucket

1. In the R2 dashboard, click **Create bucket**
2. Enter a bucket name (e.g., `oral-exam-recordings`)
3. Choose a location (closest to your users is best)
4. Click **Create bucket**

## Step 4: Enable Public Access

⚠️ **Important**: Only do this if you want recordings to be publicly accessible via direct URLs.

1. Open your newly created bucket
2. Go to **Settings** tab
3. Scroll to **Public Access** section
4. Click **Allow Access**
5. Confirm the action
6. **Copy the Public R2.dev URL** (e.g., `https://pub-xxxxxxxxxxxxx.r2.dev`)
   - Save this - you'll need it for Step 7

## Step 5: Get Your Account ID

1. In the Cloudflare dashboard, click **R2** in the sidebar
2. On the R2 Overview page, you'll see **Account ID** in the right sidebar
3. Click to copy your Account ID
4. Save it - you'll need it for Step 7

## Step 6: Create API Tokens

1. In the R2 dashboard, click **Manage R2 API Tokens** (top right)
2. Click **Create API Token**
3. Configure the token:
   - **Token name**: `clementime-recordings` (or any name you prefer)
   - **Permissions**: Select **Object Read & Write**
   - **Specify bucket**: Select your bucket (e.g., `oral-exam-recordings`)
   - **TTL**: Leave as default or set to never expire
4. Click **Create API Token**
5. **Important**: Copy both values immediately (you won't see them again):
   - **Access Key ID** (starts with a long alphanumeric string)
   - **Secret Access Key** (longer secret string)
6. Save these securely - you'll need them for Step 7

## Step 7: Configure Clementime

1. Log in to your Clementime admin account
2. Go to **System Preferences** → **Integrations** tab
3. Scroll to the **Cloudflare R2 Storage** section
4. Fill in the following fields:

   | Field | Value | Where to Find It |
   |-------|-------|------------------|
   | **Cloudflare Account ID** | Your account ID | Step 5 |
   | **R2 Access Key ID** | Your access key | Step 6 |
   | **R2 Secret Access Key** | Your secret key | Step 6 |
   | **R2 Bucket Name** | `oral-exam-recordings` | Step 3 (your bucket name) |
   | **R2 Public URL** | `https://pub-xxxxx.r2.dev` | Step 4 |

5. Click **Save Configuration**

## Step 8: Test the Configuration

1. Go to the **TA Dashboard** and navigate to a week with exam slots
2. Click **🎙️ Record** for any exam slot
3. Record a test audio clip
4. Stop and upload the recording
5. Verify that:
   - Upload completes successfully
   - A **▶️ Play** button appears next to the recording
   - Clicking the Play button opens the recording in a new tab

## Troubleshooting

### Upload fails with "Access Denied" or "403 Forbidden"

**Solution**: Check that:
- Your API token has **Object Read & Write** permissions
- The token is scoped to the correct bucket
- Account ID, Access Key, and Secret Key are entered correctly (no extra spaces)

### Upload succeeds but Play button doesn't work

**Solution**:
- Verify that Public Access is enabled on your bucket (Step 4)
- Check that the Public R2.dev URL is correct
- Make sure you copied the full URL including `https://`

### "Bucket not found" error

**Solution**:
- Verify the bucket name is exactly correct (case-sensitive)
- Ensure the bucket exists in your Cloudflare account

### Recordings work but URLs are wrong

**Solution**:
- Double-check the Public R2.dev URL in System Preferences
- The URL should NOT end with a slash (/)
- Format: `https://pub-xxxxxxxxxxxxx.r2.dev` (no trailing slash)

## File Organization

Recordings are automatically organized in R2 with this structure:

```
your-bucket/
├── week_1/
│   ├── ta_username/
│   │   ├── Section_StudentName_Exam1_20250102_143000.webm
│   │   └── Section_StudentName_Exam1_20250102_143800.webm
├── week_2/
│   ├── ta_username/
│   │   └── ...
└── ...
```

## Cost Estimates

Cloudflare R2 pricing (as of 2025):

- **Storage**: $0.015/GB-month
  - Free tier: 10GB included
- **Class A Operations** (writes): $4.50/million requests
  - Free tier: 1 million/month included
- **Class B Operations** (reads): $0.36/million requests
  - Free tier: 10 million/month included
- **Egress**: FREE (no bandwidth charges)

**Example**: For 100 students × 5 exams × 5MB/recording = 2.5GB storage
- Cost: ~$0.04/month (well within free tier)

## Security Notes

1. **API Keys**: Never commit API keys to git or share them publicly
2. **Public Access**: If you disable public access, recordings won't be playable via the Play button
3. **Bucket Permissions**: Only grant the minimum required permissions to API tokens
4. **Access Logs**: Enable R2 access logs if you need to track who accessed recordings

## Next Steps

- Configure automatic backups of recordings
- Set up lifecycle policies to archive old recordings
- Consider using custom domains instead of R2.dev URLs

## Support

If you encounter issues:
1. Check Cloudflare R2 status: https://www.cloudflarestatus.com
2. Review R2 documentation: https://developers.cloudflare.com/r2/
3. Check Clementime logs for specific error messages
