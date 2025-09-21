import { google } from 'googleapis';
import { GoogleAuth } from 'google-auth-library';
import { ScheduleSlot, Config } from '../types';

interface GoogleMeetSpace {
  name: string;
  meetingUri: string;
  meetingCode: string;
}

interface GoogleMeetRecording {
  name: string;
  driveDestination: {
    file: string;
    exportUri: string;
  };
  state: string;
}

interface GoogleMeetTranscript {
  name: string;
  docsDestination: {
    document: string;
    exportUri: string;
  };
  state: string;
}

export class GoogleMeetService {
  private config: Config;
  private auth!: GoogleAuth;
  private calendar: any;

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
      console.warn('⚠️  Using OAuth credentials for Google Meet - consider using service account credentials.');
      this.auth = new GoogleAuth({
        scopes: [
          'https://www.googleapis.com/auth/calendar',
          'https://www.googleapis.com/auth/calendar.events',
        ],
        credentials: {
          client_id: process.env.GOOGLE_MEET_CLIENT_ID || process.env.GOOGLE_CLIENT_ID,
          client_secret: process.env.GOOGLE_MEET_CLIENT_SECRET || process.env.GOOGLE_CLIENT_SECRET,
          refresh_token: process.env.GOOGLE_MEET_REFRESH_TOKEN || process.env.GOOGLE_REFRESH_TOKEN,
          type: 'authorized_user',
        },
      });
    }

    this.calendar = google.calendar({ version: 'v3', auth: this.auth });
  }

  async createMeetingSpace(slot: ScheduleSlot): Promise<GoogleMeetSpace> {
    try {
      // Create a temporary calendar event to generate a Meet link
      const event = {
        summary: `Session - ${slot.student.name}`,
        description: `
Scheduled Session

Participant: ${slot.student.name}
Email: ${slot.student.email}
Facilitator: ${slot.ta.name}
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
          // Add facilitator as attendee
          { email: slot.ta.email },
          // Add AI recording service if enabled
          ...(this.config.ai_recording?.enabled && this.config.ai_recording?.auto_invite ?
            [{ email: this.config.ai_recording.service_email }] : []),
        ],
        // Create Google Meet conference
        conferenceData: {
          createRequest: {
            requestId: `session-${slot.section_id}-${slot.student.email}-${Date.now()}`,
            conferenceSolutionKey: {
              type: 'hangoutsMeet',
            },
          },
        },
        // Allow guests to see other guests and join directly
        guestsCanModify: false,
        guestsCanSeeOtherGuests: true,
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

      const response = await this.calendar.events.insert({
        calendarId: 'primary',
        resource: event,
        conferenceDataVersion: 1,
        sendUpdates: 'all', // Send invitations to all attendees including fred@fireflies.ai
      });

      const createdEvent = response.data;
      const meetingCode = this.extractMeetingCodeFromLink(createdEvent.hangoutLink || '');

      console.log(`✅ Google Meet space created for ${slot.student.name}: ${createdEvent.hangoutLink}`);

      return {
        name: createdEvent.id!,
        meetingUri: createdEvent.hangoutLink!,
        meetingCode: meetingCode,
      };
    } catch (error) {
      console.error(`❌ Failed to create Google Meet space for ${slot.student.name}:`, error);

      // Generate fallback Meet link
      const fallbackLink = `https://meet.google.com/new?authuser=0&ijlm=${slot.section_id}-${slot.student.email.split('@')[0]}-${Date.now()}`;
      console.log(`📎 Generated fallback Google Meet link for ${slot.student.name}: ${fallbackLink}`);

      return {
        name: `fallback-${Date.now()}`,
        meetingUri: fallbackLink,
        meetingCode: '',
      };
    }
  }

  private extractMeetingCodeFromLink(hangoutLink: string): string {
    // Extract meeting code from Google Meet link
    // Format: https://meet.google.com/abc-defg-hij
    const match = hangoutLink.match(/meet\.google\.com\/([a-z-]+)/);
    return match ? match[1] : '';
  }

  async getMeetingRecordings(conferenceRecordName: string): Promise<GoogleMeetRecording[]> {
    console.log(`ℹ️  Recording retrieval not available with Calendar API approach for conference ${conferenceRecordName}`);
    console.log(`   Recordings are still created automatically if enabled in workspace settings`);
    console.log(`   Check Google Drive for meeting recordings after sessions complete`);
    return [];
  }

  async getMeetingTranscripts(conferenceRecordName: string): Promise<GoogleMeetTranscript[]> {
    console.log(`ℹ️  Transcript retrieval not available with Calendar API approach for conference ${conferenceRecordName}`);
    console.log(`   Transcripts are still created automatically if enabled in workspace settings`);
    console.log(`   Check Google Docs for meeting transcripts after sessions complete`);
    return [];
  }

  async getConferenceRecord(spaceName: string): Promise<string | null> {
    console.log(`ℹ️  Conference record lookup not available with Calendar API approach for space ${spaceName}`);
    console.log(`   Meetings are still created and work normally`);
    return null;
  }

  async createMeetingsForSchedule(schedule: Map<string, ScheduleSlot[]>): Promise<Map<string, ScheduleSlot[]>> {
    const updatedSchedule = new Map<string, ScheduleSlot[]>();

    for (const [sectionId, slots] of schedule) {
      const updatedSlots: ScheduleSlot[] = [];

      for (const slot of slots) {
        try {
          const meetingSpace = await this.createMeetingSpace(slot);

          const updatedSlot: ScheduleSlot = {
            ...slot,
            meet_link: meetingSpace.meetingUri,
            meet_space_name: meetingSpace.name,
            meet_code: meetingSpace.meetingCode,
          };

          updatedSlots.push(updatedSlot);

          await new Promise(resolve => setTimeout(resolve, 100));
        } catch (error) {
          console.error(`Failed to create meeting space for ${slot.student.name}:`, error);
          updatedSlots.push(slot);
        }
      }

      updatedSchedule.set(sectionId, updatedSlots);
    }

    return updatedSchedule;
  }

  async pollForRecordingsAndTranscripts(spaceName: string, maxAttempts: number = 20): Promise<{recordings: GoogleMeetRecording[], transcripts: GoogleMeetTranscript[]}> {
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        const conferenceRecord = await this.getConferenceRecord(spaceName);

        if (!conferenceRecord) {
          console.log(`⏳ Attempt ${attempt}/${maxAttempts}: No conference record yet for space ${spaceName}`);
          await new Promise(resolve => setTimeout(resolve, 30000));
          continue;
        }

        const [recordings, transcripts] = await Promise.all([
          this.getMeetingRecordings(conferenceRecord),
          this.getMeetingTranscripts(conferenceRecord)
        ]);

        const completedRecordings = recordings.filter(r => r.state === 'FILE_GENERATED');
        const completedTranscripts = transcripts.filter(t => t.state === 'FILE_GENERATED');

        if (completedRecordings.length > 0 || completedTranscripts.length > 0) {
          console.log(`✅ Found ${completedRecordings.length} recording(s) and ${completedTranscripts.length} transcript(s) for space ${spaceName}`);
          return { recordings: completedRecordings, transcripts: completedTranscripts };
        }

        console.log(`⏳ Attempt ${attempt}/${maxAttempts}: No completed recordings or transcripts yet for space ${spaceName}`);
        await new Promise(resolve => setTimeout(resolve, 30000));
      } catch (error) {
        console.error(`Attempt ${attempt}/${maxAttempts} failed:`, error);

        if (attempt === maxAttempts) {
          throw error;
        }

        await new Promise(resolve => setTimeout(resolve, 60000));
      }
    }

    throw new Error(`No recordings or transcripts found after ${maxAttempts} attempts`);
  }

  async pollForRecordings(spaceName: string, maxAttempts: number = 20): Promise<GoogleMeetRecording[]> {
    const result = await this.pollForRecordingsAndTranscripts(spaceName, maxAttempts);
    return result.recordings;
  }

  async getRecordingDownloadUrl(recording: GoogleMeetRecording): Promise<string> {
    if (recording.driveDestination?.exportUri) {
      return recording.driveDestination.exportUri;
    }

    if (recording.driveDestination?.file) {
      return `https://drive.google.com/file/d/${recording.driveDestination.file}/view`;
    }

    throw new Error('No download URL available for recording');
  }

  async getTranscriptDownloadUrl(transcript: GoogleMeetTranscript): Promise<string> {
    if (transcript.docsDestination?.exportUri) {
      return transcript.docsDestination.exportUri;
    }

    if (transcript.docsDestination?.document) {
      return `https://docs.google.com/document/d/${transcript.docsDestination.document}/edit`;
    }

    throw new Error('No download URL available for transcript');
  }
}