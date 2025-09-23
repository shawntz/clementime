#!/usr/bin/env node

import * as dotenv from 'dotenv';
import { loadConfigSync as loadConfig } from '../utils/config';
import { SlackNotificationService } from '../integrations/slack';
import { TestDataGenerator } from '../utils/test-data-generator';
import { SchedulingAlgorithm } from '../scheduler/algorithm';
import { format } from 'date-fns';

dotenv.config({ override: true });

async function testSlackNotifications() {
  try {
    console.log('🧪 Testing Slack Notifications in Test Mode\n');

    // Load config
    const config = loadConfig();

    if (!config.test_mode?.enabled) {
      console.error('❌ Test mode is not enabled in config.yml');
      console.log('💡 Enable test mode in your config.yml file:');
      console.log('test_mode:');
      console.log('  enabled: true');
      console.log('  redirect_to_slack_id: "YOUR_SLACK_ID"');
      process.exit(1);
    }

    console.log(`✅ Test mode enabled - Messages will go to: ${config.test_mode.redirect_to_slack_id}\n`);

    // Create test config with fake students
    const testSections = TestDataGenerator.createTestSections(
      config.sections,
      5, // Just 5 fake students for testing
      config.test_mode.fake_student_prefix || 'Test Student',
      config.test_mode.redirect_to_slack_id
    );

    const testConfig = {
      ...config,
      sections: testSections
    };

    // Generate a simple schedule
    console.log('📅 Generating test schedules...');
    const scheduler = new SchedulingAlgorithm(testConfig);
    const startDate = new Date('2025-01-20');
    const schedules = scheduler.generateRecurringSchedule(startDate, 1);

    // Initialize Slack service
    console.log('📱 Initializing Slack service...');
    const slackService = new SlackNotificationService(testConfig);

    // Send test notifications
    console.log('🚀 Sending test notifications to your Slack...\n');

    let messageCount = 0;
    for (const [weekNum, weekSchedule] of schedules) {
      console.log(`📅 Processing Week ${weekNum + 1}...`);

      for (const [sectionId, slots] of weekSchedule) {
        console.log(`  📚 Section ${sectionId}: ${slots.length} students`);

        for (const slot of slots.slice(0, 3)) { // Only send first 3 messages per section
          try {
            console.log(`    🔄 Sending notification for ${slot.student.name}...`);
            await slackService.notifyParticipant(slot);
            messageCount++;
            console.log(`    ✅ Sent notification for ${slot.student.name}`);

            // Small delay between messages
            await new Promise(resolve => setTimeout(resolve, 1000));
          } catch (error) {
            console.error(`    ❌ Failed to notify ${slot.student.name}:`, error);
          }
        }
      }
    }

    console.log(`\n✅ Test completed! Sent ${messageCount} test notifications to your Slack.`);
    console.log('🔍 Check your Slack for messages prefixed with 🧪 [TEST MODE]');

  } catch (error) {
    console.error('❌ Test failed:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  testSlackNotifications();
}