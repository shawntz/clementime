import express from "express";
import session from "express-session";
import passport from "passport";
import connectSqlite3 from "connect-sqlite3";
import * as path from "path";
import { Config, ScheduleSlot } from "../types";
import { OrchestrationService } from "../services/orchestration";
import { SlackNotificationService } from "../integrations/slack";
import { TestDataGenerator } from "../utils/test-data-generator";
import { DatabaseService } from "../database";
import { AuthService } from "../auth";
import { DriveUploadService } from "../services/drive-upload";
import { format } from "date-fns";
import multer from "multer";
import * as fs from "fs";
import { ConfigLoader } from "../utils/config-loader";
import { cloudStorage } from "../utils/cloud-storage";

export class WebServer {
  private app: express.Application;
  private config: Config;
  private orchestration: OrchestrationService;
  private db: DatabaseService;
  private auth: AuthService;
  private driveService: DriveUploadService | null = null;
  private configLoader: ConfigLoader;
  private upload = multer({ storage: multer.memoryStorage() });

  // Helper methods for configurable terminology
  private getFacilitatorLabel(): string {
    return this.config.terminology?.facilitator_label || "Facilitator";
  }

  private getParticipantLabel(): string {
    return this.config.terminology?.participant_label || "Participant";
  }

  constructor(config: Config) {
    this.app = express();
    this.db = new DatabaseService(config);
    this.configLoader = new ConfigLoader(this.db);

    // Use provided config initially (will be reloaded with cloud storage in initialize())
    this.config = config;

    this.auth = new AuthService(this.config, this.db);
    this.orchestration = new OrchestrationService(this.config, this.db);

    // Initialize Drive service if credentials are available
    const clientId =
      process.env.GOOGLE_MEET_CLIENT_ID || process.env.GOOGLE_CLIENT_ID;
    const clientSecret =
      process.env.GOOGLE_MEET_CLIENT_SECRET || process.env.GOOGLE_CLIENT_SECRET;
    const folderId = process.env.GOOGLE_DRIVE_FOLDER_ID;

    console.log("🔑 Google Drive Service Configuration:");
    console.log(`  - Client ID: ${clientId ? "Present" : "Missing"}`);
    console.log(`  - Client Secret: ${clientSecret ? "Present" : "Missing"}`);
    console.log(
      `  - Drive Folder ID: ${folderId || "Not specified (will use root)"}`
    );

    if (clientId && clientSecret) {
      this.driveService = new DriveUploadService({
        clientId,
        clientSecret,
        folderId,
      });
      console.log("✅ Google Drive service initialized successfully");
      console.log(
        `📁 Recording destination: ${
          folderId ? `Folder ID ${folderId}` : "Google Drive root folder"
        }`
      );
    } else {
      console.log(
        "❌ Google Drive service not initialized - missing OAuth credentials"
      );
      console.log(
        "  Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET environment variables to enable Drive uploads"
      );
    }

    this.setupMiddleware();
    this.setupAuthRoutes();
    this.setupRoutes();
  }

  private setupMiddleware(): void {
    this.app.use(express.json());
    this.app.use(express.urlencoded({ extended: true }));

    // In production, static files are copied to /app/src/web/public by Dockerfile
    const publicPath = process.env.NODE_ENV === "production"
      ? path.join(process.cwd(), "src", "web", "public")
      : path.join(__dirname, "..", "..", "src", "web", "public");
    this.app.use(express.static(publicPath));
    this.app.set("view engine", "ejs");
    // In production, views are copied to /app/src/web/views by Dockerfile
    const viewsPath = process.env.NODE_ENV === "production"
      ? path.join(process.cwd(), "src", "web", "views")
      : path.join(__dirname, "views");
    this.app.set("views", viewsPath);

    console.log(`📁 Views directory: ${viewsPath}`);

    // Check if views directory exists
    try {
      const viewsDirExists = fs.existsSync(viewsPath);
      console.log(`📁 Views directory exists: ${viewsDirExists}`);

      if (viewsDirExists) {
        const viewFiles = fs.readdirSync(viewsPath);
        console.log(`📁 View files found: ${viewFiles.join(', ')}`);

        const configViewExists = fs.existsSync(path.join(viewsPath, 'config.ejs'));
        console.log(`📁 Config view exists: ${configViewExists}`);
      }
    } catch (error) {
      console.error(`❌ Error checking views directory: ${error}`);
    }

    // Session configuration
    const sessionSecret =
      process.env.SESSION_SECRET ||
      "clementime-secret-" + Math.random().toString(36);

    // Create SQLite session store (using separate database file to avoid schema conflicts)
    const SQLiteStore = connectSqlite3(session);
    const mainDbPath = process.env.DATABASE_PATH || path.join(process.cwd(), 'data', 'clementime.db');
    const sessionDir = path.dirname(mainDbPath);
    const sessionDbName = "sessions.db";
    const sessionStore = new SQLiteStore({
      db: sessionDbName,
      table: "sessions",
      dir: sessionDir,
    });

    console.log('🔐 Session store configuration:');
    console.log(`  - Session database: ${sessionDbName}`);
    console.log(`  - Session directory: ${sessionDir}`);
    console.log(`  - NODE_ENV: ${process.env.NODE_ENV}`);
    console.log(`  - COOKIE_SECURE: ${process.env.COOKIE_SECURE}`);

    // Check if we should use memory-based sessions instead of SQLite
    const useMemoryStore = process.env.SESSION_STORE === "memory";

    // TEMPORARILY disable secure cookies to test if HTTPS is causing issues
    const cookieSecure = false; // process.env.COOKIE_SECURE === "true" || process.env.NODE_ENV === "production";

    console.log('🍪 Session cookie configuration:');
    console.log(`  - secure: ${cookieSecure}`);
    console.log(`  - httpOnly: true`);
    console.log(`  - sameSite: "lax"`);
    console.log(`  - maxAge: ${24 * 60 * 60 * 1000}ms (24 hours)`);
    console.log(`  - using store: ${useMemoryStore ? 'MemoryStore' : 'SQLite'}`);

    this.app.use(
      session({
        secret: sessionSecret,
        resave: false,
        saveUninitialized: process.env.SESSION_SAVE_UNINITIALIZED === "true" ? true : false,
        store: useMemoryStore ? undefined : (sessionStore as any),
        cookie: {
          maxAge: 24 * 60 * 60 * 1000, // 24 hours
          secure: cookieSecure,
          httpOnly: true,
          sameSite: "lax", // Use "lax" for OAuth compatibility (not "strict")
        },
      })
    );

    // Add cookie debugging middleware
    this.app.use((req, res, next) => {
      console.log(`🍪 Request to ${req.url}:`);
      console.log(`  - Cookies: ${JSON.stringify(req.headers.cookie || 'none')}`);
      console.log(`  - Session ID: ${req.session?.id || 'no session'}`);
      next();
    });

    // Initialize Passport
    this.app.use(passport.initialize());
    this.app.use(passport.session());

    // Make auth available to all views
    this.app.use((req, res, next) => {
      res.locals.user = req.user || null;
      res.locals.isAuthenticated = req.isAuthenticated();
      next();
    });
  }

