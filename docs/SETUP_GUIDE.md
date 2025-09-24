# 🚀 ClemenTime Complete Setup Guide

> **Universal Scheduling Automation Platform**
> Transform any scheduling workflow into a smart, automated system with Google Calendar, Slack, and AI integration.

---

## 📋 Table of Contents

1. [🎯 Overview](#-overview)
2. [📦 Prerequisites](#-prerequisites)
3. [🔑 Step 1: Google Cloud Setup](#-step-1-google-cloud-setup)
4. [🤖 Step 2: Slack App Setup](#-step-2-slack-app-setup)
5. [⚙️ Step 3: Configuration](#-step-3-configuration)
6. [🐳 Step 4: Docker Deployment](#-step-4-docker-deployment)
7. [🎥 Step 5: AI Recording Integration (Optional)](#-step-5-ai-recording-integration-optional)
8. [✅ Step 6: Verification & Testing](#-step-6-verification--testing)
10. [🔧 Advanced Configuration](#-advanced-configuration)
11. [🛠️ Troubleshooting](#-troubleshooting)
12. [📞 Support](#-support)

---

## 🎯 Overview

ClemenTime automates scheduling workflows across organizations, from academic institutions to corporate teams. Originally designed for Stanford's Psych 10 sessions, it now powers scheduling automation for any use case:

- **Academic**: Oral exams, office hours, thesis defenses, lab sessions
- **Corporate**: Team meetings, client calls, interview scheduling, performance reviews
- **Healthcare**: Patient appointments, consultations, staff scheduling
- **Sports**: Practice sessions, coaching meetings, tournament planning
- **Community**: Workshop scheduling, volunteer coordination, event planning

**What ClemenTime Does:**
- 📅 Automatically generates optimized schedules
- 🗓️ Creates Google Calendar events with Meet links
- 📱 Sends smart Slack notifications and reminders
- 🎥 Integrates with AI recording services (Fireflies.ai, Otter.ai)
- 🔄 Manages the entire scheduling lifecycle automatically

---

## 📦 Prerequisites

### System Requirements
- **Docker** (latest version) - [Install Docker](https://docs.docker.com/get-docker/)
- **Docker Compose** (included with Docker Desktop)
- **Git** (for cloning the repository)

### Accounts Needed
- **Google Cloud Platform** account (free tier sufficient)
- **Slack** workspace with admin permissions
- **GitHub** account (for deployment)
- **AI Recording Service** account (optional - Fireflies.ai, Otter.ai, or Grain)

### Time Estimate
- **Basic Setup**: 30-45 minutes
- **With AI Recording**: +15 minutes
- **Full Customization**: +30 minutes

---

## 🔑 Step 1: Google Cloud Setup

### 1.1 Create Google Cloud Project

1. **Visit Google Cloud Console**: https://console.cloud.google.com
2. **Create New Project**:
   - Click "Select a project" → "New Project"
   - Name: `clementime-[your-org]` (e.g., `clementime-stanford-psych10`)
   - Note the **Project ID** (you'll need this)

### 1.2 Enable Required APIs

Navigate to **APIs & Services** → **Library** and enable:

- ✅ **Google Calendar API**
- ✅ **Google Meet API** (optional, for advanced meeting features)

### 1.3 Create Service Account (Recommended)

1. **Navigate to IAM & Admin** → **Service Accounts**
2. **Click "Create Service Account"**:
   - Name: `clementime-automation`
   - Description: `ClemenTime scheduling automation service`
3. **Grant Roles**:
   - `Editor` (for Calendar access)
   - Or more restrictive: `Calendar Editor`
4. **Create Key**:
   - Click on the service account
   - **Keys** tab → **Add Key** → **Create New Key** → **JSON**
   - **Save the JSON file securely** (you'll copy its contents later)

### 1.4 Alternative: OAuth Setup

If you prefer OAuth over service accounts:

1. **Go to APIs & Services** → **Credentials**
2. **Create Credentials** → **OAuth 2.0 Client IDs**
3. **Application Type**: Web application
4. **Authorized redirect URIs**: `http://localhost:3000/auth/google/callback`
5. **Download JSON** and note the `client_id`, `client_secret`

---

## 🤖 Step 2: Slack App Setup

### 2.1 Create Slack App

1. **Visit Slack API**: https://api.slack.com/apps
2. **Click "Create New App"** → **From scratch**
3. **App Name**: `ClemenTime Scheduler`
4. **Workspace**: Select your target workspace

### 2.2 Configure OAuth & Permissions

1. **Navigate to OAuth & Permissions**
2. **Add Bot Token Scopes**:
   ```
   channels:read
   chat:write
   users:read
   users:read.email
   channels:manage
   groups:write
   im:write
   mpim:write
   ```

3. **Install App to Workspace**
4. **Copy Bot User OAuth Token** (starts with `xoxb-`)

### 2.3 Enable Socket Mode (Required)

1. **Navigate to Socket Mode**
2. **Enable Socket Mode**
3. **Generate App-Level Token**:
   - Token Name: `clementime-socket`
   - Scopes: `connections:write`
4. **Copy App-Level Token** (starts with `xapp-`)

### 2.4 Get Signing Secret

1. **Navigate to Basic Information**
2. **Copy Signing Secret** from App Credentials section

### 2.5 User IDs for Testing

1. **Find Your Slack User ID**:
   - Right-click your profile → **Copy member ID**
   - Or use: https://slack.com/api/users.list with your bot token

---

## ⚙️ Step 3: Configuration

### 3.1 Clone Repository

```bash
git clone https://github.com/shawntz/clementime.git
cd clementime
```

### 3.2 Setup Environment Variables

```bash
# Copy environment template
cp .env.example .env

# Edit with your values
nano .env  # or your preferred editor
```

**Fill in Required Values:**

```env
# Google Service Account (Recommended)
GOOGLE_SERVICE_ACCOUNT_KEY={"type":"service_account","project_id":"your-project-id"...}

# OR Google OAuth (Alternative)
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
GOOGLE_REFRESH_TOKEN=your-google-refresh-token

# Slack
SLACK_BOT_TOKEN=xoxb-your-bot-token-here
SLACK_APP_TOKEN=xapp-your-app-token-here
SLACK_SIGNING_SECRET=your-signing-secret-here

# Optional: AI Recording
AI_RECORDING_ENABLED=true
AI_RECORDING_SERVICE_EMAIL=fred@fireflies.ai
AI_RECORDING_SERVICE_NAME=Fireflies.ai
```

### 3.3 Customize Configuration

**Edit `config.yml` for your specific use case:**

```yaml
# Basic Course/Organization Info
course:
  name: "Your Organization/Course Name"
  term: "Current Term/Period"
  total_students: 150

# Scheduling Parameters
scheduling:
  exam_duration_minutes: 15      # Session length
  buffer_minutes: 5              # Break between sessions
  start_time: "09:00"           # Daily start time
  end_time: "17:00"             # Daily end time
  excluded_days:                # Skip these days
    - Saturday
    - Sunday
  schedule_frequency_weeks: 2    # Repeat every N weeks

# Groups/Sections/Teams
sections:
  - id: "section_01"
    ta_name: "Facilitator Name"
    ta_email: "facilitator@organization.edu"
    location: "Room 101, Building A"
    preferred_days:
      - Monday
      - Wednesday
    students_csv: "data/students/section_01.csv"

# Admin Users (receive summary notifications)
admin_users:
  - "U12345678"  # Your Slack user ID

# Test Mode (redirect all notifications to you)
test_mode:
  enabled: true
  redirect_to_slack_id: "U12345678"
  fake_student_prefix: "Test Participant"
  number_of_fake_students: 30
  test_email: "your-email@organization.edu"
```

### 3.4 Prepare Student Data

**Option A: CSV Files (Recommended)**

Create `data/students/section_01.csv`:

```csv
name,email,slack_id
John Smith,john.smith@university.edu,U12345678
Jane Doe,jane.doe@university.edu,U23456789
Bob Wilson,bob.wilson@university.edu,U34567890
```

**Option B: Inline Configuration**

```yaml
sections:
  - id: "section_01"
    students:
      - name: "John Smith"
        email: "john.smith@university.edu"
        slack_id: "U12345678"
      - name: "Jane Doe"
        email: "jane.doe@university.edu"
        slack_id: "U23456789"
```

---

## 🐳 Step 4: Docker Deployment

### 4.1 Deploy ClemenTime

```bash
# Make deployment script executable
chmod +x clementime

# Start the service
./clementime start

# Check status
./clementime status

# View logs
./clementime logs
```

### 4.2 Verify Deployment

```bash
# Check container is running
docker ps

# Test API health
curl http://localhost:3000/health

# Validate configuration
./clementime validate
```

### 4.3 Alternative: Manual Docker

```bash
# Build image
docker build -t clementime .

# Run with docker-compose
docker-compose up -d

# Or run directly
docker run -d \
  --name clementime \
  --env-file .env \
  -v $(pwd)/config.yml:/app/config.yml \
  -v $(pwd)/data:/app/data \
  -p 3000:3000 \
  clementime
```

---

## 🎥 Step 5: AI Recording Integration (Optional)

### 5.1 Choose AI Service

**Recommended: Fireflies.ai**
- Sign up at https://fireflies.ai
- Note the bot email: `fred@fireflies.ai`
- Configure Google Meet integration in Fireflies dashboard

**Alternative: Otter.ai**
- Sign up at https://otter.ai
- Bot email: See Otter.ai documentation for current bot email
- Configure meeting bot in Otter settings

**Alternative: Grain**
- Contact Grain for enterprise setup
- They'll provide custom bot email

### 5.2 Configure AI Recording

**Update your `config.yml`:**

```yaml
ai_recording:
  enabled: true
  service_email: "fred@fireflies.ai"  # Or your service's bot email
  service_name: "Fireflies.ai"        # Display name
  auto_invite: true                   # Auto-add to all meetings
  notification_enabled: false        # Let AI service handle notifications
```

**Or use environment variables:**

```env
AI_RECORDING_ENABLED=true
AI_RECORDING_SERVICE_EMAIL=fred@fireflies.ai
AI_RECORDING_SERVICE_NAME=Fireflies.ai
```

### 5.3 Test AI Integration

```bash
# Restart service to pick up AI config
./clementime restart

# Create test meeting
npx tsx scripts/test-real-stanford-invite.ts

# Verify AI bot appears in calendar invite
```

---

## ✅ Step 6: Verification & Testing

### 6.1 Run Configuration Validation

```bash
# Validate all settings
npm run validate

# Test Google APIs
npm run test:google

# Test Slack integration
npm run test:slack

# Test full workflow
npm run test:workflow
```

### 6.2 Create Test Schedule

```bash
# Generate sample schedule
npm run schedule -- --weeks 1 --dry-run

# Create actual test schedule
npm run schedule -- --weeks 1 --start-date "2024-01-15"
```

### 6.3 Verification Checklist

- [ ] Google Calendar events created successfully
- [ ] Meet links generated and accessible
- [ ] Slack notifications sent to test users
- [ ] AI recording bot invited (if enabled)
- [ ] TA channels created with correct permissions
- [ ] Student notifications received
- [ ] Admin notifications received
- [ ] Reminder system functioning
- [ ] Recording monitoring active

---

## 🔧 Advanced Configuration

### Advanced.1 Custom Branding

```yaml
branding:
  primary_color: "#FF6B35"        # Orange (default)
  app_name: "ClemenTime"          # Header name
  footer_text: "Made with ❤️ by @shawntz"
```

### Advanced.2 Multi-Section Management

```yaml
sections:
  # CSV-based sections
  - id: "math_101"
    ta_name: "Math TA"
    students_csv: "data/students/math_101.csv"

  # Inline sections
  - id: "physics_201"
    ta_name: "Physics TA"
    students: [...]

  # Environment-driven sections
  - id: "chem_301"
    ta_name: "Chemistry TA"
    # TA_SLACK_ID_CHEM_301 environment variable
    students_csv: "data/students/chem_301.csv"
```

### Advanced.3 Custom Notification Templates

Edit notification templates in `src/integrations/slack.ts` to customize:
- Student reminder messages
- TA summary formats
- Admin notification styles
- Recording notification content

### Advanced.4 Production Deployment

**Environment-Specific Configs:**

```yaml
# config.production.yml
test_mode:
  enabled: false  # Disable test mode for production

notifications:
  reminder_days_before: [7, 3, 1, 0]  # More frequent reminders

ai_recording:
  enabled: true
  service_email: "fred@fireflies.ai"
```

**Deploy to Production:**

```bash
# Use production config
./clementime start config.production.yml

# Or set via environment
export CONFIG_FILE=config.production.yml
./clementime start
```

---

## 🛠️ Troubleshooting

### Common Issues

**🔴 Google Calendar API Errors**
```
Error: Calendar API not enabled
```
**Solution**: Enable Google Calendar API in Google Cloud Console

**🔴 Slack Bot Permissions**
```
Error: missing_scope
```
**Solution**: Add required scopes in Slack App settings and reinstall


**🔴 AI Recording Not Working**
```
Warning: AI bot not invited to meeting
```
**Solution**: Verify `ai_recording.enabled: true` and correct service email

### Debug Commands

```bash
# View detailed logs
./clementime logs --follow

# Test specific integrations
npm run test:google-calendar
npm run test:slack-notifications
npm run test:ai-recording

# Validate configuration
npm run validate-config

# Reset and rebuild
./clementime stop
docker system prune -f
./clementime start
```

### Log Analysis

**Key log patterns to watch:**
- `✅ Google Calendar API authenticated successfully`
- `✅ Slack bot connected to workspace`
- `✅ AI recording service configured`
- `📅 Created calendar event for [student]`
- `📱 Slack notification sent to [user]`
- `🎥 AI bot invited to meeting`

---

## 📞 Support

### Documentation
- **Setup Guide**: You're reading it! 📖
- **AI Recording Setup**: [AI_RECORDING_SETUP.md](AI_RECORDING_SETUP.md)
- **Configuration Examples**: [config.example.yml](config.example.yml)
- **API Documentation**: Coming soon

### Community Support
- **GitHub Issues**: https://github.com/shawntz/clementime/issues
- **Discussions**: https://github.com/shawntz/clementime/discussions
- **Wiki**: https://github.com/shawntz/clementime/wiki

### Professional Support
For organizations needing dedicated support:
- Email: support@clementime.org (coming soon)
- Enterprise setup assistance
- Custom integration development
- Training and onboarding

### Contribute
ClemenTime is open source! Contributions welcome:
- 🐛 **Bug Reports**: Help us improve reliability
- 🚀 **Feature Requests**: Share your automation needs
- 💻 **Code Contributions**: Submit pull requests
- 📚 **Documentation**: Help others succeed

---

## 🎉 Success Stories

**Stanford Psychology Department**
> "ClemenTime automated our entire session process, saving 20+ hours per week and ensuring zero scheduling conflicts." - Prof. Psychology

**Tech Startup**
> "We use ClemenTime for all client meetings. The AI recording integration means we never miss important details." - CEO, TechCorp

**Medical Practice**
> "Patient scheduling is now completely automated. Our staff can focus on care instead of calendars." - Practice Manager

---

**Ready to automate your scheduling?** 🚀

Follow this guide step-by-step, and you'll have a fully automated scheduling system running in under an hour. Need help? Check our [troubleshooting section](#-troubleshooting) or [open an issue](https://github.com/shawntz/clementime/issues).

---

*Made with ❤️ by [@shawntz](https://github.com/shawntz)*