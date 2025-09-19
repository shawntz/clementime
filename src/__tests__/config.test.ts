import { Config } from '../types';
import { SchedulingAlgorithm } from '../scheduler/algorithm';

describe('Configuration Tests', () => {
  test('should create valid test config', () => {
    const mockConfig: Config = {
      course: {
        name: 'Test Course',
        term: 'Spring 2024',
        total_students: 10
      },
      scheduling: {
        exam_duration_minutes: 30,
        buffer_minutes: 10,
        start_time: '09:00',
        end_time: '17:00',
        excluded_days: [],
        schedule_frequency_weeks: 1
      },
      sections: [
        {
          id: 'test_section',
          ta_name: 'Test Facilitator',
          ta_email: 'facilitator@test.edu',
          ta_slack_id: 'U123456',
          google_email: 'facilitator@test.edu',
          location: 'Test Room',
          preferred_days: ['Monday', 'Wednesday', 'Friday'],
          students: [
            {
              name: 'Test Student 1',
              email: 'student1@test.edu',
              slack_id: 'U789101'
            },
            {
              name: 'Test Student 2',
              email: 'student2@test.edu',
              slack_id: 'U111213'
            }
          ]
        }
      ],
      google_meet: {
        recording_settings: {
          auto_recording: true,
          save_to_drive: false
        }
      },
      notifications: {
        reminder_days_before: [1],
        reminder_time: '09:00',
        include_meet_link: true,
        include_location: true,
        ta_summary_enabled: false,
        ta_summary_time: '17:00'
      },
      admin_users: ['U123456'],
      weekly_forms: [],
      recording: {
        base_url: 'https://test.com/recordings/',
        ta_specific: false
      },
      slack_channels: {
        prefix: 'test',
        suffix: 'spring2024'
      }
    };

    expect(mockConfig).toBeDefined();
    expect(mockConfig.course.name).toBe('Test Course');
    expect(mockConfig.sections).toHaveLength(1);
    expect(mockConfig.sections[0].students).toHaveLength(2);
  });
});

describe('Scheduling Algorithm Tests', () => {
  const mockConfig: Config = {
    course: {
      name: 'Test Course',
      term: 'Spring 2024',
      total_students: 2
    },
    scheduling: {
      exam_duration_minutes: 30,
      buffer_minutes: 10,
      start_time: '09:00',
      end_time: '11:00',
      excluded_days: [],
      schedule_frequency_weeks: 1
    },
    sections: [
      {
        id: 'test_section',
        ta_name: 'Test Facilitator',
        ta_email: 'facilitator@test.edu',
        ta_slack_id: 'U123456',
        google_email: 'facilitator@test.edu',
        location: 'Test Room',
        preferred_days: ['Monday'],
        students: [
          {
            name: 'Test Student 1',
            email: 'student1@test.edu',
            slack_id: 'U789101'
          },
          {
            name: 'Test Student 2',
            email: 'student2@test.edu',
            slack_id: 'U111213'
          }
        ]
      }
    ],
    google_meet: {
      recording_settings: {
        auto_recording: true,
        save_to_drive: false
      }
    },
    notifications: {
      reminder_days_before: [1],
      reminder_time: '09:00',
      include_meet_link: true,
      include_location: true,
      ta_summary_enabled: false,
      ta_summary_time: '17:00'
    },
    admin_users: ['U123456'],
    weekly_forms: [],
    recording: {
      base_url: 'https://test.com/recordings/',
      ta_specific: false
    },
    slack_channels: {
      prefix: 'test',
      suffix: 'spring2024'
    }
  };

  test('should initialize scheduling algorithm', () => {
    const scheduler = new SchedulingAlgorithm(mockConfig);
    expect(scheduler).toBeDefined();
  });

  test('should generate schedule for mock data', () => {
    const scheduler = new SchedulingAlgorithm(mockConfig);
    const startDate = new Date('2024-01-15'); // A Monday

    const schedule = scheduler.generateSchedule(startDate);

    expect(schedule).toBeDefined();
    expect(schedule.has('test_section')).toBe(true);

    const sectionSchedule = schedule.get('test_section');
    expect(sectionSchedule).toBeDefined();
    expect(sectionSchedule!.length).toBe(2); // Should schedule both students

    // Verify each slot has required properties
    sectionSchedule!.forEach(slot => {
      expect(slot.student).toBeDefined();
      expect(slot.ta).toBeDefined();
      expect(slot.start_time).toBeDefined();
      expect(slot.end_time).toBeDefined();
      expect(slot.location).toBe('Test Room');
      expect(slot.section_id).toBe('test_section');
    });
  });

  test('should handle empty sections gracefully', () => {
    const emptyConfig = {
      ...mockConfig,
      sections: [
        {
          ...mockConfig.sections[0],
          students: []
        }
      ]
    };

    const scheduler = new SchedulingAlgorithm(emptyConfig);
    const startDate = new Date('2024-01-15');

    const schedule = scheduler.generateSchedule(startDate);

    expect(schedule).toBeDefined();
    expect(schedule.has('test_section')).toBe(true);

    const sectionSchedule = schedule.get('test_section');
    expect(sectionSchedule).toBeDefined();
    expect(sectionSchedule!.length).toBe(0);
  });
});