  private setupAuthRoutes(): void {
    // Login page
    this.app.get("/auth/login", (req, res) => {
      if (req.isAuthenticated()) {
        res.redirect("/");
        return;
      }
      res.render("login", {
        config: this.config,
        error: req.query.error,
        facilitatorLabel: this.getFacilitatorLabel(),
        participantLabel: this.getParticipantLabel(),
      });
    });

    // Google OAuth routes
    this.app.get(
      "/auth/google",
      passport.authenticate("google", {
        scope: ["profile", "email", "https://www.googleapis.com/auth/drive"],
        accessType: "offline",
        prompt: "consent",
      })
    );

    this.app.get(
      "/auth/google/callback",
      passport.authenticate("google", {
        failureRedirect: "/auth/login?error=unauthorized",
        failureMessage: true,
      }),
      (req, res) => {
        console.log(`🎉 OAuth Success! User:`, req.user);
        console.log(`🔐 Session ID:`, req.session?.id);
        console.log(`✅ Is Authenticated:`, req.isAuthenticated());
        res.redirect("/");
      }
    );

    // Logout
    this.app.get("/auth/logout", (req, res, next) => {
      req.logout((err) => {
        if (err) {
          return next(err);
        }
        // Clear the session completely
        req.session.destroy((sessionErr) => {
          if (sessionErr) {
            console.error("Session destruction error:", sessionErr);
          }
          // Clear all possible session cookies
          res.clearCookie("connect.sid");
          res.clearCookie("session");
          res.clearCookie("sessionId");
          res.redirect("/auth/login");
        });
      });
    });

    // Admin routes for managing authorized users
    this.app.get(
      "/admin/users",
      this.auth.requireAdmin.bind(this.auth),
      this.renderAdminUsers.bind(this)
    );
    this.app.post(
      "/admin/users/add",
      this.auth.requireAdmin.bind(this.auth),
      this.addAuthorizedUser.bind(this)
    );
    this.app.post(
      "/admin/users/remove",
      this.auth.requireAdmin.bind(this.auth),
      this.removeAuthorizedUser.bind(this)
    );
  }

  private setupRoutes(): void {
    // Protected routes - require authentication
    this.app.get(
      "/",
      this.auth.requireAuth.bind(this.auth),
      this.renderDashboard.bind(this)
    );
    this.app.get(
      "/schedules",
      this.auth.requireAuth.bind(this.auth),
      this.renderSchedules.bind(this)
    );
    this.app.get(
      "/schedules/api",
      this.auth.requireAuth.bind(this.auth),
      this.getSchedulesAPI.bind(this)
    );
    this.app.post(
      "/schedules/generate",
      this.auth.requireAdmin.bind(this.auth),
      this.generateSchedules.bind(this)
    );
    this.app.post(
      "/schedules/run-workflow",
      this.auth.requireAdmin.bind(this.auth),
      this.runWorkflow.bind(this)
    );
    this.app.post(
      "/schedules/clear-all",
      this.auth.requireAdmin.bind(this.auth),
      this.clearAllSchedules.bind(this)
    );

    this.app.get(
      "/config",
      this.auth.requireAuth.bind(this.auth),
      this.renderConfig.bind(this)
    );
    this.app.post(
      "/config/save",
      this.auth.requireAuth.bind(this.auth),
      this.saveConfig.bind(this)
    );

    // File tree API
    this.app.get(
      "/api/file-tree",
      this.auth.requireAuth.bind(this.auth),
      this.getFileTree.bind(this)
    );

    // Section mapping APIs
    this.app.post(
      "/api/section-mapping/upload",
      this.auth.requireAdmin.bind(this.auth),
      this.upload.single("csvFile"),
      this.uploadSectionMapping.bind(this)
    );
    this.app.get(
      "/api/section-mappings",
      this.auth.requireAuth.bind(this.auth),
      this.getSectionMappings.bind(this)
    );
    this.app.post(
      "/api/section-mapping/activate",
      this.auth.requireAdmin.bind(this.auth),
      this.activateSectionMapping.bind(this)
    );
    this.app.delete(
      "/api/section-mapping/:id",
      this.auth.requireAdmin.bind(this.auth),
      this.deleteSectionMapping.bind(this)
    );

    this.app.get("/health", (req, res) => {
      res.json({ status: "healthy", timestamp: new Date().toISOString() });
    });

    this.app.get(
      "/api/sections",
      this.auth.requireAuth.bind(this.auth),
      (req, res) => {
        res.json(this.config.sections);
      }
    );

    this.app.get(
      "/api/stats",
      this.auth.requireAuth.bind(this.auth),
      this.getStats.bind(this)
    );
    this.app.get(
      "/api/workflow-runs",
      this.auth.requireAuth.bind(this.auth),
      this.getWorkflowRuns.bind(this)
    );

    // Test mode endpoints (also protected)
    this.app.post(
      "/test/generate-fake-schedules",
      this.auth.requireAuth.bind(this.auth),
      this.generateTestSchedules.bind(this)
    );
    this.app.get(
      "/test/config",
      this.auth.requireAuth.bind(this.auth),
      this.getTestConfig.bind(this)
    );

    // Recording endpoints
    this.app.get(
      "/recording",
      this.auth.requireAuth.bind(this.auth),
      this.renderRecordingPage.bind(this)
    );
    this.app.post(
      "/api/recording/upload",
      this.auth.requireAuth.bind(this.auth),
      this.upload.single("audio"),
      this.uploadRecording.bind(this)
    );
    this.app.post(
      "/api/recording/save-metadata",
      this.auth.requireAuth.bind(this.auth),
      this.saveRecordingMetadata.bind(this)
    );
    this.app.get(
      "/api/recording/list",
      this.auth.requireAuth.bind(this.auth),
      this.listRecordings.bind(this)
    );
    this.app.get(
      "/api/recording/:fileId",
      this.auth.requireAuth.bind(this.auth),
      this.getRecording.bind(this)
    );
    this.app.delete(
      "/api/recording/:fileId",
      this.auth.requireAuth.bind(this.auth),
      this.deleteRecording.bind(this)
    );
    this.app.get(
      "/api/recording/auth/url",
      this.auth.requireAuth.bind(this.auth),
      this.getGoogleAuthUrl.bind(this)
    );
    this.app.post(
      "/api/recording/auth/callback",
      this.auth.requireAuth.bind(this.auth),
      this.handleGoogleAuthCallback.bind(this)
    );

    // TA page endpoints
    this.app.get(
      "/ta/:taName/week/:weekNumber",
      this.auth.requireAuth.bind(this.auth),
      this.renderTAPage.bind(this)
    );
  }

