#!/usr/bin/env tsx

import { loadConfig } from '../src/utils/config';
import { GoogleCalendarService } from '../src/integrations/google-calendar';

class InternalAttendeeTest extends GoogleCalendarService {
  async createEventWithInternalAttendee(targetUserEmail: string): Promise<void> {
    try {
      const impersonatedService = await this.impersonateUser(targetUserEmail);

      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(14, 30, 0, 0); // 2:30 PM tomorrow

      const endTime = new Date(tomorrow);
      endTime.setMinutes(endTime.getMinutes() + 30); // 30 minute demo

      const event = {
        summary: '30-Minute Demo - Internal Attendee Test',
        description: `Demo meeting with internal attendee to test domain-wide delegation.

Testing if internal attendees work differently than external ones.`,
        start: {
          dateTime: tomorrow.toISOString(),
          timeZone: this.config.organization?.timezone || 'America/Los_Angeles',
        },
        end: {
          dateTime: endTime.toISOString(),
          timeZone: this.config.organization?.timezone || 'America/Los_Angeles',
        },
        attendees: [
          { email: 'stschwartz@stanford.edu' }, // Internal attendee (same domain)
        ],
        conferenceData: {
          createRequest: {
            requestId: `internal-test-${Date.now()}`,
            conferenceSolutionKey: {
              type: 'hangoutsMeet',
            },
          },
        },
        guestsCanModify: false,
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

      console.log(`📧 Creating event with internal attendee...`);

      const response = await (impersonatedService as any).calendar.events.insert({
        calendarId: 'primary',
        resource: event,
        conferenceDataVersion: 1,
        sendUpdates: 'all',
      });

      const createdEvent = response.data;

      console.log('✅ Event with internal attendee created successfully!');
      console.log(`   Event ID: ${createdEvent.id}`);
      console.log(`   Summary: ${createdEvent.summary}`);
      console.log(`   Start: ${new Date(createdEvent.start!.dateTime!).toLocaleString()}`);
      console.log(`   Calendar Link: ${createdEvent.htmlLink}`);
      console.log(`   Google Meet Link: ${createdEvent.hangoutLink || 'Not created'}`);
      console.log(`   📧 Invitation sent to internal attendee`);

      // Now try the external attendee approach
      console.log('\n🔄 Now testing external attendee workaround...');
      await this.createEventWithExternalWorkaround(targetUserEmail);

    } catch (error: any) {
      console.error(`❌ Failed to create event with internal attendee:`, error.message);

      // Try external attendee workaround anyway
      console.log('\n🔄 Trying external attendee workaround...');
      await this.createEventWithExternalWorkaround(targetUserEmail);
    }
  }

  async createEventWithExternalWorkaround(targetUserEmail: string): Promise<void> {
    try {
      const impersonatedService = await this.impersonateUser(targetUserEmail);

      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(14, 45, 0, 0); // 2:45 PM tomorrow

      const endTime = new Date(tomorrow);
      endTime.setMinutes(endTime.getMinutes() + 30); // 30 minute demo

      // Create event without external attendees first
      const event = {
        summary: '30-Minute Demo - External Attendee Workaround',
        description: `Demo meeting with Fireflies.ai.

Google Meet Link: [Will be available after creation]

External attendees:
- fred@fireflies.ai (invite manually or add after creation)

This is a workaround for service account limitations with external attendees.`,
        start: {
          dateTime: tomorrow.toISOString(),
          timeZone: this.config.organization?.timezone || 'America/Los_Angeles',
        },
        end: {
          dateTime: endTime.toISOString(),
          timeZone: this.config.organization?.timezone || 'America/Los_Angeles',
        },
        // No attendees initially - add them after creation
        conferenceData: {
          createRequest: {
            requestId: `workaround-test-${Date.now()}`,
            conferenceSolutionKey: {
              type: 'hangoutsMeet',
            },
          },
        },
        guestsCanModify: false,
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

      console.log(`📅 Creating event without external attendees first...`);

      const response = await (impersonatedService as any).calendar.events.insert({
        calendarId: 'primary',
        resource: event,
        conferenceDataVersion: 1,
        sendUpdates: 'none', // Don't send updates yet
      });

      const createdEvent = response.data;

      console.log('✅ Base event created successfully!');
      console.log(`   Event ID: ${createdEvent.id}`);
      console.log(`   Summary: ${createdEvent.summary}`);
      console.log(`   Start: ${new Date(createdEvent.start!.dateTime!).toLocaleString()}`);
      console.log(`   Calendar Link: ${createdEvent.htmlLink}`);
      console.log(`   Google Meet Link: ${createdEvent.hangoutLink}`);

      // Now try to add external attendee via patch
      console.log('\n📧 Attempting to add external attendee via patch...');

      try {
        const patchResponse = await (impersonatedService as any).calendar.events.patch({
          calendarId: 'primary',
          eventId: createdEvent.id,
          resource: {
            attendees: [
              { email: 'fred@fireflies.ai' },
            ],
          },
          sendUpdates: 'all',
        });

        console.log('✅ External attendee added successfully!');
        console.log(`   📧 Invitation sent to fred@fireflies.ai`);

      } catch (patchError: any) {
        console.error(`❌ Failed to add external attendee via patch:`, patchError.message);
        console.log('\n💡 Manual workaround needed:');
        console.log('1. Go to the calendar event in Google Calendar');
        console.log('2. Edit the event and manually add fred@fireflies.ai');
        console.log('3. Or share the Google Meet link directly with them');
        console.log(`\n📋 Event details for manual sharing:`);
        console.log(`   Title: ${createdEvent.summary}`);
        console.log(`   Time: ${new Date(createdEvent.start!.dateTime!).toLocaleString()}`);
        console.log(`   Google Meet: ${createdEvent.hangoutLink}`);
      }

    } catch (error: any) {
      console.error(`❌ Failed to create event with workaround:`, error.message);
      throw error;
    }
  }
}

async function runTest() {
  console.log('🧪 Testing internal vs external attendee behavior...\n');

  try {
    const config = loadConfig();
    const tester = new InternalAttendeeTest(config);

    const testEmail = config.test_mode?.test_email || 'stschwartz@stanford.edu';
    console.log(`Testing with user: ${testEmail}\n`);

    await tester.createEventWithInternalAttendee(testEmail);

  } catch (error) {
    console.error('❌ Test failed:', error);
    process.exit(1);
  }
}

runTest().catch(console.error);