# Quick Start Guide

Get Clementime running in 10 minutes or less.

## Choose Your Platform

### Option 1: macOS App (Recommended for Mac Users)

**Requirements**: macOS 15.0+

**Steps**:

1. **Download the latest release**
   - Go to [GitHub Releases](https://github.com/shawntz/clementime/releases)
   - Download the latest `.dmg` file (e.g., `Clementime-v25.2.0.dmg`)
   - Open the DMG and drag Clementime to your Applications folder

2. **Sign in to iCloud**
   - Ensure you're signed in to iCloud on your Mac (System Settings → Apple ID)
   - iCloud Drive must be enabled for automatic sync

3. **Launch the app**
   - Open Clementime from Applications
   - If prompted with "unidentified developer", go to System Settings → Privacy & Security and click "Open Anyway"
   - The app will launch and prompt you through onboarding

4. **Create your first course**
   - Follow the onboarding wizard to create a course
   - Import a CSV roster ([download example](./examples/roster-mac-example.csv))
   - Configure exam sessions
   - Generate your first schedule

**You're done!** The Mac app is now running with automatic iCloud sync.

---

#### Building from Source (Optional - For Developers)

If you want to build the Mac app yourself:

**Requirements**: macOS 15.0+, Xcode 15+

1. **Clone the repository**
   ```bash
   git clone https://github.com/shawntz/clementime.git
   cd clementime/clementime-mac
   ```

2. **Open in Xcode**
   ```bash
   open Clementime/Clementime.xcodeproj
   ```

3. **Build and run**
   - Click the "Play" button in Xcode (or press ⌘R)
   - The app will launch and prompt you through onboarding

---

### Option 2: Web App (Cross-Platform)

**Requirements**: Docker Desktop installed

**Steps**:

1. **Clone the repository**
   ```bash
   git clone https://github.com/shawntz/clementime.git
   cd clementime/clementime-web
   ```

2. **Start with Docker Compose**
   ```bash
   docker-compose up -d
   ```

   This starts:
   - PostgreSQL database (port 5432)
   - Redis cache (port 6379)
   - Rails API (port 3000)

3. **Setup the database**
   ```bash
   docker-compose exec web rails db:create db:migrate db:seed
   ```

4. **Install frontend dependencies**
   ```bash
   cd client
   npm install
   npm run dev
   ```

   This starts the React dev server on port 5173.

5. **Access the application**
   - Open your browser to `http://localhost:5173`
   - Login with the seeded admin account:
     - Email: `admin@example.com`
     - Password: `password`

6. **Create your first course**
   - Click "New Course" in the dashboard
   - Import a CSV roster ([download example](./examples/roster-web-example.csv))
   - Configure exam sessions
   - Generate your first schedule

**You're done!** The web app is running locally.

---

## Quick Docker Alternative (Web App)

If you prefer using the Makefile:

```bash
cd clementime/clementime-web
make quick-dev
```

This single command:
- Starts all Docker services
- Creates and migrates the database
- Seeds initial data

Then start the frontend separately:
```bash
cd client && npm install && npm run dev
```

---

## Next Steps

### For Mac App Users
- **Learn about CloudKit sharing**: Share courses with TAs via iCloud
- **Export courses**: Create `.clementime` backup files
- **Configure permissions**: Set up granular TA permissions (8 types)
- **Record exams**: Use built-in audio recording

### For Web App Users
- **Configure Slack**: Set up real-time notifications
- **Connect Canvas LMS**: Enable automatic roster imports
- **Set up file storage**: Configure Google Drive or Cloudflare R2
- **Deploy to production**: See [Full Deployment Guide](./DEPLOYMENT_GUIDE.md)

---

## Troubleshooting

### Mac App Issues

**"CloudKit not available"**
- Ensure you're signed in to iCloud (System Settings → Apple ID)
- Check that iCloud Drive is enabled
- Verify Xcode has correct entitlements configured

**Build errors in Xcode**
- Clean build folder: Product → Clean Build Folder (⇧⌘K)
- Delete derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData`
- Ensure Xcode 15+ is installed

### Web App Issues

**Database connection errors**
```bash
# Reset the database
docker-compose down -v
docker-compose up -d
docker-compose exec web rails db:create db:migrate db:seed
```

**Port already in use**
```bash
# Kill processes on ports 3000, 5173, 5432, or 6379
lsof -ti:3000 | xargs kill -9
lsof -ti:5173 | xargs kill -9
```

**Frontend won't start**
```bash
# Clear npm cache and reinstall
cd client
rm -rf node_modules package-lock.json
npm install
npm run dev
```

---

## CSV Roster Format

### Mac App Format

```csv
sis_user_id,email,full_name,section_code
student001,alice@fakeuni.edu,Alice Johnson,F25-PSYCH-10-01
student002,bob@fakeuni.edu,Bob Smith,F25-PSYCH-10-02
```

**Required columns**:
- `sis_user_id`: Unique student ID from your SIS
- `email`: Student email address
- `full_name`: Student's full name
- `section_code`: Section identifier (lecture/lab)

**Download**: [Mac App CSV Example](./examples/roster-mac-example.csv)

### Web App Format (Canvas Export Compatible)

```csv
Student,SIS User ID,SIS Login ID,Section
"Johnson, Alice Marie",student001,alice.johnson@fakeuni.edu,F25-PSYCH-10-01
"Smith, Bob Thomas",student002,bob.smith@fakeuni.edu,F25-PSYCH-10-02
```

**Required columns**:
- `Student`: Full name in "Last, First Middle" format
- `SIS User ID`: Unique student ID from your SIS
- `SIS Login ID`: Student email address (login)
- `Section`: Section identifier (lecture/lab)

**Download**: [Web App CSV Example](./examples/roster-web-example.csv)

**Canvas LMS Users**: Instead of manually creating a CSV, simply export your gradebook:
1. Go to your Canvas course → **Grades**
2. Click **Export** → **Export Entire Gradebook**
3. Upload the downloaded CSV to Clementime (extra columns are automatically ignored)

### Slack Integration (Web App Only)

To enable Slack notifications, you'll also need to export your Slack workspace members:

**How to export Slack members**:
1. Go to your Slack workspace in a web browser
2. Click on your workspace name → **Settings & administration** → **Workspace settings**
3. Click **Import/Export Data**
4. Under **Export**, click **Export member list**
5. Download the CSV file

**Example Slack Members CSV**:
```csv
username,email,status,has-2fa,has-sso,userid,fullname,displayname,expiration-timestamp
alice_j,alice.johnson@fakeuni.edu,Member,0,1,UFAKE001ABC,"Alice Johnson",Alice,
bob_smith,bob.smith@fakeuni.edu,Member,0,1,UFAKE002DEF,"Bob Smith",Bob,
```

**Download**: [Slack Members Example CSV](./examples/slack-members-example.csv)

**How the merge works**: Clementime matches students from the Canvas roster with Slack members by email address. When a match is found, the student's Slack user ID is stored, enabling direct message notifications for schedule changes.

---

## Support

Need help?
- Read the [Full Deployment Guide](./DEPLOYMENT_GUIDE.md) for production setup
- Check the [Main README](../README.md) for platform comparison
- Open an [issue on GitHub](https://github.com/shawntz/clementime/issues)