  private async renderAdminUsers(
    req: express.Request,
    res: express.Response
  ): Promise<void> {
    try {
      const users = this.db.getAuthorizedUsers();
      res.render("admin-users", {
        config: this.config,
        users,
        facilitatorLabel: this.getFacilitatorLabel(),
        participantLabel: this.getParticipantLabel(),
        currentPage: "admin",
        message: req.query.message,
      });
    } catch (error) {
      console.error("Admin users render error:", error);
      res
        .status(500)
        .render("error", { message: "Failed to load admin users" });
    }
  }

  private async addAuthorizedUser(
    req: express.Request,
    res: express.Response
  ): Promise<void> {
    try {
      const { email } = req.body;
      if (email) {
        this.auth.addAuthorizedUser(email);
        res.redirect("/admin/users?message=User added successfully");
      } else {
        res.redirect("/admin/users?message=Email is required");
      }
    } catch (error) {
      console.error("Add user error:", error);
      res.redirect("/admin/users?message=Failed to add user");
    }
  }

  private async removeAuthorizedUser(
    req: express.Request,
    res: express.Response
  ): Promise<void> {
    try {
      const { email } = req.body;
      if (email) {
        this.auth.removeAuthorizedUser(email);
        res.redirect("/admin/users?message=User removed successfully");
      } else {
        res.redirect("/admin/users?message=Email is required");
      }
    } catch (error) {
      console.error("Remove user error:", error);
      res.redirect("/admin/users?message=Failed to remove user");
    }
  }

  private checkEnvironmentVariables(): string[] {
    const missingVars: string[] = [];

    // Required environment variables
    const requiredVars = [
      "GOOGLE_CLIENT_ID",
      "GOOGLE_CLIENT_SECRET",
      "SESSION_SECRET",
    ];

    // Check required variables
    for (const varName of requiredVars) {
      if (!process.env[varName]) {
        missingVars.push(varName);
      }
    }

    // Check for at least one Google authentication method
    const hasServiceAccount =
      process.env.GOOGLE_SERVICE_ACCOUNT_KEY ||
      process.env.GOOGLE_APPLICATION_CREDENTIALS;
    const hasOAuthTokens =
      process.env.GOOGLE_REFRESH_TOKEN || process.env.GOOGLE_MEET_REFRESH_TOKEN;

    if (!hasServiceAccount && !hasOAuthTokens) {
      missingVars.push("GOOGLE_REFRESH_TOKEN (or GOOGLE_SERVICE_ACCOUNT_KEY)");
    }

    // Check Slack integration (optional but recommended)
    const slackVars = ["SLACK_BOT_TOKEN", "SLACK_SIGNING_SECRET"];
    const missingSlackVars = slackVars.filter(
      (varName) => !process.env[varName]
    );
    if (missingSlackVars.length > 0) {
      missingVars.push(`Slack: ${missingSlackVars.join(", ")}`);
    }

    return missingVars;
  }

  private async renderDashboard(
    req: express.Request,
    res: express.Response
  ): Promise<void> {
    try {
      const schedules = this.orchestration.getSchedules();
      const stats = this.calculateStats(schedules);
      const missingEnvVars = this.checkEnvironmentVariables();

      // Calculate actual total students from all sections (like config page)
      const actualTotalStudents = this.config.sections.reduce((total, section) => {
        return total + section.students.length;
      }, 0);

      res.render("dashboard", {
        config: this.config,
        stats,
        schedules: schedules.size > 0,
        facilitatorLabel: this.getFacilitatorLabel(),
        participantLabel: this.getParticipantLabel(),
        currentPage: "dashboard",
        user: req.user,
        missingEnvVars,
        actualTotalStudents,
      });
    } catch (error) {
      console.error("Dashboard render error:", error);
      res.status(500).render("error", { message: "Failed to load dashboard" });
    }
  }

  private async renderSchedules(
    req: express.Request,
    res: express.Response
  ): Promise<void> {
    try {
      const schedules = this.orchestration.getSchedules();
      const user = req.user as any;

      let formattedSchedules = this.formatSchedulesForView(schedules);

      // Filter schedules for TAs - only show their sections
      if (user?.role === 'ta' && user?.sections) {
        formattedSchedules = formattedSchedules.map(weekData => ({
          ...weekData,
          sections: weekData.sections.filter((section: any) =>
            user.sections.includes(section.id)
          )
        })).filter((weekData: any) => weekData.sections.length > 0);
      }

      res.render("schedules", {
        config: this.config,
        schedules: formattedSchedules,
        hasSchedules: schedules.size > 0,
        facilitatorLabel: this.getFacilitatorLabel(),
        participantLabel: this.getParticipantLabel(),
        currentPage: "schedules",
        calendarInvitesEnabled: this.config.google_meet.calendar_invites_enabled === true,
        user: user,
        weeklyForms: this.config.weekly_forms || [],
      });
    } catch (error) {
      console.error("Schedules render error:", error);
      res.status(500).render("error", { message: "Failed to load schedules" });
    }
  }

  private async getSchedulesAPI(
    _req: express.Request,
    res: express.Response
  ): Promise<void> {
    try {
      const schedules = this.orchestration.getSchedules();
      const formattedSchedules = this.formatSchedulesForAPI(schedules);

      res.json({
        success: true,
        data: formattedSchedules,
        stats: this.calculateStats(schedules),
      });
    } catch (error) {
      console.error("Schedules API error:", error);
      res
        .status(500)
        .json({ success: false, error: "Failed to load schedules" });
    }
  }

  private async generateSchedules(
    req: express.Request,
    res: express.Response
  ): Promise<void> {
    try {
      const { startDate, weeks } = req.body;

      if (!startDate || !weeks) {
        res
          .status(400)
          .json({ success: false, error: "Start date and weeks are required" });
        return;
      }

      await this.orchestration.regenerateSchedule(
        new Date(startDate),
        parseInt(weeks)
      );

      res.json({ success: true, message: "Schedules generated successfully" });
    } catch (error) {
      console.error("Generate schedules error:", error);
      res
        .status(500)
        .json({ success: false, error: "Failed to generate schedules" });
    }
  }

