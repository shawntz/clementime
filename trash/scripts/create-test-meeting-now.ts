#!/usr/bin/env tsx

import { loadConfig } from '../src/utils/config';
import { GoogleCalendarService } from '../src/integrations/google-calendar';
import { ScheduleSlot } from '../src/types';

async function main() {
  try {
    console.log('🎯 Creating Google Meet RIGHT NOW for immediate testing...\n');

    const config = loadConfig();
    const calendar = new GoogleCalendarService(config);

    // Create meeting starting NOW and ending in 5 minutes
    const now = new Date();
    const endTime = new Date(now.getTime() + 5 * 60 * 1000); // 5 minutes from now

    console.log(`⏰ Meeting Time: ${now.toLocaleTimeString()} - ${endTime.toLocaleTimeString()}`);

    const testSlot: ScheduleSlot = {
      student: {
        name: 'Live Test Recording Student',
        email: config.test_mode?.test_email || 'test.student@university.edu',
        slack_id: 'U123456789'
      },
      ta: {
        id: 'section_01',
        name: 'John Doe',
        email: 'john.doe@university.edu',
        slack_id: config.test_mode?.redirect_to_slack_id || 'UTEST123456',
        google_email: config.test_mode?.test_email || 'john.doe@university.edu'
      },
      section_id: 'section_01',
      start_time: now,
      end_time: endTime,
      location: 'Google Meet - LIVE TEST'
    };

    console.log('📅 Creating calendar event...');
    const adminEmails = [config.test_mode?.test_email || 'admin@university.edu'];

    try {
      const meeting = await calendar.createMeetingForSlot(testSlot, adminEmails);

      console.log('✅ LIVE TEST MEETING CREATED!');
      console.log(`📧 Event ID: ${meeting.id}`);
      console.log(`🔗 Google Meet Link: ${meeting.hangoutLink}`);
      console.log(`📅 Calendar Link: ${meeting.htmlLink}`);

      console.log('\n🎬 IMMEDIATE ACTION REQUIRED:');
      console.log('1. 🔗 JOIN THIS MEETING NOW:', meeting.hangoutLink);
      console.log('2. 🎥 START RECORDING immediately when you join');
      console.log('3. 🗣️  Talk for 30-60 seconds to create content');
      console.log('4. ⏹️  END the meeting (it will auto-end in 5 minutes)');
      console.log('5. ⏳ Wait 5-10 minutes for recording to process');
      console.log('6. 🔍 Check your Slack for the recording notification!');

      console.log('\n📊 What will happen after recording processes:');
      console.log(`   → Recording handled by AI service (Fireflies.ai, etc.)`);
      console.log(`   → Notification sent to Slack channel (based on config)`);
      console.log(`   → Meeting details logged in system`);

      // Also show the raw meet link in case the formatted one doesn't work
      console.log('\n📎 Raw Meet Link (backup):');
      console.log(meeting.hangoutLink);

    } catch (error) {
      console.error('❌ Failed to create calendar event:', error.message);

      // Fallback: provide manual instructions
      console.log('\n🔧 MANUAL FALLBACK:');
      console.log('1. Go to https://meet.google.com');
      console.log('2. Click "New meeting" → "Start an instant meeting"');
      console.log('3. Enable recording immediately');
      console.log('4. Talk for 30-60 seconds');
      console.log('5. End the meeting');
      console.log('6. Wait for recording to process and check Slack!');
    }

  } catch (error) {
    console.error('❌ Test setup failed:', error);
    process.exit(1);
  }
}

main();
