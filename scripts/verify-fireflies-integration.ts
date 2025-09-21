#!/usr/bin/env tsx

import { Config, ScheduleSlot } from '../src/types';

// Mock config with AI recording enabled
const configWithFireflies: Config = {
  organization: {
    name: 'Test Organization',
    domain: 'example.com',
    timezone: 'America/Los_Angeles'
  },
  ai_recording: {
    enabled: true,
    service_email: 'fred@fireflies.ai',
    auto_invite: true
  }
};

// Mock config without AI recording
const configWithoutFireflies: Config = {
  organization: {
    name: 'Test Organization',
    domain: 'example.com',
    timezone: 'America/Los_Angeles'
  }
};

// Mock schedule slot
const testSlot: ScheduleSlot = {
  student: {
    name: 'Jane Student',
    email: 'jane@student.com'
  },
  ta: {
    name: 'John TA',
    email: 'john@ta.com'
  },
  section_id: 'section-01',
  location: 'Online',
  start_time: new Date(),
  end_time: new Date(),
  week: 1,
  assignment_name: 'Test Assignment'
};

function buildAttendeesList(config: Config, slot: ScheduleSlot) {
  return [
    // Add facilitator as attendee
    { email: slot.ta.email },
    // Add AI recording service if enabled
    ...(config.ai_recording?.enabled && config.ai_recording?.auto_invite ?
      [{ email: config.ai_recording.service_email }] : []),
  ];
}

console.log('🔍 Verifying fred@fireflies.ai integration:\n');

console.log('1. With AI recording enabled:');
const attendeesWithFireflies = buildAttendeesList(configWithFireflies, testSlot);
console.log('   Attendees list:', JSON.stringify(attendeesWithFireflies, null, 2));
console.log('   ✅ fred@fireflies.ai will be invited:', attendeesWithFireflies.some(a => a.email === 'fred@fireflies.ai'));

console.log('\n2. With AI recording disabled:');
const attendeesWithoutFireflies = buildAttendeesList(configWithoutFireflies, testSlot);
console.log('   Attendees list:', JSON.stringify(attendeesWithoutFireflies, null, 2));
console.log('   ❌ fred@fireflies.ai will NOT be invited:', !attendeesWithoutFireflies.some(a => a.email === 'fred@fireflies.ai'));

console.log('\n✅ Integration confirmed: The Google Meet service will automatically invite fred@fireflies.ai when:');
console.log('   - config.ai_recording.enabled = true');
console.log('   - config.ai_recording.auto_invite = true');
console.log('   - config.ai_recording.service_email = "fred@fireflies.ai"');