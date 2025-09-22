import { google } from "googleapis";
import { OAuth2Client } from "google-auth-library";
import { Readable } from "stream";

export interface DriveUploadConfig {
  clientId: string;
  clientSecret: string;
  redirectUri?: string;
  folderId?: string;
}

export interface UploadResult {
  fileId: string;
  fileName: string;
  webViewLink: string;
  webContentLink: string;
  mimeType: string;
  size: number;
  createdTime: string;
}

export class DriveUploadService {
  private oauth2Client: OAuth2Client;
  private drive: any;
  private config: DriveUploadConfig;

  constructor(config: DriveUploadConfig) {
    this.config = config;
    this.oauth2Client = new OAuth2Client(
      config.clientId,
      config.clientSecret,
      config.redirectUri || "http://localhost:3000/auth/google/callback"
    );

    this.drive = google.drive({ version: "v3", auth: this.oauth2Client });
  }

  setAccessToken(accessToken: string): void {
    this.oauth2Client.setCredentials({ access_token: accessToken });
  }

  setRefreshToken(refreshToken: string): void {
    this.oauth2Client.setCredentials({ refresh_token: refreshToken });
  }

  setTokens(tokens: { access_token: string; refresh_token?: string }): void {
    this.oauth2Client.setCredentials(tokens);
  }

  private async ensureValidToken(): Promise<void> {
    try {
      // Check if we have credentials and if the access token is expired
      const credentials = this.oauth2Client.credentials;

      if (!credentials.access_token) {
        throw new Error("No access token available");
      }

      // If we have a refresh token, try to refresh the access token
      if (credentials.refresh_token) {
        try {
          const { credentials: newCredentials } =
            await this.oauth2Client.refreshAccessToken();
          this.oauth2Client.setCredentials(newCredentials);
          console.log("✅ Access token refreshed successfully");
        } catch (refreshError) {
          console.error("❌ Failed to refresh access token:", refreshError);
          throw new Error("Access token expired and refresh failed");
        }
      }
    } catch (error) {
      console.error("❌ Token validation failed:", error);
      throw error;
    }
  }

  private async ensureRecordingFolder(): Promise<string> {
    try {
      const folderName = "clementime-recordings";
      const parentFolderId = this.config.folderId;

      const query = parentFolderId
        ? `name='${folderName}' and mimeType='application/vnd.google-apps.folder' and '${parentFolderId}' in parents and trashed=false`
        : `name='${folderName}' and mimeType='application/vnd.google-apps.folder' and trashed=false`;

      const response = await this.drive.files.list({
        q: query,
        fields: "files(id, name)",
        spaces: "drive",
      });

      if (response.data.files && response.data.files.length > 0) {
        return response.data.files[0].id;
      }

      const folderMetadata = {
        name: folderName,
        mimeType: "application/vnd.google-apps.folder",
        ...(parentFolderId && { parents: [parentFolderId] }),
      };

      const folder = await this.drive.files.create({
        requestBody: folderMetadata,
        fields: "id",
      });

      return folder.data.id;
    } catch (error) {
      console.error("Error ensuring recording folder:", error);
      throw new Error(
        `Failed to create/find recording folder: ${(error as Error).message}`
      );
    }
  }

