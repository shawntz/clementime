#!/usr/bin/env tsx

import { loadConfig } from '../src/utils/config';
import { GoogleCalendarService } from '../src/integrations/google-calendar';

// Extend the GoogleCalendarService to add a demo invite method
class DemoCalendarService extends GoogleCalendarService {
  async createDemoInviteWithFireflies(targetUserEmail: string): Promise<void> {
    try {
      // Create impersonated service for the target user
      const impersonatedService = await this.impersonateUser(targetUserEmail);

      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(14, 0, 0, 0); // 2:00 PM tomorrow

      const endTime = new Date(tomorrow);
      endTime.setMinutes(endTime.getMinutes() + 30); // 30 minute demo

      const event = {
        summary: '30-Minute Demo - ClemenTime Testing',
        description: `Demo meeting to test ClemenTime calendar integration and domain-wide delegation fixes.

Agenda:
- Test Google Meet functionality
- Verify attendee invitations work
- Check recording capabilities with Fireflies.ai

This meeting was created automatically via ClemenTime's calendar service.`,
        start: {
          dateTime: tomorrow.toISOString(),
          timeZone: this.config.organization?.timezone || 'America/Los_Angeles',
        },
        end: {
          dateTime: endTime.toISOString(),
          timeZone: this.config.organization?.timezone || 'America/Los_Angeles',
        },
        attendees: [
          { email: 'fred@fireflies.ai' }, // Fireflies.ai attendee
        ],
        // Create Google Meet conference
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
        // Enable recording preferences
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

      console.log(`📅 Creating demo invite for ${tomorrow.toLocaleString()}...`);

      const response = await (impersonatedService as any).calendar.events.insert({
        calendarId: 'primary',
        resource: event,
        conferenceDataVersion: 1,
        sendUpdates: 'all', // Send invitations to all attendees
      });

      const createdEvent = response.data;

      console.log('✅ Demo invite created successfully!');
      console.log(`   Event ID: ${createdEvent.id}`);
      console.log(`   Summary: ${createdEvent.summary}`);
      console.log(`   Start: ${new Date(createdEvent.start!.dateTime!).toLocaleString()}`);
      console.log(`   End: ${new Date(createdEvent.end!.dateTime!).toLocaleString()}`);
      console.log(`   Calendar Link: ${createdEvent.htmlLink}`);
      console.log(`   Google Meet Link: ${createdEvent.hangoutLink}`);
      console.log(`   Attendees: fred@fireflies.ai`);
      console.log(`   📧 Invitation sent to fred@fireflies.ai`);

    } catch (error: any) {
      console.error(`❌ Failed to create demo invite:`, error.message);

      if (error.code === 401 || error.code === 403) {
        console.log('\n📋 Troubleshooting Domain-Wide Delegation:');
        console.log('1. Go to Google Admin Console (admin.google.com)');
        console.log('2. Navigate to Security > API Controls > Domain-wide delegation');
        console.log('3. Add a new client with:');
        console.log(`   Client ID: ${(this as any).auth.jsonContent?.client_id || 'your-service-account-client-id'}`);
        console.log('   Scopes:');
        console.log('     https://www.googleapis.com/auth/calendar');
        console.log('     https://www.googleapis.com/auth/calendar.events');
        console.log('4. Save and wait a few minutes for propagation');
        console.log('5. Try running this test again');
      }

      throw error;
    }
  }
}

async function createDemoInvite() {
  console.log('🧪 Testing demo invite creation with fixed domain-wide delegation...');

  try {
    const config = loadConfig();
    const calendar = new DemoCalendarService(config);

    // Use configured test email or fallback
    const testEmail = config.test_mode?.test_email || 'stschwartz@stanford.edu';
    await calendar.createDemoInviteWithFireflies(testEmail);

  } catch (error) {
    console.error('❌ Test failed:', error);
    process.exit(1);
  }
}

createDemoInvite().catch(console.error);