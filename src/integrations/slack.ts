import { App } from '@slack/bolt';
import { WebClient } from '@slack/web-api';
import { ScheduleSlot, Config } from '../types';
import { format, isSameDay } from 'date-fns';

export class SlackNotificationService {
  private app: App;
  private client: WebClient;
  private config: Config;

  // Helper methods for configurable terminology
  private getFacilitatorLabel(): string {
    return this.config.terminology?.facilitator_label || 'Facilitator';
  }

  private getParticipantLabel(): string {
    return this.config.terminology?.participant_label || 'Participant';
  }

  constructor(config: Config) {
    this.config = config;
    this.client = new WebClient(process.env.SLACK_BOT_TOKEN);
    this.app = new App({
      token: process.env.SLACK_BOT_TOKEN,
      signingSecret: process.env.SLACK_SIGNING_SECRET,
      appToken: process.env.SLACK_APP_TOKEN,
      socketMode: true,
    });

    this.setupSlashCommands();
  }

  private setupSlashCommands() {
    this.app.command('/schedule', async ({ ack, respond }) => {
      await ack();

      await respond({
        text: `📅 *Schedule for ${this.config.course.name}*\n\nUse the web interface to view and manage schedules.`,
        response_type: 'ephemeral'
      });
    });

    this.app.command('/my-session', async ({ ack, respond }) => {
      await ack();

      await respond({
        text: '🔍 Looking up your next session appointment...',
        response_type: 'ephemeral'
      });
    });
  }

  async start() {
    await this.app.start();
    console.log('⚡️ Slack app is running!');
  }

  async notifyParticipant(slot: ScheduleSlot): Promise<void> {
    const message = this.buildParticipantMessage(slot);

    // Determine the target channel based on test mode
    let targetChannel: string | undefined;
    if (this.config.test_mode?.enabled && this.config.test_mode.redirect_to_slack_id) {
      targetChannel = this.config.test_mode.redirect_to_slack_id;
    } else {
      targetChannel = slot.student.slack_id;
    }

    // Skip if no target channel
    if (!targetChannel) {
      console.warn(`No Slack ID for ${this.getParticipantLabel().toLowerCase()} ${slot.student.name}, skipping notification`);
      return;
    }

    try {
      // Add test mode indicator if in test mode
      const testModePrefix = this.config.test_mode?.enabled
        ? `🧪 [TEST MODE - Originally for: ${slot.student.name}]\n`
        : '';

      // Get customizable title template or use default
      const titleTemplate = this.config.notifications.student_notification_title || 'Session for {name}';
      const notificationTitle = titleTemplate.replace('{name}', slot.student.name);

      await this.client.chat.postMessage({
        channel: targetChannel,
        text: `${testModePrefix}📚 ${notificationTitle}`,
        blocks: [
          {
            type: 'header',
            text: {
              type: 'plain_text',
              text: this.config.test_mode?.enabled
                ? `🧪 TEST: ${notificationTitle}`
                : `📚 ${notificationTitle}`,
            },
          },
          {
            type: 'section',
            fields: [
              {
                type: 'mrkdwn',
                text: `*Date:*\n${format(slot.start_time, 'EEEE, MMMM d, yyyy')}`,
              },
              {
                type: 'mrkdwn',
                text: `*Time:*\n${format(slot.start_time, 'h:mm a')} - ${format(slot.end_time, 'h:mm a')}`,
              },
              {
                type: 'mrkdwn',
                text: `*Location:*\n${slot.location}`,
              },
              {
                type: 'mrkdwn',
                text: `*${this.getFacilitatorLabel()}:*\n${slot.ta.name}`,
              },
            ],
          },
          ...(slot.meet_link ? [{
            type: 'section' as const,
            text: {
              type: 'mrkdwn' as const,
              text: `🔗 *Google Meet Link:* <${slot.meet_link}|Join Meeting>`,
            },
          }] : []),
          {
            type: 'context' as const,
            elements: [
              {
                type: 'mrkdwn' as const,
                text: `📋 Course: ${this.config.course.name} | 📚 Term: ${this.config.course.term}`,
              },
            ],
          },
        ],
      });

      console.log(`✅ Notification sent to ${this.getParticipantLabel().toLowerCase()}: ${slot.student.name}`);
    } catch (error) {
      console.error(`❌ Failed to notify ${this.getParticipantLabel().toLowerCase()} ${slot.student.name}:`, error);
      throw error;
    }
  }

