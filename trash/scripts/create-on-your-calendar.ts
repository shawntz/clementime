#!/usr/bin/env tsx

import { loadConfig } from '../src/utils/config';
import { GoogleCalendarService } from '../src/integrations/google-calendar';

class YourCalendarTest extends GoogleCalendarService {
  async createEventOnYourCalendar(): Promise<void> {
    try {
      // Create impersonated service for YOUR Stanford email specifically
      const impersonatedService = await this.impersonateUser('stschwartz@stanford.edu');

      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(14, 0, 0, 0); // 2:00 PM tomorrow

      const endTime = new Date(tomorrow);
      endTime.setMinutes(endTime.getMinutes() + 30); // 30 minute demo

      const event = {
        summary: '30-Minute Demo - ClemenTime Testing (On Your Calendar)',
        description: `Demo meeting to test ClemenTime calendar integration.

This event is created directly on stschwartz@stanford.edu calendar.

Please manually add fred@fireflies.ai as an attendee after creation.

Agenda:
- Test Google Meet functionality
- Verify attendee invitations work
- Check recording capabilities with Fireflies.ai

This meeting was created automatically via ClemenTime's calendar service with fixed domain-wide delegation.`,
        start: {
          dateTime: tomorrow.toISOString(),
          timeZone: 'America/Los_Angeles',
        },
        end: {
          dateTime: endTime.toISOString(),
          timeZone: 'America/Los_Angeles',
        },
        guestsCanModify: true,
        guestsCanSeeOtherGuests: true,
        visibility: 'private',
        reminders: {
          useDefault: false,
          overrides: [
            { method: 'email', minutes: 30 },
            { method: 'popup', minutes: 10 },
          ],
        },
      };

      console.log(`📅 Creating demo event on YOUR Stanford calendar (stschwartz@stanford.edu)...`);
      console.log(`   Time: ${tomorrow.toLocaleString()}`);

      const response = await (impersonatedService as any).calendar.events.insert({
        calendarId: 'primary', // This should be YOUR primary calendar
        resource: event,
        sendUpdates: 'none',
      });

      const createdEvent = response.data;

      console.log('✅ Demo event created on YOUR calendar!');
      console.log(`   Event ID: ${createdEvent.id}`);
      console.log(`   Summary: ${createdEvent.summary}`);
      console.log(`   Start: ${new Date(createdEvent.start!.dateTime!).toLocaleString()}`);
      console.log(`   End: ${new Date(createdEvent.end!.dateTime!).toLocaleString()}`);
      console.log(`   Calendar Link: ${createdEvent.htmlLink}`);

      console.log('\n📧 Check your Stanford calendar now!');
      console.log('   This event should appear on stschwartz@stanford.edu calendar');
      console.log('   Look for: "30-Minute Demo - ClemenTime Testing (On Your Calendar)"');

      console.log('\n📋 Next steps:');
      console.log('1. Check your Stanford Google Calendar');
      console.log('2. Find the event and edit it');
      console.log('3. Add Google Meet video conferencing');
      console.log('4. Add fred@fireflies.ai as an attendee');
      console.log('5. Save the event');

    } catch (error: any) {
      console.error(`❌ Failed to create event on your calendar:`, error.message);

      if (error.code === 403) {
        console.log('\n🔧 Domain-wide delegation might need the user email scope:');
        console.log('Make sure these scopes are configured in Google Admin Console:');
        console.log('- https://www.googleapis.com/auth/calendar');
        console.log('- https://www.googleapis.com/auth/calendar.events');
        console.log('- https://www.googleapis.com/auth/admin.directory.user.readonly');
      }

      throw error;
    }
  }
}

async function runTest() {
  console.log('🎯 Creating demo event on YOUR Stanford calendar...\n');

  try {
    const config = loadConfig();
    const creator = new YourCalendarTest(config);

    await creator.createEventOnYourCalendar();

  } catch (error) {
    console.error('❌ Test failed:', error);
    process.exit(1);
  }
}

runTest().catch(console.error);