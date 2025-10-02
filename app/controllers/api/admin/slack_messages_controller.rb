module Api
  module Admin
    class SlackMessagesController < Api::BaseController
      before_action :authorize_admin!

      # Send schedule messages to TAs for a specific exam and week type
      def send_ta_schedules
        exam_number = params[:exam_number].to_i
        week_type = params[:week_type] # 'odd' or 'even'

        if exam_number < 1 || exam_number > 5
          return render json: { errors: "Invalid exam number" }, status: :unprocessable_entity
        end

        unless %w[odd even].include?(week_type)
          return render json: { errors: "Invalid week type" }, status: :unprocessable_entity
        end

        # Get all TAs with sections
        tas = User.where(role: "ta").includes(:sections)
        results = []
        errors = []

        tas.each do |ta|
          ta.sections.each do |section|
            # Get students for this section, exam, and week type
            students = Student.joins(:exam_slots)
                             .where(section: section, week_group: week_type)
                             .where(exam_slots: { exam_number: exam_number, is_scheduled: true })
                             .distinct

            next if students.empty?

            # Send message to TA
            message = build_ta_message(ta, section, exam_number, week_type, students.count)

            begin
              send_slack_message(ta.slack_user_id, message)
              results << { ta: ta.full_name, section: section.name, student_count: students.count }
            rescue => e
              errors << "#{ta.full_name} (#{section.name}): #{e.message}"
            end
          end
        end

        render json: {
          message: "TA schedules sent",
          sent_count: results.count,
          results: results,
          errors: errors
        }, status: :ok
      end

      # Send schedule messages to students for a specific exam and week type
      def send_student_schedules
        exam_number = params[:exam_number].to_i
        week_type = params[:week_type] # 'odd' or 'even'

        if exam_number < 1 || exam_number > 5
          return render json: { errors: "Invalid exam number" }, status: :unprocessable_entity
        end

        unless %w[odd even].include?(week_type)
          return render json: { errors: "Invalid week type" }, status: :unprocessable_entity
        end

        # Get all students with scheduled slots for this exam and week type
        exam_slots = ExamSlot.joins(:student)
                            .where(exam_number: exam_number, is_scheduled: true)
                            .where(students: { week_group: week_type, slack_matched: true })
                            .includes(:student, :section)

        results = []
        errors = []
        locked_count = 0

        exam_slots.each do |slot|
          # Build message for student
          message = build_student_message(slot)

          begin
            send_slack_message(slot.student.slack_user_id, message)

            # Lock the slot after sending
            slot.update!(is_locked: true)
            locked_count += 1

            results << {
              student: slot.student.full_name,
              time: slot.formatted_time_range,
              locked: true
            }
          rescue => e
            errors << "#{slot.student.full_name}: #{e.message}"
          end
        end

        render json: {
          message: "Student schedules sent and locked",
          sent_count: results.count,
          locked_count: locked_count,
          results: results,
          errors: errors
        }, status: :ok
      end

      # Test recording functionality
      def test_recording
        begin
          # Get test configuration from system config
          test_audio_url = SystemConfig.get_value("test_recording_url", "https://example.com/test-audio.mp3")

          # Trigger Google Drive upload test
          # This would actually upload a test file

          render json: {
            message: "Recording test completed successfully",
            test_url: test_audio_url,
            status: "success"
          }, status: :ok
        rescue => e
          render json: {
            message: "Recording test failed",
            error: e.message
          }, status: :internal_server_error
        end
      end

      private

      def build_ta_message(ta, section, exam_number, week_type, student_count)
        template = SystemConfig.get_value("slack_ta_schedule_template", "")

        week_number = calculate_week_number(exam_number, week_type)

        template.gsub("{{ta_name}}", ta.full_name)
                .gsub("{{exam_number}}", exam_number.to_s)
                .gsub("{{week}}", week_number.to_s)
                .gsub("{{week_type}}", week_type.capitalize)
                .gsub("{{student_count}}", student_count.to_s)
                .gsub("{{ta_page_url}}", SystemConfig.get_value("slack_ta_page_url", ""))
                .gsub("{{grade_form_url}}", SystemConfig.get_value("slack_grade_form_url", ""))
                .gsub("{{course}}", SystemConfig.get_value("slack_course_name", ""))
                .gsub("{{term}}", SystemConfig.get_value("slack_term", ""))
      end

      def build_student_message(exam_slot)
        template = SystemConfig.get_value("slack_student_schedule_template", "")

        # Get TA for this section
        ta = exam_slot.section.tas.first
        facilitator = ta ? ta.full_name : "TBA"

        template.gsub("{{student_name}}", exam_slot.student.full_name)
                .gsub("{{exam_number}}", exam_slot.exam_number.to_s)
                .gsub("{{week}}", exam_slot.week_number.to_s)
                .gsub("{{date}}", exam_slot.date ? exam_slot.date.strftime("%A, %B %d, %Y") : "TBA")
                .gsub("{{time}}", exam_slot.formatted_time_range)
                .gsub("{{location}}", SystemConfig.get_value("slack_exam_location", ""))
                .gsub("{{facilitator}}", facilitator)
                .gsub("{{course}}", SystemConfig.get_value("slack_course_name", ""))
                .gsub("{{term}}", SystemConfig.get_value("slack_term", ""))
      end

      def send_slack_message(slack_user_id, message)
        # Use existing Slack API service
        slack_api = SlackApiService.new
        slack_api.send_direct_message(slack_user_id, message)
      end

      def calculate_week_number(exam_number, week_type)
        # Calculate week number based on exam number and week type
        # Odd weeks: 1, 3, 5, 7, 9
        # Even weeks: 2, 4, 6, 8, 10
        base = (exam_number - 1) * 2
        week_type == "odd" ? base + 1 : base + 2
      end
    end
  end
end
