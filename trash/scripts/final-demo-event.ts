#!/usr/bin/env tsx

import { loadConfig } from '../src/utils/config';
import { GoogleCalendarService } from '../src/integrations/google-calendar';

class FinalDemoEvent extends GoogleCalendarService {
  async createFinalDemo(): Promise<void> {
    try {
      // Use domain-wide delegation to create on cal@shawnschwartz.com calendar
      const impersonatedService = await this.impersonateUser('cal@shawnschwartz.com');

      // Create for tomorrow at 2:00 PM Pacific Time
      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(14, 0, 0, 0); // 2:00 PM tomorrow
      tomorrow.setMinutes(0);
      tomorrow.setSeconds(0);
      tomorrow.setMilliseconds(0);

      const endTime = new Date(tomorrow);
      endTime.setMinutes(endTime.getMinutes() + 30); // 30 minute demo

      const event = {
        summary: '30-Minute Demo - ClemenTime Testing',
        description: `Demo meeting to test ClemenTime calendar integration and domain-wide delegation.

MANUALLY ADD THESE ATTENDEES:
- fred@fireflies.ai

Agenda:
- Test Google Meet functionality
- Verify attendee invitations work
- Check recording capabilities with Fireflies.ai

This meeting was created automatically via ClemenTime's calendar service with working domain-wide delegation.

Event created on: ${new Date().toLocaleString()}`,
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

      console.log(`📅 Creating final demo event on cal@shawnschwartz.com calendar...`);

      const response = await (impersonatedService as any).calendar.events.insert({
        calendarId: 'primary',
        resource: event,
        sendUpdates: 'none',
      });

      const createdEvent = response.data;

      console.log('\n🎉 FINAL DEMO EVENT CREATED SUCCESSFULLY!');
      console.log('=' .repeat(60));

      const eventStart = new Date(createdEvent.start!.dateTime!);
      const eventEnd = new Date(createdEvent.end!.dateTime!);

      console.log(`📅 EVENT DATE: ${eventStart.toLocaleDateString('en-US', {
        weekday: 'long',
        year: 'numeric',
        month: 'long',
        day: 'numeric'
      })}`);
      console.log(`🕐 EVENT TIME: ${eventStart.toLocaleTimeString('en-US', {
        hour: 'numeric',
        minute: '2-digit',
        timeZoneName: 'short'
      })} - ${eventEnd.toLocaleTimeString('en-US', {
        hour: 'numeric',
        minute: '2-digit',
        timeZoneName: 'short'
      })}`);
      console.log(`📧 CALENDAR: cal@shawnschwartz.com`);
      console.log(`🆔 EVENT ID: ${createdEvent.id}`);
      console.log(`📎 CALENDAR LINK: ${createdEvent.htmlLink}`);
      console.log(`📝 TITLE: ${createdEvent.summary}`);
      console.log('=' .repeat(60));

      console.log('\n📋 NEXT STEPS:');
      console.log('1. Check your cal@shawnschwartz.com Google Calendar');
      console.log('2. Look for the event titled "30-Minute Demo - ClemenTime Testing"');
      console.log('3. Edit the event to add:');
      console.log('   - Google Meet video conferencing');
      console.log('   - fred@fireflies.ai as an attendee');
      console.log('4. Save the event');

      console.log('\n✅ DOMAIN-WIDE DELEGATION IS WORKING!');
      console.log('   The original calendar errors have been fixed.');
      console.log('   Service account can now create events on user calendars.');

    } catch (error: any) {
      console.error(`❌ Failed to create final demo event:`, error.message);
      throw error;
    }
  }
}

async function runFinalDemo() {
  console.log('🎯 Creating final demo event with explicit date/time...\n');

  try {
    const config = loadConfig();
    const creator = new FinalDemoEvent(config);

    await creator.createFinalDemo();

  } catch (error) {
    console.error('❌ Final demo failed:', error);
    process.exit(1);
  }
}

runFinalDemo().catch(console.error);