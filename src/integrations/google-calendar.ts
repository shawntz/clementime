import { google } from 'googleapis';
import { GoogleAuth, JWT } from 'google-auth-library';
import { ScheduleSlot, Config } from '../types';
import { format } from 'date-fns';

interface CalendarMeeting {
  id: string;
  htmlLink: string;
  hangoutLink: string;
  summary: string;
  start: { dateTime: string };
  end: { dateTime: string };
}

export class GoogleCalendarService {
  private config: Config;
  private auth!: GoogleAuth;
  private calendar: any;

  // Helper methods for configurable terminology
  private getFacilitatorLabel(): string {
    return this.config.terminology?.facilitator_label || 'Facilitator';
  }

  private getParticipantLabel(): string {
    return this.config.terminology?.participant_label || 'Participant';
  }

  constructor(config: Config) {
    this.config = config;
    this.initializeAuth();
  }

  private initializeAuth(): void {
    // Check if we have service account credentials
    if (process.env.GOOGLE_SERVICE_ACCOUNT_KEY) {
      try {
        const serviceAccountKey = JSON.parse(process.env.GOOGLE_SERVICE_ACCOUNT_KEY);
        this.auth = new GoogleAuth({
          credentials: serviceAccountKey,
          scopes: [
            'https://www.googleapis.com/auth/calendar',
            'https://www.googleapis.com/auth/calendar.events',
          ],
        });
      } catch (error) {
        console.error('Failed to parse GOOGLE_SERVICE_ACCOUNT_KEY:', error);
        throw new Error('Invalid service account credentials');
      }
    } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      // Use service account key file
      this.auth = new GoogleAuth({
        keyFile: process.env.GOOGLE_APPLICATION_CREDENTIALS,
        scopes: [
          'https://www.googleapis.com/auth/calendar',
          'https://www.googleapis.com/auth/calendar.events',
        ],
      });
    } else {
      // Fallback to OAuth
      console.warn('⚠️  Using OAuth credentials for Google Calendar - consider using service account credentials.');
      this.auth = new GoogleAuth({
        scopes: [
          'https://www.googleapis.com/auth/calendar',
          'https://www.googleapis.com/auth/calendar.events',
        ],
        credentials: {
          client_id: process.env.GOOGLE_CLIENT_ID,
          client_secret: process.env.GOOGLE_CLIENT_SECRET,
          refresh_token: process.env.GOOGLE_REFRESH_TOKEN,
          type: 'authorized_user',
        },
      });
    }