  private async runWorkflow(
    req: express.Request,
    res: express.Response
  ): Promise<void> {
    try {
      const { startDate, weeks, dryRun } = req.body;

      if (!startDate || !weeks) {
        res
          .status(400)
          .json({ success: false, error: "Start date and weeks are required" });
        return;
      }

      await this.orchestration.runFullWorkflow(
        new Date(startDate),
        parseInt(weeks),
        Boolean(dryRun)
      );

      res.json({ success: true, message: "Workflow completed successfully" });
    } catch (error) {
      console.error("Run workflow error:", error);
      res.status(500).json({ success: false, error: "Workflow failed" });
    }
  }

  private async clearAllSchedules(
    req: express.Request,
    res: express.Response
  ): Promise<void> {
    try {
      console.log("🗑️ Admin requested to clear all schedules");

      // Clear schedules from orchestration service
      this.orchestration.clearAllSchedules();

      console.log("✅ All schedules cleared successfully");

      res.json({
        success: true,
        message: "All schedules have been cleared from the database"
      });
    } catch (error) {
      console.error("Clear schedules error:", error);
      res.status(500).json({
        success: false,
        error: "Failed to clear schedules",
        details: error instanceof Error ? error.message : "Unknown error"
      });
    }
  }

  private renderConfig(_req: express.Request, res: express.Response): void {
    try {
      console.log('🔍 Config debug - instructor field:', this.config?.course?.instructor);
      console.log('🔍 Config debug - sections count:', this.config?.sections?.length);
      console.log('🔍 Config debug - config exists:', !!this.config);

      // Safely handle config that might be missing or malformed
      if (!this.config) {
        console.error('❌ Config is null or undefined');
        res.status(500).render("error", {
          message: "Configuration not loaded"
        });
        return;
      }

      if (!this.config.sections) {
        console.error('❌ Config sections is null or undefined');
        res.status(500).render("error", {
          message: "Configuration sections not found"
        });
        return;
      }

      // Calculate actual total students from all sections
      const actualTotalStudents = this.config.sections.reduce((total, section) => {
        return total + (section?.students?.length || 0);
      }, 0);

      console.log('✅ Config render - total students:', actualTotalStudents);

      res.render("config", {
        config: this.config,
        actualTotalStudents,
        facilitatorLabel: this.getFacilitatorLabel(),
        participantLabel: this.getParticipantLabel(),
        currentPage: "config",
      });
    } catch (error) {
      console.error('❌ Config render error:', error);
      console.error('❌ Error stack:', error instanceof Error ? error.stack : 'No stack trace');
      res.status(500).render("error", {
        message: "Failed to load configuration page",
        details: error instanceof Error ? error.message : "Unknown error"
      });
    }
  }

  private saveConfig(_req: express.Request, res: express.Response): void {
    res.json({ success: false, error: "Config editing not implemented yet" });
  }

  private getStats(_req: express.Request, res: express.Response): void {
    try {
      const schedules = this.orchestration.getSchedules();
      const stats = this.calculateStats(schedules);
      res.json(stats);
    } catch (error) {
      console.error("Stats API error:", error);
      res.status(500).json({ error: "Failed to calculate stats" });
    }
  }

  private getWorkflowRuns(_req: express.Request, res: express.Response): void {
    try {
      const runs = this.db.getWorkflowRuns(50);
      res.json(runs);
    } catch (error) {
      console.error("Workflow runs API error:", error);
      res.status(500).json({ error: "Failed to get workflow runs" });
    }
  }

  private calculateStats(
    schedules: Map<number, Map<string, ScheduleSlot[]>>
  ): any {
    let totalSlots = 0;
    let totalStudents = new Set<string>();
    let totalSections = new Set<string>();
    let slotsWithMeetLinks = 0;
    let slotsWithRecordings = 0;

    for (const [weekNum, weekSchedule] of schedules) {
      for (const [sectionId, slots] of weekSchedule) {
        totalSections.add(sectionId);

        for (const slot of slots) {
          totalSlots++;
          totalStudents.add(slot.student.email);

          if (slot.meet_link) slotsWithMeetLinks++;
          if (slot.recording_url) slotsWithRecordings++;
        }
      }
    }

    return {
      totalSlots,
      totalStudents: totalStudents.size,
      totalSections: totalSections.size,
      totalWeeks: schedules.size,
      slotsWithMeetLinks,
      slotsWithRecordings,
      meetLinkCoverage:
        totalSlots > 0
          ? ((slotsWithMeetLinks / totalSlots) * 100).toFixed(1)
          : 0,
      recordingCoverage:
        totalSlots > 0
          ? ((slotsWithRecordings / totalSlots) * 100).toFixed(1)
          : 0,
    };
  }

  private formatSchedulesForView(
    schedules: Map<number, Map<string, ScheduleSlot[]>>
  ): any[] {
    const formatted: any[] = [];

    for (const [weekNum, weekSchedule] of schedules) {
      const weekData = {
        week: weekNum + 1,
        sections: [] as any[],
      };

      for (const [sectionId, slots] of weekSchedule) {
        const section = this.config.sections.find((s) => s.id === sectionId);

        weekData.sections.push({
          id: sectionId,
          name: section?.ta_name || "Unknown TA",
          location: section?.location || "TBD",
          slots: slots.map((slot) => ({
            student: slot.student.name,
            startTime: format(slot.start_time, "EEE MMM d, h:mm a"),
            endTime: format(slot.end_time, "h:mm a"),
            hasMeetLink: !!slot.meet_link,
            hasRecording: !!slot.recording_url,
            meetLink: slot.meet_link,
            recordingUrl: slot.recording_url,
          })),
        });
      }

      formatted.push(weekData);
    }

    return formatted;
  }

  private formatSchedulesForAPI(
    schedules: Map<number, Map<string, ScheduleSlot[]>>
  ): any {
    const formatted: any = {};

    for (const [weekNum, weekSchedule] of schedules) {
      formatted[`week_${weekNum + 1}`] = {};

      for (const [sectionId, slots] of weekSchedule) {
        formatted[`week_${weekNum + 1}`][sectionId] = slots.map((slot) => ({
          student: {
            name: slot.student.name,
            email: slot.student.email,
          },
          ta: {
            name: slot.ta.name,
            email: slot.ta.email,
          },
          startTime: slot.start_time.toISOString(),
          endTime: slot.end_time.toISOString(),
          location: slot.location,
          meetLink: slot.meet_link || null,
          meetCode: slot.meet_code || null,
          recordingUrl: slot.recording_url || null,
        }));
      }
    }

    return formatted;
  }

