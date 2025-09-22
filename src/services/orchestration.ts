import { Config, ScheduleSlot } from '../types';
import { SchedulingAlgorithm } from '../scheduler/algorithm';
import { SlackNotificationService } from '../integrations/slack';
import { GoogleMeetService } from '../integrations/google-meet';
import { GoogleCalendarService } from '../integrations/google-calendar';
import { DatabaseService } from '../database';
import { format, isBefore, differenceInDays } from 'date-fns';
import * as cron from 'node-cron';

export class OrchestrationService {
  private config: Config;
  private scheduler: SchedulingAlgorithm;
  private slack: SlackNotificationService;
  private meet?: GoogleMeetService; // Lazy initialization (legacy)
  private calendar: GoogleCalendarService;
  private db: DatabaseService;
  private schedules: Map<number, Map<string, ScheduleSlot[]>> = new Map();

  constructor(config: Config, db?: DatabaseService) {
    this.config = config;
    this.scheduler = new SchedulingAlgorithm(config);
    this.slack = new SlackNotificationService(config);
    // Don't initialize GoogleMeetService here to avoid auth errors (legacy)
    this.calendar = new GoogleCalendarService(config);
    this.db = db || new DatabaseService(config);

    // Load existing schedules from database
    this.loadSchedulesFromDatabase();
  }

  private loadSchedulesFromDatabase(): void {
    try {
      const savedSchedules = this.db.loadSchedules();
      if (savedSchedules.size > 0) {
        this.schedules = savedSchedules;
        console.log(`📚 Loaded ${savedSchedules.size} weeks of schedules from database`);
      }
    } catch (error) {
      console.warn('⚠️  Could not load schedules from database:', error);
    }
  }

  private getMeetService(): GoogleMeetService {
    if (!this.meet) {
      this.meet = new GoogleMeetService(this.config);
    }
    return this.meet;
  }

  async runFullWorkflow(startDate: Date, weeks: number, dryRun: boolean = false): Promise<void> {
    console.log('🔄 Starting full automation workflow...\n');

    // Track workflow run in database
    const runId = this.db.startWorkflowRun(startDate, weeks, dryRun);
    let slotsCreated = 0;
    let notificationsSent = 0;

    try {
      console.log('1️⃣ Generating schedules...');
      const schedules = this.scheduler.generateRecurringSchedule(startDate, weeks);
      this.schedules = schedules;

      // Save schedules to database
      if (!dryRun) {
        console.log('💾 Saving schedules to database...');
        this.db.saveSchedules(schedules);

        // Count slots created
        for (const weekSchedule of schedules.values()) {
          for (const slots of weekSchedule.values()) {
            slotsCreated += slots.length;
          }
        }
      }

    if (!dryRun) {
      console.log('2️⃣ Creating Calendar Events with Google Meet...');
      await this.createCalendarEvents(schedules);

      console.log('3️⃣ Sending initial notifications...');
      await this.sendInitialNotifications(schedules);

      console.log('4️⃣ Setting up automated reminders...');
      this.setupAutomatedReminders();

      console.log('5️⃣ Setting up meeting start monitoring...');
      this.setupMeetingStartMonitoring();
    } else {
      console.log('🔍 DRY RUN: Skipping actual integrations');
    }

    this.printScheduleSummary(schedules);

      // Update workflow run as completed
      if (!dryRun) {
        this.db.completeWorkflowRun(runId, slotsCreated, notificationsSent);
      }
    } catch (error) {
      // Mark workflow run as failed
      this.db.failWorkflowRun(runId, error instanceof Error ? error.message : 'Unknown error');
      throw error;
    }
  }

