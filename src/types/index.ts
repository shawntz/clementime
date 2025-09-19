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
  };
  admin_users: string[]; // Slack IDs of teaching team admins
  weekly_forms: WeeklyFormConfig[]; // Week-by-week Google Form links
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
}