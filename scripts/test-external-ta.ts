#!/usr/bin/env tsx

import { loadConfig } from '../src/utils/config';
import { GoogleCalendarService } from '../src/integrations/google-calendar';
import { ScheduleSlot } from '../src/types';

async function main() {
  try {
    console.log('🧪 Testing External Facilitator Calendar Invitation...\n');

    const config = loadConfig();
    const calendar = new GoogleCalendarService(config);

    // Create a fake schedule slot with external facilitator
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(19, 0, 0, 0); // 7:00 PM tomorrow

    const endTime = new Date(tomorrow);
    endTime.setMinutes(endTime.getMinutes() + 15);

    const fakeSlot: ScheduleSlot = {
      student: {
        name: 'Test Participant',
        email: 'test.participant@university.edu',
        slack_id: 'U123456789'
      },
      ta: {
        id: 'test_ta',
        name: 'Test External Facilitator',
        email: config.test_mode?.test_email || 'external.facilitator@university.edu',
        slack_id: 'U987654321',
        google_email: config.test_mode?.test_email || 'external.facilitator@university.edu'
      },
      section_id: 'test_section',
      start_time: tomorrow,
      end_time: endTime,
      location: 'Google Meet'
    };

    // Test with admin emails (should create on admin calendar and invite external facilitator)
    const adminEmails = [config.test_mode?.test_email || 'admin@university.edu'];

    console.log('Creating calendar event for external facilitator...');
    console.log(`External Facilitator: ${fakeSlot.ta.email}`);
    console.log(`Admin emails: ${adminEmails.join(', ')}`);

    const meeting = await calendar.createMeetingForSlot(fakeSlot, adminEmails);

    console.log('✅ External facilitator calendar invitation test successful!');
    console.log(`   Event ID: ${meeting.id}`);
    console.log(`   Summary: ${meeting.summary}`);
    console.log(`   Google Meet Link: ${meeting.hangoutLink}`);
    console.log(`   Calendar Link: ${meeting.htmlLink}`);
    console.log(`   External facilitator should receive calendar invitation at: ${fakeSlot.ta.email}`);

  } catch (error) {
    console.error('❌ Test failed:', error);
    process.exit(1);
  }
}

main();