module Api
  module Admin
    class StudentsController < Api::BaseController
      before_action :authorize_admin!
      before_action :set_student, only: [ :show, :update, :deactivate, :transfer_week_group, :change_section, :notify_slack, :swap_to_opposite_week ]

      def index
        students = Student.includes(:section, :constraints)
                         .order(:full_name)

        # Filter by section if provided
        students = students.where(section_id: params[:section_id]) if params[:section_id].present?

        # Filter by active status
        students = students.where(is_active: params[:is_active]) if params[:is_active].present?

        # Filter by constraint status
        if params[:constraint_filter].present?
          case params[:constraint_filter]
          when "with_constraints"
            students = students.joins(:constraints).where(constraints: { is_active: true }).distinct
          when "without_constraints"
            students = students.left_joins(:constraints)
                              .where(constraints: { id: nil })
                              .or(students.left_joins(:constraints).where(constraints: { is_active: false }))
                              .distinct
          end
        end

        # Filter by specific constraint type
        if params[:constraint_type].present?
          students = students.joins(:constraints)
                            .where(constraints: { constraint_type: params[:constraint_type], is_active: true })
                            .distinct
        end

        render json: {
          students: students.map { |s| student_response(s) },
          constraint_types: get_active_constraint_types
        }, status: :ok
      end

      def export_by_section
        require "csv"

        # Build base query with filters
        students = Student.includes(:section, :constraints).order(:full_name)

        # Apply filters
        students = students.where(section_id: params[:section_id]) if params[:section_id].present?
        students = students.where(week_group: params[:week_group]) if params[:week_group].present?
        students = students.where(is_active: params[:is_active]) if params[:is_active].present?

        # Search filter
        if params[:search].present?
          search_term = "%#{params[:search].downcase}%"
          students = students.where(
            "LOWER(full_name) LIKE ? OR LOWER(email) LIKE ?",
            search_term, search_term
          )
        end

        # Constraint filters
        if params[:constraint_filter] == "with_constraints"
          students = students.joins(:constraints).where(constraints: { is_active: true }).distinct
        elsif params[:constraint_filter] == "without_constraints"
          students = students.left_joins(:constraints)
                            .where(constraints: { id: nil })
                            .or(students.left_joins(:constraints).where(constraints: { is_active: false }))
                            .distinct
        end

        if params[:constraint_type].present?
          students = students.joins(:constraints)
                            .where(constraints: { constraint_type: params[:constraint_type], is_active: true })
                            .distinct
        end

        if students.empty?
          return render json: { error: "No students match the current filters" }, status: :not_found
        end

        # Generate CSV data
        csv_data = CSV.generate(headers: true) do |csv|
          csv << [ "Name", "Email", "Slack ID", "SIS ID", "Section Number", "Section Name", "TA Name", "Week Group", "Active" ]

          students.each do |student|
            csv << [
              student.full_name,
              student.email,
              student.slack_user_id || "",
              student.sis_user_id || "",
              student.section&.code || "",
              student.section&.name || "",
              student.section&.ta ? student.section.ta.full_name : "No TA",
              student.week_group || "",
              student.is_active ? "Yes" : "No"
            ]
          end
        end

        # Send the CSV file
        send_data csv_data,
                  filename: "roster_filtered_#{Date.today.strftime('%Y%m%d')}.csv",
                  type: "text/csv",
                  disposition: "attachment"
      rescue => e
        render json: { error: e.message }, status: :internal_server_error
      end

      def show
        render json: { student: student_detail_response(@student) }, status: :ok
      end

      def update
        if @student.update(student_params)
          render json: {
            message: "Student updated successfully",
            student: student_detail_response(@student)
          }, status: :ok
        else
          render json: { errors: @student.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def deactivate
        # Check if student has any locked exam slots
        locked_slots_count = @student.exam_slots.where(is_locked: true).count

        if locked_slots_count > 0
          return render json: {
            errors: "Cannot deactivate student: #{locked_slots_count} exam slots are locked (already sent to student). Please unlock them first."
          }, status: :forbidden
        end

        ActiveRecord::Base.transaction do
          # Delete all exam slots to free up time slots for other students
          @student.exam_slots.destroy_all

          # Deactivate the student
          @student.update!(is_active: false)
        end

        render json: {
          message: "Student deactivated successfully. All exam slots have been freed.",
          student: student_response(@student)
        }, status: :ok
      rescue => e
        render json: { errors: e.message }, status: :internal_server_error
      end

      def clear_all
        Student.destroy_all
        render json: { message: "All students deleted successfully" }, status: :ok
      rescue => e
        render json: { errors: e.message }, status: :internal_server_error
      end

      # Transfer student between odd/even weeks (for athletes, etc.)
      def transfer_week_group
        new_week_group = params[:week_group]
        from_exam = params[:from_exam].to_i

        unless %w[odd even].include?(new_week_group)
          return render json: { errors: "Invalid week group" }, status: :unprocessable_entity
        end

        # Check if any slots from this exam onwards are locked
        locked_slots = @student.exam_slots
                               .where("exam_number >= ?", from_exam)
                               .where(is_locked: true)

        if locked_slots.any?
          return render json: {
            errors: "Cannot transfer: some exam slots (#{from_exam}+) are locked. Please unlock them first."
          }, status: :forbidden
        end

        ActiveRecord::Base.transaction do
          # Update student's week group
          @student.update!(week_group: new_week_group)

          # Clear affected exam slots
          slots_cleared = @student.exam_slots
                                  .where("exam_number >= ?", from_exam)
                                  .update_all(
                                    is_scheduled: false,
                                    date: nil,
                                    start_time: nil,
                                    end_time: nil
                                  )

          # Get total exams from config
          total_exams = SystemConfig.get(SystemConfig::TOTAL_EXAMS, 5)

          # Regenerate schedule for affected exams
          generator = ScheduleGenerator.new
          section = @student.section
          slots_scheduled = 0

          (from_exam..total_exams).each do |exam_number|
            if generator.send(:generate_single_student_slot, @student, section, exam_number)
              slots_scheduled += 1
            end
          end

          render json: {
            message: "Student transferred to #{new_week_group} week group and rescheduled",
            student: student_detail_response(@student.reload),
            slots_cleared: slots_cleared,
            slots_scheduled: slots_scheduled
          }, status: :ok
        end
      rescue => e
        render json: { errors: e.message }, status: :internal_server_error
      end

      # Swap student to opposite week cadence and place at end of schedule
      def swap_to_opposite_week
        from_exam = params[:from_exam].to_i

        if from_exam < 1 || from_exam > 5
          return render json: { errors: "Invalid exam number" }, status: :unprocessable_entity
        end

        # Determine new week group (opposite of current)
        new_week_group = @student.week_group == "odd" ? "even" : "odd"

        begin
          ActiveRecord::Base.transaction do
            # Get system config
            total_exams = SystemConfig.get(SystemConfig::TOTAL_EXAMS, 5)
            exam_duration = SystemConfig.get(SystemConfig::EXAM_DURATION_MINUTES, 7)
            exam_buffer = SystemConfig.get(SystemConfig::EXAM_BUFFER_MINUTES, 1)
            exam_end_time_str = SystemConfig.get(SystemConfig::EXAM_END_TIME, "14:50")
            exam_end_time = Time.parse("2000-01-01 #{exam_end_time_str}")

            # Update student's week group
            @student.update!(week_group: new_week_group)

            moved_count = 0
            unlocked_count = 0

            # Process each exam from start onwards
            (from_exam..total_exams).each do |exam_number|
              # Find and delete old slot (unlock if needed)
              old_slot = @student.exam_slots.find_by(exam_number: exam_number)

              if old_slot
                unlocked_count += 1 if old_slot.is_locked
                old_slot.destroy
              end

              # Calculate new week number based on new week_group
              base_week = (exam_number - 1) * 2 + 1
              new_week_number = new_week_group == "odd" ? base_week : base_week + 1

              # Calculate exam date for this week
              quarter_start = SystemConfig.get(SystemConfig::QUARTER_START_DATE, Date.today.to_s)
              quarter_start_date = quarter_start.is_a?(Date) ? quarter_start : Date.parse(quarter_start.to_s)
              exam_day = SystemConfig.get(SystemConfig::EXAM_DAY, "friday")

              # Calculate the date
              days_until_exam = case exam_day.downcase
              when "monday" then 0
              when "tuesday" then 1
              when "wednesday" then 2
              when "thursday" then 3
              when "friday" then 4
              when "saturday" then 5
              when "sunday" then 6
              else 4 # default to Friday
              end

              # Find the Monday of the target week
              weeks_offset = new_week_number - 1
              target_week_monday = quarter_start_date + (weeks_offset * 7).days

              # Adjust to the Monday of that week
              days_since_monday = (target_week_monday.wday - 1) % 7
              actual_monday = target_week_monday - days_since_monday.days

              # Calculate the exam date
              exam_date = actual_monday + days_until_exam.days

              # Find the last time slot used on this date for this section
              section = @student.section
              existing_slots = ExamSlot.joins(:student)
                                      .where(section: section, date: exam_date, is_scheduled: true)
                                      .where.not(end_time: nil)
                                      .order(end_time: :desc)

              # Determine start time (either after last slot or if it fits before exam_end_time)
              if existing_slots.any?
                last_end_time = existing_slots.first.end_time
                new_start_time = last_end_time + (exam_buffer * 60)
              else
                # No existing slots, use exam start time
                exam_start_time_str = SystemConfig.get(SystemConfig::EXAM_START_TIME, "13:30")
                new_start_time = Time.parse("2000-01-01 #{exam_start_time_str}")
              end

              new_end_time = new_start_time + (exam_duration * 60)

              # Check if it fits within exam window
              if new_end_time > exam_end_time
                # Create unscheduled slot if it doesn't fit
                ExamSlot.create!(
                  student: @student,
                  section: section,
                  exam_number: exam_number,
                  week_number: new_week_number,
                  date: nil,
                  start_time: nil,
                  end_time: nil,
                  is_scheduled: false,
                  is_locked: false
                )
              else
                # Create scheduled slot at the end
                ExamSlot.create!(
                  student: @student,
                  section: section,
                  exam_number: exam_number,
                  week_number: new_week_number,
                  date: exam_date,
                  start_time: new_start_time,
                  end_time: new_end_time,
                  is_scheduled: true,
                  is_locked: false
                )
                moved_count += 1
              end
            end

            render json: {
              message: "Student swapped to #{new_week_group} week cadence and placed at end of schedule",
              student: @student.full_name,
              old_week_group: new_week_group == "odd" ? "even" : "odd",
              new_week_group: new_week_group,
              from_exam: from_exam,
              moved_count: moved_count,
              unlocked_count: unlocked_count
            }, status: :ok
          end
        rescue => e
          Rails.logger.error("Failed to swap student to opposite week: #{e.message}")
          render json: { errors: e.message }, status: :internal_server_error
        end
      end

      # Send Slack notification to a single student for a specific exam
      def notify_slack
        exam_number = params[:exam_number].to_i

        if exam_number < 1 || exam_number > 5
          return render json: { errors: "Invalid exam number" }, status: :unprocessable_entity
        end

        # Check if student has Slack matched
        unless @student.slack_matched
          return render json: { errors: "Student is not matched with Slack" }, status: :unprocessable_entity
        end

        # Find the exam slot for this student and exam
        exam_slot = @student.exam_slots.find_by(exam_number: exam_number)

        unless exam_slot
          return render json: { errors: "No exam slot found for this exam" }, status: :not_found
        end

        unless exam_slot.is_scheduled
          return render json: { errors: "Exam slot is not scheduled yet" }, status: :unprocessable_entity
        end

        bot_token = SystemConfig.get(SystemConfig::SLACK_BOT_TOKEN)
        unless bot_token.present?
          return render json: { errors: "Slack bot token not configured" }, status: :unprocessable_entity
        end

        begin
          # Build message for student
          message = build_student_slack_message(exam_slot)

          # Build list of participants for MPDM
          participants = []

          # Check if test mode is enabled
          test_mode = SystemConfig.get("slack_test_mode", false)
          test_user_id = SystemConfig.get("slack_test_user_id", "")
          super_admin_slack_id = SystemConfig.get("super_admin_slack_id", "")

          if test_mode && test_user_id.present?
            # Test mode: send to test user instead of actual student
            participants << test_user_id
          else
            # Normal mode: send to actual student
            participants << @student.slack_user_id
          end

          # Add TA if they have a Slack ID
          ta = exam_slot.section.ta
          participants << ta.slack_id if ta && ta.slack_id.present?

          # Add super admin if configured
          participants << super_admin_slack_id if super_admin_slack_id.present?

          # Remove duplicates and nils
          participants = participants.compact.uniq

          # Create MPDM if multiple participants, otherwise send DM
          channel = if participants.length > 1
            create_slack_mpdm(bot_token, participants)
          else
            participants.first
          end

          unless channel
            raise "Failed to create conversation for #{@student.full_name}"
          end

          send_slack_message(bot_token, channel, message)

          # Lock the slot after sending (if not already locked)
          unless exam_slot.is_locked
            exam_slot.update!(is_locked: true)
          end

          render json: {
            message: "Slack notification sent successfully",
            student: @student.full_name,
            exam_number: exam_number,
            locked: exam_slot.is_locked
          }, status: :ok
        rescue => e
          Rails.logger.error("Failed to send Slack notification: #{e.message}")
          render json: { errors: e.message }, status: :internal_server_error
        end
      end

      # Change student's section assignment (with override flag)
      def change_section
        new_section = Section.find(params[:section_id])

        # Check if student has any locked exam slots
        locked_slots_count = @student.exam_slots.where(is_locked: true).count

        if locked_slots_count > 0
          return render json: {
            errors: "Cannot change section: #{locked_slots_count} exam slots are locked. Please unlock them first or clear future slots."
          }, status: :forbidden
        end

        ActiveRecord::Base.transaction do
          # Clear all exam slots since they're scheduled for the old section
          @student.exam_slots.destroy_all

          # Update section and set override flag
          @student.update!(
            section: new_section,
            section_override: true
          )
        end

        render json: {
          message: "Student moved to #{new_section.name}. Section override set - this will be preserved on roster uploads.",
          student: student_detail_response(@student.reload)
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { errors: "Section not found" }, status: :not_found
      rescue => e
        render json: { errors: e.message }, status: :internal_server_error
      end

      private

      def set_student
        @student = Student.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { errors: "Student not found" }, status: :not_found
      end

      def student_params
        params.require(:student).permit(:week_group, :is_active)
      end

      def get_active_constraint_types
        Constraint.where(is_active: true)
                  .select(:constraint_type)
                  .distinct
                  .pluck(:constraint_type)
                  .map { |type|
                    {
                      value: type,
                      label: type.split("_").map(&:capitalize).join(" "),
                      count: Constraint.where(constraint_type: type, is_active: true).count
                    }
                  }
      end

      def student_response(student)
        {
          id: student.id,
          full_name: student.full_name,
          email: student.email,
          section: student.section ? {
            id: student.section.id,
            code: student.section.code,
            name: student.section.name
          } : nil,
          section_override: student.section_override,
          week_group: student.week_group,
          slack_matched: student.slack_matched,
          slack_username: student.slack_username,
          slack_user_id: student.slack_user_id,
          is_active: student.is_active,
          constraints_count: student.constraints.active.count,
          constraint_types: student.constraints.active.pluck(:constraint_type).uniq
        }
      end

      def student_detail_response(student)
        {
          id: student.id,
          full_name: student.full_name,
          email: student.email,
          sis_user_id: student.sis_user_id,
          sis_login_id: student.sis_login_id,
          section: {
            id: student.section.id,
            code: student.section.code,
            name: student.section.name
          },
          section_override: student.section_override,
          week_group: student.week_group,
          slack_user_id: student.slack_user_id,
          slack_username: student.slack_username,
          slack_matched: student.slack_matched,
          is_active: student.is_active,
          constraints: student.constraints.active.map { |c| constraint_response(c) },
          exam_slots: student.exam_slots.map { |es| exam_slot_response(es) }
        }
      end

      def constraint_response(constraint)
        {
          id: constraint.id,
          constraint_type: constraint.constraint_type,
          constraint_value: constraint.constraint_value,
          description: constraint.display_description,
          is_active: constraint.is_active
        }
      end

      def exam_slot_response(slot)
        {
          id: slot.id,
          exam_number: slot.exam_number,
          week_number: slot.week_number,
          date: slot.date,
          start_time: slot.start_time,
          end_time: slot.end_time,
          is_scheduled: slot.is_scheduled,
          formatted_time: slot.formatted_time_range
        }
      end

      def build_student_slack_message(exam_slot)
        template = SystemConfig.get("slack_student_message_template", "")

        # Get TA for this section (with nil safety)
        section = exam_slot.section
        ta = section&.ta
        ta_name = ta ? ta.full_name : "TBA"
        location = ta && ta.location.present? ? ta.location : "TBA"

        template.gsub("{{student_name}}", exam_slot.student.full_name)
                .gsub("{{exam_number}}", exam_slot.exam_number.to_s)
                .gsub("{{week}}", exam_slot.week_number.to_s)
                .gsub("{{date}}", exam_slot.date ? exam_slot.date.strftime("%A, %B %d, %Y") : "TBA")
                .gsub("{{time}}", exam_slot.formatted_time_range)
                .gsub("{{location}}", location)
                .gsub("{{ta_name}}", ta_name)
                .gsub("{{course}}", SystemConfig.get("slack_course_name", ""))
                .gsub("{{term}}", SystemConfig.get("slack_term", ""))
      end

      def create_slack_mpdm(bot_token, user_ids)
        require "net/http"
        require "uri"
        require "json"

        uri = URI.parse("https://slack.com/api/conversations.open")
        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{bot_token}"
        request["Content-Type"] = "application/json"
        request.body = {
          users: user_ids.join(",")
        }.to_json

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        result = JSON.parse(response.body)

        if result["ok"]
          result["channel"]["id"]
        else
          Rails.logger.error("Failed to create MPDM: #{result['error']}")
          nil
        end
      rescue => e
        Rails.logger.error("Failed to create MPDM: #{e.message}")
        nil
      end

      def send_slack_message(bot_token, channel, message_text)
        require "net/http"
        require "uri"
        require "json"

        uri = URI.parse("https://slack.com/api/chat.postMessage")
        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{bot_token}"
        request["Content-Type"] = "application/json"
        request.body = {
          channel: channel,
          text: message_text
        }.to_json

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        result = JSON.parse(response.body)

        unless result["ok"]
          raise "Slack API error: #{result["error"] || "Unknown error"}"
        end

        result
      end
    end
  end
end
