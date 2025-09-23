import Database from 'better-sqlite3';
import { ScheduleSlot, Config } from '../types';
import { format } from 'date-fns';
import * as path from 'path';
import * as fs from 'fs';
import { cloudStorage } from '../utils/cloud-storage';

export class DatabaseService {
  private db: Database.Database;
  private config: Config;

  constructor(config: Config, dbPath?: string) {
    this.config = config;

    // Get database path from cloud storage service (handles cloud vs local)
    const databasePath = dbPath || cloudStorage.getDatabasePath();

    // Debug logging for Cloud Run
    console.log('🗄️ DatabaseService initialization:');
    console.log(`  - dbPath parameter: ${dbPath}`);
    console.log(`  - DATABASE_PATH env: ${process.env.DATABASE_PATH}`);
    console.log(`  - Cloud Storage enabled: ${cloudStorage.isCloudStorageEnabled()}`);
    console.log(`  - Final database path: ${databasePath}`);

    // If using Cloud Storage, try to download existing database first
    if (cloudStorage.isCloudStorageEnabled()) {
      this.initializeCloudDatabase(databasePath);
    } else {
      // Ensure the data directory exists for local filesystem
      const dataDir = path.dirname(databasePath);
      if (!fs.existsSync(dataDir)) {
        fs.mkdirSync(dataDir, { recursive: true });
      }
    }

    this.db = new Database(databasePath);
    this.db.pragma('journal_mode = WAL');
    this.db.pragma('foreign_keys = ON');

    this.initializeSchema();

    // If using Cloud Storage, set up periodic backup
    if (cloudStorage.isCloudStorageEnabled()) {
      this.setupCloudBackup(databasePath);
    }
  }

  private async initializeCloudDatabase(databasePath: string): Promise<void> {
    try {
      // Check if database exists in Cloud Storage
      const cloudDbPath = 'data/clementime.db';
      if (await cloudStorage.fileExists(cloudDbPath)) {
        console.log('☁️  Downloading existing database from Cloud Storage...');
        await cloudStorage.downloadToTemp(cloudDbPath);
      } else {
        console.log('☁️  No existing database in Cloud Storage, creating new one...');
      }
    } catch (error) {
      console.warn('⚠️  Could not download database from Cloud Storage:', error);
    }
  }

  private setupCloudBackup(databasePath: string): void {
    // Backup database to Cloud Storage every 5 minutes
    setInterval(async () => {
      try {
        if (fs.existsSync(databasePath)) {
          const dbContent = await fs.promises.readFile(databasePath);
          await cloudStorage.writeFile('data/clementime.db', dbContent);
          console.log('☁️  Database backed up to Cloud Storage');
        }
      } catch (error) {
        console.error('❌ Failed to backup database to Cloud Storage:', error);
      }
    }, 5 * 60 * 1000); // 5 minutes
  }

  private initializeSchema(): void {
    // Create tables for schedule data
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        week_number INTEGER NOT NULL,
        section_id TEXT NOT NULL,
        student_name TEXT NOT NULL,
        student_email TEXT NOT NULL,
        student_slack_id TEXT,
        ta_id TEXT NOT NULL,
        ta_name TEXT NOT NULL,
        ta_email TEXT NOT NULL,
        ta_slack_id TEXT,
        ta_google_email TEXT,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        location TEXT,
        meet_link TEXT,
        meet_space_name TEXT,
        meet_code TEXT,
        recording_url TEXT,
        calendar_event_id TEXT,
        calendar_link TEXT,
        meeting_start_notified INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(week_number, section_id, student_email)
      );

      CREATE INDEX IF NOT EXISTS idx_schedules_week ON schedules(week_number);
      CREATE INDEX IF NOT EXISTS idx_schedules_section ON schedules(section_id);
      CREATE INDEX IF NOT EXISTS idx_schedules_student_email ON schedules(student_email);
      CREATE INDEX IF NOT EXISTS idx_schedules_ta_email ON schedules(ta_email);
      CREATE INDEX IF NOT EXISTS idx_schedules_start_time ON schedules(start_time);

