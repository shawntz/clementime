# 🎥 AI Recording Integration Guide

ClemenTime supports automatic integration with algorithmic recording and transcription services. This eliminates the need for manual recording management while providing smart meeting insights.

## 🌟 Supported Services

### Fireflies.ai (Recommended)
- **Email**: `fred@fireflies.ai`
- **Features**: Real-time transcription, AI summaries, action items, searchable conversations
- **Dashboard**: https://app.fireflies.ai
- **Setup**: Sign up at fireflies.ai, get the bot email

### Otter.ai
- **Email**: See Otter.ai documentation for current bot email
- **Features**: Live transcription, speaker identification, meeting notes
- **Dashboard**: https://otter.ai
- **Setup**: Sign up at otter.ai, configure meeting bot for Google Meet

### Grain
- **Email**: Custom bot email provided by Grain
- **Features**: Video highlights, automatic clips, team insights
- **Dashboard**: https://grain.co
- **Setup**: Contact Grain for enterprise setup

### Other Services
The system supports any AI recording service that works via calendar invitations. Simply configure the bot email in your settings.

## 🚀 Quick Setup

### Option 1: Configuration File (Recommended)

Edit your `config.yml` file:

```yaml
# AI Recording Integration
ai_recording:
  enabled: true
  service_email: "fred@fireflies.ai"  # Bot email for your AI service
  service_name: "Fireflies.ai"        # Display name
  auto_invite: true                   # Automatically invite to all meetings
  notification_enabled: false        # Let AI service handle notifications
```

### Option 2: Environment Variables

Add to your `.env` file:

```env
AI_RECORDING_ENABLED=true
AI_RECORDING_SERVICE_EMAIL=fred@fireflies.ai
AI_RECORDING_SERVICE_NAME=Fireflies.ai
```

## 📋 Step-by-Step Setup Guide

### Step 1: Choose Your AI Recording Service

1. **Sign up** for your preferred service (Fireflies.ai recommended)
2. **Get the bot email** (usually provided in service documentation)
3. **Configure your account** for Google Meet/Calendar integration

### Step 2: Configure ClemenTime

1. **Edit config.yml** to enable AI recording:
   ```yaml
   ai_recording:
     enabled: true
     service_email: "fred@fireflies.ai"
     service_name: "Fireflies.ai"
     auto_invite: true
   ```

2. **Test the configuration**:
   ```bash
   npm run app -- validate
   ```

### Step 3: Verify Integration

1. **Create a test meeting** using ClemenTime
2. **Check that the AI bot** is automatically invited
3. **Verify recording starts** when meeting begins
4. **Confirm dashboard access** in your AI service

### Step 4: Production Deployment

1. **Update your production config**
2. **Restart ClemenTime**:
   ```bash
   ./clementime restart
   ```
3. **Monitor the logs** for successful AI bot invitations

## ⚙️ Configuration Options

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `enabled` | boolean | `false` | Enable/disable AI recording integration |
| `service_email` | string | Required | Bot email address for the AI service |
| `service_name` | string | Optional | Display name for logging and notifications |
| `auto_invite` | boolean | `true` | Automatically add bot to calendar invites |
| `notification_enabled` | boolean | `false` | Enable ClemenTime notifications (usually disabled when AI handles this) |

## 🔧 Advanced Configuration

### Service-Specific Setup

#### Fireflies.ai Advanced Setup
```yaml
ai_recording:
  enabled: true
  service_email: "fred@fireflies.ai"
  service_name: "Fireflies.ai"
  auto_invite: true
  notification_enabled: false
  # Additional Fireflies-specific options can be added here
```

#### Multiple Services (Not Recommended)
While possible, using multiple AI services simultaneously can cause conflicts:
```yaml
# Only use if you need multiple services
ai_recording:
  enabled: true
  service_email: "fred@fireflies.ai,your-second-service@provider.ai"
  service_name: "Fireflies.ai + Other Service"
```

### Environment-Specific Configuration

#### Development Environment
```yaml
ai_recording:
  enabled: false  # Disable in development to avoid unnecessary recordings
```

#### Production Environment
```yaml
ai_recording:
  enabled: true
  service_email: "fred@fireflies.ai"
  auto_invite: true
```

## 🚨 Important Notes

### Slack Notifications
- **When AI recording is enabled**, ClemenTime automatically **disables its own recording notifications**
- **AI services handle their own notifications** through their platforms
- **This prevents duplicate notifications** and reduces Slack noise
- **TA channels still receive** scheduling and reminder notifications

### Privacy & Security
- **AI bots only record meetings** they're invited to
- **Meeting recordings are stored** in the AI service's platform
- **Access is controlled** by the AI service's permissions
- **Data retention policies** follow the AI service's terms

### Recording Process
1. **ClemenTime creates** the Google Calendar event
2. **AI bot is automatically invited** (if enabled)
3. **Bot joins the meeting** when it starts
4. **Recording begins automatically**
5. **Transcription happens in real-time**
6. **Recordings are processed** and made available in AI dashboard
7. **ClemenTime skips Slack notifications** for recordings

## 🎯 Testing Your Setup

### Test Script
Run the comprehensive test to verify AI integration:

```bash
npm run test:ai-recording
```

Or create a test meeting manually:

```bash
npx tsx scripts/test-real-stanford-invite.ts
```

### Verification Checklist
- [ ] AI bot email appears in calendar invites
- [ ] Bot successfully joins test meetings
- [ ] Recording starts automatically
- [ ] Transcription appears in AI dashboard
- [ ] ClemenTime logs show AI service integration
- [ ] No duplicate recording notifications in Slack

## 🛠️ Troubleshooting

### AI Bot Not Invited
- Check `ai_recording.enabled` is `true`
- Verify `service_email` is correct
- Ensure `auto_invite` is `true`

### Bot Joins But Doesn't Record
- Check AI service account configuration
- Verify Google Meet recording permissions
- Review AI service dashboard for errors

### Duplicate Notifications
- Ensure `notification_enabled` is `false` in config
- Check that ClemenTime properly detects AI recording is enabled

### Recording Not Appearing in Dashboard
- Check AI service account has proper permissions
- Verify meeting was actually recorded by the AI bot
- Review AI service status page for outages

## 📞 Support

### ClemenTime Support
- GitHub Issues: https://github.com/shawntz/clementime/issues
- Documentation: https://github.com/shawntz/clementime/wiki

### AI Service Support
- **Fireflies.ai**: support@fireflies.ai
- **Otter.ai**: https://help.otter.ai
- **Grain**: support@grain.co

## 🎉 Benefits of AI Recording Integration

### For Instructors/Facilitators
- **Automatic meeting summaries** with key points
- **Action items extraction** from conversations
- **Searchable conversation history**
- **No manual recording management**

### For Students/Participants
- **Meeting notes automatically generated**
- **Key quotes and decisions captured**
- **Ability to search past meetings**
- **Never miss important information**

### For Administrators
- **Centralized recording management**
- **Analytics on meeting effectiveness**
- **Reduced support requests**
- **Compliance and audit trails**

---

**Ready to get started?** Follow the Quick Setup guide above, or check out our [complete configuration examples](config-psych10-example.yml) for real-world implementations.

Made with ❤️ by @shawntz