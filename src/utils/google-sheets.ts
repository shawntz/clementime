import { google } from "googleapis";
import { GoogleAuth } from "google-auth-library";
import https from "https";
import http from "http";

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
  private auth!: GoogleAuth;

  constructor() {
    this.initializeAuth();
  }

  private initializeAuth(): void {
    // Check if we have service account credentials
    if (process.env.GOOGLE_SERVICE_ACCOUNT_KEY) {
      try {
        const serviceAccountKey = JSON.parse(
          process.env.GOOGLE_SERVICE_ACCOUNT_KEY
        );
        this.auth = new GoogleAuth({
          credentials: serviceAccountKey,
          scopes: [
            "https://www.googleapis.com/auth/spreadsheets",
            "https://www.googleapis.com/auth/spreadsheets.readonly",
            "https://www.googleapis.com/auth/drive",
            "https://www.googleapis.com/auth/drive.readonly",
          ],
        });
        console.log(
          "✅ Using service account key from GOOGLE_SERVICE_ACCOUNT_KEY"
        );
      } catch (error) {
        console.error("Failed to parse GOOGLE_SERVICE_ACCOUNT_KEY:", error);
        this.initializeFallbackAuth();
        return;
      }
    } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      // Use service account key file
      try {
        this.auth = new GoogleAuth({
          keyFile: process.env.GOOGLE_APPLICATION_CREDENTIALS,
          scopes: [
            "https://www.googleapis.com/auth/spreadsheets",
            "https://www.googleapis.com/auth/spreadsheets.readonly",
            "https://www.googleapis.com/auth/drive",
            "https://www.googleapis.com/auth/drive.readonly",
          ],
        });
        console.log(
          "✅ Using service account key file from GOOGLE_APPLICATION_CREDENTIALS"
        );
      } catch (error) {
        console.error("Failed to load service account key file:", error);
        this.initializeFallbackAuth();
        return;
      }
    } else {
      this.initializeFallbackAuth();
      return;
    }

    this.sheets = google.sheets({ version: "v4", auth: this.auth });
  }

  private initializeFallbackAuth(): void {
    // Fallback to OAuth or Application Default Credentials
    console.warn(
      "⚠️  Service account credentials not available, trying fallback authentication..."
    );

    if (
      process.env.GOOGLE_CLIENT_ID &&
      process.env.GOOGLE_CLIENT_SECRET &&
      process.env.GOOGLE_REFRESH_TOKEN
    ) {
      // Use OAuth credentials
      this.auth = new GoogleAuth({
        scopes: [
          "https://www.googleapis.com/auth/spreadsheets",
          "https://www.googleapis.com/auth/spreadsheets.readonly",
          "https://www.googleapis.com/auth/drive",
          "https://www.googleapis.com/auth/drive.readonly",
        ],
        credentials: {
          client_id: process.env.GOOGLE_CLIENT_ID,
          client_secret: process.env.GOOGLE_CLIENT_SECRET,
          refresh_token: process.env.GOOGLE_REFRESH_TOKEN,
          type: "authorized_user",
        },
      });
      console.log("✅ Using OAuth credentials for Google Sheets");
    } else {
      // Try Application Default Credentials (for Cloud Run, etc.)
      this.auth = new GoogleAuth({
        scopes: [
          "https://www.googleapis.com/auth/spreadsheets",
          "https://www.googleapis.com/auth/spreadsheets.readonly",
          "https://www.googleapis.com/auth/drive",
          "https://www.googleapis.com/auth/drive.readonly",
        ],
      });
      console.log("✅ Using Application Default Credentials for Google Sheets");
    }

    this.sheets = google.sheets({ version: "v4", auth: this.auth });
  }

  /**
   * Extract spreadsheet ID from various Google Sheets URL formats
   */
  private extractSpreadsheetId(url: string): string {
    const patterns = [
      /\/spreadsheets\/d\/([a-zA-Z0-9-_]+)/, // Standard URL
      /\/d\/([a-zA-Z0-9-_]+)/, // Short URL
      /^([a-zA-Z0-9-_]+)$/, // Direct ID
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
        fields: "sheets.properties.title",
      });

      return response.data.sheets.map((sheet: any) => sheet.properties.title);
    } catch (error) {
      console.error("Error getting sheet tabs:", error);
      throw new Error(
        `Failed to get sheet tabs: ${
          error instanceof Error ? error.message : "Unknown error"
        }`
      );
    }
  }

  /**
   * Download CSV content from a published Google Sheets URL
   */
  async downloadCSVFromPublishedUrl(publishedUrl: string): Promise<string> {
    return new Promise((resolve, reject) => {
      const makeRequest = (url: string, redirectCount = 0) => {
        const urlObj = new URL(url);
        const isHttps = urlObj.protocol === "https:";
        const client = isHttps ? https : http;

        const options = {
          hostname: urlObj.hostname,
          port: urlObj.port || (isHttps ? 443 : 80),
          path: urlObj.pathname + urlObj.search,
          method: "GET",
          headers: {
            "User-Agent": "ClemenTime/1.0",
          },
        };

        const req = client.request(options, (res) => {
          // Handle redirects
          if (
            res.statusCode === 301 ||
            res.statusCode === 302 ||
            res.statusCode === 307 ||
            res.statusCode === 308
          ) {
            if (redirectCount >= 5) {
              reject(new Error("Too many redirects"));
              return;
            }

            const location = res.headers.location;
            if (location) {
              console.log(`🔄 Following redirect to: ${location}`);
              makeRequest(location, redirectCount + 1);
              return;
            } else {
              reject(new Error("Redirect without location header"));
              return;
            }
          }

          let data = "";

          res.on("data", (chunk) => {
            data += chunk;
          });

          res.on("end", () => {
            if (res.statusCode === 200) {
              resolve(data);
            } else {
              reject(new Error(`HTTP ${res.statusCode}: ${res.statusMessage}`));
            }
          });
        });

        req.on("error", (error) => {
          reject(new Error(`Request failed: ${error.message}`));
        });

        req.setTimeout(30000, () => {
          req.destroy();
          reject(new Error("Request timeout"));
        });

        req.end();
      };

      makeRequest(publishedUrl);
    });
  }

  /**
   * Read students from a published CSV URL (simpler approach)
   */
  async readStudentsFromPublishedCSV(
    publishedUrl: string
  ): Promise<SheetStudent[]> {
    try {
      // Convert Google Sheets URL to CSV export URL if needed
      let csvUrl = publishedUrl;
      if (publishedUrl.includes("docs.google.com/spreadsheets")) {
        // Extract spreadsheet ID
        const spreadsheetId = this.extractSpreadsheetId(publishedUrl);
        // Convert to CSV export URL (exports the first sheet)
        csvUrl = `https://docs.google.com/spreadsheets/d/${spreadsheetId}/export?format=csv`;
        console.log(`📥 Converted to CSV export URL: ${csvUrl}`);
      }

      console.log(`📥 Downloading CSV from URL: ${csvUrl}`);
      const csvContent = await this.downloadCSVFromPublishedUrl(csvUrl);

      console.log(`📊 Downloaded ${csvContent.length} characters of CSV data`);

      // Parse CSV content
      const lines = csvContent.trim().split("\n");
      if (lines.length < 2) {
        console.log("⚠️  CSV has no data rows");
        return [];
      }

      // Parse header row
      const headers = lines[0].split(",").map((h) => h.trim().toLowerCase());
      console.log(`📋 Headers found: ${headers.join(", ")}`);

      // Find column indices
      const nameIndex = headers.findIndex((h) => h.includes("name"));
      const emailIndex = headers.findIndex((h) => h.includes("email"));
      const slackIndex = headers.findIndex((h) => h.includes("slack"));

      if (nameIndex === -1 || emailIndex === -1) {
        throw new Error("Required columns (name, email) not found in CSV");
      }

      console.log(
        `📊 Column mapping: name=${nameIndex}, email=${emailIndex}, slack=${slackIndex}`
      );

      // Parse data rows
      const students: SheetStudent[] = [];
      for (let i = 1; i < lines.length; i++) {
        const row = lines[i].split(",");
        if (row.length < 2) continue; // Skip incomplete rows

        const name = row[nameIndex]?.trim();
        const email = row[emailIndex]?.trim();
        const slack_id =
          slackIndex !== -1 ? row[slackIndex]?.trim() : undefined;

        if (name && email) {
          students.push({
            name,
            email,
            slack_id: slack_id || undefined,
          });
        }
      }

      console.log(`✅ Parsed ${students.length} students from CSV`);
      return students;
    } catch (error) {
      console.error("Error reading students from published CSV:", error);
      throw new Error(`Failed to read students from CSV: ${error}`);
    }
  }

  /**
   * Read students from a specific sheet tab
   */
  async readStudentsFromTab(
    spreadsheetUrl: string,
    tabName: string
  ): Promise<SheetStudent[]> {
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
      const nameCol = this.findColumnIndex(headers, [
        "name",
        "student name",
        "full name",
      ]);
      const emailCol = this.findColumnIndex(headers, [
        "email",
        "student email",
        "email address",
      ]);
      const slackCol = this.findColumnIndex(headers, [
        "slack_id",
        "slack id",
        "slack",
        "slack user id",
      ]);

      if (nameCol === -1 || emailCol === -1) {
        throw new Error(
          `Required columns not found in sheet '${tabName}'. Need 'name' and 'email' columns.`
        );
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
          name: String(row[nameCol] || "").trim(),
          email: String(row[emailCol] || "")
            .trim()
            .toLowerCase(),
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

      console.log(
        `📊 Loaded ${students.length} students from sheet tab: ${tabName}`
      );
      return students;
    } catch (error) {
      console.error(`Error reading students from tab '${tabName}':`, error);
      throw new Error(
        `Failed to read students from tab '${tabName}': ${
          error instanceof Error ? error.message : "Unknown error"
        }`
      );
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
          const students = await this.readStudentsFromTab(
            spreadsheetUrl,
            tabName
          );
          results.push({
            title: tabName,
            students,
          });
        } catch (error) {
          console.warn(`Skipping tab '${tabName}' due to error:`, error);
          // Continue with other tabs
        }
      }

      return results;
    } catch (error) {
      console.error("Error reading all students:", error);
      throw error;
    }
  }

  /**
   * Helper to find column index by multiple possible names
   */
  private findColumnIndex(headers: string[], possibleNames: string[]): number {
    for (const name of possibleNames) {
      const index = headers.findIndex(
        (header) => header.includes(name) || name.includes(header)
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
  async writeSessionLog(
    spreadsheetUrl: string,
    entries: SessionLogEntry[],
    logTabName: string = "SessionLog"
  ): Promise<void> {
    try {
      const spreadsheetId = this.extractSpreadsheetId(spreadsheetUrl);

      // Check if log tab exists, create if it doesn't
      await this.ensureLogTabExists(spreadsheetId, logTabName);

      // Prepare rows for insertion
      const rows = entries.map((entry) => [
        entry.timestamp,
        entry.operation,
        entry.section_id,
        entry.student_name,
        entry.student_email,
        entry.ta_name,
        entry.session_time,
        entry.meeting_link || "",
        entry.status,
        entry.notes || "",
      ]);

      // Append to the sheet
      await this.sheets.spreadsheets.values.append({
        spreadsheetId,
        range: `'${logTabName}'!A:J`,
        valueInputOption: "RAW",
        resource: {
          values: rows,
        },
      });

      console.log(
        `✅ Wrote ${entries.length} session log entries to Google Sheets`
      );
    } catch (error) {
      console.error("Error writing session log:", error);
      throw new Error(
        `Failed to write session log: ${
          error instanceof Error ? error.message : "Unknown error"
        }`
      );
    }
  }

  /**
   * Ensure log tab exists with proper headers
   */
  private async ensureLogTabExists(
    spreadsheetId: string,
    logTabName: string
  ): Promise<void> {
    try {
      // First check if tab exists
      const response = await this.sheets.spreadsheets.get({
        spreadsheetId,
        fields: "sheets.properties.title",
      });

      const existingTabs = response.data.sheets.map(
        (sheet: any) => sheet.properties.title
      );

      if (existingTabs.includes(logTabName)) {
        // Tab exists, check if it has headers
        const headerResponse = await this.sheets.spreadsheets.values.get({
          spreadsheetId,
          range: `'${logTabName}'!A1:J1`,
        });

        if (
          !headerResponse.data.values ||
          headerResponse.data.values.length === 0
        ) {
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
                    title: logTabName,
                  },
                },
              },
            ],
          },
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
  private async addLogHeaders(
    spreadsheetId: string,
    logTabName: string
  ): Promise<void> {
    const headers = [
      "Timestamp",
      "Operation",
      "Section ID",
      "Student Name",
      "Student Email",
      "TA Name",
      "Session Time",
      "Meeting Link",
      "Status",
      "Notes",
    ];

    await this.sheets.spreadsheets.values.update({
      spreadsheetId,
      range: `'${logTabName}'!A1:J1`,
      valueInputOption: "RAW",
      resource: {
        values: [headers],
      },
    });
  }

  /**
   * Create a new Google Sheet with template tabs for sections
   */
  async createTemplateSheet(
    title: string,
    sectionIds: string[]
  ): Promise<{
    success: boolean;
    spreadsheetUrl?: string;
    spreadsheetId?: string;
    message: string;
  }> {
    try {
      console.log(
        `📊 Creating template sheet: "${title}" with ${sectionIds.length} sections`
      );

      // Create a new spreadsheet
      const response = await this.sheets.spreadsheets.create({
        resource: {
          properties: {
            title: `${title} - ClemenTime Student Roster`,
          },
          sheets: [
            // Create initial sheet for instructions
            {
              properties: {
                title: "Instructions",
              },
            },
            // Create tabs for each section
            ...sectionIds.map((sectionId) => ({
              properties: {
                title: sectionId,
              },
            })),
            // Create session log tab
            {
              properties: {
                title: "SessionLog",
              },
            },
          ],
        },
      });

      const spreadsheetId = response.data.spreadsheetId!;
      const spreadsheetUrl = `https://docs.google.com/spreadsheets/d/${spreadsheetId}/edit`;

      console.log(`✅ Created spreadsheet: ${spreadsheetUrl}`);

      // Add instructions to the Instructions tab
      await this.addInstructionsTab(spreadsheetId);
      console.log("✅ Added instructions tab");

      // Add headers to each section tab
      for (const sectionId of sectionIds) {
        await this.addSectionHeaders(spreadsheetId, sectionId);
        console.log(`✅ Added headers for section: ${sectionId}`);
      }

      // Add session log headers
      await this.addLogHeaders(spreadsheetId, "SessionLog");
      console.log("✅ Added session log tab");

      // Make the sheet publicly viewable (or at least accessible to the service account)
      await this.makeSheetAccessible(spreadsheetId);
      console.log("✅ Made sheet accessible");

      return {
        success: true,
        spreadsheetUrl,
        spreadsheetId,
        message: `Successfully created template sheet with ${sectionIds.length} section tabs`,
      };
    } catch (error) {
      console.error("Error creating template sheet:", error);

      // Provide more specific error messages
      let errorMessage = "Failed to create template sheet";
      if (error instanceof Error) {
        if (error.message.includes("invalid_grant")) {
          errorMessage =
            "Authentication failed. Please check your Google credentials.";
        } else if (
          error.message.includes("insufficient authentication scopes")
        ) {
          errorMessage =
            "Insufficient permissions. Please ensure your service account has Sheets and Drive access.";
        } else if (error.message.includes("quota")) {
          errorMessage = "Google API quota exceeded. Please try again later.";
        } else {
          errorMessage = error.message;
        }
      }

      return {
        success: false,
        message: errorMessage,
      };
    }
  }

  /**
   * Add instructions to the Instructions tab
   */
  private async addInstructionsTab(spreadsheetId: string): Promise<void> {
    const instructions = [
      ["ClemenTime Student Roster - Instructions"],
      [""],
      [
        "This Google Sheet has been automatically created for your ClemenTime session scheduler.",
      ],
      [""],
      ["How to use:"],
      ["1. Each tab represents a section (e.g., section_01, section_02)"],
      ["2. Add student information in each tab with these columns:"],
      ["   - name: Student full name"],
      ["   - email: Student email address"],
      ["   - slack_id: (Optional) Student Slack ID for notifications"],
      [""],
      ["3. The SessionLog tab will automatically track all scheduled sessions"],
      [""],
      [
        "4. Changes to student rosters will be automatically synced to your dashboard",
      ],
      ["   (refresh may take up to 15 minutes depending on your settings)"],
      [""],
      ["5. Do not rename the tab names - they must match your section IDs"],
      [""],
      ["Need help? Check the ClemenTime documentation or contact support."],
    ];

    await this.sheets.spreadsheets.values.update({
      spreadsheetId,
      range: "Instructions!A:A",
      valueInputOption: "RAW",
      resource: {
        values: instructions,
      },
    });
  }

  /**
   * Add headers to a section tab
   */
  private async addSectionHeaders(
    spreadsheetId: string,
    tabName: string
  ): Promise<void> {
    const headers = [["name", "email", "slack_id"]];
    const sampleData = [
      ["John Doe", "john.doe@university.edu", "U12345678"],
      ["Jane Smith", "jane.smith@university.edu", "U87654321"],
    ];

    await this.sheets.spreadsheets.values.update({
      spreadsheetId,
      range: `'${tabName}'!A1:C1`,
      valueInputOption: "RAW",
      resource: {
        values: headers,
      },
    });

    // Add sample data
    await this.sheets.spreadsheets.values.update({
      spreadsheetId,
      range: `'${tabName}'!A2:C3`,
      valueInputOption: "RAW",
      resource: {
        values: sampleData,
      },
    });
  }

  /**
   * Make the sheet accessible (this might need adjustment based on your auth setup)
   */
  private async makeSheetAccessible(spreadsheetId: string): Promise<void> {
    try {
      // Make the sheet readable by anyone with the link
      const drive = google.drive({ version: "v3", auth: this.auth });

      await drive.permissions.create({
        fileId: spreadsheetId,
        requestBody: {
          role: "reader",
          type: "anyone",
        },
      });
    } catch (error) {
      console.warn("Could not make sheet publicly accessible:", error);
      // This is non-critical - the sheet might still work with service account access
    }
  }

  /**
   * Test connection to a Google Sheet
   */
  async testConnection(
    spreadsheetUrl: string
  ): Promise<{ success: boolean; message: string; tabs?: string[] }> {
    try {
      const tabs = await this.getSheetTabs(spreadsheetUrl);
      return {
        success: true,
        message: `Successfully connected to sheet with ${tabs.length} tabs`,
        tabs,
      };
    } catch (error) {
      return {
        success: false,
        message: error instanceof Error ? error.message : "Unknown error",
      };
    }
  }
}

// Singleton instance
export const googleSheetsService = new GoogleSheetsService();
