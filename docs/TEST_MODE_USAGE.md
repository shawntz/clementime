# Test Mode Usage Guide

## Overview
The test mode feature allows you to simulate schedule generation and Slack notifications for fake students, with all messages redirected to your personal Slack account. This is perfect for testing the system without spamming real students.

## Features
- ✅ Generates fake student data
- ✅ Creates realistic schedules for testing
- ✅ Redirects ALL Slack notifications to your account
- ✅ Clearly marks test messages with 🧪 [TEST MODE] prefix
- ✅ Shows which fake student each message was originally intended for

## Setup

### Option 1: Interactive Script (Recommended)
```bash
npm run test:mode
```

This will prompt you for:
- Your Slack user ID (e.g., `U12345678`)
- Number of fake students (default: 30)
- Fake student name prefix (default: "Test Student")
- Schedule start date and number of weeks

### Option 2: Direct API Call
With the web server running (`npm run web`), you can also call the API directly:

```bash
curl -X POST http://localhost:3000/test/generate-fake-schedules \
  -H "Content-Type: application/json" \
  -d '{
    "startDate": "2024-01-15",
    "weeks": 2,
    "numberOfFakeStudents": 20,
    "fakeStudentPrefix": "Test Student",
    "redirectToSlackId": "U12345678"
  }'
```

### Option 3: Configuration File
You can also enable test mode permanently in your `config.yml`:

```yaml
test_mode:
  enabled: true
  redirect_to_slack_id: "U12345678"  # Your Slack user ID
  fake_student_prefix: "Test Student"
  number_of_fake_students: 30
```

## Finding Your Slack User ID

1. Open Slack in your browser
2. Click on your profile picture → View profile
3. Click the three dots menu → Copy member ID
4. Use this ID (starts with `U`) in the test mode

## What You'll See

When test mode runs, you'll receive Slack messages like:

```
🧪 [TEST MODE - Originally for: Test Student 1]
📚 Oral Exam Appointment

Date: Monday, January 15, 2024
Time: 9:00 AM - 9:15 AM
Location: Room 101, Building A
TA: John Doe
🔗 Google Meet Link: https://meet.google.com/...
```

## Safety Features

- All messages are clearly marked as test mode
- Shows the original intended recipient
- No real student data is used or affected
- Test data is generated fresh each time

## Troubleshooting

### "No Slack ID" Error
Make sure you provide your actual Slack user ID (starts with `U`) when prompted.

### Messages Not Appearing
- Verify your Slack ID is correct
- Check that the Clementime bot has permission to message you
- Ensure your Slack workspace allows DMs from apps

### Server Not Responding
Make sure the web server is running:
```bash
npm run web
```

## Example Test Session

```bash
$ npm run test:mode

🧪 CLEMENTIME TEST MODE SETUP
================================

This will generate fake student schedules and send all notifications to YOUR Slack account.

Enter server URL (default: http://localhost:3000):
Enter YOUR Slack user ID (e.g., U12345678): U87654321
Number of fake students to generate (default: 30): 15
Fake student name prefix (default: "Test Student"): Demo Student
Start date for schedules (YYYY-MM-DD): 2024-01-15
Number of weeks to schedule (default: 2): 1

📋 Test Configuration:
----------------------
Server: http://localhost:3000
Your Slack ID: U87654321
Fake Students: 15 (named "Demo Student 1", "Demo Student 2", etc.)
Schedule Start: 2024-01-15
Weeks: 1

⚠️  This will send ALL test notifications to your Slack. Continue? (y/N): y

🚀 Generating test schedules and sending notifications...

✅ Test mode executed successfully!

📊 Results:
- 15 fake students created
- 1 weeks of schedules generated
- All notifications sent to Slack ID: U87654321

🔍 Check your Slack for the test messages!
Each message will be prefixed with 🧪 [TEST MODE] to indicate it's a test.
```