  async uploadRecording(
    audioBlob: Blob,
    metadata: {
      studentName: string;
      studentEmail: string;
      taName: string;
      sessionDate: Date;
      weekNumber: number;
      sectionId: string;
    }
  ): Promise<UploadResult> {
    try {
      await this.ensureValidToken();
      const folderId = await this.ensureRecordingFolder();

      const fileName = this.generateFileName(metadata);

      const bufferData = await audioBlob.arrayBuffer();
      const buffer = Buffer.from(bufferData);
      const stream = Readable.from(buffer);

      const fileMetadata = {
        name: fileName,
        parents: [folderId],
        description: `Recording for ${metadata.studentName} (${metadata.studentEmail}) with ${metadata.taName} - Week ${metadata.weekNumber}`,
        properties: {
          studentName: metadata.studentName,
          studentEmail: metadata.studentEmail,
          taName: metadata.taName,
          weekNumber: metadata.weekNumber.toString(),
          sectionId: metadata.sectionId,
          sessionDate: metadata.sessionDate.toISOString(),
        },
      };

      const media = {
        mimeType: audioBlob.type || "audio/webm",
        body: stream,
      };

      const response = await this.drive.files.create({
        requestBody: fileMetadata,
        media: media,
        fields:
          "id, name, webViewLink, webContentLink, mimeType, size, createdTime",
      });

      // Set permissions to make the file accessible to the student
      try {
        await this.drive.permissions.create({
          fileId: response.data.id,
          requestBody: {
            role: "reader",
            type: "user",
            emailAddress: metadata.studentEmail,
          },
        });
      } catch (permissionError) {
        console.warn("Could not set file permissions:", permissionError);
        // Continue without setting permissions - the file will still be uploaded
      }

      return {
        fileId: response.data.id,
        fileName: response.data.name,
        webViewLink: response.data.webViewLink,
        webContentLink: response.data.webContentLink,
        mimeType: response.data.mimeType,
        size: parseInt(response.data.size || "0"),
        createdTime: response.data.createdTime,
      };
    } catch (error) {
      console.error("Upload error:", error);
      throw new Error(
        `Failed to upload recording: ${(error as Error).message}`
      );
    }
  }

  private generateFileName(metadata: {
    studentName: string;
    sessionDate: Date;
    weekNumber: number;
    sectionId: string;
  }): string {
    const date = metadata.sessionDate;
    const dateStr = `${date.getFullYear()}${String(
      date.getMonth() + 1
    ).padStart(2, "0")}${String(date.getDate()).padStart(2, "0")}`;
    const timeStr = `${String(date.getHours()).padStart(2, "0")}${String(
      date.getMinutes()
    ).padStart(2, "0")}`;
    const studentNameClean = metadata.studentName.replace(/[^a-zA-Z0-9]/g, "_");

    return `recording_${dateStr}_${timeStr}_${studentNameClean}_week${metadata.weekNumber}_${metadata.sectionId}.webm`;
  }

  private extractDomain(email: string): string {
    const domain = email.split("@")[1];
    return domain || "gmail.com";
  }

  async listRecordings(limit = 100): Promise<any[]> {
    try {
      await this.ensureValidToken();
      const folderId = await this.ensureRecordingFolder();

      const response = await this.drive.files.list({
        q: `'${folderId}' in parents and trashed=false`,
        fields: "files(id, name, createdTime, size, webViewLink, properties)",
        orderBy: "createdTime desc",
        pageSize: limit,
      });

      return response.data.files || [];
    } catch (error) {
      console.error("Error listing recordings:", error);
      throw new Error(`Failed to list recordings: ${(error as Error).message}`);
    }
  }

  async deleteRecording(fileId: string): Promise<void> {
    try {
      await this.ensureValidToken();
      await this.drive.files.delete({ fileId });
    } catch (error) {
      console.error("Error deleting recording:", error);
      throw new Error(
        `Failed to delete recording: ${(error as Error).message}`
      );
    }
  }

  async getRecording(fileId: string): Promise<any> {
    try {
      await this.ensureValidToken();
      const response = await this.drive.files.get({
        fileId,
        fields:
          "id, name, createdTime, size, webViewLink, webContentLink, properties",
      });

      return response.data;
    } catch (error) {
      console.error("Error getting recording:", error);
      throw new Error(`Failed to get recording: ${(error as Error).message}`);
    }
  }

  getAuthUrl(
    scopes: string[] = ["https://www.googleapis.com/auth/drive.file"]
  ): string {
    return this.oauth2Client.generateAuthUrl({
      access_type: "offline",
      scope: scopes,
      prompt: "consent",
    });
  }

  async getTokensFromCode(code: string): Promise<any> {
    const { tokens } = await this.oauth2Client.getToken(code);
    this.oauth2Client.setCredentials(tokens);
    return tokens;
  }
}
