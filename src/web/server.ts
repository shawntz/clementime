import express from 'express';
import * as path from 'path';
import { Config, ScheduleSlot } from '../types';
import { OrchestrationService } from '../services/orchestration';
import { SlackNotificationService } from '../integrations/slack';
import { TestDataGenerator } from '../utils/test-data-generator';
import { format } from 'date-fns';

export class WebServer {
  private app: express.Application;
  private config: Config;
  private orchestration: OrchestrationService;

  constructor(config: Config) {
    this.config = config;
    this.app = express();
    this.orchestration = new OrchestrationService(config);

    this.setupMiddleware();
    this.setupRoutes();
  }

  private setupMiddleware(): void {
    this.app.use(express.json());
    this.app.use(express.urlencoded({ extended: true }));
    this.app.use(express.static(path.join(__dirname, 'public')));
    this.app.set('view engine', 'ejs');
    this.app.set('views', path.join(__dirname, 'views'));
  }

  private setupRoutes(): void {
    this.app.get('/', this.renderDashboard.bind(this));
    this.app.get('/schedules', this.renderSchedules.bind(this));
    this.app.get('/schedules/api', this.getSchedulesAPI.bind(this));
    this.app.post('/schedules/generate', this.generateSchedules.bind(this));
    this.app.post('/schedules/run-workflow', this.runWorkflow.bind(this));

    this.app.get('/config', this.renderConfig.bind(this));
    this.app.post('/config/save', this.saveConfig.bind(this));


    this.app.get('/health', (req, res) => {
      res.json({ status: 'healthy', timestamp: new Date().toISOString() });
    });

    this.app.get('/api/sections', (req, res) => {
      res.json(this.config.sections);
    });

    this.app.get('/api/stats', this.getStats.bind(this));

    // Test mode endpoints
    this.app.post('/test/generate-fake-schedules', this.generateTestSchedules.bind(this));
    this.app.get('/test/config', this.getTestConfig.bind(this));
  }

  private async renderDashboard(_req: express.Request, res: express.Response): Promise<void> {
    try {
      const schedules = this.orchestration.getSchedules();
      const stats = this.calculateStats(schedules);

      res.render('dashboard', {
        config: this.config,
        stats,
        schedules: schedules.size > 0,
      });
    } catch (error) {
      console.error('Dashboard render error:', error);
      res.status(500).render('error', { message: 'Failed to load dashboard' });
    }
  }

  private async renderSchedules(_req: express.Request, res: express.Response): Promise<void> {
    try {
      const schedules = this.orchestration.getSchedules();
      const formattedSchedules = this.formatSchedulesForView(schedules);

      res.render('schedules', {
        config: this.config,
        schedules: formattedSchedules,
        hasSchedules: schedules.size > 0,
      });
    } catch (error) {
      console.error('Schedules render error:', error);
      res.status(500).render('error', { message: 'Failed to load schedules' });
    }
  }

  private async getSchedulesAPI(_req: express.Request, res: express.Response): Promise<void> {
    try {
      const schedules = this.orchestration.getSchedules();
      const formattedSchedules = this.formatSchedulesForAPI(schedules);

      res.json({
        success: true,
        data: formattedSchedules,
        stats: this.calculateStats(schedules),
      });
    } catch (error) {
      console.error('Schedules API error:', error);
      res.status(500).json({ success: false, error: 'Failed to load schedules' });
    }
  }

  private async generateSchedules(req: express.Request, res: express.Response): Promise<void> {
    try {
      const { startDate, weeks } = req.body;

      if (!startDate || !weeks) {
        res.status(400).json({ success: false, error: 'Start date and weeks are required' });
        return;
      }

      await this.orchestration.regenerateSchedule(new Date(startDate), parseInt(weeks));

      res.json({ success: true, message: 'Schedules generated successfully' });
    } catch (error) {
      console.error('Generate schedules error:', error);
      res.status(500).json({ success: false, error: 'Failed to generate schedules' });
    }
  }

  private async runWorkflow(req: express.Request, res: express.Response): Promise<void> {
    try {
      const { startDate, weeks, dryRun } = req.body;

      if (!startDate || !weeks) {
        res.status(400).json({ success: false, error: 'Start date and weeks are required' });
        return;
      }

      await this.orchestration.runFullWorkflow(
        new Date(startDate),
        parseInt(weeks),
        dryRun === 'true'
      );

      res.json({ success: true, message: 'Workflow completed successfully' });
    } catch (error) {
      console.error('Run workflow error:', error);
      res.status(500).json({ success: false, error: 'Workflow failed' });
    }
  }

  private renderConfig(_req: express.Request, res: express.Response): void {
    res.render('config', { config: this.config });
  }

  private saveConfig(_req: express.Request, res: express.Response): void {
    res.json({ success: false, error: 'Config editing not implemented yet' });
  }


  private getStats(_req: express.Request, res: express.Response): void {
    try {
      const schedules = this.orchestration.getSchedules();
      const stats = this.calculateStats(schedules);
      res.json(stats);
    } catch (error) {
      console.error('Stats API error:', error);
      res.status(500).json({ error: 'Failed to calculate stats' });
    }
  }

