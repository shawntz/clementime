import * as fs from 'fs';
import * as path from 'path';
import * as yaml from 'js-yaml';
import { Config } from '../types';
import { z } from 'zod';
import { loadStudentsFromCSV } from './csv-loader';

const StudentSchema = z.object({
  name: z.string(),
  email: z.string().email(),
  slack_id: z.string().optional(),
});

const SectionSchema = z.object({
  id: z.string(),
  ta_name: z.string(),
  ta_email: z.string().email(),
  ta_slack_id: z.string().optional(),
  google_email: z.string().email().optional(),
  location: z.string(),
  preferred_days: z.array(z.string()),
  students: z.array(StudentSchema).optional(),
  students_csv: z.string().optional(), // Path to CSV file
  student_split: z.object({
    enabled: z.boolean(),
    split_percentage: z.number().min(0).max(100),
    weeks_between_splits: z.number().min(1),
  }).optional(),
});

const ConfigSchema = z.object({
  course: z.object({
    name: z.string(),
    term: z.string(),
    total_students: z.number(),
    instructor: z.string().optional(),
  }),
  organization: z.object({
    domain: z.string(),
    timezone: z.string(),
  }).optional(),
  terminology: z.object({
    facilitator_label: z.string().optional(),
    participant_label: z.string().optional(),
  }).optional(),
  scheduling: z.object({
    exam_duration_minutes: z.number(),
    buffer_minutes: z.number(),
    break_duration_minutes: z.number().optional(),
    start_time: z.string(),
    end_time: z.string(),
    excluded_days: z.array(z.string()),
    schedule_frequency_weeks: z.number(),
  }),
  sections: z.array(SectionSchema),
  google_meet: z.object({
    calendar_invites_enabled: z.boolean().optional(),
    recording_settings: z.object({
      auto_recording: z.boolean(),
      folder_id: z.string().optional(),
    }),
  }),
  notifications: z.object({
    reminder_days_before: z.array(z.number()),
    reminder_time: z.string(),
    include_meet_link: z.boolean(),
    include_location: z.boolean(),
    ta_summary_enabled: z.boolean(),
    ta_summary_time: z.string(),
    student_notification_title: z.string().optional(),
  }),
  admin_users: z.array(z.string()),
  authorized_google_users: z.array(z.string()).optional(),
  weekly_forms: z.array(z.object({
    week: z.number(),
    google_form_url: z.string(),
    description: z.string().optional(),
  })),
  slack_channels: z.object({
    prefix: z.string().optional(),
    suffix: z.string().optional(),
  }).optional(),
  test_mode: z.object({
    enabled: z.boolean(),
    redirect_to_slack_id: z.string(),
    fake_student_prefix: z.string().optional(),
    number_of_fake_students: z.number().optional(),
    test_email: z.string().email().optional(),
  }).optional(),
  web_ui: z.object({
    navbar_title: z.string().optional(),
    server_base_url: z.string().optional(),
  }).optional(),
});

export function loadConfig(configPath?: string): Config {
  const filePath = configPath || path.join(process.cwd(), 'config.yml');

  if (!fs.existsSync(filePath)) {
    throw new Error(`Configuration file not found at: ${filePath}`);
  }

  const fileContents = fs.readFileSync(filePath, 'utf8');
  const rawConfig = yaml.load(fileContents) as any;

  // Process sections to load students from CSV if specified
  if (rawConfig.sections && Array.isArray(rawConfig.sections)) {
    rawConfig.sections = rawConfig.sections.map((section: any) => {
      if (section.students_csv) {
        // Load students from CSV file
        const csvPath = path.isAbsolute(section.students_csv)
          ? section.students_csv
          : path.join(path.dirname(filePath), section.students_csv);

        let csvStudents: any[] = [];

        // Try Cloud Storage first if enabled
        if (process.env.USE_CLOUD_STORAGE === 'true') {
          console.log(`🔍 Attempting to load CSV from Cloud Storage: ${section.students_csv}`);
          try {
            // Use gsutil command for immediate sync access
            const { execSync } = require('child_process');
            const bucketName = process.env.STORAGE_BUCKET;
            const tempPath = `/tmp/${section.id}_students.csv`;

            execSync(`gsutil cp "gs://${bucketName}/${section.students_csv}" "${tempPath}"`, {
              stdio: 'pipe',
              timeout: 10000
            });

            csvStudents = loadStudentsFromCSV(tempPath);
            console.log(`✅ Loaded ${csvStudents.length} students from Cloud Storage CSV`);
          } catch (cloudError) {
            console.warn(`⚠️  Cloud Storage CSV load failed, trying local: ${cloudError}`);
            csvStudents = loadStudentsFromCSV(csvPath);
          }
        } else {
          csvStudents = loadStudentsFromCSV(csvPath);
        }

        console.log(`Loaded ${csvStudents.length} students from ${section.students_csv} for section ${section.id}`);

        // If both CSV and inline students exist, merge them (CSV takes priority)
        if (section.students && Array.isArray(section.students)) {
          // Create a map of existing students by email
          const existingStudentsMap = new Map(
            section.students.map((s: any) => [s.email.toLowerCase(), s])
          );

          // Merge CSV students, preferring CSV data
          csvStudents.forEach(csvStudent => {
            existingStudentsMap.set(csvStudent.email.toLowerCase(), csvStudent);
          });

          section.students = Array.from(existingStudentsMap.values());
        } else {
          section.students = csvStudents;
        }

        // Remove the CSV path from the config as it's no longer needed
        delete section.students_csv;
      }

      // Ensure students array exists
      if (!section.students) {
        section.students = [];
      }

      // Fill in optional fields from FACILITATOR_MAPPING environment variable
      if (process.env.FACILITATOR_MAPPING) {
        try {
          const mapping = JSON.parse(process.env.FACILITATOR_MAPPING);
          if (mapping[section.id]) {
            if (!section.ta_slack_id && mapping[section.id].slack_id) {
              section.ta_slack_id = mapping[section.id].slack_id;
            }
            if (!section.google_email && mapping[section.id].google_email) {
              section.google_email = mapping[section.id].google_email;
            }
          }
        } catch (e) {
          console.error('Failed to parse FACILITATOR_MAPPING JSON:', e);
        }
      }

      // Fallback to old individual env vars for backward compatibility
      if (!section.ta_slack_id && process.env[`TA_SLACK_ID_${section.id.toUpperCase()}`]) {
        section.ta_slack_id = process.env[`TA_SLACK_ID_${section.id.toUpperCase()}`];
      }
      if (!section.google_email && process.env[`TA_GOOGLE_EMAIL_${section.id.toUpperCase()}`]) {
        section.google_email = process.env[`TA_GOOGLE_EMAIL_${section.id.toUpperCase()}`];
      }

      return section;
    });
  }

  try {
    return ConfigSchema.parse(rawConfig) as Config;
  } catch (error) {
    if (error instanceof z.ZodError) {
      console.error('Configuration validation failed:', error.errors);
      throw new Error('Invalid configuration file');
    }
    throw error;
  }
}

export function validateConfig(config: Config): boolean {
  const totalConfiguredStudents = config.sections.reduce(
    (sum, section) => sum + section.students.length,
    0
  );

  if (totalConfiguredStudents !== config.course.total_students) {
    console.warn(
      `Warning: Configured students (${totalConfiguredStudents}) doesn't match total_students (${config.course.total_students})`
    );
  }

  const sectionIds = new Set<string>();
  for (const section of config.sections) {
    if (sectionIds.has(section.id)) {
      throw new Error(`Duplicate section ID: ${section.id}`);
    }
    sectionIds.add(section.id);
  }

  return true;
}