import { ConferenceRecordsServiceClient, SpacesServiceClient } from '@google-apps/meet';
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
  private spacesClient!: SpacesServiceClient;
  private recordingsClient!: ConferenceRecordsServiceClient;
  private auth!: GoogleAuth;

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
            'https://www.googleapis.com/auth/meetings.space.created',
            'https://www.googleapis.com/auth/meetings.space.readonly',
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
          'https://www.googleapis.com/auth/meetings.space.created',
          'https://www.googleapis.com/auth/meetings.space.readonly',
        ],
      });
    } else {
      // Fallback to OAuth (will likely fail for Google Meet API)
      console.warn('⚠️  Using OAuth credentials for Google Meet - this may not work. Consider using service account credentials.');
      this.auth = new GoogleAuth({
        scopes: [
          'https://www.googleapis.com/auth/meetings.space.created',
          'https://www.googleapis.com/auth/meetings.space.readonly',
        ],
        credentials: {
          client_id: process.env.GOOGLE_MEET_CLIENT_ID || process.env.GOOGLE_CLIENT_ID,
          client_secret: process.env.GOOGLE_MEET_CLIENT_SECRET || process.env.GOOGLE_CLIENT_SECRET,
          refresh_token: process.env.GOOGLE_MEET_REFRESH_TOKEN || process.env.GOOGLE_REFRESH_TOKEN,
          type: 'authorized_user',
        },
      });
    }

    this.spacesClient = new SpacesServiceClient({ auth: this.auth as any });
    this.recordingsClient = new ConferenceRecordsServiceClient({ auth: this.auth as any });
  }

  async createMeetingSpace(slot: ScheduleSlot): Promise<GoogleMeetSpace> {
    try {
      const [space] = await this.spacesClient.createSpace({
        space: {
          config: {
            entryPointAccess: 'ALL',
            accessType: 'OPEN',
          },
        },
      });

      console.log(`✅ Google Meet space created for ${slot.student.name}: ${space.name}`);

      return {
        name: space.name!,
        meetingUri: space.meetingUri!,
        meetingCode: space.meetingCode!,
      };
    } catch (error) {
      console.error(`❌ Failed to create Google Meet space for ${slot.student.name}:`, error);
      throw error;
    }
  }

  async getMeetingRecordings(conferenceRecordName: string): Promise<GoogleMeetRecording[]> {
    try {
      const [recordings] = await this.recordingsClient.listRecordings({
        parent: conferenceRecordName,
      });

      return recordings.map(recording => ({
        name: recording.name!,
        driveDestination: {
          file: recording.driveDestination?.file || '',
          exportUri: recording.driveDestination?.exportUri || '',
        },
        state: String(recording.state || ''),
      }));
    } catch (error: any) {
      console.error(`Failed to get recordings for conference ${conferenceRecordName}:`, error);
      if (error.code === 5) { // NOT_FOUND
        console.log(`No recordings found for conference ${conferenceRecordName}`);
        return [];
      }
      throw error;
    }
  }

  async getMeetingTranscripts(conferenceRecordName: string): Promise<GoogleMeetTranscript[]> {
    try {
      const [transcripts] = await this.recordingsClient.listTranscripts({
        parent: conferenceRecordName,
      });

      return transcripts.map(transcript => ({
        name: transcript.name!,
        docsDestination: {
          document: transcript.docsDestination?.document || '',
          exportUri: transcript.docsDestination?.exportUri || '',
        },
        state: String(transcript.state || ''),
      }));
    } catch (error: any) {
      console.error(`Failed to get transcripts for conference ${conferenceRecordName}:`, error);
      if (error.code === 5) { // NOT_FOUND
        console.log(`No transcripts found for conference ${conferenceRecordName}`);
        return [];
      }
      throw error;
    }
  }

  async getConferenceRecord(spaceName: string): Promise<string | null> {
    try {
      const [records] = await this.recordingsClient.listConferenceRecords({
        filter: `space.name="${spaceName}"`,
      });

      return records.length > 0 ? records[0].name! : null;
    } catch (error) {
      console.error(`Failed to get conference record for space ${spaceName}:`, error);
      return null;
    }
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