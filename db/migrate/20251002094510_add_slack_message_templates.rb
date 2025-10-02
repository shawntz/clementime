class AddSlackMessageTemplates < ActiveRecord::Migration[8.0]
  def change
    # Add Slack template configurations to system_configs if they don't exist
    reversible do |dir|
      dir.up do
        # Student schedule message template
        execute <<-SQL
          INSERT INTO system_configs (key, value, config_type, description, created_at, updated_at)
          VALUES (
            'slack_student_schedule_template',
            'Hi {{student_name}}! 👋\n\nHere is your schedule for Oral Exam #{{exam_number}} (Week {{week}}):\n\n📅 Date: {{date}}\n⏰ Time: {{time}}\n📍 Location: {{location}}\n\nYour facilitator: {{facilitator}}\n\nGood luck! 🎓',
            'text',
            'Template for student schedule Slack messages',
            NOW(),
            NOW()
          ) ON CONFLICT (key) DO NOTHING;
        SQL

        # TA schedule message template
        execute <<-SQL
          INSERT INTO system_configs (key, value, config_type, description, created_at, updated_at)
          VALUES (
            'slack_ta_schedule_template',
            'Hi {{ta_name}}! 👋\n\nHere is your schedule for Oral Exam #{{exam_number}} (Week {{week}} - {{week_type}}):\n\nYou have {{student_count}} students scheduled.\n\n📋 View full schedule: {{ta_page_url}}\n📝 Grade form: {{grade_form_url}}\n\nPlease review and prepare accordingly. Let us know if you have any questions!',
            'text',
            'Template for TA schedule Slack messages',
            NOW(),
            NOW()
          ) ON CONFLICT (key) DO NOTHING;
        SQL

        # Slack message configuration variables
        execute <<-SQL
          INSERT INTO system_configs (key, value, config_type, description, created_at, updated_at)
          VALUES (
            'slack_exam_location',
            'Jordan Hall, Building 420',
            'string',
            'Default exam location for Slack messages',
            NOW(),
            NOW()
          ) ON CONFLICT (key) DO NOTHING;
        SQL

        execute <<-SQL
          INSERT INTO system_configs (key, value, config_type, description, created_at, updated_at)
          VALUES (
            'slack_course_name',
            'PSYCH 10 / STATS 60',
            'string',
            'Course name for Slack messages',
            NOW(),
            NOW()
          ) ON CONFLICT (key) DO NOTHING;
        SQL

        execute <<-SQL
          INSERT INTO system_configs (key, value, config_type, description, created_at, updated_at)
          VALUES (
            'slack_term',
            'Fall 2025',
            'string',
            'Current term for Slack messages',
            NOW(),
            NOW()
          ) ON CONFLICT (key) DO NOTHING;
        SQL

        execute <<-SQL
          INSERT INTO system_configs (key, value, config_type, description, created_at, updated_at)
          VALUES (
            'slack_ta_page_url',
            'https://psych10.clementime.app/ta',
            'string',
            'URL to TA page for schedule viewing',
            NOW(),
            NOW()
          ) ON CONFLICT (key) DO NOTHING;
        SQL

        execute <<-SQL
          INSERT INTO system_configs (key, value, config_type, description, created_at, updated_at)
          VALUES (
            'slack_grade_form_url',
            'https://forms.gle/example',
            'string',
            'URL to grade submission form',
            NOW(),
            NOW()
          ) ON CONFLICT (key) DO NOTHING;
        SQL
      end

      dir.down do
        # Clean up on rollback
        execute "DELETE FROM system_configs WHERE key LIKE 'slack_%'"
      end
    end
  end
end
