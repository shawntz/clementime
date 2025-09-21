#!/bin/bash

echo "🧪 Testing Clementime API Endpoints"
echo "===================================="
echo ""

SERVER_URL="http://localhost:3000"

# Check if server is running
echo "1. Checking server health..."
HEALTH_RESPONSE=$(curl -s $SERVER_URL/health)
if [ $? -eq 0 ]; then
    echo "✅ Server is running: $HEALTH_RESPONSE"
else
    echo "❌ Server is not running on port 3000"
    echo "💡 Start the server with: npm run web -- --port 3000"
    exit 1
fi

echo ""

# Test schedule generation
echo "2. Testing schedule generation..."
GENERATE_RESPONSE=$(curl -s -X POST $SERVER_URL/schedules/generate \
    -H "Content-Type: application/json" \
    -d '{"startDate": "2025-01-15", "weeks": 1}')

if echo "$GENERATE_RESPONSE" | grep -q '"success":true'; then
    echo "✅ Schedule generation works"
else
    echo "❌ Schedule generation failed: $GENERATE_RESPONSE"
fi

echo ""

# Test dry run workflow
echo "3. Testing dry run workflow..."
WORKFLOW_RESPONSE=$(curl -s -X POST $SERVER_URL/schedules/run-workflow \
    -H "Content-Type: application/json" \
    -d '{"startDate": "2025-01-15", "weeks": 1, "dryRun": "true"}')

if echo "$WORKFLOW_RESPONSE" | grep -q '"success":true'; then
    echo "✅ Dry run workflow works"
else
    echo "❌ Dry run workflow failed: $WORKFLOW_RESPONSE"
fi

echo ""

# Test fake schedule generation (test mode)
echo "4. Testing test mode fake schedule generation..."
TEST_RESPONSE=$(curl -s -X POST $SERVER_URL/test/generate-fake-schedules \
    -H "Content-Type: application/json" \
    -d '{
        "startDate": "2025-01-15",
        "weeks": 1,
        "numberOfFakeStudents": 2,
        "fakeStudentPrefix": "API Test Student",
        "redirectToSlackId": "UTEST123456"
    }')

if echo "$TEST_RESPONSE" | grep -q '"success":true'; then
    echo "✅ Test mode fake schedule generation works"
    NOTIFICATIONS_SENT=$(echo "$TEST_RESPONSE" | grep -o '"notificationsSent":[0-9]*' | cut -d':' -f2)
    echo "📱 Sent $NOTIFICATIONS_SENT test notifications to your Slack"
else
    echo "❌ Test mode failed: $TEST_RESPONSE"
fi

echo ""
echo "🎉 API endpoint testing complete!"
echo ""
echo "🔍 If test mode worked, check your Slack for messages prefixed with 🧪 [TEST MODE]"
echo "🌐 Web interface available at: $SERVER_URL"