  private async createCalendarEvents(schedules: Map<number, Map<string, ScheduleSlot[]>>): Promise<void> {
    for (const [weekNum, weekSchedule] of schedules) {
      console.log(`  📅 Creating calendar events for Week ${weekNum + 1}...`);

      let updatedWeekSchedule;
      try {
        updatedWeekSchedule = await this.calendar.createMeetingsForSchedule(weekSchedule);
        console.log(`  ✅ Created ${Array.from(updatedWeekSchedule.values()).reduce((sum, slots) => sum + slots.length, 0)} calendar events for Week ${weekNum + 1}`);
      } catch (error: any) {
        console.warn(`⚠️  Google Calendar API unavailable, continuing without calendar events:`, error.message);
        updatedWeekSchedule = weekSchedule; // Use original schedule without calendar events
      }
      schedules.set(weekNum, updatedWeekSchedule);

      await new Promise(resolve => setTimeout(resolve, 1000));
    }
  }


  private async sendInitialNotifications(schedules: Map<number, Map<string, ScheduleSlot[]>>): Promise<void> {
    for (const [weekNum, weekSchedule] of schedules) {
      console.log(`  📬 Sending notifications for Week ${weekNum + 1}...`);

      // Send student notifications (no admin links)
      for (const [sectionId, slots] of weekSchedule) {
        for (const slot of slots) {
          try {
            await this.slack.notifyParticipant(slot);
            await new Promise(resolve => setTimeout(resolve, 200));
          } catch (error) {
            console.error(`    ❌ Failed to notify ${slot.student.name}:`, error);
          }
        }
      }

      // Send TA channel notifications with admin features
      await this.sendTANotifications(weekSchedule, weekNum + 1);
    }
  }

