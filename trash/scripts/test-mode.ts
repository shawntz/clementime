#!/usr/bin/env node

/*
 * ClemenTime Test Mode Script
 *
 * Usage with Docker:
 *   docker exec -it clementime npm run test:mode
 *
 * Or if the service is running locally:
 *   npm run test:mode
 */

import axios from 'axios';
import * as readline from 'readline';

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

const question = (prompt: string): Promise<string> => {
  return new Promise((resolve) => {
    rl.question(prompt, resolve);
  });
};

async function runTestMode() {
  console.log('\n🧪 CLEMENTIME TEST MODE SETUP');
  console.log('================================\n');
  console.log('This will generate fake student schedules and send all notifications to YOUR Slack account.\n');

  const serverUrl = await question('Enter server URL (default: http://localhost:3000): ') || 'http://localhost:3000';
  const slackId = await question('Enter YOUR Slack user ID (e.g., U12345678): ');

  if (!slackId) {
    console.error('❌ Slack ID is required for test mode');
    process.exit(1);
  }

  const numberOfStudents = await question('Number of fake students to generate (default: 30): ') || '30';
  const studentPrefix = await question('Fake student name prefix (default: "Test Student"): ') || 'Test Student';

  // Get schedule details
  const startDate = await question('Start date for schedules (YYYY-MM-DD): ');
  const weeks = await question('Number of weeks to schedule (default: 2): ') || '2';

  console.log('\n📋 Test Configuration:');
  console.log('----------------------');
  console.log(`Server: ${serverUrl}`);
  console.log(`Your Slack ID: ${slackId}`);
  console.log(`Fake Students: ${numberOfStudents} (named "${studentPrefix} 1", "${studentPrefix} 2", etc.)`);
  console.log(`Schedule Start: ${startDate}`);
  console.log(`Weeks: ${weeks}`);

  const confirm = await question('\n⚠️  This will send ALL test notifications to your Slack. Continue? (y/N): ');

  if (confirm.toLowerCase() !== 'y') {
    console.log('❌ Test mode cancelled');
    process.exit(0);
  }

  console.log('\n🚀 Generating test schedules and sending notifications...\n');

  try {
    const response = await axios.post(`${serverUrl}/test/generate-fake-schedules`, {
      startDate,
      weeks: parseInt(weeks),
      numberOfFakeStudents: parseInt(numberOfStudents),
      fakeStudentPrefix: studentPrefix,
      redirectToSlackId: slackId
    });

    if (response.data.success) {
      console.log('✅ Test mode executed successfully!\n');
      console.log('📊 Results:');
      console.log(`- ${response.data.details.fakeStudents} fake students created`);
      console.log(`- ${response.data.details.weeks} weeks of schedules generated`);
      console.log(`- All notifications sent to Slack ID: ${response.data.details.redirectedTo}`);
      console.log('\n🔍 Check your Slack for the test messages!');
      console.log('Each message will be prefixed with 🧪 [TEST MODE] to indicate it\'s a test.\n');
    } else {
      console.error('❌ Test mode failed:', response.data.error);
    }
  } catch (error: any) {
    console.error('❌ Error running test mode:', error.response?.data?.error || error.message);
  } finally {
    rl.close();
  }
}

// Run the test mode
runTestMode().catch(console.error);