  private calculateStats(schedules: Map<number, Map<string, ScheduleSlot[]>>): any {
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
      meetLinkCoverage: totalSlots > 0 ? (slotsWithMeetLinks / totalSlots * 100).toFixed(1) : 0,
      recordingCoverage: totalSlots > 0 ? (slotsWithRecordings / totalSlots * 100).toFixed(1) : 0,
    };
  }

  private formatSchedulesForView(schedules: Map<number, Map<string, ScheduleSlot[]>>): any[] {
    const formatted: any[] = [];

    for (const [weekNum, weekSchedule] of schedules) {
      const weekData = {
        week: weekNum + 1,
        sections: [] as any[],
      };

      for (const [sectionId, slots] of weekSchedule) {
        const section = this.config.sections.find(s => s.id === sectionId);

        weekData.sections.push({
          id: sectionId,
          name: section?.ta_name || 'Unknown TA',
          location: section?.location || 'TBD',
          slots: slots.map(slot => ({
            student: slot.student.name,
            startTime: format(slot.start_time, 'EEE MMM d, h:mm a'),
            endTime: format(slot.end_time, 'h:mm a'),
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

  private formatSchedulesForAPI(schedules: Map<number, Map<string, ScheduleSlot[]>>): any {
    const formatted: any = {};

    for (const [weekNum, weekSchedule] of schedules) {
      formatted[`week_${weekNum + 1}`] = {};

      for (const [sectionId, slots] of weekSchedule) {
        formatted[`week_${weekNum + 1}`][sectionId] = slots.map(slot => ({
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

  private async generateTestSchedules(req: express.Request, res: express.Response): Promise<void> {
    try {
      const {
        startDate,
        weeks,
        numberOfFakeStudents = 30,
        fakeStudentPrefix = 'Test Student',
        redirectToSlackId
      } = req.body;

      if (!startDate || !weeks || !redirectToSlackId) {
        res.status(400).json({
          success: false,
          error: 'Start date, weeks, and your Slack ID are required for test mode'
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
          number_of_fake_students: parseInt(numberOfFakeStudents)
        }
      };

      // Create a test orchestration service with the test config
      const testOrchestration = new OrchestrationService(testConfig);

      // Generate schedules first
      await testOrchestration.regenerateSchedule(new Date(startDate), parseInt(weeks));
      const schedules = testOrchestration.getSchedules();

      // Initialize Slack service for test mode
      const testSlack = new SlackNotificationService(testConfig);

      // Send student notifications and TA workflow (skip Google Meet/Drive due to auth issues in test mode)
      console.log('📬 Sending student notifications...');
      let notificationCount = 0;

      for (const [weekNum, weekSchedule] of schedules) {
        console.log(`  📅 Week ${weekNum + 1} - Student notifications...`);

        for (const [sectionId, slots] of weekSchedule) {
          console.log(`    📚 Section ${sectionId}: ${slots.length} students`);

          for (const slot of slots) {
            try {
              await testSlack.notifyStudent(slot);
              notificationCount++;
              await new Promise(resolve => setTimeout(resolve, 300)); // Small delay between messages
            } catch (error) {
              console.error(`      ❌ Failed to notify ${slot.student.name}:`, error);
            }
          }
        }

        // Send TA channel notifications
        console.log(`  📋 Week ${weekNum + 1} - Creating TA channels and admin notifications...`);
        await this.sendTestTANotifications(testSlack, weekSchedule, weekNum + 1);
      }

      res.json({
        success: true,
        message: `Test schedules generated and sent to your Slack (${redirectToSlackId})`,
        details: {
          fakeStudents: numberOfFakeStudents,
          weeks: weeks,
          startDate: startDate,
          redirectedTo: redirectToSlackId,
          notificationsSent: notificationCount
        }
      });
    } catch (error) {
      console.error('Test schedule generation error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to generate test schedules',
        details: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  private async sendTestTANotifications(slackService: SlackNotificationService, weekSchedule: Map<string, ScheduleSlot[]>, weekNumber: number): Promise<void> {
    for (const [sectionId, slots] of weekSchedule) {
      if (slots.length === 0) continue;

      const taSlackId = slots[0]?.ta.slack_id;
      if (!taSlackId) {
        console.log(`    ⚠️  No Slack ID for TA in section ${sectionId}, skipping TA notifications`);
        continue;
      }

      try {
        // Group slots by exam date (in case a TA has multiple exam dates in a week)
        const slotsByDate = new Map<string, ScheduleSlot[]>();
        slots.forEach(slot => {
          const dateKey = format(slot.start_time, 'yyyy-MM-dd');
          if (!slotsByDate.has(dateKey)) {
            slotsByDate.set(dateKey, []);
          }
          slotsByDate.get(dateKey)!.push(slot);
        });

        // Create separate TA channel for each exam date
        for (const [dateKey, dateSlots] of slotsByDate) {
          await slackService.sendTADaySchedule(taSlackId, dateSlots, weekNumber);
          await new Promise(resolve => setTimeout(resolve, 1000));
        }

        console.log(`    ✅ Created TA channels for ${slots[0].ta.name} (${slotsByDate.size} exam dates)`);
      } catch (error) {
        console.error(`    ❌ Failed to create TA channels for section ${sectionId}:`, error);
      }
    }
  }

  private getTestConfig(_req: express.Request, res: express.Response): void {
    res.json({
      testModeEnabled: this.config.test_mode?.enabled || false,
      testModeConfig: this.config.test_mode || null,
      slackChannels: this.config.slack_channels || null,
      fullConfig: this.config,
      message: 'Use POST /test/generate-fake-schedules to create test schedules'
    });
  }

  async start(port: number): Promise<void> {
    return new Promise((resolve) => {
      this.app.listen(port, () => {
        console.log(`🌐 Web server started on http://localhost:${port}`);
        if (this.config.test_mode?.enabled) {
          console.log(`🧪 TEST MODE ENABLED - All notifications will be sent to: ${this.config.test_mode.redirect_to_slack_id}`);
        }
        resolve();
      });
    });
  }
}