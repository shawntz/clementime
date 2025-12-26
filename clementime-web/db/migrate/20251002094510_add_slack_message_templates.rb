class AddSlackMessageTemplates < ActiveRecord::Migration[8.0]
  def change
    # Add Slack template configurations to system_configs if they don't exist
    reversible do |dir|
      dir.up do
        # Student schedule message template
        SystemConfig.create!(
          key: 'slack_student_schedule_template',
          value: 'Hi {{student_name}}! 👋

Here is your schedule for Oral Exam #{{exam_number}} (Week {{week}}):

📅 Date: {{date}}
⏰ Time: {{time}}
📍 Location: {{location}}

Your facilitator: {{facilitator}}

Good luck! 🎓',
          config_type: 'text',
          description: 'Template for student schedule Slack messages'
        ) rescue ActiveRecord::RecordNotUnique

        # TA schedule message template
        SystemConfig.create!(
          key: 'slack_ta_schedule_template',
          value: 'Hi {{ta_name}}! 👋

Here is your schedule for Oral Exam #{{exam_number}} (Week {{week}} - {{week_type}}):

You have {{student_count}} students scheduled.

📋 View full schedule: {{ta_page_url}}
📝 Grade form: {{grade_form_url}}

Please review and prepare accordingly. Let us know if you have any questions!',
          config_type: 'text',
          description: 'Template for TA schedule Slack messages'
        ) rescue ActiveRecord::RecordNotUnique

        # Slack message configuration variables
        SystemConfig.create!(
          key: 'slack_exam_location',
          value: 'Jordan Hall, Building 420',
          config_type: 'string',
          description: 'Default exam location for Slack messages'
        ) rescue ActiveRecord::RecordNotUnique

        SystemConfig.create!(
          key: 'slack_course_name',
          value: 'PSYCH 10 / STATS 60',
          config_type: 'string',
          description: 'Course name for Slack messages'
        ) rescue ActiveRecord::RecordNotUnique

        SystemConfig.create!(
          key: 'slack_term',
          value: 'Fall 2025',
          config_type: 'string',
          description: 'Current term for Slack messages'
        ) rescue ActiveRecord::RecordNotUnique

        SystemConfig.create!(
          key: 'slack_ta_page_url',
          value: 'https://psych10.clementime.app/ta',
          config_type: 'string',
          description: 'URL to TA page for schedule viewing'
        ) rescue ActiveRecord::RecordNotUnique

        SystemConfig.create!(
          key: 'slack_grade_form_url',
          value: 'https://forms.gle/example',
          config_type: 'string',
          description: 'URL to grade submission form'
        ) rescue ActiveRecord::RecordNotUnique
      end

      dir.down do
        # Clean up on rollback
        SystemConfig.where("key LIKE ?", "slack_%").destroy_all
      end
    end
  end
end
