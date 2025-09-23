#!/usr/bin/env tsx

import { loadConfig } from '../src/utils/config';
import { GoogleCalendarService } from '../src/integrations/google-calendar';

// Test basic domain-wide delegation without attendees
class BasicDelegationTest extends GoogleCalendarService {
  async createBasicTestEvent(targetUserEmail: string): Promise<void> {
    try {
      // Create impersonated service for the target user
      const impersonatedService = await this.impersonateUser(targetUserEmail);

      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(15, 0, 0, 0); // 3:00 PM tomorrow

      const endTime = new Date(tomorrow);
      endTime.setMinutes(endTime.getMinutes() + 15); // 15 minute test

      const event = {
        summary: 'Domain-Wide Delegation Test - No Attendees',
        description: `Basic test to verify domain-wide delegation is working.

This event has no attendees to isolate domain-wide delegation testing.`,
        start: {
          dateTime: tomorrow.toISOString(),
          timeZone: this.config.organization?.timezone || 'America/Los_Angeles',
        },
        end: {
          dateTime: endTime.toISOString(),
          timeZone: this.config.organization?.timezone || 'America/Los_Angeles',
        },
        // NO attendees - this should work if domain-wide delegation is configured
        // Create Google Meet conference
        conferenceData: {
          createRequest: {
            requestId: `basic-test-${Date.now()}`,
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
            { method: 'popup', minutes: 5 },
          ],
        },
      };

      console.log(`📅 Creating basic test event for ${tomorrow.toLocaleString()}...`);

      const response = await (impersonatedService as any).calendar.events.insert({
        calendarId: 'primary',
        resource: event,
        conferenceDataVersion: 1,
        sendUpdates: 'none', // No invitations since no attendees
      });

      const createdEvent = response.data;

      console.log('✅ Basic delegation test successful!');
      console.log(`   Event ID: ${createdEvent.id}`);
      console.log(`   Summary: ${createdEvent.summary}`);
      console.log(`   Start: ${new Date(createdEvent.start!.dateTime!).toLocaleString()}`);
      console.log(`   Calendar Link: ${createdEvent.htmlLink}`);
      console.log(`   Google Meet Link: ${createdEvent.hangoutLink}`);
      console.log('\n✅ Domain-wide delegation is working! Now testing with attendees...');

      // Now try with attendees
      await this.createEventWithAttendees(targetUserEmail);

    } catch (error: any) {
      console.error(`❌ Basic delegation test failed:`, error.message);
      throw error;
    }
  }

  async createEventWithAttendees(targetUserEmail: string): Promise<void> {
    try {
      const impersonatedService = await this.impersonateUser(targetUserEmail);

      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(14, 0, 0, 0); // 2:00 PM tomorrow

      const endTime = new Date(tomorrow);
      endTime.setMinutes(endTime.getMinutes() + 30); // 30 minute demo

      const event = {
        summary: '30-Minute Demo - ClemenTime Testing',
        description: `Demo meeting with Fireflies.ai attendee.

This tests attendee invitations with domain-wide delegation.`,
        start: {
          dateTime: tomorrow.toISOString(),
          timeZone: this.config.organization?.timezone || 'America/Los_Angeles',
        },
        end: {
          dateTime: endTime.toISOString(),
          timeZone: this.config.organization?.timezone || 'America/Los_Angeles',
        },
        attendees: [
          { email: 'fred@fireflies.ai' },
        ],
        conferenceData: {
          createRequest: {
            requestId: `demo-test-${Date.now()}`,
            conferenceSolutionKey: {
              type: 'hangoutsMeet',
            },
          },
        },
        guestsCanModify: false,
        guestsCanSeeOtherGuests: true,
        gadgets: {
          preferences: {
            'goo.hangout.recordingEnabled': 'true',
          },
        },
        visibility: 'private',
        reminders: {
          useDefault: false,
          overrides: [
            { method: 'email', minutes: 30 },
            { method: 'popup', minutes: 10 },
          ],
        },
      };

      console.log(`📧 Creating demo invite with attendees...`);

      const response = await (impersonatedService as any).calendar.events.insert({
        calendarId: 'primary',
        resource: event,
        conferenceDataVersion: 1,
        sendUpdates: 'all',
      });

      const createdEvent = response.data;

      console.log('✅ Demo invite with attendees created successfully!');
      console.log(`   Event ID: ${createdEvent.id}`);
      console.log(`   Summary: ${createdEvent.summary}`);
      console.log(`   Start: ${new Date(createdEvent.start!.dateTime!).toLocaleString()}`);
      console.log(`   Calendar Link: ${createdEvent.htmlLink}`);
      console.log(`   Google Meet Link: ${createdEvent.hangoutLink}`);
      console.log(`   📧 Invitation sent to fred@fireflies.ai`);

    } catch (error: any) {
      console.error(`❌ Failed to create event with attendees:`, error.message);

      if (error.code === 403 && error.message.includes('forbiddenForServiceAccounts')) {
        console.log('\n🔧 The attendee invitation is still failing.');
        console.log('This could be due to:');
        console.log('1. Domain policy restrictions on external attendees');
        console.log('2. Need additional scopes or permissions');
        console.log('3. Google Workspace admin settings blocking external invites');
        console.log('\nTry creating the event without sendUpdates or with limited attendees.');
      }

      throw error;
    }
  }
}

async function runTest() {
  console.log('🧪 Testing domain-wide delegation step by step...\n');

  try {
    const config = loadConfig();
    const tester = new BasicDelegationTest(config);

    const testEmail = config.test_mode?.test_email || 'stschwartz@stanford.edu';
    console.log(`Testing with user: ${testEmail}\n`);

    await tester.createBasicTestEvent(testEmail);

  } catch (error) {
    console.error('❌ Test failed:', error);
    process.exit(1);
  }
}

runTest().catch(console.error);