#!/usr/bin/env tsx

import { loadConfig } from '../src/utils/config';
import { GoogleCalendarService } from '../src/integrations/google-calendar';

// Test simple event creation without Google Meet to verify delegation works
class SimpleEventTest extends GoogleCalendarService {
  async createSimpleEvent(targetUserEmail: string): Promise<void> {
    try {
      // Create impersonated service for the target user
      const impersonatedService = await this.impersonateUser(targetUserEmail);

      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(15, 30, 0, 0); // 3:30 PM tomorrow

      const endTime = new Date(tomorrow);
      endTime.setMinutes(endTime.getMinutes() + 15); // 15 minute test

      const event = {
        summary: 'Simple Test Event - Domain-Wide Delegation',
        description: `Simple test to verify domain-wide delegation is working.

No Google Meet link for this test - just a basic calendar event.`,
        start: {
          dateTime: tomorrow.toISOString(),
          timeZone: this.config.organization?.timezone || 'America/Los_Angeles',
        },
        end: {
          dateTime: endTime.toISOString(),
          timeZone: this.config.organization?.timezone || 'America/Los_Angeles',
        },
        // No conference data for this test
        visibility: 'private',
        reminders: {
          useDefault: false,
          overrides: [
            { method: 'popup', minutes: 5 },
          ],
        },
      };

      console.log(`📅 Creating simple test event for ${tomorrow.toLocaleString()}...`);

      const response = await (impersonatedService as any).calendar.events.insert({
        calendarId: 'primary',
        resource: event,
        sendUpdates: 'none',
      });

      const createdEvent = response.data;

      console.log('✅ Simple event created successfully!');
      console.log(`   Event ID: ${createdEvent.id}`);
      console.log(`   Summary: ${createdEvent.summary}`);
      console.log(`   Start: ${new Date(createdEvent.start!.dateTime!).toLocaleString()}`);
      console.log(`   Calendar Link: ${createdEvent.htmlLink}`);
      console.log('\n✅ Domain-wide delegation is confirmed working!');

      // Now try with Google Meet using different conference type
      await this.createEventWithMeet(targetUserEmail);

    } catch (error: any) {
      console.error(`❌ Simple event test failed:`, error.message);
      throw error;
    }
  }

  async createEventWithMeet(targetUserEmail: string): Promise<void> {
    try {
      const impersonatedService = await this.impersonateUser(targetUserEmail);

      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(14, 0, 0, 0); // 2:00 PM tomorrow

      const endTime = new Date(tomorrow);
      endTime.setMinutes(endTime.getMinutes() + 30); // 30 minute demo

      const event = {
        summary: '30-Minute Demo - ClemenTime Testing',
        description: `Demo meeting with Google Meet.

Testing Google Meet creation with domain-wide delegation.`,
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
        // Try different conference configuration
        conferenceData: {
          createRequest: {
            requestId: `meet-test-${Date.now()}`,
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

      console.log(`📧 Creating event with Google Meet and attendees...`);

      const response = await (impersonatedService as any).calendar.events.insert({
        calendarId: 'primary',
        resource: event,
        conferenceDataVersion: 1,
        sendUpdates: 'all',
      });

      const createdEvent = response.data;

      console.log('✅ Event with Google Meet created successfully!');
      console.log(`   Event ID: ${createdEvent.id}`);
      console.log(`   Summary: ${createdEvent.summary}`);
      console.log(`   Start: ${new Date(createdEvent.start!.dateTime!).toLocaleString()}`);
      console.log(`   Calendar Link: ${createdEvent.htmlLink}`);
      console.log(`   Google Meet Link: ${createdEvent.hangoutLink || 'Not created'}`);
      console.log(`   📧 Invitation sent to fred@fireflies.ai`);

    } catch (error: any) {
      console.error(`❌ Failed to create event with Google Meet:`, error.message);

      if (error.message.includes('Invalid conference type value')) {
        console.log('\n🔧 Trying alternative Google Meet configuration...');
        await this.createEventWithAlternateMeet(targetUserEmail);
      } else {
        throw error;
      }
    }
  }

  async createEventWithAlternateMeet(targetUserEmail: string): Promise<void> {
    try {
      const impersonatedService = await this.impersonateUser(targetUserEmail);

      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(14, 15, 0, 0); // 2:15 PM tomorrow

      const endTime = new Date(tomorrow);
      endTime.setMinutes(endTime.getMinutes() + 30); // 30 minute demo

      // Try without explicit conferenceData - Google should auto-create Meet link
      const event = {
        summary: '30-Minute Demo - ClemenTime Testing (Alt)',
        description: `Demo meeting with auto-generated Google Meet.

Testing Google Meet auto-creation with domain-wide delegation.`,
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

      console.log(`📧 Creating event with auto-generated Google Meet...`);

      const response = await (impersonatedService as any).calendar.events.insert({
        calendarId: 'primary',
        resource: event,
        sendUpdates: 'all',
      });

      const createdEvent = response.data;

      console.log('✅ Event with auto Meet created successfully!');
      console.log(`   Event ID: ${createdEvent.id}`);
      console.log(`   Summary: ${createdEvent.summary}`);
      console.log(`   Start: ${new Date(createdEvent.start!.dateTime!).toLocaleString()}`);
      console.log(`   Calendar Link: ${createdEvent.htmlLink}`);
      console.log(`   Google Meet Link: ${createdEvent.hangoutLink || 'Auto-generated (check calendar)'}`);
      console.log(`   📧 Invitation sent to fred@fireflies.ai`);

    } catch (error: any) {
      console.error(`❌ Failed to create event with auto Meet:`, error.message);
      throw error;
    }
  }
}

async function runTest() {
  console.log('🧪 Testing domain-wide delegation with progressive complexity...\n');

  try {
    const config = loadConfig();
    const tester = new SimpleEventTest(config);

    const testEmail = config.test_mode?.test_email || 'stschwartz@stanford.edu';
    console.log(`Testing with user: ${testEmail}\n`);

    await tester.createSimpleEvent(testEmail);

  } catch (error) {
    console.error('❌ Test failed:', error);
    process.exit(1);
  }
}

runTest().catch(console.error);