  private async generateTestSchedules(
    req: express.Request,
    res: express.Response
  ): Promise<void> {
    try {
      const {
        startDate,
        weeks,
        numberOfFakeStudents = 30,
        fakeStudentPrefix = "Test Student",
        redirectToSlackId,
      } = req.body;

      if (!startDate || !weeks || !redirectToSlackId) {
        res.status(400).json({
          success: false,
          error:
            "Start date, weeks, and your Slack ID are required for test mode",
        });
        return;
      }

      // Create a test configuration with fake students
      const testSections = TestDataGenerator.createTestSections(
        this.config.sections,
        parseInt(numberOfFakeStudents),
        fakeStudentPrefix,
        redirectToSlackId
      );

      const testConfig: Config = {
        ...this.config,
        sections: testSections,
        test_mode: {
          enabled: true,
          redirect_to_slack_id: redirectToSlackId,
          fake_student_prefix: fakeStudentPrefix,
          number_of_fake_students: parseInt(numberOfFakeStudents),
        },
      };

      // Create a test orchestration service with the test config
      const testOrchestration = new OrchestrationService(testConfig);

      // Generate schedules first
      await testOrchestration.regenerateSchedule(
        new Date(startDate),
        parseInt(weeks)
      );
      const schedules = testOrchestration.getSchedules();

      // Initialize Slack service for test mode
      const testSlack = new SlackNotificationService(testConfig);

      // Send student notifications and TA workflow (skip Google Meet/Drive due to auth issues in test mode)
      console.log("📬 Sending student notifications...");
      let notificationCount = 0;

      for (const [weekNum, weekSchedule] of schedules) {
        console.log(`  📅 Week ${weekNum + 1} - Student notifications...`);

        for (const [sectionId, slots] of weekSchedule) {
          console.log(`    📚 Section ${sectionId}: ${slots.length} students`);

          for (const slot of slots) {
            try {
              await testSlack.notifyParticipant(slot);
              notificationCount++;
              await new Promise((resolve) => setTimeout(resolve, 300)); // Small delay between messages
            } catch (error) {
              console.error(
                `      ❌ Failed to notify ${slot.student.name}:`,
                error
              );
            }
          }
        }

        // Send TA channel notifications
        console.log(
          `  📋 Week ${
            weekNum + 1
          } - Creating TA channels and admin notifications...`
        );
        await this.sendTestTANotifications(
          testSlack,
          weekSchedule,
          weekNum + 1
        );
      }

      res.json({
        success: true,
        message: `Test schedules generated and sent to your Slack (${redirectToSlackId})`,
        details: {
          fakeStudents: numberOfFakeStudents,
          weeks: weeks,
          startDate: startDate,
          redirectedTo: redirectToSlackId,
          notificationsSent: notificationCount,
        },
      });
    } catch (error) {
      console.error("Test schedule generation error:", error);
      res.status(500).json({
        success: false,
        error: "Failed to generate test schedules",
        details: error instanceof Error ? error.message : "Unknown error",
      });
    }
  }

  private async sendTestTANotifications(
    slackService: SlackNotificationService,
    weekSchedule: Map<string, ScheduleSlot[]>,
    weekNumber: number
  ): Promise<void> {
    for (const [sectionId, slots] of weekSchedule) {
      if (slots.length === 0) continue;

      const taSlackId = slots[0]?.ta.slack_id;
      if (!taSlackId) {
        console.log(
          `    ⚠️  No Slack ID for TA in section ${sectionId}, skipping TA notifications`
        );
        continue;
      }

      try {
        // Group slots by exam date (in case a TA has multiple exam dates in a week)
        const slotsByDate = new Map<string, ScheduleSlot[]>();
        slots.forEach((slot) => {
          const dateKey = format(slot.start_time, "yyyy-MM-dd");
          if (!slotsByDate.has(dateKey)) {
            slotsByDate.set(dateKey, []);
          }
          slotsByDate.get(dateKey)!.push(slot);
        });

        // Create separate TA channel for each exam date
        for (const [dateKey, dateSlots] of slotsByDate) {
          await slackService.sendTADaySchedule(
            taSlackId,
            dateSlots,
            weekNumber
          );
          await new Promise((resolve) => setTimeout(resolve, 1000));
        }

        console.log(
          `    ✅ Created TA channels for ${slots[0].ta.name} (${slotsByDate.size} exam dates)`
        );
      } catch (error) {
        console.error(
          `    ❌ Failed to create TA channels for section ${sectionId}:`,
          error
        );
      }
    }
  }

  private getTestConfig(_req: express.Request, res: express.Response): void {
    res.json({
      testModeEnabled: this.config.test_mode?.enabled || false,
      testModeConfig: this.config.test_mode || null,
      slackChannels: this.config.slack_channels || null,
      fullConfig: this.config,
      message:
        "Use POST /test/generate-fake-schedules to create test schedules",
    });
  }

  async initialize(): Promise<void> {
    // Reload config with Cloud Storage support if enabled
    if (cloudStorage.isCloudStorageEnabled()) {
      try {
        console.log('☁️  Initializing with Cloud Storage support...');
        this.config = await this.configLoader.loadConfig();

        // Reinitialize services with updated config
        this.auth = new AuthService(this.config, this.db);
        this.orchestration = new OrchestrationService(this.config, this.db);

        console.log('✅ Cloud Storage initialization complete');
      } catch (error) {
        console.error('❌ Failed to initialize with Cloud Storage:', error);
      }
    }
  }

  async start(port: number): Promise<void> {
    // Initialize Cloud Storage if enabled
    await this.initialize();

    return new Promise((resolve) => {
      this.app.listen(port, () => {
        console.log(`🌐 Web server started on http://localhost:${port}`);

        if (cloudStorage.isCloudStorageEnabled()) {
          console.log(`☁️  Using Cloud Storage: ${process.env.STORAGE_BUCKET}`);
        } else {
          console.log(`📁 Using local filesystem`);
        }

        if (this.config.test_mode?.enabled) {
          console.log(
            `🧪 TEST MODE ENABLED - All notifications will be sent to: ${this.config.test_mode.redirect_to_slack_id}`
          );
        }
        resolve();
      });
    });
  }

