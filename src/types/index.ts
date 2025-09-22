export type UserRole = 'admin' | 'ta';

export interface Student {
  name: string;
  email: string;
  slack_id?: string;
}

export interface TA {
  id: string;
  name: string;
  email: string;
  slack_id: string;
  google_email: string;
}

export interface Section {
  id: string;
  ta_name: string;
  ta_email: string;
  ta_slack_id?: string;
  google_email?: string;
  location: string;
  preferred_days: string[];
  students: Student[];
  students_csv?: string;  // Optional path to CSV file
  student_split?: {
    enabled: boolean;  // Whether to split students across multiple weeks
    split_percentage: number;  // Percentage of students for first week (0-100, default: 50)
    weeks_between_splits: number;  // Number of weeks between each split (default: 2)
  };
}

export interface ScheduleSlot {
  student: Student;
  ta: TA;
  section_id: string;
  start_time: Date;
  end_time: Date;
  location: string;
  meet_link?: string;
  meet_space_name?: string;
  meet_code?: string;
  recording_url?: string;
  calendar_event_id?: string;
  calendar_link?: string;
  meeting_start_notified?: boolean;
}

export interface WeeklyFormConfig {
  week: number;
  google_form_url: string;
  description?: string;
}

export interface Config {
  course: {
    name: string;
    term: string;
    total_students: number;
    instructor?: string;
  };
  organization?: {
    domain: string; // e.g. "shawnschwartz.com" - used to identify internal users
    timezone: string; // e.g. "America/Los_Angeles" - used for calendar events
  };
  terminology?: {
    facilitator_label?: string; // Custom label for "Facilitator" (e.g., "TA", "Instructor", "Coach")
    participant_label?: string; // Custom label for "Participant" (e.g., "Student", "Client", "Patient")
  };
  web_ui?: {
    navbar_title?: string; // Custom title for the navbar header (e.g., "Session Scheduler")
    server_base_url?: string; // Base URL for the server (e.g., "https://clementime.example.com")
  };
  scheduling: {
    exam_duration_minutes: number;
    buffer_minutes: number;
    start_time: string;
    end_time: string;
    excluded_days: string[];
    schedule_frequency_weeks: number;
  };
  sections: Section[];
  google_meet: {
    calendar_invites_enabled?: boolean; // Whether to create calendar invites with meeting links (default: false)
    recording_settings: {
      auto_recording: boolean;
      save_to_drive: boolean;
      folder_id?: string;
    };
  };
  notifications: {
    reminder_days_before: number[];
    reminder_time: string;
    include_meet_link: boolean;
    include_location: boolean;
    ta_summary_enabled: boolean;
    ta_summary_time: string;
    student_notification_title?: string;
  };
  admin_users: string[]; // Slack IDs of teaching team admins
  weekly_forms?: WeeklyFormConfig[]; // Week-by-week Google Form links
  recording: {
    base_url: string; // Base recording URL template
    ta_specific: boolean; // Whether each TA gets unique recording links
  };
  slack_channels?: {
    prefix?: string; // Prefix for TA channel names (e.g., "psych10") - dash added automatically
    suffix?: string; // Suffix for TA channel names (e.g., "fall2025") - dash added automatically
  };
  ai_recording?: {
    enabled: boolean;
    service_email: string; // e.g., "fred@fireflies.ai", "zoom@otter.ai", etc.
    service_name?: string; // e.g., "Fireflies.ai", "Otter.ai", "Grain", etc.
    auto_invite: boolean; // Whether to automatically add to all meeting invites
    notification_enabled?: boolean; // Whether to notify when AI bot joins/leaves
  };
  test_mode?: {
    enabled: boolean;
    redirect_to_slack_id: string;
    fake_student_prefix?: string;
    number_of_fake_students?: number;
    test_email?: string;
  };
  authorized_google_users?: string[]; // List of Google email addresses allowed to access the dashboard
}