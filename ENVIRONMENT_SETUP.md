# ClemenTime Environment Setup Guide

## 🚀 Quick Start

### For Local Development:

```bash
./start-dev.sh
```

### For Production:

```bash
./start-prod.sh
```

## 🔧 Environment Configuration

### 1. OAuth Callback URLs

Your existing `.env.example` already has the OAuth callback URL configuration. Here's how to set it up:

#### Local Development:

```bash
GOOGLE_AUTH_CALLBACK_URL=http://localhost:3000/auth/google/callback
```

#### Production:

```bash
GOOGLE_AUTH_CALLBACK_URL=https://your-domain.com/auth/google/callback
```

### 2. Google Cloud Console Setup

In your Google Cloud Console OAuth 2.0 Client:

**Authorized JavaScript origins:**

- `http://localhost:3000` (for development)
- `https://your-domain.com` (for production)

**Authorized redirect URIs:**

- `http://localhost:3000/auth/google/callback` (for development)
- `https://your-domain.com/auth/google/callback` (for production)

### 3. Environment Variables

Your `.env.example` file already contains all the necessary environment variables. Copy it to `.env` and fill in your values:

```bash
cp .env.example .env
# Edit .env with your actual credentials
```

### 4. Security Settings

The startup scripts automatically configure security settings:

#### Development (`start-dev.sh`):

- `COOKIE_SECURE=false` (works with HTTP)
- `COOKIE_HTTPONLY=true`
- `COOKIE_SAMESITE=lax`

#### Production (`start-prod.sh`):

- `COOKIE_SECURE=true` (requires HTTPS)
- `COOKIE_HTTPONLY=true`
- `COOKIE_SAMESITE=strict`

## 🔍 Troubleshooting

### Port Already in Use

The development script automatically kills processes on port 3000. If you still have issues:

```bash
# Find and kill process on port 3000
lsof -ti:3000 | xargs kill -9

# Or use a different port
export PORT=3001
./start-dev.sh
```

### OAuth Issues

1. Make sure your callback URLs match exactly in Google Cloud Console
2. Check that your `.env` file has the correct `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`
3. Verify the `GOOGLE_AUTH_CALLBACK_URL` matches your environment

### Authentication Not Working

1. Check the console output for OAuth configuration details
2. Verify your user email is in the `authorized_google_users` list in `config.yml`
3. Make sure your Google account has access to the OAuth application

## 📋 Environment Checklist

### Development:

- [ ] `.env` file created from `.env.example`
- [ ] Google OAuth credentials configured
- [ ] Callback URL set to `http://localhost:3000/auth/google/callback`
- [ ] User email added to `authorized_google_users` in `config.yml`
- [ ] Run `./start-dev.sh`

### Production:

- [ ] `.env` file with production credentials
- [ ] Google OAuth credentials configured
- [ ] Callback URL set to `https://your-domain.com/auth/google/callback`
- [ ] HTTPS enabled on your domain
- [ ] User emails added to `authorized_google_users` in `config.yml`
- [ ] Run `./start-prod.sh`

## 🔐 Security Notes

1. **Never commit `.env` files** to version control
2. **Use strong session secrets** in production
3. **Enable HTTPS** in production (required for secure cookies)
4. **Limit OAuth scopes** to only what's needed
5. **Regularly rotate** API keys and tokens

## 🚀 Deployment

### Local Development:

```bash
./start-dev.sh
```

### Production (with your domain):

```bash
# Update GOOGLE_AUTH_CALLBACK_URL in .env
export GOOGLE_AUTH_CALLBACK_URL="https://your-domain.com/auth/google/callback"
./start-prod.sh
```

### Docker:

```bash
# Development
docker-compose up

# Production
docker-compose -f docker-compose.prod.yml up
```

The system is now properly configured to handle both local development and production environments with appropriate OAuth callback URLs and security settings!