  // Recording endpoint handlers
  private async renderRecordingPage(
    req: express.Request,
    res: express.Response
  ): Promise<void> {
    try {
      const schedules = this.orchestration.getSchedules();
      console.log("Raw schedules size:", schedules.size);
      console.log("Raw schedules keys:", Array.from(schedules.keys()));

      const formattedSchedules = this.formatSchedulesForRecording(schedules);
      console.log("Formatted schedules count:", formattedSchedules.length);

      if (formattedSchedules.length > 0) {
        console.log(
          "Sample formatted schedule:",
          JSON.stringify(formattedSchedules[0], null, 2)
        );
      }

      res.render("recording", {
        config: this.config,
        schedules: formattedSchedules,
        facilitatorLabel: this.getFacilitatorLabel(),
        participantLabel: this.getParticipantLabel(),
        user: req.user,
        currentPage: "recording",
        hasGoogleDrive: !!this.driveService,
      });
    } catch (error) {
      console.error("Recording page render error:", error);
      res
        .status(500)
        .render("error", { message: "Failed to load recording page" });
    }
  }

  private formatSchedulesForRecording(
    schedules: Map<number, Map<string, ScheduleSlot[]>>
  ): any[] {
    const formatted: any[] = [];
    const now = new Date();

    for (const [weekNum, weekSchedule] of schedules) {
      for (const [sectionId, slots] of weekSchedule) {
        const section = this.config.sections.find((s) => s.id === sectionId);

        for (const slot of slots) {
          formatted.push({
            weekNumber: weekNum + 1,
            sectionId,
            taName: section?.ta_name || "Unknown TA",
            taEmail: slot.ta.email,
            studentName: slot.student.name,
            studentEmail: slot.student.email,
            startTime: slot.start_time,
            endTime: slot.end_time,
            isUpcoming: slot.start_time > now,
            isCurrent: slot.start_time <= now && slot.end_time >= now,
            isPast: slot.end_time < now,
            meetLink: slot.meet_link,
            recordingUrl: slot.recording_url,
          });
        }
      }
    }

    return formatted.sort(
      (a, b) => a.startTime.getTime() - b.startTime.getTime()
    );
  }

  private async renderTAPage(
    req: express.Request,
    res: express.Response
  ): Promise<void> {
    try {
      const { taName, weekNumber } = req.params;
      const weekNum = parseInt(weekNumber) - 1; // Convert to 0-based index

      // Convert URL slug back to TA name (john-doe -> John Doe)
      const displayTaName = taName
        .split('-')
        .map(word => word.charAt(0).toUpperCase() + word.slice(1))
        .join(' ');

      const schedules = this.orchestration.getSchedules();
      const weekSchedule = schedules.get(weekNum);

      if (!weekSchedule) {
        res.status(404).render("error", {
          message: `No schedule found for week ${weekNumber}`
        });
        return;
      }

      // Find the section that matches this TA
      let taSlots: any[] = [];
      let sectionInfo: any = null;

      for (const [sectionId, slots] of weekSchedule) {
        if (slots.length > 0) {
          const sectionTaName = slots[0].ta.name.toLowerCase().replace(/\s+/g, '-');
          if (sectionTaName === taName.toLowerCase()) {
            const section = this.config.sections.find(s => s.id === sectionId);
            sectionInfo = {
              id: sectionId,
              name: section?.ta_name || displayTaName,
              email: section?.ta_email || '',
              location: section?.location || '',
            };

            // Format slots for display
            taSlots = slots.map(slot => ({
              studentName: slot.student.name,
              studentEmail: slot.student.email,
              startTime: slot.start_time,
              endTime: slot.end_time,
              location: slot.location,
              meetLink: slot.meet_link,
              recordingUrl: slot.recording_url,
            })).sort((a, b) => a.startTime.getTime() - b.startTime.getTime());
            break;
          }
        }
      }

      if (!sectionInfo) {
        res.status(404).render("error", {
          message: `No sessions found for ${displayTaName} in week ${weekNumber}`
        });
        return;
      }

      // Get Google Form for this week
      const weekForm = this.config.weekly_forms?.find(f => f.week === parseInt(weekNumber));

      res.render("ta-page", {
        config: this.config,
        taInfo: sectionInfo,
        slots: taSlots,
        weekNumber: parseInt(weekNumber),
        weekForm,
        facilitatorLabel: this.getFacilitatorLabel(),
        participantLabel: this.getParticipantLabel(),
        currentPage: "ta",
        user: req.user,
      });
    } catch (error) {
      console.error("TA page render error:", error);
      res.status(500).render("error", { message: "Failed to load TA page" });
    }
  }

  private async uploadRecording(
    req: express.Request,
    res: express.Response
  ): Promise<void> {
    try {
      if (!this.driveService) {
        res.status(500).json({
          success: false,
          error: "Google Drive service not configured",
        });
        return;
      }

      if (!req.file) {
        res
          .status(400)
          .json({ success: false, error: "No audio file provided" });
        return;
      }

      const {
        studentName,
        studentEmail,
        taName,
        sessionDate,
        weekNumber,
        sectionId,
      } = req.body;

      if (
        !studentName ||
        !studentEmail ||
        !taName ||
        !sessionDate ||
        !weekNumber ||
        !sectionId
      ) {
        res
          .status(400)
          .json({ success: false, error: "Missing required metadata" });
        return;
      }

      // Get access token from session or request
      const accessToken =
        (req.session as any)?.googleAccessToken ||
        req.headers["x-google-access-token"];
      const refreshToken =
        (req.session as any)?.googleRefreshToken ||
        req.headers["x-google-refresh-token"];

      if (!accessToken) {
        res.status(401).json({
          success: false,
          error: "Google authentication required",
          authUrl: this.driveService.getAuthUrl(),
        });
        return;
      }

      // Set both access and refresh tokens if available
      if (refreshToken) {
        this.driveService.setTokens({
          access_token: accessToken as string,
          refresh_token: refreshToken as string,
        });
      } else {
        this.driveService.setAccessToken(accessToken as string);
      }

      const audioBlob = new Blob([req.file.buffer], {
        type: req.file.mimetype,
      });

      const uploadResult = await this.driveService.uploadRecording(audioBlob, {
        studentName,
        studentEmail,
        taName,
        sessionDate: new Date(sessionDate),
        weekNumber: parseInt(weekNumber),
        sectionId,
      });

      // Update the schedule with the recording URL
      this.orchestration.updateRecordingUrl(
        sectionId,
        studentEmail,
        uploadResult.webViewLink
      );

      res.json({ success: true, data: uploadResult });
    } catch (error) {
      console.error("Recording upload error:", error);
      const errorMessage =
        error instanceof Error ? error.message : "Unknown error";
      const errorStack = error instanceof Error ? error.stack : undefined;
      console.error("Error details:", errorMessage, errorStack);
      res.status(500).json({
        success: false,
        error: "Failed to upload recording",
        details: errorMessage,
      });
    }
  }