  private async sendTANotifications(weekSchedule: Map<string, ScheduleSlot[]>, weekNumber: number): Promise<void> {
    console.log(`  📋 Creating TA channels and notifications for Week ${weekNumber}...`);

    for (const [sectionId, slots] of weekSchedule) {
      if (slots.length === 0) continue;

      let taSlackId = slots[0]?.ta.slack_id;

      // In test mode, use the test Slack ID as fallback if TA doesn't have one
      if (!taSlackId && this.config.test_mode?.enabled && this.config.test_mode.redirect_to_slack_id) {
        taSlackId = this.config.test_mode.redirect_to_slack_id;
        console.log(`    🧪 TEST MODE: Using test Slack ID for TA in section ${sectionId}`);
      }

      if (!taSlackId) {
        console.warn(`    ⚠️  No Slack ID for TA in section ${sectionId}, skipping TA notifications`);
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
          await this.slack.sendTADaySchedule(taSlackId, dateSlots, weekNumber);
          await new Promise(resolve => setTimeout(resolve, 1000));
        }

        console.log(`    ✅ Sent TA notifications for ${slots[0].ta.name} (${slotsByDate.size} exam dates)`);
      } catch (error) {
        console.error(`    ❌ Failed to notify TA for section ${sectionId}:`, error);
      }
    }
  }

  private setupAutomatedReminders(): Promise<void> {
    return new Promise((resolve) => {
      const reminderSchedule = `0 ${this.config.notifications.reminder_time.split(':')[1]} ${this.config.notifications.reminder_time.split(':')[0]} * * *`;

      cron.schedule(reminderSchedule, async () => {
        console.log('⏰ Running automated reminder check...');
        await this.sendDailyReminders();
      });

      console.log(`  ⏰ Reminder cron job scheduled for ${this.config.notifications.reminder_time}`);
      resolve();
    });
  }

  private async sendDailyReminders(): Promise<void> {
    const today = new Date();

    for (const [_weekNum, weekSchedule] of this.schedules) {
      for (const [_sectionId, slots] of weekSchedule) {
        for (const slot of slots) {
          const daysUntilExam = differenceInDays(slot.start_time, today);

          if (this.config.notifications.reminder_days_before.includes(daysUntilExam)) {
            try {
              await this.slack.sendReminderToParticipant(slot, daysUntilExam);
            } catch (error) {
              console.error(`Failed to send reminder to ${slot.student.name}:`, error);
            }
          }
        }
      }
    }
  }

  private setupMeetingStartMonitoring(): Promise<void> {
    return new Promise((resolve) => {
      cron.schedule('*/5 * * * *', async () => {
        console.log('🟢 Checking for meetings starting soon...');
        await this.processMeetingStarts();
      });

      console.log('  🟢 Meeting start monitoring scheduled (every 5 minutes)');
      resolve();
    });
  }

  private async processMeetingStarts(): Promise<void> {
    const now = new Date();
    const fiveMinutesFromNow = new Date(now.getTime() + 5 * 60 * 1000);

    for (const [weekNum, weekSchedule] of this.schedules) {
      for (const [_sectionId, slots] of weekSchedule) {
        for (const slot of slots) {
          // Check if meeting is starting within the next 5 minutes and hasn't been notified yet
          if (!slot.meeting_start_notified &&
              slot.start_time >= now &&
              slot.start_time <= fiveMinutesFromNow) {
            try {
              await this.slack.notifyMeetingStarted(slot, weekNum);
              slot.meeting_start_notified = true;
              console.log(`✅ Meeting start notification sent for ${slot.student.name}`);
            } catch (error) {
              console.error(`❌ Failed to send meeting start notification for ${slot.student.name}:`, error);
            }
          }
        }
      }
    }
  }


  private printScheduleSummary(schedules: Map<number, Map<string, ScheduleSlot[]>>): void {
    console.log('\n📊 SCHEDULE SUMMARY');
    console.log('==================');

    let totalSlots = 0;
    let totalStudents = new Set<string>();

    for (const [weekNum, weekSchedule] of schedules) {
      console.log(`\n📅 Week ${weekNum + 1}:`);

      for (const [sectionId, slots] of weekSchedule) {
        const section = this.config.sections.find(s => s.id === sectionId);
        console.log(`  📚 Section ${sectionId} (${section?.ta_name}):`);
        console.log(`      Students: ${slots.length}`);
        console.log(`      First exam: ${slots.length > 0 ? format(slots[0].start_time, 'EEE MMM d, h:mm a') : 'N/A'}`);
        console.log(`      Last exam: ${slots.length > 0 ? format(slots[slots.length - 1].end_time, 'EEE MMM d, h:mm a') : 'N/A'}`);

        totalSlots += slots.length;
        slots.forEach(slot => totalStudents.add(slot.student.email));
      }
    }

    console.log('\n📈 TOTALS:');
    console.log(`   Total exam slots: ${totalSlots}`);
    console.log(`   Unique students: ${totalStudents.size}`);
    console.log(`   Weeks scheduled: ${schedules.size}`);
    console.log(`   Sections: ${this.config.sections.length}`);
  }

  async startSlackBot(): Promise<void> {
    await this.slack.start();
  }

  async stopServices(): Promise<void> {
    console.log('🛑 Shutting down services...');
  }

  getSchedules(): Map<number, Map<string, ScheduleSlot[]>> {
    return this.schedules;
  }

  async regenerateSchedule(startDate: Date, weeks: number): Promise<void> {
    console.log('🔄 Regenerating schedules...');
    this.schedules = this.scheduler.generateRecurringSchedule(startDate, weeks);

    // Save to database
    console.log('💾 Saving schedules to database...');
    this.db.saveSchedules(this.schedules);
  }

  updateRecordingUrl(sectionId: string, studentEmail: string, recordingUrl: string): void {
    for (const [weekNum, weekSchedule] of this.schedules) {
      const sectionSlots = weekSchedule.get(sectionId);
      if (sectionSlots) {
        const slot = sectionSlots.find(s => s.student.email === studentEmail);
        if (slot) {
          slot.recording_url = recordingUrl;
          // Save updated schedules to database
          this.db.saveSchedules(this.schedules);
          console.log(`✅ Updated recording URL for ${studentEmail} in section ${sectionId}`);
          return;
        }
      }
    }
    console.warn(`⚠️  Could not find slot for ${studentEmail} in section ${sectionId}`);
  }

  clearAllSchedules(): void {
    console.log('🗑️ Clearing all schedules from orchestration service...');

    // Clear in-memory schedules
    this.schedules.clear();

    // Clear schedules from database
    this.db.clearSchedules();

    console.log('✅ All schedules cleared successfully');
  }
}