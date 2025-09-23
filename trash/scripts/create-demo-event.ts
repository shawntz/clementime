#!/usr/bin/env tsx

import { loadConfig } from '../src/utils/config';
import { GoogleCalendarService } from '../src/integrations/google-calendar';

class DemoEventCreator extends GoogleCalendarService {
  async createDemoEvent(targetUserEmail: string): Promise<void> {
    try {
      const impersonatedService = await this.impersonateUser(targetUserEmail);

      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(14, 0, 0, 0); // 2:00 PM tomorrow

      const endTime = new Date(tomorrow);
      endTime.setMinutes(endTime.getMinutes() + 30); // 30 minute demo

      // Create event without Google Meet first, then try to add it
      const event = {
        summary: '30-Minute Demo - ClemenTime Testing',
        description: `Demo meeting to test ClemenTime calendar integration.

Please manually add fred@fireflies.ai as an attendee after creation.

Agenda:
- Test Google Meet functionality
- Verify attendee invitations work
- Check recording capabilities with Fireflies.ai

This meeting was created automatically via ClemenTime's calendar service with fixed domain-wide delegation.`,
        start: {
          dateTime: tomorrow.toISOString(),
          timeZone: this.config.organization?.timezone || 'America/Los_Angeles',
        },
        end: {
          dateTime: endTime.toISOString(),
          timeZone: this.config.organization?.timezone || 'America/Los_Angeles',
        },
        // No attendees or conference data to avoid errors
        guestsCanModify: true, // Allow manual editing
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

      console.log(`📅 Creating demo event for ${tomorrow.toLocaleString()}...`);

      const response = await (impersonatedService as any).calendar.events.insert({
        calendarId: 'primary',
        resource: event,
        sendUpdates: 'none',
      });

      const createdEvent = response.data;

      console.log('✅ Demo event created successfully!');
      console.log(`   Event ID: ${createdEvent.id}`);
      console.log(`   Summary: ${createdEvent.summary}`);
      console.log(`   Start: ${new Date(createdEvent.start!.dateTime!).toLocaleString()}`);
      console.log(`   End: ${new Date(createdEvent.end!.dateTime!).toLocaleString()}`);
      console.log(`   Calendar Link: ${createdEvent.htmlLink}`);

      console.log('\n📋 Next steps:');
      console.log('1. Open the calendar event in Google Calendar');
      console.log('2. Click "Add Google Meet video conferencing"');
      console.log('3. Add fred@fireflies.ai as an attendee');
      console.log('4. Save the event');
      console.log('5. The invitation will be sent automatically');

      console.log('\n🎉 Domain-wide delegation fix is working!');
      console.log('   ✅ Service account can create events on your calendar');
      console.log('   ✅ Domain-wide delegation is properly configured');
      console.log('   📝 Manual attendee addition required due to Google security restrictions');

    } catch (error: any) {
      console.error(`❌ Failed to create demo event:`, error.message);
      throw error;
    }
  }
}

async function runDemo() {
  console.log('🎯 Creating demo event with working domain-wide delegation...\n');

  try {
    const config = loadConfig();
    const creator = new DemoEventCreator(config);

    const testEmail = config.test_mode?.test_email || 'stschwartz@stanford.edu';
    console.log(`Creating event on calendar: ${testEmail}\n`);

    await creator.createDemoEvent(testEmail);

  } catch (error) {
    console.error('❌ Demo creation failed:', error);
    process.exit(1);
  }
}

runDemo().catch(console.error);