  private async listRecordings(
    req: express.Request,
    res: express.Response
  ): Promise<void> {
    try {
      if (!this.driveService) {
        res.status(500).json({
          success: false,
          error: "Google Drive service not configured",
        });
        return;
      }

      const accessToken =
        (req.session as any)?.googleAccessToken ||
        req.headers["x-google-access-token"];
      const refreshToken =
        (req.session as any)?.googleRefreshToken ||
        req.headers["x-google-refresh-token"];

      if (!accessToken) {
        res
          .status(401)
          .json({ success: false, error: "Google authentication required" });
        return;
      }

      // Set both access and refresh tokens if available
      if (refreshToken) {
        this.driveService.setTokens({
          access_token: accessToken as string,
          refresh_token: refreshToken as string,
        });
      } else {
        this.driveService.setAccessToken(accessToken as string);
      }

      const recordings = await this.driveService.listRecordings();
      res.json({ success: true, data: recordings });
    } catch (error) {
      console.error("List recordings error:", error);
      const errorMessage =
        error instanceof Error ? error.message : "Unknown error";
      const errorStack = error instanceof Error ? error.stack : undefined;
      console.error("Error details:", errorMessage, errorStack);
      res.status(500).json({
        success: false,
        error: "Failed to list recordings",
        details: errorMessage,
      });
    }
  }

  private async getRecording(
    req: express.Request,
    res: express.Response
  ): Promise<void> {
    try {
      if (!this.driveService) {
        res.status(500).json({
          success: false,
          error: "Google Drive service not configured",
        });
        return;
      }

      const { fileId } = req.params;

      const accessToken =
        (req.session as any)?.googleAccessToken ||
        req.headers["x-google-access-token"];
      const refreshToken =
        (req.session as any)?.googleRefreshToken ||
        req.headers["x-google-refresh-token"];

      if (!accessToken) {
        res
          .status(401)
          .json({ success: false, error: "Google authentication required" });
        return;
      }

      // Set both access and refresh tokens if available
      if (refreshToken) {
        this.driveService.setTokens({
          access_token: accessToken as string,
          refresh_token: refreshToken as string,
        });
      } else {
        this.driveService.setAccessToken(accessToken as string);
      }

      const recording = await this.driveService.getRecording(fileId);
      res.json({ success: true, data: recording });
    } catch (error) {
      console.error("Get recording error:", error);
      res
        .status(500)
        .json({ success: false, error: "Failed to get recording" });
    }
  }

  private async deleteRecording(
    req: express.Request,
    res: express.Response
  ): Promise<void> {
    try {
      if (!this.driveService) {
        res.status(500).json({
          success: false,
          error: "Google Drive service not configured",
        });
        return;
      }

      const { fileId } = req.params;

      const accessToken =
        (req.session as any)?.googleAccessToken ||
        req.headers["x-google-access-token"];
      const refreshToken =
        (req.session as any)?.googleRefreshToken ||
        req.headers["x-google-refresh-token"];

      if (!accessToken) {
        res
          .status(401)
          .json({ success: false, error: "Google authentication required" });
        return;
      }

      // Set both access and refresh tokens if available
      if (refreshToken) {
        this.driveService.setTokens({
          access_token: accessToken as string,
          refresh_token: refreshToken as string,
        });
      } else {
        this.driveService.setAccessToken(accessToken as string);
      }

      await this.driveService.deleteRecording(fileId);
      res.json({ success: true, message: "Recording deleted successfully" });
    } catch (error) {
      console.error("Delete recording error:", error);
      res
        .status(500)
        .json({ success: false, error: "Failed to delete recording" });
    }
  }

  private async getGoogleAuthUrl(
    req: express.Request,
    res: express.Response
  ): Promise<void> {
    try {
      if (!this.driveService) {
        res.status(500).json({
          success: false,
          error: "Google Drive service not configured",
        });
        return;
      }

      const authUrl = this.driveService.getAuthUrl([
        "https://www.googleapis.com/auth/drive.file",
        "https://www.googleapis.com/auth/drive.metadata.readonly",
      ]);

      res.json({ success: true, authUrl });
    } catch (error) {
      console.error("Get auth URL error:", error);
      res.status(500).json({ success: false, error: "Failed to get auth URL" });
    }
  }

  private async handleGoogleAuthCallback(
    req: express.Request,
    res: express.Response
  ): Promise<void> {
    try {
      if (!this.driveService) {
        res.status(500).json({
          success: false,
          error: "Google Drive service not configured",
        });
        return;
      }

      const { code } = req.body;

      if (!code) {
        res
          .status(400)
          .json({ success: false, error: "Authorization code required" });
        return;
      }

      const tokens = await this.driveService.getTokensFromCode(code);

      // Store tokens in session
      (req.session as any).googleAccessToken = tokens.access_token;
      (req.session as any).googleRefreshToken = tokens.refresh_token;

      res.json({ success: true, tokens });
    } catch (error) {
      console.error("Auth callback error:", error);
      res.status(500).json({
        success: false,
        error: "Failed to exchange authorization code",
      });
    }
  }

  private async saveRecordingMetadata(
    req: express.Request,
    res: express.Response
  ): Promise<void> {
    try {
      const {
        studentName,
        studentEmail,
        taName,
        sessionDate,
        weekNumber,
        sectionId,
        fileName,
        fileSize,
        duration,
      } = req.body;

      if (!studentName || !studentEmail || !fileName) {
        res
          .status(400)
          .json({ success: false, error: "Missing required fields" });
        return;
      }

      // Save recording metadata to database
      this.db.saveRecordingMetadata({
        studentName,
        studentEmail,
        taName,
        sessionDate: new Date(sessionDate),
        weekNumber: parseInt(weekNumber),
        sectionId,
        fileName,
        fileSize: parseInt(fileSize),
        duration: parseInt(duration),
        recordedAt: new Date(),
        recordedBy: (req.user as any)?.email || "unknown",
      });

      res.json({ success: true, message: "Recording metadata saved" });
    } catch (error) {
      console.error("Save recording metadata error:", error);
      res
        .status(500)
        .json({ success: false, error: "Failed to save recording metadata" });
    }
  }