      -- Table for authenticated users
      CREATE TABLE IF NOT EXISTS authorized_users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        google_email TEXT UNIQUE NOT NULL,
        google_id TEXT UNIQUE,
        name TEXT,
        picture TEXT,
        access_token TEXT,
        refresh_token TEXT,
        token_expires_at DATETIME,
        is_admin INTEGER DEFAULT 0,
        last_login DATETIME,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );

      CREATE INDEX IF NOT EXISTS idx_auth_users_email ON authorized_users(google_email);

      -- Table for session data (if needed for persistence)
      CREATE TABLE IF NOT EXISTS sessions (
        id TEXT PRIMARY KEY,
        user_email TEXT,
        data TEXT,
        expires_at DATETIME,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_email) REFERENCES authorized_users(google_email) ON DELETE CASCADE
      );

      CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_email);
      CREATE INDEX IF NOT EXISTS idx_sessions_expires ON sessions(expires_at);

      -- Table for workflow runs (audit trail)
      CREATE TABLE IF NOT EXISTS workflow_runs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_date TEXT NOT NULL,
        weeks INTEGER NOT NULL,
        dry_run INTEGER DEFAULT 0,
        status TEXT CHECK(status IN ('pending', 'running', 'completed', 'failed')) DEFAULT 'pending',
        error_message TEXT,
        slots_created INTEGER DEFAULT 0,
        notifications_sent INTEGER DEFAULT 0,
        started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        completed_at DATETIME
      );

      CREATE INDEX IF NOT EXISTS idx_workflow_runs_status ON workflow_runs(status);
      CREATE INDEX IF NOT EXISTS idx_workflow_runs_started ON workflow_runs(started_at);

      -- Trigger to update the updated_at timestamp
      CREATE TRIGGER IF NOT EXISTS update_schedules_timestamp
      AFTER UPDATE ON schedules
      BEGIN
        UPDATE schedules SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
      END;

      CREATE TRIGGER IF NOT EXISTS update_auth_users_timestamp
      AFTER UPDATE ON authorized_users
      BEGIN
        UPDATE authorized_users SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
      END;

      -- Table for section CSV mappings
      CREATE TABLE IF NOT EXISTS section_mappings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        filename TEXT NOT NULL,
        csv_content TEXT NOT NULL,
        section_id TEXT NOT NULL,
        is_active INTEGER DEFAULT 0,
        uploaded_by TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );

      CREATE INDEX IF NOT EXISTS idx_section_mappings_section ON section_mappings(section_id);
      CREATE INDEX IF NOT EXISTS idx_section_mappings_active ON section_mappings(is_active);

      CREATE TRIGGER IF NOT EXISTS update_section_mappings_timestamp
      AFTER UPDATE ON section_mappings
      BEGIN
        UPDATE section_mappings SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
      END;
    `);

    // Add columns for Google OAuth tokens if they don't exist (migration)
    this.migrateSchema();
  }

  private migrateSchema(): void {
    try {
      // Check if access_token column exists
      const columns = this.db.prepare("PRAGMA table_info(authorized_users)").all() as any[];
      const hasAccessToken = columns.some(col => col.name === 'access_token');

      if (!hasAccessToken) {
        console.log('🔄 Migrating database schema to add OAuth token columns...');
        this.db.exec(`
          ALTER TABLE authorized_users ADD COLUMN access_token TEXT;
          ALTER TABLE authorized_users ADD COLUMN refresh_token TEXT;
          ALTER TABLE authorized_users ADD COLUMN token_expires_at DATETIME;
        `);
        console.log('✅ Database schema migration completed');
      }
    } catch (error) {
      console.error('❌ Database migration failed:', error);
    }
  }

  // Schedule-related methods
  saveScheduleSlot(weekNumber: number, sectionId: string, slot: ScheduleSlot): void {
    const stmt = this.db.prepare(`
      INSERT OR REPLACE INTO schedules (
        week_number, section_id, student_name, student_email, student_slack_id,
        ta_id, ta_name, ta_email, ta_slack_id, ta_google_email,
        start_time, end_time, location,
        meet_link, meet_space_name, meet_code, recording_url,
        calendar_event_id, calendar_link, meeting_start_notified
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      weekNumber,
      sectionId,
      slot.student.name,
      slot.student.email,
      slot.student.slack_id || null,
      slot.ta.id,
      slot.ta.name,
      slot.ta.email,
      slot.ta.slack_id,
      slot.ta.google_email,
      slot.start_time.toISOString(),
      slot.end_time.toISOString(),
      slot.location,
      slot.meet_link || null,
      slot.meet_space_name || null,
      slot.meet_code || null,
      slot.recording_url || null,
      slot.calendar_event_id || null,
      slot.calendar_link || null,
      slot.meeting_start_notified ? 1 : 0
    );
  }

  saveSchedules(schedules: Map<number, Map<string, ScheduleSlot[]>>): void {
    const transaction = this.db.transaction(() => {
      for (const [weekNum, weekSchedule] of schedules) {
        for (const [sectionId, slots] of weekSchedule) {
          for (const slot of slots) {
            this.saveScheduleSlot(weekNum, sectionId, slot);
          }
        }
      }
    });

    transaction();
  }

  loadSchedules(): Map<number, Map<string, ScheduleSlot[]>> {
    const schedules = new Map<number, Map<string, ScheduleSlot[]>>();

    const rows = this.db.prepare(`
      SELECT * FROM schedules ORDER BY week_number, section_id, start_time
    `).all();

    for (const row of rows as any[]) {
      const weekNum = row.week_number;
      const sectionId = row.section_id;

      if (!schedules.has(weekNum)) {
        schedules.set(weekNum, new Map());
      }

      const weekSchedule = schedules.get(weekNum)!;
      if (!weekSchedule.has(sectionId)) {
        weekSchedule.set(sectionId, []);
      }

      const slot: ScheduleSlot = {
        student: {
          name: row.student_name,
          email: row.student_email,
          slack_id: row.student_slack_id
        },
        ta: {
          id: row.ta_id,
          name: row.ta_name,
          email: row.ta_email,
          slack_id: row.ta_slack_id,
          google_email: row.ta_google_email
        },
        section_id: sectionId,
        start_time: new Date(row.start_time),
        end_time: new Date(row.end_time),
        location: row.location,
        meet_link: row.meet_link,
        meet_space_name: row.meet_space_name,
        meet_code: row.meet_code,
        recording_url: row.recording_url,
        calendar_event_id: row.calendar_event_id,
        calendar_link: row.calendar_link,
        meeting_start_notified: row.meeting_start_notified === 1
      };

      weekSchedule.get(sectionId)!.push(slot);
    }

    return schedules;
  }

  clearSchedules(): void {
    this.db.prepare('DELETE FROM schedules').run();
  }

  saveRecordingMetadata(metadata: {
    studentName: string;
    studentEmail: string;
    taName: string;
    sessionDate: Date;
    weekNumber: number;
    sectionId: string;
    fileName: string;
    fileSize: number;
    duration: number;
    recordedAt: Date;
    recordedBy: string;
  }): void {
    // Create recordings table if it doesn't exist
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS recordings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_name TEXT NOT NULL,
        student_email TEXT NOT NULL,
        ta_name TEXT,
        session_date TEXT,
        week_number INTEGER,
        section_id TEXT,
        file_name TEXT NOT NULL,
        file_size INTEGER,
        duration INTEGER,
        recorded_at TEXT NOT NULL,
        recorded_by TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    const stmt = this.db.prepare(`
      INSERT INTO recordings (
        student_name, student_email, ta_name, session_date, week_number,
        section_id, file_name, file_size, duration, recorded_at, recorded_by
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      metadata.studentName,
      metadata.studentEmail,
      metadata.taName,
      metadata.sessionDate.toISOString(),
      metadata.weekNumber,
      metadata.sectionId,
      metadata.fileName,
      metadata.fileSize,
      metadata.duration,
      metadata.recordedAt.toISOString(),
      metadata.recordedBy
    );
  }

  getSchedulesByWeek(weekNumber: number): Map<string, ScheduleSlot[]> {
    const weekSchedule = new Map<string, ScheduleSlot[]>();

    const rows = this.db.prepare(`
      SELECT * FROM schedules WHERE week_number = ? ORDER BY section_id, start_time
    `).all(weekNumber);

    for (const row of rows as any[]) {
      const sectionId = row.section_id;

      if (!weekSchedule.has(sectionId)) {
        weekSchedule.set(sectionId, []);
      }

      const slot: ScheduleSlot = {
        student: {
          name: row.student_name,
          email: row.student_email,
          slack_id: row.student_slack_id
        },
        ta: {
          id: row.ta_id,
          name: row.ta_name,
          email: row.ta_email,
          slack_id: row.ta_slack_id,
          google_email: row.ta_google_email
        },
        section_id: sectionId,
        start_time: new Date(row.start_time),
        end_time: new Date(row.end_time),
        location: row.location,
        meet_link: row.meet_link,
        meet_space_name: row.meet_space_name,
        meet_code: row.meet_code,
        recording_url: row.recording_url,
        calendar_event_id: row.calendar_event_id,
        calendar_link: row.calendar_link,
        meeting_start_notified: row.meeting_start_notified === 1
      };

      weekSchedule.get(sectionId)!.push(slot);
    }

    return weekSchedule;
  }

  // User authentication methods
  addAuthorizedUser(email: string, googleId?: string, name?: string, picture?: string): void {
    const stmt = this.db.prepare(`
      INSERT OR IGNORE INTO authorized_users (google_email, google_id, name, picture)
      VALUES (?, ?, ?, ?)
    `);

    stmt.run(email, googleId || null, name || null, picture || null);
  }

  isUserAuthorized(email: string): boolean {
    const row = this.db.prepare('SELECT 1 FROM authorized_users WHERE google_email = ?').get(email);
    return !!row;
  }

  updateUserLogin(email: string, googleId?: string, name?: string, picture?: string, accessToken?: string, refreshToken?: string): void {
    const stmt = this.db.prepare(`
      UPDATE authorized_users
      SET last_login = CURRENT_TIMESTAMP,
          google_id = COALESCE(?, google_id),
          name = COALESCE(?, name),
          picture = COALESCE(?, picture),
          access_token = COALESCE(?, access_token),
          refresh_token = COALESCE(?, refresh_token),
          token_expires_at = CASE WHEN ? IS NOT NULL THEN datetime('now', '+1 hour') ELSE token_expires_at END
      WHERE google_email = ?
    `);

    stmt.run(googleId, name, picture, accessToken, refreshToken, accessToken, email);
  }

  getAuthorizedUsers(): any[] {
    return this.db.prepare('SELECT * FROM authorized_users ORDER BY google_email').all();
  }

  removeAuthorizedUser(email: string): void {
    this.db.prepare('DELETE FROM authorized_users WHERE google_email = ?').run(email);
  }

  // Workflow run tracking
  startWorkflowRun(startDate: Date, weeks: number, dryRun: boolean): number {
    const stmt = this.db.prepare(`
      INSERT INTO workflow_runs (start_date, weeks, dry_run, status)
      VALUES (?, ?, ?, 'running')
    `);

    const result = stmt.run(format(startDate, 'yyyy-MM-dd'), weeks, dryRun ? 1 : 0);
    return result.lastInsertRowid as number;
  }

  completeWorkflowRun(runId: number, slotsCreated: number, notificationsSent: number): void {
    const stmt = this.db.prepare(`
      UPDATE workflow_runs
      SET status = 'completed',
          completed_at = CURRENT_TIMESTAMP,
          slots_created = ?,
          notifications_sent = ?
      WHERE id = ?
    `);

    stmt.run(slotsCreated, notificationsSent, runId);
  }

  failWorkflowRun(runId: number, errorMessage: string): void {
    const stmt = this.db.prepare(`
      UPDATE workflow_runs
      SET status = 'failed',
          completed_at = CURRENT_TIMESTAMP,
          error_message = ?
      WHERE id = ?
    `);

    stmt.run(errorMessage, runId);
  }

  getWorkflowRuns(limit: number = 50): any[] {
    return this.db.prepare(`
      SELECT * FROM workflow_runs
      ORDER BY started_at DESC
      LIMIT ?
    `).all(limit);
  }

  // Section mapping methods
  saveSectionMapping(name: string, filename: string, csvContent: string, sectionId: string, uploadedBy: string): number {
    const stmt = this.db.prepare(`
      INSERT INTO section_mappings (name, filename, csv_content, section_id, uploaded_by)
      VALUES (?, ?, ?, ?, ?)
    `);

    const result = stmt.run(name, filename, csvContent, sectionId, uploadedBy);
    return result.lastInsertRowid as number;
  }

  getSectionMappings(sectionId?: string): any[] {
    if (sectionId) {
      return this.db.prepare(`
        SELECT * FROM section_mappings
        WHERE section_id = ?
        ORDER BY created_at DESC
      `).all(sectionId);
    }
    return this.db.prepare('SELECT * FROM section_mappings ORDER BY section_id, created_at DESC').all();
  }

  getActiveSectionMapping(sectionId: string): any {
    return this.db.prepare(`
      SELECT * FROM section_mappings
      WHERE section_id = ? AND is_active = 1
      LIMIT 1
    `).get(sectionId);
  }

  setActiveSectionMapping(mappingId: number, sectionId: string): void {
    this.db.transaction(() => {
      // Deactivate all mappings for this section
      this.db.prepare('UPDATE section_mappings SET is_active = 0 WHERE section_id = ?').run(sectionId);
      // Activate the specified mapping
      this.db.prepare('UPDATE section_mappings SET is_active = 1 WHERE id = ? AND section_id = ?').run(mappingId, sectionId);
    })();
  }

  deleteSectionMapping(mappingId: number): void {
    this.db.prepare('DELETE FROM section_mappings WHERE id = ?').run(mappingId);
  }

  // Clean up old sessions
  cleanupExpiredSessions(): void {
    this.db.prepare('DELETE FROM sessions WHERE expires_at < CURRENT_TIMESTAMP').run();
  }

  close(): void {
    this.db.close();
  }
}