  async notifyFacilitator(taSlackId: string, slots: ScheduleSlot[]): Promise<void> {
    const taName = slots[0]?.ta.name || this.getFacilitatorLabel();

    const blocks = [
      {
        type: 'header',
        text: {
          type: 'plain_text',
          text: `📋 Your Session Schedule`,
        },
      },
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `Hello ${taName}! Here's your upcoming session schedule for ${this.config.course.name}:`,
        },
      },
    ];

    const slotsText = slots
      .sort((a, b) => a.start_time.getTime() - b.start_time.getTime())
      .map((slot, index) =>
        `${index + 1}. *${slot.student.name}*\n` +
        `   📅 ${format(slot.start_time, 'EEE, MMM d - h:mm a')}\n` +
        `   📍 ${slot.location}` +
        (slot.meet_link ? `\n   🔗 <${slot.meet_link}|Google Meet Link>` : '')
      )
      .join('\n\n');

    blocks.push({
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: slotsText,
      },
    });

    blocks.push({
      type: 'context' as const,
      elements: [
        {
          type: 'mrkdwn' as const,
          text: `📊 Total appointments: ${slots.length} | 🎯 Auto-recording enabled`,
        },
      ],
    } as any);

    try {
      await this.client.chat.postMessage({
        channel: taSlackId,
        text: `📋 Your Session Schedule - ${this.config.course.name}`,
        blocks,
      });

      console.log(`✅ Schedule sent to ${this.getFacilitatorLabel().toLowerCase()}: ${taName}`);
    } catch (error) {
      console.error(`❌ Failed to notify ${this.getFacilitatorLabel().toLowerCase()} ${taName}:`, error);
      throw error;
    }
  }

  async sendReminderToParticipant(slot: ScheduleSlot, daysUntil: number): Promise<void> {
    // Determine the target channel based on test mode
    let targetChannel: string | undefined;
    if (this.config.test_mode?.enabled && this.config.test_mode.redirect_to_slack_id) {
      targetChannel = this.config.test_mode.redirect_to_slack_id;
    } else {
      targetChannel = slot.student.slack_id;
    }

    // Skip if no target channel
    if (!targetChannel) {
      console.warn(`No Slack ID for ${this.getParticipantLabel().toLowerCase()} ${slot.student.name}, skipping reminder`);
      return;
    }

    const testModePrefix = this.config.test_mode?.enabled
      ? `🧪 [TEST MODE - Originally for: ${slot.student.name}] `
      : '';

    const reminderText = daysUntil === 0
      ? `${testModePrefix}🔔 Your session is TODAY!`
      : `${testModePrefix}🔔 Reminder: Your session is in ${daysUntil} day${daysUntil > 1 ? 's' : ''}`;

    try {
      await this.client.chat.postMessage({
        channel: targetChannel,
        text: reminderText,
        blocks: [
          {
            type: 'section' as const,
            text: {
              type: 'mrkdwn' as const,
              text: `${reminderText}\n\n*Details:*\n📅 ${format(slot.start_time, 'EEEE, MMMM d, yyyy')}\n⏰ ${format(slot.start_time, 'h:mm a')} - ${format(slot.end_time, 'h:mm a')}\n📍 ${slot.location}\n👨‍🏫 ${this.getFacilitatorLabel()}: ${slot.ta.name}` +
              (slot.meet_link ? `\n🔗 <${slot.meet_link}|Join Google Meet>` : ''),
            },
          },
        ],
      });

      console.log(`✅ Reminder sent to ${slot.student.name} (${daysUntil} days)`);
    } catch (error) {
      console.error(`❌ Failed to send reminder to ${slot.student.name}:`, error);
    }
  }

  async notifyMeetingStarted(slot: ScheduleSlot, weekNumber?: number): Promise<void> {
    try {
      // Find the appropriate facilitator channel for this meeting
      const targetChannel = await this.findFacilitatorChannelForMeeting(slot, weekNumber);

      await this.client.chat.postMessage({
        channel: targetChannel,
        text: '🟢 Meeting has started',
        blocks: [
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: `🟢 *Meeting has started*\n\n*${this.getParticipantLabel()}:* ${slot.student.name}\n*${this.getFacilitatorLabel()}:* ${slot.ta.name}\n*Time:* ${format(slot.start_time, 'h:mm a')} - ${format(slot.end_time, 'h:mm a')}`,
            },
          },
        ],
      });

      const channelType = targetChannel === slot.ta.slack_id ? `${this.getFacilitatorLabel()} DM` : `${this.getFacilitatorLabel()} channel`;
      console.log(`✅ Meeting started notification sent to ${channelType} for ${this.getFacilitatorLabel().toLowerCase()}: ${slot.ta.name}`);
    } catch (error) {
      console.error(`❌ Failed to notify about meeting start:`, error);
    }
  }

  private async findFacilitatorChannelForMeeting(slot: ScheduleSlot, weekNumber?: number): Promise<string> {
    // If no week number provided, estimate from exam date
    if (weekNumber === undefined) {
      // Simple estimation - you might want to improve this logic based on your semester structure
      const examDate = slot.start_time;
      const startOfYear = new Date(examDate.getFullYear(), 0, 1);
      const daysSinceStart = Math.floor((examDate.getTime() - startOfYear.getTime()) / (1000 * 60 * 60 * 24));
      weekNumber = Math.floor(daysSinceStart / 7) + 1;
    }

    try {
      // Generate the expected channel name pattern
      const baseChannelName = `ta-${slot.ta.name.toLowerCase().replace(/\s+/g, '-')}-week${weekNumber}-${format(slot.start_time, 'MM-dd')}`;

      let expectedChannelName = baseChannelName;

      // Add prefix if configured (with automatic dash)
      if (this.config.slack_channels?.prefix) {
        expectedChannelName = `${this.config.slack_channels.prefix}-${expectedChannelName}`;
      }

      // Add suffix if configured (with automatic dash)
      if (this.config.slack_channels?.suffix) {
        expectedChannelName = `${expectedChannelName}-${this.config.slack_channels.suffix}`;
      }

      // Search for channels that match the pattern
      const channels = await this.client.conversations.list({
        types: 'private_channel',
        limit: 1000,
      });

      if (channels.channels) {
        // Look for exact match first
        const exactMatch = channels.channels.find(channel =>
          channel.name === expectedChannelName
        );

        if (exactMatch?.id) {
          console.log(`✅ Found ${this.getFacilitatorLabel().toLowerCase()} channel for meeting: ${expectedChannelName}`);
          return exactMatch.id;
        }

        // Look for partial matches (in case the date part is slightly different)
        const partialMatch = channels.channels.find(channel =>
          channel.name?.includes(`ta-${slot.ta.name.toLowerCase().replace(/\s+/g, '-')}`) &&
          channel.name?.includes(`week${weekNumber}`)
        );

        if (partialMatch?.id) {
          console.log(`✅ Found partial ${this.getFacilitatorLabel().toLowerCase()} channel match for meeting: ${partialMatch.name}`);
          return partialMatch.id;
        }
      }

      console.log(`⚠️  No ${this.getFacilitatorLabel().toLowerCase()} channel found for ${slot.ta.name}, falling back to DM`);
      return slot.ta.slack_id;
    } catch (error) {
      console.error(`❌ Error finding ${this.getFacilitatorLabel().toLowerCase()} channel for meeting, falling back to DM:`, error);
      return slot.ta.slack_id;
    }
  }

  async createFacilitatorChannel(taName: string, examDate: Date, weekNumber: number): Promise<string | null> {
    // Get custom session name from config (remove {name} placeholder if present)
    const customSessionName = this.config.notifications.student_notification_title
      ? this.config.notifications.student_notification_title.replace(/ for \{name\}$/, '').replace(/\{name\}/, '').trim()
      : 'Session';

    // Convert custom session name to channel-friendly format
    const sessionSlug = customSessionName.toLowerCase().replace(/\s+/g, '-');

    // Build new channel name format: prefix-{custom-session-name}-{facilitator-label}-first-last-week{x}-suffix
    const facilitatorLabel = this.getFacilitatorLabel().toLowerCase();
    const taSlug = taName.toLowerCase().replace(/\s+/g, '-');

    let channelParts = [];

    // Add prefix if configured
    if (this.config.slack_channels?.prefix) {
      channelParts.push(this.config.slack_channels.prefix);
    }

    // Add custom session name (optional)
    if (sessionSlug && sessionSlug !== 'session') {
      channelParts.push(sessionSlug);
    } else if (!sessionSlug || sessionSlug === 'session') {
      // Only add 'session' if there's no custom session name or it's just 'session'
      channelParts.push('session');
    }

    // Add facilitator label and name
    channelParts.push(facilitatorLabel);
    channelParts.push(taSlug);

    // Add week number
    channelParts.push(`week${weekNumber}`);

    // Add suffix if configured
    if (this.config.slack_channels?.suffix) {
      channelParts.push(this.config.slack_channels.suffix);
    }

    const channelNameBase = channelParts.join('-');

    // Try to find existing channel first
    try {
      const channels = await this.client.conversations.list({
        types: 'private_channel',
        limit: 1000,
      });

      if (channels.channels) {
        // Look for existing channel with exact name or with suffix
        const existingChannel = channels.channels.find(channel =>
          channel.name === channelNameBase ||
          (channel.name?.startsWith(channelNameBase + '-') && /^-\d+$/.test(channel.name.slice(channelNameBase.length)))
        );

        if (existingChannel?.id) {
          console.log(`✅ Found existing ${this.getFacilitatorLabel().toLowerCase()} channel: ${existingChannel.name} (${existingChannel.id})`);
          return existingChannel.id;
        }
      }
    } catch (error) {
      console.warn(`⚠️  Error searching for existing channels:`, error);
    }

    // Try to create channel with incremental suffix if needed
    let attemptCount = 0;
    let channelName = channelNameBase;

    while (attemptCount < 10) { // Limit attempts to prevent infinite loop
      try {
        const result = await this.client.conversations.create({
          name: channelName,
          is_private: true,
        });

        const channelId = result.channel?.id;
        if (!channelId) {
          throw new Error('Failed to get channel ID');
        }

        console.log(`✅ Created ${this.getFacilitatorLabel().toLowerCase()} channel: ${channelName} (${channelId})`);
        return channelId;
      } catch (error: any) {
        // Check if error is due to channel name already taken
        if (error?.data?.error === 'name_taken' || error?.message?.includes('name_taken')) {
          attemptCount++;
          channelName = `${channelNameBase}-${attemptCount}`;
          console.log(`⚠️  Channel name taken, trying: ${channelName}`);
        } else {
          console.warn(`⚠️  Could not create ${this.getFacilitatorLabel().toLowerCase()} channel ${channelName}:`, error);
          return null;
        }
      }
    }

    console.error(`❌ Failed to create channel after ${attemptCount} attempts`);
    return null;
  }

  async inviteUsersToChannel(channelId: string, userIds: string[]): Promise<void> {
    try {
      // First check who's already in the channel
      const members = await this.client.conversations.members({
        channel: channelId,
      });

      const existingMembers = new Set(members.members || []);
      const usersToInvite = userIds.filter(userId => !existingMembers.has(userId));

      if (usersToInvite.length === 0) {
        console.log(`ℹ️  All users already in channel ${channelId}`);
        return;
      }

      await this.client.conversations.invite({
        channel: channelId,
        users: usersToInvite.join(','),
      });
      console.log(`✅ Invited ${usersToInvite.length} new users to channel ${channelId} (${userIds.length - usersToInvite.length} already members)`);
    } catch (error: any) {
      // Handle specific Slack errors
      if (error?.data?.error === 'already_in_channel') {
        console.log(`ℹ️  Users already in channel ${channelId}`);
      } else if (error?.data?.error === 'cant_invite_self') {
        console.log(`ℹ️  Bot can't invite itself to channel ${channelId}`);
      } else {
        console.error(`❌ Failed to invite users to channel ${channelId}:`, error);
        throw error;
      }
    }
  }

  async generateRecordingMeetLink(taId: string, taName: string, weekNumber: number, examDate: Date): Promise<string> {
    try {
      // Import Google Meet service dynamically to avoid circular dependencies
      const { GoogleMeetService } = await import('./google-meet');
      const meetService = new GoogleMeetService(this.config);

      // Create a Google Meet space for recording
      const meetingSpace = await meetService.createMeetingSpace({
        student: { name: `Recording Session`, email: `recording@${taId}`, slack_id: '' },
        ta: { id: taId, name: taName, email: '', slack_id: '', google_email: '' },
        section_id: taId,
        start_time: examDate,
        end_time: new Date(examDate.getTime() + 4 * 60 * 60 * 1000), // 4 hours later
        location: 'Virtual Recording Session'
      });

      console.log(`✅ Generated recording Google Meet link for ${taName}: ${meetingSpace.meetingUri}`);
      return meetingSpace.meetingUri;
    } catch (error: any) {
      console.warn(`⚠️  Google Meet API unavailable (${error.message}), generating simple Meet link`);

      // Generate a simple Google Meet link as fallback
      const meetingCode = `${taId.replace(/[^a-zA-Z0-9]/g, '')}-week${weekNumber}-${examDate.getMonth() + 1}${examDate.getDate()}`;
      const fallbackUrl = `https://meet.google.com/new?authuser=0&ijlm=${meetingCode}`;

      console.log(`📎 Generated fallback Google Meet link for ${taName}: ${fallbackUrl}`);
      return fallbackUrl;
    }
  }

  getGoogleFormForWeek(weekNumber: number): { url: string; description: string } | null {
    const form = this.config.weekly_forms.find(f => f.week === weekNumber);
    return form ? { url: form.google_form_url, description: form.description || `Week ${weekNumber} Form` } : null;
  }

  async sendTADaySchedule(taSlackId: string, slots: ScheduleSlot[], weekNumber: number): Promise<void> {
    if (slots.length === 0) return;

    const examDate = slots[0].start_time;
    const taName = slots[0].ta.name;

    // Generate Google Meet recording link
    const recordingLink = await this.generateRecordingMeetLink(slots[0].section_id, taName, weekNumber, examDate);

    // Get Google Form for this week
    const googleForm = this.getGoogleFormForWeek(weekNumber);

    // Try to create facilitator-specific channel for this exam date
    const channelId = await this.createFacilitatorChannel(taName, examDate, weekNumber);

    let targetChannel = taSlackId; // Default to direct message

    if (channelId) {
      // Channel created successfully, invite users and use channel
      try {
        const usersToInvite = [taSlackId, ...this.config.admin_users].filter(Boolean);
        await this.inviteUsersToChannel(channelId, usersToInvite);
        targetChannel = channelId;
        console.log(`✅ Using ${this.getFacilitatorLabel().toLowerCase()} channel ${channelId} for ${taName}`);
      } catch (error) {
        console.warn(`⚠️  Could not invite users to channel, falling back to DM:`, error);
        targetChannel = taSlackId;
      }
    } else {
      console.log(`📩 Sending ${this.getFacilitatorLabel().toLowerCase()} schedule via direct message to ${taName}`);
    }

    try {
      // Group slots by day (in case there are multiple days)
      const slotsByDay = new Map<string, ScheduleSlot[]>();
      slots.forEach(slot => {
        const dateKey = format(slot.start_time, 'yyyy-MM-dd');
        if (!slotsByDay.has(dateKey)) {
          slotsByDay.set(dateKey, []);
        }
        slotsByDay.get(dateKey)!.push(slot);
      });

      // Send message for each day
      for (const [dateKey, daySlots] of slotsByDay) {
        const examDate = daySlots[0].start_time;
        const sortedSlots = daySlots.sort((a, b) => a.start_time.getTime() - b.start_time.getTime());

        // Get custom session name for header
        const customSessionName = this.config.notifications.student_notification_title
          ? this.config.notifications.student_notification_title.replace(/ for \{name\}$/, '').replace(/\{name\}/, '').trim()
          : 'Session';

        const blocks = [
          {
            type: 'header',
            text: {
              type: 'plain_text',
              text: `📋 ${taName} - ${customSessionName} Schedule`,
            },
          },
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: `*Date:* ${format(examDate, 'EEEE, MMMM d, yyyy')}\n*Location:* ${daySlots[0].location}\n*Week:* ${weekNumber}`,
            },
          },
          {
            type: 'divider',
          },
        ];

        // Add student schedule
        const scheduleText = sortedSlots
          .map((slot, index) =>
            `${index + 1}. *${slot.student.name}*\n   ⏰ ${format(slot.start_time, 'h:mm a')} - ${format(slot.end_time, 'h:mm a')}`
          )
          .join('\n\n');

        blocks.push({
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: `*Today's Schedule (${sortedSlots.length} ${this.getParticipantLabel().toLowerCase()}s):*\n\n${scheduleText}`,
          },
        });

        blocks.push({
          type: 'divider',
        });

        // Add action buttons
        const actionElements: any[] = [];

        // Check if calendar invites are enabled to determine which button to show
        if (this.config.google_meet?.calendar_invites_enabled !== false) {
          // Calendar invites are enabled, show Meet link
          actionElements.push({
            type: 'button',
            text: {
              type: 'plain_text',
              text: '🎥 Recording Meet Link',
            },
            style: 'primary',
            url: recordingLink,
            action_id: 'start_recording',
          });
        } else {
          // Calendar invites are disabled, show web UI button to TA page
          const serverBaseUrl = this.config.web_ui?.server_base_url || 'http://localhost:3000';
          const taPageUrl = `${serverBaseUrl}/ta/${encodeURIComponent(taName.toLowerCase().replace(/\s+/g, '-'))}/week/${weekNumber}`;

          actionElements.push({
            type: 'button',
            text: {
              type: 'plain_text',
              text: '🌐 Go to TA Page',
            },
            style: 'primary',
            url: taPageUrl,
            action_id: 'open_ta_page',
          });
        }

        if (googleForm) {
          actionElements.push({
            type: 'button',
            text: {
              type: 'plain_text',
              text: '📝 Grade Form',
            },
            url: googleForm.url,
            action_id: 'open_grade_form',
          });
        }

        blocks.push({
          type: 'actions',
          elements: actionElements,
        } as any);

        blocks.push({
          type: 'context',
          elements: [
            {
              type: 'mrkdwn',
              text: `📋 Course: ${this.config.course.name} | 📅 Week ${weekNumber} | 👥 ${this.config.admin_users.length + 1} members`,
            },
          ],
        } as any);

        await this.client.chat.postMessage({
          channel: targetChannel,
          text: `📋 ${taName} - Session Schedule for ${format(examDate, 'MMMM d, yyyy')}`,
          blocks,
        });

        // Send backup plain text links
        let backupText = `📎 *Backup Links (in case buttons don't work):*\n`;

        if (this.config.google_meet?.calendar_invites_enabled !== false) {
          backupText += `🎥 Recording Meet Link: ${recordingLink}\n`;
        } else {
          const serverBaseUrl = this.config.web_ui?.server_base_url || 'http://localhost:3000';
          const taPageUrl = `${serverBaseUrl}/ta/${encodeURIComponent(taName.toLowerCase().replace(/\s+/g, '-'))}/week/${weekNumber}`;
          backupText += `🌐 TA Page: ${taPageUrl}\n`;
        }

        if (googleForm) {
          backupText += `📝 Grade Form: ${googleForm.url}\n`;
        }
        backupText += `\n_These are the same links as the buttons above._`;

        await this.client.chat.postMessage({
          channel: targetChannel,
          text: backupText,
          thread_ts: undefined, // Post as a new message, not a thread
        });

        console.log(`✅ Sent ${this.getFacilitatorLabel().toLowerCase()} schedule to ${targetChannel === taSlackId ? 'DM' : 'channel'} for ${taName} on ${format(examDate, 'MMMM d, yyyy')}`);
      }
    } catch (error) {
      console.error(`❌ Failed to send ${this.getFacilitatorLabel().toLowerCase()} schedule for ${taName}:`, error);
      // Don't throw error to allow other facilitators to continue receiving their schedules
      console.log(`⚠️  Continuing with other ${this.getFacilitatorLabel().toLowerCase()} notifications despite error for ${taName}`);
    }
  }

  private buildParticipantMessage(slot: ScheduleSlot): string {
    let message = `📚 **Session Appointment**\n\n`;
    message += `**Course:** ${this.config.course.name}\n`;
    message += `**Date:** ${format(slot.start_time, 'EEEE, MMMM d, yyyy')}\n`;
    message += `**Time:** ${format(slot.start_time, 'h:mm a')} - ${format(slot.end_time, 'h:mm a')}\n`;
    message += `**Location:** ${slot.location}\n`;
    message += `**${this.getFacilitatorLabel()}:** ${slot.ta.name}\n`;

    if (slot.meet_link) {
      message += `**Google Meet Link:** ${slot.meet_link}\n`;
    }

    message += `\nPlease arrive on time and bring any required materials.`;

    return message;
  }
}