  // File tree endpoint
  private async getFileTree(_req: express.Request, res: express.Response): Promise<void> {
    try {
      if (cloudStorage.isCloudStorageEnabled()) {
        // Use Cloud Storage
        const bucketName = process.env.STORAGE_BUCKET || '';
        const tree = await this.buildCloudFileTree();
        res.json({
          success: true,
          path: `gs://${bucketName}`,
          tree,
          source: 'cloud-storage'
        });
      } else {
        // Use local filesystem
        const dataPath = process.env.NODE_ENV === "production" ? "/app/data" : path.join(process.cwd(), "data");
        const tree = this.buildFileTree(dataPath);
        res.json({
          success: true,
          path: dataPath,
          tree,
          source: 'local-filesystem'
        });
      }
    } catch (error) {
      console.error("File tree error:", error);
      res.status(500).json({
        success: false,
        error: "Failed to retrieve file tree",
        details: error instanceof Error ? error.message : "Unknown error"
      });
    }
  }

  private buildFileTree(dirPath: string, basePath?: string): any[] {
    const tree: any[] = [];
    const base = basePath || dirPath;

    try {
      const items = fs.readdirSync(dirPath);

      for (const item of items) {
        const fullPath = path.join(dirPath, item);
        const relativePath = path.relative(base, fullPath);
        const stats = fs.statSync(fullPath);

        if (stats.isDirectory()) {
          tree.push({
            name: item,
            type: "directory",
            path: relativePath,
            children: this.buildFileTree(fullPath, base)
          });
        } else {
          tree.push({
            name: item,
            type: "file",
            path: relativePath,
            size: stats.size,
            modified: stats.mtime
          });
        }
      }
    } catch (error) {
      console.error(`Error reading directory ${dirPath}:`, error);
    }

    return tree;
  }

  private async buildCloudFileTree(): Promise<any[]> {
    const { Storage } = await import('@google-cloud/storage');
    const storage = new Storage();
    const bucketName = process.env.STORAGE_BUCKET;

    if (!bucketName) {
      throw new Error('STORAGE_BUCKET environment variable not set');
    }

    const bucket = storage.bucket(bucketName);
    const [files] = await bucket.getFiles();

    const tree: any[] = [];
    const directoryMap = new Map<string, any>();

    // Build directory structure
    for (const file of files) {
      const parts = file.name.split('/');
      let currentLevel = tree;
      let currentPath = '';

      for (let i = 0; i < parts.length - 1; i++) {
        currentPath = currentPath ? `${currentPath}/${parts[i]}` : parts[i];

        let dir = directoryMap.get(currentPath);
        if (!dir) {
          dir = {
            name: parts[i],
            type: 'directory',
            path: currentPath,
            children: []
          };
          directoryMap.set(currentPath, dir);
          currentLevel.push(dir);
        }
        currentLevel = dir.children;
      }

      // Add file to its directory
      if (parts.length > 0) {
        const fileName = parts[parts.length - 1];
        if (fileName) {
          currentLevel.push({
            name: fileName,
            type: 'file',
            path: file.name,
            size: file.metadata.size || 0,
            modified: file.metadata.updated || file.metadata.timeCreated
          });
        }
      }
    }

    return tree;
  }

  // Section mapping endpoints
  private async uploadSectionMapping(req: express.Request, res: express.Response): Promise<void> {
    try {
      const { sectionId, name } = req.body;
      const file = req.file;
      const user = (req.user as any)?.email || "unknown";

      if (!file || !sectionId || !name) {
        res.status(400).json({
          success: false,
          error: "Missing required fields: file, sectionId, or name"
        });
        return;
      }

      // Validate section exists
      const section = this.config.sections.find(s => s.id === sectionId);
      if (!section) {
        res.status(400).json({
          success: false,
          error: `Section ${sectionId} not found`
        });
        return;
      }

      // Parse CSV to validate format
      const csvContent = file.buffer.toString("utf-8");
      const lines = csvContent.split("\n").filter(line => line.trim());

      if (lines.length < 2) {
        res.status(400).json({
          success: false,
          error: "CSV file must contain header and at least one data row"
        });
        return;
      }

      // Save to database
      const mappingId = this.db.saveSectionMapping(
        name,
        file.originalname,
        csvContent,
        sectionId,
        user
      );

      // Also save CSV to Cloud Storage if enabled
      if (cloudStorage.isCloudStorageEnabled()) {
        const csvPath = `uploads/section-mappings/${sectionId}/${Date.now()}-${file.originalname}`;
        await cloudStorage.writeFile(csvPath, csvContent);
        console.log(`☁️  CSV saved to Cloud Storage: ${csvPath}`);
      }

      res.json({
        success: true,
        message: "Section mapping uploaded successfully",
        mappingId,
        rowCount: lines.length - 1
      });
    } catch (error) {
      console.error("Upload section mapping error:", error);
      res.status(500).json({
        success: false,
        error: "Failed to upload section mapping",
        details: error instanceof Error ? error.message : "Unknown error"
      });
    }
  }

  private getSectionMappings(req: express.Request, res: express.Response): void {
    try {
      const { sectionId } = req.query;
      const mappings = this.db.getSectionMappings(sectionId as string);

      // Parse config.yml mappings
      const configMappings = this.config.sections.map(section => ({
        sectionId: section.id,
        sectionName: section.ta_name,
        studentCount: section.students.length,
        hasConfigMapping: section.students.length > 0,
        csvPath: (section as any).students_csv || null
      }));

      res.json({
        success: true,
        mappings,
        configMappings,
        sections: this.config.sections.map(s => ({
          id: s.id,
          name: s.ta_name,
          location: s.location
        }))
      });
    } catch (error) {
      console.error("Get section mappings error:", error);
      res.status(500).json({
        success: false,
        error: "Failed to retrieve section mappings"
      });
    }
  }

  private activateSectionMapping(req: express.Request, res: express.Response): void {
    try {
      const { mappingId, sectionId } = req.body;

      if (!mappingId || !sectionId) {
        res.status(400).json({
          success: false,
          error: "Missing mappingId or sectionId"
        });
        return;
      }

      this.db.setActiveSectionMapping(mappingId, sectionId);

      res.json({
        success: true,
        message: "Section mapping activated successfully"
      });
    } catch (error) {
      console.error("Activate section mapping error:", error);
      res.status(500).json({
        success: false,
        error: "Failed to activate section mapping"
      });
    }
  }

  private deleteSectionMapping(req: express.Request, res: express.Response): void {
    try {
      const { id } = req.params;

      if (!id) {
        res.status(400).json({
          success: false,
          error: "Missing mapping ID"
        });
        return;
      }

      this.db.deleteSectionMapping(parseInt(id));

      res.json({
        success: true,
        message: "Section mapping deleted successfully"
      });
    } catch (error) {
      console.error("Delete section mapping error:", error);
      res.status(500).json({
        success: false,
        error: "Failed to delete section mapping"
      });
    }
  }
}