    this.calendar = google.calendar({ version: 'v3', auth: this.auth });
  }

  async createMeetingForSlot(slot: ScheduleSlot, adminEmails: string[] = []): Promise<CalendarMeeting> {
    try {
      // Determine if we should create on facilitator's calendar (if in our workspace) or admin's calendar
      const organizationDomain = this.config.organization?.domain || 'shawnschwartz.com';
      const isInternalTA = slot.ta.email.endsWith(`@${organizationDomain}`);
      let calendarService: GoogleCalendarService = this;
      let calendarId = 'primary';

      if (isInternalTA) {
        // If facilitator is in our workspace, create directly on their calendar
        console.log(`  📅 Creating on internal ${this.getFacilitatorLabel().toLowerCase()} calendar: ${slot.ta.email}`);
        calendarService = await this.impersonateUser(slot.ta.email);
      } else {
        // For external facilitators, create on an admin's calendar within the workspace
        // This allows us to send invitations properly
        const workspaceAdmin = adminEmails.find(email => email.endsWith(`@${organizationDomain}`));
        if (workspaceAdmin) {
          console.log(`  📧 Creating on admin calendar (${workspaceAdmin}), inviting external ${this.getFacilitatorLabel().toLowerCase()}: ${slot.ta.email}`);
          calendarService = await this.impersonateUser(workspaceAdmin);
        } else {
          console.log(`  ⚠️  No workspace admin found, creating without invitations`);
        }
      }

      const event = {
        summary: `Session - ${slot.student.name}`,
        description: `
Scheduled Session

${this.getParticipantLabel()}: ${slot.student.name}
Email: ${slot.student.email}
${this.getFacilitatorLabel()}: ${slot.ta.name}
Section: ${slot.section_id}
Location: ${slot.location}

This is an automated scheduling session. Recording will be enabled.
        `.trim(),
        start: {
          dateTime: slot.start_time.toISOString(),
          timeZone: this.config.organization?.timezone || 'America/Los_Angeles',
        },
        end: {
          dateTime: slot.end_time.toISOString(),
          timeZone: this.config.organization?.timezone || 'America/Los_Angeles',
        },
        attendees: [
          // Add facilitator as attendee (for external facilitators or when created on admin calendar)
          ...(!isInternalTA ? [{ email: slot.ta.email }] : []),
          // Include other admin team members (but not the one whose calendar we're using)
          ...adminEmails
            .filter(email => {
              // Don't add the calendar owner as an attendee
              const calendarOwner = isInternalTA ? slot.ta.email :
                adminEmails.find(e => e.endsWith(`@${organizationDomain}`));
              return email !== calendarOwner;
            })
            .map(email => ({ email })),
          // Add AI recording service if enabled
          ...(this.config.ai_recording?.enabled && this.config.ai_recording?.auto_invite ?
            [{ email: this.config.ai_recording.service_email }] : []),
          // Only invite facilitator and admin team members, not participants for security
          // Participants will get the meet link via Slack notifications
        ],
        // Create Google Meet conference
        conferenceData: {
          createRequest: {
            requestId: `session-${slot.section_id}-${slot.student.email}-${Date.now()}`,
            conferenceSolutionKey: {
              type: 'hangoutsMeet',  // Use 'hangoutsMeet' for Google Meet
            },
          },
        },
        // Allow guests to modify event and see other guests (enables direct join)
        guestsCanModify: false,
        guestsCanSeeOtherGuests: true,
        // Enable recording by default (if workspace allows)
        gadgets: {
          preferences: {
            'goo.hangout.recordingEnabled': 'true',
          },
        },
        // Set meeting as private
        visibility: 'private',
        // Set reminder for facilitator
        reminders: {
          useDefault: false,
          overrides: [
            { method: 'email', minutes: 30 },
            { method: 'popup', minutes: 10 },
          ],
        },
      };

      const response = await calendarService.calendar.events.insert({
        calendarId: calendarId,
        resource: event,
        conferenceDataVersion: 1,
        sendUpdates: isInternalTA ? 'none' : 'all', // Only send invites for external facilitators
      });

      const createdEvent = response.data;

      console.log(`✅ Calendar event created for ${slot.student.name}: ${createdEvent.id}`);

      return {
        id: createdEvent.id!,
        htmlLink: createdEvent.htmlLink!,
        hangoutLink: createdEvent.hangoutLink!,
        summary: createdEvent.summary!,
        start: createdEvent.start!,
        end: createdEvent.end!,
      };
    } catch (error: any) {
      console.error(`❌ Failed to create calendar event for ${slot.student.name}:`, error);

      // If it's an auth error, provide helpful guidance
      if (error.code === 401) {
        console.error('Authentication failed. Make sure service account has Calendar API access and domain-wide delegation.');
      } else if (error.code === 403) {
        console.error('Permission denied. Check if service account has proper Calendar scopes in domain-wide delegation.');
      }

      throw error;
    }
  }

  private getAdminEmails(): string[] {
    const adminEmails: string[] = [];

    // Include test email if in test mode
    if (this.config.test_mode?.enabled && this.config.test_mode.test_email) {
      adminEmails.push(this.config.test_mode.test_email);
    }

    // TODO: Map admin_users Slack IDs to email addresses
    // For now, we use test_email when available
    return adminEmails;
  }

  async createMeetingsForSchedule(schedule: Map<string, ScheduleSlot[]>): Promise<Map<string, ScheduleSlot[]>> {
    const updatedSchedule = new Map<string, ScheduleSlot[]>();

    // Check if calendar invites are enabled (default: false)
    const calendarInvitesEnabled = this.config.google_meet.calendar_invites_enabled === true;

    if (!calendarInvitesEnabled) {
      console.log('📅 Calendar invites disabled in configuration, skipping calendar event creation');
      return schedule; // Return original schedule without calendar events
    }

    const adminEmails = this.getAdminEmails();

    for (const [sectionId, slots] of schedule) {
      const updatedSlots: ScheduleSlot[] = [];

      for (const slot of slots) {
        try {
          const meeting = await this.createMeetingForSlot(slot, adminEmails);

          const updatedSlot: ScheduleSlot = {
            ...slot,
            meet_link: meeting.hangoutLink,
            meet_code: this.extractMeetingCodeFromLink(meeting.hangoutLink),
            calendar_event_id: meeting.id,
            calendar_link: meeting.htmlLink,
          };

          updatedSlots.push(updatedSlot);

          // Small delay to avoid rate limiting
          await new Promise(resolve => setTimeout(resolve, 200));
        } catch (error) {
          console.error(`Failed to create calendar event for ${slot.student.name}:`, error);
          // Add slot without meeting link as fallback
          updatedSlots.push(slot);
        }
      }

      updatedSchedule.set(sectionId, updatedSlots);
    }

    return updatedSchedule;
  }

  private extractMeetingCodeFromLink(hangoutLink: string): string {
    // Extract meeting code from Google Meet link
    // Format: https://meet.google.com/abc-defg-hij
    const match = hangoutLink.match(/meet\.google\.com\/([a-z-]+)/);
    return match ? match[1] : '';
  }

  async updateEventRecordingSettings(eventId: string, enableRecording: boolean = true): Promise<void> {
    try {
      await this.calendar.events.patch({
        calendarId: 'primary',
        eventId: eventId,
        resource: {
          gadgets: {
            preferences: {
              'goo.hangout.recordingEnabled': enableRecording.toString(),
            },
          },
        },
      });

      console.log(`✅ Updated recording settings for event ${eventId}: ${enableRecording}`);
    } catch (error) {
      console.error(`❌ Failed to update recording settings for event ${eventId}:`, error);
    }
  }

  async deleteEvent(eventId: string): Promise<void> {
    try {
      await this.calendar.events.delete({
        calendarId: 'primary',
        eventId: eventId,
      });

      console.log(`✅ Deleted calendar event: ${eventId}`);
    } catch (error) {
      console.error(`❌ Failed to delete calendar event ${eventId}:`, error);
    }
  }


  // Helper method to impersonate a user (needed for service accounts)
  async impersonateUser(userEmail: string): Promise<GoogleCalendarService> {
    if (process.env.GOOGLE_SERVICE_ACCOUNT_KEY) {
      const serviceAccountKey = JSON.parse(process.env.GOOGLE_SERVICE_ACCOUNT_KEY);
      const auth = new JWT({
        email: serviceAccountKey.client_email,
        key: serviceAccountKey.private_key,
        scopes: [
          'https://www.googleapis.com/auth/calendar',
          'https://www.googleapis.com/auth/calendar.events',
        ],
        subject: userEmail, // Impersonate this user
      });

      const newService = new GoogleCalendarService(this.config);
      newService.auth = auth as any;
      newService.calendar = google.calendar({ version: 'v3', auth: auth as any });

      return newService;
    }

    return this; // Return self if not using service account
  }

  async shareCalendarWithUser(userEmail: string): Promise<void> {
    try {
      const rule = {
        scope: {
          type: 'user',
          value: userEmail,
        },
        role: 'reader', // or 'writer' if you want edit access
      };

      await this.calendar.acl.insert({
        calendarId: 'primary',
        resource: rule,
      });

      console.log(`✅ Calendar shared with ${userEmail}`);
      console.log(`   The service account calendar should now appear in your "Other calendars" list`);
    } catch (error: any) {
      console.error(`❌ Failed to share calendar:`, error.message);
      throw error;
    }
  }

  async createTestEventOnUserCalendar(targetUserEmail: string): Promise<void> {
    try {
      // Create impersonated service for the target user
      const impersonatedService = await this.impersonateUser(targetUserEmail);

      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(18, 0, 0, 0); // 6:00 PM tomorrow

      const endTime = new Date(tomorrow);
      endTime.setMinutes(endTime.getMinutes() + 15); // 15 minute test event

      const event = {
        summary: 'Test Event - Host Management Settings Check',
        description: `This event tests Google Meet host management settings after admin console changes.\n\nCreated on ${targetUserEmail}'s calendar using Domain-Wide Delegation.`,
        start: {
          dateTime: tomorrow.toISOString(),
          timeZone: this.config.organization?.timezone || 'America/Los_Angeles',
        },
        end: {
          dateTime: endTime.toISOString(),
          timeZone: this.config.organization?.timezone || 'America/Los_Angeles',
        },
        // Create Google Meet conference to test host management
        conferenceData: {
          createRequest: {
            requestId: `host-management-test-${Date.now()}`,
            conferenceSolutionKey: {
              type: 'hangoutsMeet',
            },
          },
        },
        // Allow guests to see other guests and join directly
        guestsCanModify: false,
        guestsCanSeeOtherGuests: true,
        visibility: 'private',
        colorId: '11', // Red color to make it stand out
        reminders: {
          useDefault: false,
          overrides: [
            { method: 'popup', minutes: 10 },
          ],
        },
      };

      const response = await impersonatedService.calendar.events.insert({
        calendarId: 'primary', // This will be the target user's primary calendar
        resource: event,
        conferenceDataVersion: 1,
      });

      const createdEvent = response.data;
      console.log(`✅ Host management test event created successfully!`);
      console.log(`   Event created on ${targetUserEmail}'s calendar`);
      console.log(`   Event ID: ${createdEvent.id}`);
      console.log(`   Summary: ${createdEvent.summary}`);
      console.log(`   Start: ${format(new Date(createdEvent.start!.dateTime!), 'EEE MMM d, h:mm a')}`);
      console.log(`   Calendar Link: ${createdEvent.htmlLink}`);
      console.log(`   Google Meet Link: ${createdEvent.hangoutLink}`);
      console.log(`   Test the Meet link to verify admin console changes worked!`);

    } catch (error: any) {
      console.error(`❌ Domain-Wide Delegation test failed:`, error.message);

      if (error.code === 401 || error.code === 403) {
        console.log('\n📋 Troubleshooting Domain-Wide Delegation:');
        console.log('1. Go to Google Admin Console (admin.google.com)');
        console.log('2. Navigate to Security > API Controls > Domain-wide delegation');
        console.log('3. Add a new client with:');
        console.log(`   Client ID: ${this.auth.jsonContent?.client_id || '104845694920093044352'}`);
        console.log('   Scopes:');
        console.log('     https://www.googleapis.com/auth/calendar');
        console.log('     https://www.googleapis.com/auth/calendar.events');
        console.log('4. Save and wait a few minutes for propagation');
        console.log('5. Try running this test again');
      }

      throw error;
    }
  }

  async createTestEvent(): Promise<void> {
    try {
      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(18, 0, 0, 0); // 6:00 PM tomorrow

      const endTime = new Date(tomorrow);
      endTime.setMinutes(endTime.getMinutes() + 15); // 15 minute test event

      const testEmail = this.config.test_mode?.test_email || 'test@example.com';

      const event = {
        summary: 'Test Calendar Event - Host Management Test',
        description: 'This is a test calendar event to verify Google Meet host management settings after admin console changes.',
        start: {
          dateTime: tomorrow.toISOString(),
          timeZone: this.config.organization?.timezone || 'America/Los_Angeles',
        },
        end: {
          dateTime: endTime.toISOString(),
          timeZone: this.config.organization?.timezone || 'America/Los_Angeles',
        },
        // Create Google Meet conference to test host management
        conferenceData: {
          createRequest: {
            requestId: `host-test-${Date.now()}`,
            conferenceSolutionKey: {
              type: 'hangoutsMeet',
            },
          },
        },
        // Allow guests to see other guests and join directly
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

      const response = await this.calendar.events.insert({
        calendarId: 'primary',
        resource: event,
        conferenceDataVersion: 1,
      });

      const createdEvent = response.data;
      console.log(`✅ Test calendar event created successfully!`);
      console.log(`   Event ID: ${createdEvent.id}`);
      console.log(`   Summary: ${createdEvent.summary}`);
      console.log(`   Start: ${format(new Date(createdEvent.start!.dateTime!), 'EEE MMM d, h:mm a')}`);
      console.log(`   Calendar Link: ${createdEvent.htmlLink}`);
      console.log(`   Google Meet Link: ${createdEvent.hangoutLink}`);
      console.log(`   Note: Testing host management settings - try joining the Meet to verify admin console changes worked`);

    } catch (error: any) {
      console.error(`❌ Failed to create test calendar event:`, error);

      if (error.code === 401) {
        console.error('Authentication failed. Check service account credentials.');
      } else if (error.code === 403) {
        console.error('Permission denied. Check Calendar API access and scopes.');
      } else {
        console.error('Error details:', error.message);
      }

      throw error;
    }
  }
}