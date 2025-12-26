# Deployment Guide

Complete guide for deploying Clementime in production environments.

## Table of Contents

- [Deployment Options](#deployment-options)
- [Option 1: Local Docker Deployment](#option-1-local-docker-deployment)
- [Option 2: Render.com Deployment](#option-2-rendercom-deployment)
- [Option 3: Custom Docker Host](#option-3-custom-docker-host)
- [macOS App Distribution](#macos-app-distribution)
- [Environment Variables](#environment-variables)
- [Post-Deployment Setup](#post-deployment-setup)
- [Monitoring and Maintenance](#monitoring-and-maintenance)
- [Troubleshooting](#troubleshooting)

---

## Deployment Options

Clementime offers multiple deployment strategies:

| Option | Best For | Complexity | Cost |
|--------|----------|------------|------|
| **Local Docker** | Development, single-institution testing | Low | Free |
| **Render.com** | Production, automatic scaling, managed services | Low | $7-25/month |
| **Custom Docker Host** | Full control, existing infrastructure | Medium | Variable |
| **macOS App** | Individual instructors, offline use | Low | Free |

---

## Option 1: Local Docker Deployment

Deploy the web app on a local server or cloud VM using Docker Compose.

### Prerequisites

- Docker Desktop (or Docker Engine + Docker Compose)
- 2GB+ RAM available
- 10GB+ disk space

### Step 1: Clone and Configure

```bash
# Clone repository
git clone https://github.com/shawntz/clementime.git
cd clementime/clementime-web
```

### Step 2: Create Environment File

Create a `.env` file in `clementime-web/` directory:

```bash
# Database
DATABASE_URL=postgres://clementime:clementime@db:5432/clementime_production
REDIS_URL=redis://redis:6379/0

# Rails
RAILS_ENV=production
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true

# Generate this with: docker-compose run web rails secret
SECRET_KEY_BASE=your_secret_key_here_minimum_64_characters_generate_with_rails_secret

# Optional: Slack Integration
SLACK_CLIENT_ID=your_slack_client_id
SLACK_CLIENT_SECRET=your_slack_client_secret
SLACK_REDIRECT_URI=http://your-domain.com/api/auth/slack/callback

# Optional: Cloudflare R2 Storage (S3-compatible)
R2_ACCESS_KEY_ID=your_r2_access_key
R2_SECRET_ACCESS_KEY=your_r2_secret_key
R2_BUCKET=clementime-recordings
R2_ENDPOINT=https://your-account-id.r2.cloudflarestorage.com
R2_REGION=auto
```

### Step 3: Generate Secret Key

```bash
# Generate SECRET_KEY_BASE
docker-compose run --rm web rails secret

# Copy the output to your .env file
```

### Step 4: Build and Start Services

```bash
# Build Docker images
docker-compose -f docker-compose.production.yml build

# Start all services in detached mode
docker-compose -f docker-compose.production.yml up -d
```

This starts:
- PostgreSQL database (internal port 5432)
- Redis cache (internal port 6379)
- Rails web server (port 3000)

### Step 5: Initialize Database

```bash
# Create database and run migrations
docker-compose -f docker-compose.production.yml exec web rails db:create db:migrate

# Create admin user
docker-compose -f docker-compose.production.yml exec web rails console
```

In the Rails console:
```ruby
User.create!(
  email: 'admin@yourinstitution.edu',
  password: 'secure_password_here',
  password_confirmation: 'secure_password_here',
  role: 'admin'
)
exit
```

### Step 6: Build Frontend Assets

```bash
# Install frontend dependencies
cd client
npm install

# Build production assets
npm run build

# Copy built files to Rails public directory
cp -r dist/* ../public/
```

### Step 7: Access Your Deployment

Open your browser to:
- **Production**: `http://localhost:3000` (or your server's IP)
- **Login** with the admin credentials you created

### Managing the Deployment

```bash
# View logs
docker-compose -f docker-compose.production.yml logs -f

# Stop services
docker-compose -f docker-compose.production.yml down

# Restart services
docker-compose -f docker-compose.production.yml restart

# Update to latest version
git pull origin main
docker-compose -f docker-compose.production.yml build
docker-compose -f docker-compose.production.yml up -d
docker-compose -f docker-compose.production.yml exec web rails db:migrate
```

---

## Option 2: Render.com Deployment

Deploy to Render.com with automatic scaling and managed PostgreSQL/Redis.

### Prerequisites

- GitHub account
- Render.com account (free tier available)

### Step 1: Fork the Repository

1. Go to https://github.com/shawntz/clementime
2. Click "Fork" to create your own copy
3. Clone your fork locally

### Step 2: Push to Your GitHub

```bash
git clone https://github.com/YOUR_USERNAME/clementime.git
cd clementime/clementime-web
```

### Step 3: Deploy via Render Blueprint

The repository includes a `render.yaml` blueprint that automatically configures:
- PostgreSQL database (Starter plan)
- Redis instance (Starter plan)
- Web service (Docker-based)

**Deploy using the Render Blueprint**:

1. Log in to [Render Dashboard](https://dashboard.render.com)
2. Click "New" → "Blueprint"
3. Connect your GitHub account if not already connected
4. Select your forked `clementime` repository
5. Render will detect the `render.yaml` file in `/clementime-web`
6. Click "Apply" to create all services

### Step 4: Configure Environment Variables

Render automatically configures:
- `DATABASE_URL` (from PostgreSQL service)
- `REDIS_URL` (from Redis service)
- `SECRET_KEY_BASE` (auto-generated)
- `RAILS_ENV=production`
- `RAILS_SERVE_STATIC_FILES=true`
- `RAILS_LOG_TO_STDOUT=true`

**Add optional integrations** (in Render dashboard → clementime service → Environment):

**Slack Integration**:
```
SLACK_CLIENT_ID=your_slack_client_id
SLACK_CLIENT_SECRET=your_slack_client_secret
SLACK_REDIRECT_URI=https://your-app.onrender.com/api/auth/slack/callback
```


**Cloudflare R2 Storage**:
```
R2_ACCESS_KEY_ID=your_r2_access_key
R2_SECRET_ACCESS_KEY=your_r2_secret_key
R2_BUCKET=clementime-recordings
R2_ENDPOINT=https://your-account-id.r2.cloudflarestorage.com
R2_REGION=auto
```

### Step 5: Initialize Database

Once deployment completes:

```bash
# Open a shell on your Render service
# (via Render Dashboard → clementime → Shell tab)

# Run migrations
rails db:migrate

# Create admin user
rails console
```

In the Rails console:
```ruby
User.create!(
  email: 'admin@yourinstitution.edu',
  password: 'secure_password_here',
  password_confirmation: 'secure_password_here',
  role: 'admin'
)
exit
```

### Step 6: Access Your App

Your app is now live at:
```
https://clementime.onrender.com
```

(Replace with your actual Render URL)

### Automatic Deployments

Render automatically deploys when you push to your `main` branch:

```bash
# Make changes, commit, and push
git add .
git commit -m "Update configuration"
git push origin main

# Render automatically builds and deploys
```

### Custom Domain (Optional)

1. In Render Dashboard → clementime service → Settings
2. Scroll to "Custom Domains"
3. Add your domain (e.g., `clementime.yourinstitution.edu`)
4. Configure DNS with the provided CNAME/A records

### Render Pricing

**Starter Plan** (recommended):
- Web Service: $7/month (512MB RAM, always-on)
- PostgreSQL: $7/month (256MB RAM, 1GB storage)
- Redis: $10/month (25MB RAM)
- **Total**: ~$24/month

**Free Tier** (development only):
- Web service spins down after 15 minutes of inactivity
- No PostgreSQL or Redis on free tier
- Not recommended for production

---

## Option 3: Custom Docker Host

Deploy to any Docker-compatible host (DigitalOcean, AWS, Azure, etc.).

### Prerequisites

- Linux server with Docker installed
- Domain name (optional but recommended)
- SSH access to server

### Step 1: Server Setup

```bash
# SSH into your server
ssh user@your-server.com

# Install Docker and Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
sudo apt-get install docker-compose-plugin

# Clone repository
git clone https://github.com/shawntz/clementime.git
cd clementime/clementime-web
```

### Step 2: Configure Environment

Follow the same `.env` setup as [Option 1](#step-2-create-environment-file).

### Step 3: Deploy with Docker Compose

```bash
# Build and start
docker-compose -f docker-compose.production.yml up -d

# Initialize database
docker-compose -f docker-compose.production.yml exec web rails db:create db:migrate

# Create admin user (see Option 1, Step 5)
```

### Step 4: Set Up Reverse Proxy (Nginx)

For production deployments, use Nginx as a reverse proxy:

```bash
# Install Nginx
sudo apt-get install nginx

# Create Nginx config
sudo nano /etc/nginx/sites-available/clementime
```

Add this configuration:

```nginx
server {
    listen 80;
    server_name clementime.yourinstitution.edu;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable the site:
```bash
sudo ln -s /etc/nginx/sites-available/clementime /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Step 5: SSL with Let's Encrypt (Recommended)

```bash
# Install Certbot
sudo apt-get install certbot python3-certbot-nginx

# Generate SSL certificate
sudo certbot --nginx -d clementime.yourinstitution.edu

# Auto-renewal is configured automatically
```

---

## macOS App Distribution

### Option 1: Direct Download (Development)

Build and distribute DMG files:

```bash
cd clementime/clementime-mac

# Build archive in Xcode
# Product → Archive → Distribute App → Developer ID

# Or use the release script
cd ../
./scripts/release.sh
```

The DMG will be available in GitHub Releases.

### Option 2: Mac App Store (Future)

Mac App Store distribution is planned but not yet implemented.

### Option 3: TestFlight (Beta Testing)

For beta testing with instructors:

1. Enroll in Apple Developer Program ($99/year)
2. Configure App Store Connect
3. Upload builds via Xcode → Organizer
4. Invite testers via TestFlight

---

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | `postgres://user:pass@host:5432/db` |
| `REDIS_URL` | Redis connection string | `redis://host:6379/0` |
| `SECRET_KEY_BASE` | Rails encryption key (64+ chars) | Generate with `rails secret` |
| `RAILS_ENV` | Rails environment | `production` |

### Optional: Slack Integration

| Variable | Description | How to Get |
|----------|-------------|------------|
| `SLACK_CLIENT_ID` | Slack OAuth app client ID | Create app at api.slack.com |
| `SLACK_CLIENT_SECRET` | Slack OAuth app secret | From Slack app settings |
| `SLACK_REDIRECT_URI` | OAuth callback URL | `https://your-domain.com/api/auth/slack/callback` |

### Optional: File Storage (Cloudflare R2)

| Variable | Description | How to Get |
|----------|-------------|------------|
| `R2_ACCESS_KEY_ID` | R2 access key | Cloudflare Dashboard → R2 → Manage R2 API Tokens |
| `R2_SECRET_ACCESS_KEY` | R2 secret key | Same as above |
| `R2_BUCKET` | R2 bucket name | Create bucket in Cloudflare R2 |
| `R2_ENDPOINT` | R2 endpoint URL | `https://account-id.r2.cloudflarestorage.com` |
| `R2_REGION` | R2 region | `auto` |

---

## Post-Deployment Setup

### 1. Create Admin Account

See deployment option instructions above for creating the first admin user.

### 2. Configure System Settings

Login as admin and navigate to Settings:

- **Exam Configuration**:
  - Exam day (e.g., "Friday")
  - Start time (e.g., "13:30")
  - End time (e.g., "14:50")
  - Duration per student (e.g., 7 minutes)
  - Buffer between students (e.g., 1 minute)

- **Quarter/Semester Settings**:
  - Quarter start date
  - Total number of exams (max 5 for web app)

- **TA Scheduling**:
  - Enable/disable balanced TA scheduling

### 3. Import Student Roster

1. Prepare CSV file ([download example](./examples/roster-web-example.csv))
2. Navigate to Students → Import
3. Upload CSV and verify data
4. Assign students to sections

### 4. Set Up Slack Notifications (Optional)

1. Create Slack app at https://api.slack.com/apps
2. Enable OAuth with scopes: `chat:write`, `users:read`, `users:read.email`
3. Add redirect URL: `https://your-domain.com/api/auth/slack/callback`
4. Configure environment variables
5. Users can connect their Slack accounts via Settings

---

## Monitoring and Maintenance

### View Logs

**Docker Compose**:
```bash
docker-compose -f docker-compose.production.yml logs -f web
```

**Render**:
- Render Dashboard → clementime service → Logs tab

### Database Backups

**Local Docker**:
```bash
# Backup
docker-compose exec db pg_dump -U clementime clementime_production > backup.sql

# Restore
cat backup.sql | docker-compose exec -T db psql -U clementime clementime_production
```

**Render**:
- Automatic daily backups included with paid PostgreSQL plans
- Manual backups via Dashboard → Database → Backups

### Update to Latest Version

**Docker Deployment**:
```bash
git pull origin main
docker-compose -f docker-compose.production.yml build
docker-compose -f docker-compose.production.yml up -d
docker-compose -f docker-compose.production.yml exec web rails db:migrate
```

**Render**:
```bash
git pull upstream main
git push origin main
# Render automatically deploys
```

### Health Checks

**Web App Health Endpoint**:
```bash
curl https://your-domain.com/up
# Should return "ok"
```

**Database Connection**:
```bash
docker-compose exec web rails console
# In console:
ActiveRecord::Base.connection.execute("SELECT 1")
```

---

## Troubleshooting

### "Database connection failed"

**Check database is running**:
```bash
docker-compose ps
# Ensure 'db' service is Up
```

**Verify DATABASE_URL**:
```bash
docker-compose exec web env | grep DATABASE_URL
```

### "Assets not loading"

**Rebuild frontend assets**:
```bash
cd client
npm run build
cp -r dist/* ../public/
```

**Check RAILS_SERVE_STATIC_FILES**:
```bash
# Should be set to 'true' in production
echo $RAILS_SERVE_STATIC_FILES
```

### "Slack integration not working"

**Verify environment variables**:
- `SLACK_CLIENT_ID` and `SLACK_CLIENT_SECRET` are set
- `SLACK_REDIRECT_URI` matches Slack app configuration exactly
- Slack app has correct OAuth scopes enabled

**Check Slack app settings**:
- OAuth redirect URLs include your domain
- Bot token scopes: `chat:write`, `users:read`, `users:read.email`

### Performance Issues

**Check resource usage**:
```bash
docker stats
# Monitor CPU/memory usage of containers
```

**Scale up** (Render):
- Dashboard → clementime service → Settings → Instance Type
- Upgrade to higher RAM/CPU plan

**Optimize database**:
```bash
docker-compose exec web rails console
# In console:
ActiveRecord::Base.connection.execute("VACUUM ANALYZE")
```

---

## Support

For deployment assistance:

- **Documentation**: [Main README](../README.md)
- **Quick Start**: [Quick Start Guide](./QUICK_START.md)
- **Issues**: [GitHub Issues](https://github.com/shawntz/clementime/issues)
- **Discussions**: [GitHub Discussions](https://github.com/shawntz/clementime/discussions)
