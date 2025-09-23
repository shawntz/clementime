import { google } from 'googleapis';
import { GoogleAuth } from 'google-auth-library';

export interface SheetStudent {
  name: string;
  email: string;
  slack_id?: string;
}

export interface SheetTab {
  title: string;
  students: SheetStudent[];
}

export interface SessionLogEntry {
  timestamp: string;
  operation: string;
  section_id: string;
  student_name: string;
  student_email: string;
  ta_name: string;
  session_time: string;
  meeting_link?: string;
  status: string;
  notes?: string;
}

export class GoogleSheetsService {
  private sheets: any;
  private auth: GoogleAuth;

  constructor() {
    // Use the same auth as other Google services
    this.auth = new GoogleAuth({
      scopes: [
        'https://www.googleapis.com/auth/spreadsheets.readonly',
        'https://www.googleapis.com/auth/drive.readonly'
      ]
    });

    this.sheets = google.sheets({ version: 'v4', auth: this.auth });
  }

  /**
   * Extract spreadsheet ID from various Google Sheets URL formats
   */
  private extractSpreadsheetId(url: string): string {
    const patterns = [
      /\/spreadsheets\/d\/([a-zA-Z0-9-_]+)/,  // Standard URL
      /\/d\/([a-zA-Z0-9-_]+)/,               // Short URL
      /^([a-zA-Z0-9-_]+)$/                   // Direct ID
    ];

    for (const pattern of patterns) {
      const match = url.match(pattern);
      if (match) {
        return match[1];
      }
    }

    throw new Error(`Invalid Google Sheets URL or ID: ${url}`);
  }

