#!/usr/bin/env tsx

import { loadConfig } from '../src/utils/config';
import { GoogleCalendarService } from '../src/integrations/google-calendar';

async function main() {
  try {
    console.log('🧪 Testing Google Calendar API with Host Management Check...\n');

    const config = loadConfig();
    const calendar = new GoogleCalendarService(config);

    // Use configured test email or fallback
    const testEmail = config.test_mode?.test_email || 'admin@university.edu';
    await calendar.createTestEventOnUserCalendar(testEmail);

  } catch (error) {
    console.error('❌ Test failed:', error);
    process.exit(1);
  }
}

main();