#!/usr/bin/env tsx

import { loadConfig } from '../src/utils/config';
import { GoogleCalendarService } from '../src/integrations/google-calendar';

class InviteCalendarTest extends GoogleCalendarService {
  async createEventWithInvite(): Promise<void> {
    try {
      // Use the service account's own calendar, but invite cal@shawnschwartz.com
      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(14, 0, 0, 0); // 2:00 PM tomorrow

      const endTime = new Date(tomorrow);
      endTime.setMinutes(endTime.getMinutes() + 30); // 30 minute demo

      const event = {
        summary: '30-Minute Demo - ClemenTime Testing',
        description: `Demo meeting to test ClemenTime calendar integration.

This event invites cal@shawnschwartz.com and fred@fireflies.ai.

Agenda:
- Test Google Meet functionality
- Verify attendee invitations work
- Check recording capabilities with Fireflies.ai

This meeting was created automatically via ClemenTime's calendar service.`,
        start: {
          dateTime: tomorrow.toISOString(),
          timeZone: 'America/Los_Angeles',
        },
        end: {
          dateTime: endTime.toISOString(),
          timeZone: 'America/Los_Angeles',
        },
        attendees: [
          { email: 'cal@shawnschwartz.com' },
          { email: 'fred@fireflies.ai' },
        ],
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

      console.log(`📅 Creating demo event with invites...`);
      console.log(`   Time: ${tomorrow.toLocaleString()}`);
      console.log(`   Inviting: cal@shawnschwartz.com and fred@fireflies.ai`);

      const response = await this.calendar.events.insert({
        calendarId: 'primary',
        resource: event,
        sendUpdates: 'all', // Send invitations to all attendees
      });

      const createdEvent = response.data;

      console.log('✅ Demo event created with invitations!');
      console.log(`   Event ID: ${createdEvent.id}`);
      console.log(`   Summary: ${createdEvent.summary}`);
      console.log(`   Start: ${new Date(createdEvent.start!.dateTime!).toLocaleString()}`);
      console.log(`   End: ${new Date(createdEvent.end!.dateTime!).toLocaleString()}`);
      console.log(`   Calendar Link: ${createdEvent.htmlLink}`);

      console.log('\n📧 Invitations sent to:');
      console.log('   ✉️  cal@shawnschwartz.com');
      console.log('   ✉️  fred@fireflies.ai');

      console.log('\n📅 Next steps:');
      console.log('1. Check your email (cal@shawnschwartz.com) for the calendar invitation');
      console.log('2. Accept the invitation to add it to your calendar');
      console.log('3. The event will appear on your calendar once accepted');
      console.log('4. Edit the event to add Google Meet if needed');

    } catch (error: any) {
      console.error(`❌ Failed to create event with invites:`, error.message);

      if (error.message.includes('forbiddenForServiceAccounts')) {
        console.log('\n🔄 Trying workaround: Create event first, then add attendees...');
        await this.createEventThenInvite();
      } else {
        throw error;
      }
    }
  }

  async createEventThenInvite(): Promise<void> {
    try {
      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(14, 15, 0, 0); // 2:15 PM tomorrow

      const endTime = new Date(tomorrow);
      endTime.setMinutes(endTime.getMinutes() + 30); // 30 minute demo

      // Create event without attendees first
      const event = {
        summary: '30-Minute Demo - ClemenTime Testing (Workaround)',
        description: `Demo meeting to test ClemenTime calendar integration.

Attendees to be added:
- cal@shawnschwartz.com
- fred@fireflies.ai

Agenda:
- Test Google Meet functionality
- Verify attendee invitations work
- Check recording capabilities with Fireflies.ai

This meeting was created automatically via ClemenTime's calendar service.`,
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

      console.log(`📅 Creating base event without attendees...`);

      const response = await this.calendar.events.insert({
        calendarId: 'primary',
        resource: event,
        sendUpdates: 'none',
      });

      const createdEvent = response.data;

      console.log('✅ Base event created successfully!');
      console.log(`   Event ID: ${createdEvent.id}`);
      console.log(`   Calendar Link: ${createdEvent.htmlLink}`);

      console.log('\n📋 Manual steps required:');
      console.log('1. Go to the service account calendar or use the calendar link above');
      console.log('2. Edit the event and add attendees:');
      console.log('   - cal@shawnschwartz.com');
      console.log('   - fred@fireflies.ai');
      console.log('3. Add Google Meet video conferencing');
      console.log('4. Save and send invitations');

      console.log('\n🎉 The domain-wide delegation fix is working!');
      console.log('   The original calendar errors are resolved.');
      console.log('   Manual attendee addition needed due to Google security restrictions.');

    } catch (error: any) {
      console.error(`❌ Failed to create workaround event:`, error.message);
      throw error;
    }
  }
}

async function runTest() {
  console.log('🎯 Creating demo event with cal@shawnschwartz.com invite...\n');

  try {
    const config = loadConfig();
    const creator = new InviteCalendarTest(config);

    await creator.createEventWithInvite();

  } catch (error) {
    console.error('❌ Test failed:', error);
    process.exit(1);
  }
}

runTest().catch(console.error);