  /**
   * Get all sheet tabs from a spreadsheet
   */
  async getSheetTabs(spreadsheetUrl: string): Promise<string[]> {
    try {
      const spreadsheetId = this.extractSpreadsheetId(spreadsheetUrl);

      const response = await this.sheets.spreadsheets.get({
        spreadsheetId,
        fields: 'sheets.properties.title'
      });

      return response.data.sheets.map((sheet: any) => sheet.properties.title);
    } catch (error) {
      console.error('Error getting sheet tabs:', error);
      throw new Error(`Failed to get sheet tabs: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Read students from a specific sheet tab
   */
  async readStudentsFromTab(spreadsheetUrl: string, tabName: string): Promise<SheetStudent[]> {
    try {
      const spreadsheetId = this.extractSpreadsheetId(spreadsheetUrl);

      // Read the entire sheet data
      const response = await this.sheets.spreadsheets.values.get({
        spreadsheetId,
        range: `'${tabName}'!A:Z`, // Read all columns to be safe
      });

      const rows = response.data.values || [];

      if (rows.length === 0) {
        console.warn(`No data found in sheet tab: ${tabName}`);
        return [];
      }

      // First row should be headers
      const headers = rows[0].map((h: string) => h.toLowerCase().trim());

      // Find column indices
      const nameCol = this.findColumnIndex(headers, ['name', 'student name', 'full name']);
      const emailCol = this.findColumnIndex(headers, ['email', 'student email', 'email address']);
      const slackCol = this.findColumnIndex(headers, ['slack_id', 'slack id', 'slack', 'slack user id']);

      if (nameCol === -1 || emailCol === -1) {
        throw new Error(`Required columns not found in sheet '${tabName}'. Need 'name' and 'email' columns.`);
      }

      // Process data rows
      const students: SheetStudent[] = [];
      for (let i = 1; i < rows.length; i++) {
        const row = rows[i];

        // Skip empty rows
        if (!row || row.length === 0 || !row[nameCol] || !row[emailCol]) {
          continue;
        }

        const student: SheetStudent = {
          name: String(row[nameCol] || '').trim(),
          email: String(row[emailCol] || '').trim().toLowerCase(),
        };

        // Add slack_id if available
        if (slackCol !== -1 && row[slackCol]) {
          student.slack_id = String(row[slackCol]).trim();
        }

        // Validate required fields
        if (student.name && student.email) {
          students.push(student);
        }
      }

      console.log(`📊 Loaded ${students.length} students from sheet tab: ${tabName}`);
      return students;
    } catch (error) {
      console.error(`Error reading students from tab '${tabName}':`, error);
      throw new Error(`Failed to read students from tab '${tabName}': ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Read all students organized by sheet tabs
   */
  async readAllStudents(spreadsheetUrl: string): Promise<SheetTab[]> {
    try {
      const tabs = await this.getSheetTabs(spreadsheetUrl);
      const results: SheetTab[] = [];

      for (const tabName of tabs) {
        try {
          const students = await this.readStudentsFromTab(spreadsheetUrl, tabName);
          results.push({
            title: tabName,
            students
          });
        } catch (error) {
          console.warn(`Skipping tab '${tabName}' due to error:`, error);
          // Continue with other tabs
        }
      }

      return results;
    } catch (error) {
      console.error('Error reading all students:', error);
      throw error;
    }
  }

  /**
   * Helper to find column index by multiple possible names
   */
  private findColumnIndex(headers: string[], possibleNames: string[]): number {
    for (const name of possibleNames) {
      const index = headers.findIndex(header =>
        header.includes(name) || name.includes(header)
      );
      if (index !== -1) {
        return index;
      }
    }
    return -1;
  }

  /**
   * Write session log entries to a Google Sheet tab (for session tracking/history)
   */
  async writeSessionLog(spreadsheetUrl: string, entries: SessionLogEntry[], logTabName: string = 'SessionLog'): Promise<void> {
    try {
      const spreadsheetId = this.extractSpreadsheetId(spreadsheetUrl);

      // Check if log tab exists, create if it doesn't
      await this.ensureLogTabExists(spreadsheetId, logTabName);

      // Prepare rows for insertion
      const rows = entries.map(entry => [
        entry.timestamp,
        entry.operation,
        entry.section_id,
        entry.student_name,
        entry.student_email,
        entry.ta_name,
        entry.session_time,
        entry.meeting_link || '',
        entry.status,
        entry.notes || ''
      ]);

      // Append to the sheet
      await this.sheets.spreadsheets.values.append({
        spreadsheetId,
        range: `'${logTabName}'!A:J`,
        valueInputOption: 'RAW',
        resource: {
          values: rows
        }
      });

      console.log(`✅ Wrote ${entries.length} session log entries to Google Sheets`);
    } catch (error) {
      console.error('Error writing session log:', error);
      throw new Error(`Failed to write session log: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Ensure log tab exists with proper headers
   */
  private async ensureLogTabExists(spreadsheetId: string, logTabName: string): Promise<void> {
    try {
      // First check if tab exists
      const response = await this.sheets.spreadsheets.get({
        spreadsheetId,
        fields: 'sheets.properties.title'
      });

      const existingTabs = response.data.sheets.map((sheet: any) => sheet.properties.title);

      if (existingTabs.includes(logTabName)) {
        // Tab exists, check if it has headers
        const headerResponse = await this.sheets.spreadsheets.values.get({
          spreadsheetId,
          range: `'${logTabName}'!A1:J1`
        });

        if (!headerResponse.data.values || headerResponse.data.values.length === 0) {
          // Add headers
          await this.addLogHeaders(spreadsheetId, logTabName);
        }
      } else {
        // Create new tab
        await this.sheets.spreadsheets.batchUpdate({
          spreadsheetId,
          resource: {
            requests: [
              {
                addSheet: {
                  properties: {
                    title: logTabName
                  }
                }
              }
            ]
          }
        });

        // Add headers to new tab
        await this.addLogHeaders(spreadsheetId, logTabName);
      }
    } catch (error) {
      console.warn(`Warning: Could not ensure log tab exists: ${error}`);
    }
  }

  /**
   * Add headers to log tab
   */
  private async addLogHeaders(spreadsheetId: string, logTabName: string): Promise<void> {
    const headers = [
      'Timestamp',
      'Operation',
      'Section ID',
      'Student Name',
      'Student Email',
      'TA Name',
      'Session Time',
      'Meeting Link',
      'Status',
      'Notes'
    ];

    await this.sheets.spreadsheets.values.update({
      spreadsheetId,
      range: `'${logTabName}'!A1:J1`,
      valueInputOption: 'RAW',
      resource: {
        values: [headers]
      }
    });
  }

  /**
   * Create a new Google Sheet with template tabs for sections
   */
  async createTemplateSheet(title: string, sectionIds: string[]): Promise<{ success: boolean; spreadsheetUrl?: string; spreadsheetId?: string; message: string }> {
    try {
      // Create a new spreadsheet
      const response = await this.sheets.spreadsheets.create({
        resource: {
          properties: {
            title: `${title} - ClemenTime Student Roster`
          },
          sheets: [
            // Create initial sheet for instructions
            {
              properties: {
                title: "Instructions"
              }
            },
            // Create tabs for each section
            ...sectionIds.map(sectionId => ({
              properties: {
                title: sectionId
              }
            })),
            // Create session log tab
            {
              properties: {
                title: "SessionLog"
              }
            }
          ]
        }
      });

      const spreadsheetId = response.data.spreadsheetId!;
      const spreadsheetUrl = `https://docs.google.com/spreadsheets/d/${spreadsheetId}/edit`;

      // Add instructions to the Instructions tab
      await this.addInstructionsTab(spreadsheetId);

      // Add headers to each section tab
      for (const sectionId of sectionIds) {
        await this.addSectionHeaders(spreadsheetId, sectionId);
      }

      // Add session log headers
      await this.addLogHeaders(spreadsheetId, 'SessionLog');

      // Make the sheet publicly viewable (or at least accessible to the service account)
      await this.makeSheetAccessible(spreadsheetId);

      return {
        success: true,
        spreadsheetUrl,
        spreadsheetId,
        message: `Successfully created template sheet with ${sectionIds.length} section tabs`
      };
    } catch (error) {
      console.error('Error creating template sheet:', error);
      return {
        success: false,
        message: error instanceof Error ? error.message : 'Failed to create template sheet'
      };
    }
  }

  /**
   * Add instructions to the Instructions tab
   */
  private async addInstructionsTab(spreadsheetId: string): Promise<void> {
    const instructions = [
      ['ClemenTime Student Roster - Instructions'],
      [''],
      ['This Google Sheet has been automatically created for your ClemenTime session scheduler.'],
      [''],
      ['How to use:'],
      ['1. Each tab represents a section (e.g., section_01, section_02)'],
      ['2. Add student information in each tab with these columns:'],
      ['   - name: Student full name'],
      ['   - email: Student email address'],
      ['   - slack_id: (Optional) Student Slack ID for notifications'],
      [''],
      ['3. The SessionLog tab will automatically track all scheduled sessions'],
      [''],
      ['4. Changes to student rosters will be automatically synced to your dashboard'],
      ['   (refresh may take up to 15 minutes depending on your settings)'],
      [''],
      ['5. Do not rename the tab names - they must match your section IDs'],
      [''],
      ['Need help? Check the ClemenTime documentation or contact support.']
    ];

    await this.sheets.spreadsheets.values.update({
      spreadsheetId,
      range: 'Instructions!A:A',
      valueInputOption: 'RAW',
      resource: {
        values: instructions
      }
    });
  }

  /**
   * Add headers to a section tab
   */
  private async addSectionHeaders(spreadsheetId: string, tabName: string): Promise<void> {
    const headers = [['name', 'email', 'slack_id']];
    const sampleData = [
      ['John Doe', 'john.doe@university.edu', 'U12345678'],
      ['Jane Smith', 'jane.smith@university.edu', 'U87654321']
    ];

    await this.sheets.spreadsheets.values.update({
      spreadsheetId,
      range: `'${tabName}'!A1:C1`,
      valueInputOption: 'RAW',
      resource: {
        values: headers
      }
    });

    // Add sample data
    await this.sheets.spreadsheets.values.update({
      spreadsheetId,
      range: `'${tabName}'!A2:C3`,
      valueInputOption: 'RAW',
      resource: {
        values: sampleData
      }
    });
  }

  /**
   * Make the sheet accessible (this might need adjustment based on your auth setup)
   */
  private async makeSheetAccessible(spreadsheetId: string): Promise<void> {
    try {
      // Make the sheet readable by anyone with the link
      const drive = google.drive({ version: 'v3', auth: this.auth });

      await drive.permissions.create({
        fileId: spreadsheetId,
        resource: {
          role: 'reader',
          type: 'anyone'
        }
      });
    } catch (error) {
      console.warn('Could not make sheet publicly accessible:', error);
      // This is non-critical - the sheet might still work with service account access
    }
  }

  /**
   * Test connection to a Google Sheet
   */
  async testConnection(spreadsheetUrl: string): Promise<{ success: boolean; message: string; tabs?: string[] }> {
    try {
      const tabs = await this.getSheetTabs(spreadsheetUrl);
      return {
        success: true,
        message: `Successfully connected to sheet with ${tabs.length} tabs`,
        tabs
      };
    } catch (error) {
      return {
        success: false,
        message: error instanceof Error ? error.message : 'Unknown error'
      };
    }
  }
}

// Singleton instance
export const googleSheetsService = new GoogleSheetsService();