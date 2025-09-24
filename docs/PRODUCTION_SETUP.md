# Production Setup Guide

This guide covers the two new critical features added for production readiness:

## 1. Google OAuth Authentication

The dashboard now requires Google OAuth authentication to access. Only authorized users can view and manage schedules.

### Setup Steps:

1. **Configure Google OAuth Credentials**
   - Use the same Google Cloud Project credentials you set up for Google Meet
   - Add the OAuth callback URL to your authorized redirect URIs:
     ```
     http://localhost:3000/auth/google/callback  # For development
     https://yourdomain.com/auth/google/callback  # For production
     ```

2. **Set Environment Variables**
   ```bash
   # In your .env file:
   SESSION_SECRET=your-random-session-secret-here
   GOOGLE_CLIENT_ID=your-client-id  # Same as GOOGLE_MEET_CLIENT_ID
   GOOGLE_CLIENT_SECRET=your-client-secret  # Same as GOOGLE_MEET_CLIENT_SECRET
   GOOGLE_AUTH_CALLBACK_URL=http://localhost:3000/auth/google/callback
   ```

3. **Configure Authorized Users**

   Add authorized Google email addresses to your `config.yml`:
   ```yaml
   authorized_google_users:
     - "professor@university.edu"
     - "head-ta@university.edu"
     - "ta1@university.edu"
     - "ta2@university.edu"
   ```

4. **Managing Users**
   - Once logged in, admins can visit `/admin/users` to add/remove authorized users
   - Users can be added through the web interface or config file
   - All users must authenticate with their Google account

### Authentication Flow:
1. User visits the dashboard
2. If not authenticated, redirected to login page
3. User clicks "Sign in with Google"
4. Google validates the user
5. System checks if user's email is in authorized list
6. If authorized, user gains access to dashboard

## 2. SQLite Database Persistence

All schedule data is now automatically saved to a local SQLite database for persistence.

### Database Features:

1. **Automatic Database Creation**
   - Database file is created at: `data/clementime.db`
   - All tables are automatically initialized on first run

2. **Data Persistence**
   - Schedules are saved whenever generated
   - Schedule data persists across server restarts
   - Previous schedules are automatically loaded on startup

3. **Workflow Tracking**
   - Every workflow run is tracked with status and statistics
   - API endpoint available at `/api/workflow-runs` to view history

4. **User Management**
   - Authorized users are stored in database
   - Login history is tracked
   - Session management for secure access

### Database Location:
- Default: `data/clementime.db` in your project directory
- The database file can be backed up by copying this file
- To reset all data, delete the database file (it will be recreated)

### Database Schema:
- `schedules` - Stores all schedule slot data
- `authorized_users` - Manages dashboard access
- `sessions` - Handles user sessions
- `workflow_runs` - Tracks automation runs

## Security Best Practices

1. **Session Secret**
   - Always set a strong `SESSION_SECRET` in production
   - Use a random string at least 32 characters long
   - Never commit this to version control

2. **HTTPS in Production**
   - Always use HTTPS in production environments
   - Update callback URLs accordingly
   - Session cookies are configured for secure transport

3. **Database Backups**
   - Regularly backup the `data/clementime.db` file
   - Consider automated backup solutions for production
   - Test restore procedures periodically

4. **Access Control**
   - Regularly review authorized users list
   - Remove access for users who no longer need it
   - Monitor login activity through database records

## Verification Steps

1. **Test Authentication:**
   ```bash
   npm run web
   # Visit http://localhost:3000
   # Should redirect to login page
   # Test with authorized and unauthorized accounts
   ```

2. **Check Database:**
   ```bash
   # After generating schedules, check database exists:
   ls -la data/clementime.db

   # You can inspect the database with any SQLite client:
   sqlite3 data/clementime.db
   .tables  # Show all tables
   SELECT COUNT(*) FROM schedules;  # Count saved schedules
   SELECT * FROM authorized_users;  # View authorized users
   ```

3. **Test Persistence:**
   - Generate schedules through the dashboard
   - Restart the server
   - Verify schedules are still visible

## Troubleshooting

### Authentication Issues:
- Ensure Google OAuth credentials are correctly set
- Check callback URL matches configuration
- Verify user email is in authorized list
- Check browser console for errors

### Database Issues:
- Ensure `data/` directory has write permissions
- Check disk space availability
- Verify SQLite is installed (comes with better-sqlite3)
- Check logs for database connection errors

### Session Issues:
- Clear browser cookies if login loops occur
- Ensure `SESSION_SECRET` is set
- Check session cookie settings for production

## Migration from Previous Version

If upgrading from a version without these features:

1. Run `npm install` to get new dependencies
2. Add `authorized_google_users` to your config.yml
3. Set required environment variables
4. First run will create the database automatically
5. Existing schedules will need to be regenerated to save to database

The system is now production-ready with secure authentication and persistent data storage!