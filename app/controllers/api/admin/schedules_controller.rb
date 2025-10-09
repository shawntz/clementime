module Api
  module Admin
    class SchedulesController < Api::BaseController
      before_action :authorize_admin!

      def generate
        generator = ScheduleGenerator.new

        if generator.generate_all_schedules
          render json: {
            message: "Schedules generated successfully",
            generated_count: generator.generated_count
          }, status: :ok
        else
          render json: {
            errors: generator.errors
          }, status: :unprocessable_entity
        end
      rescue => e
        render json: { errors: [ e.message ] }, status: :internal_server_error
      end

      def regenerate_student
        student = Student.find(params[:student_id])
        generator = ScheduleGenerator.new

        if generator.regenerate_student_schedule(student.id)
          render json: {
            message: "Student schedule regenerated successfully",
            student: {
              id: student.id,
              full_name: student.full_name,
              exam_slots: student.exam_slots.reload.map { |es| exam_slot_response(es) }
            }
          }, status: :ok
        else
          render json: {
            errors: generator.errors
          }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { errors: "Student not found" }, status: :not_found
      rescue => e
        render json: { errors: [ e.message ] }, status: :internal_server_error
      end

      def clear
        # Check if there are any locked slots
        locked_count = ExamSlot.where(is_locked: true).count

        if locked_count > 0
          return render json: {
            errors: "Cannot clear schedules: #{locked_count} exam slots are locked. Please unlock them first or use bulk unlock."
          }, status: :forbidden
        end

        Recording.delete_all
        ExamSlot.delete_all
        Student.update_all(week_group: nil)

        render json: {
          message: "All schedules cleared successfully"
        }, status: :ok
      rescue => e
        render json: { errors: [ e.message ] }, status: :internal_server_error
      end

      def export_csv
        require "csv"

        begin
          # Get all exam slots with associated data
          exam_slots = ExamSlot.includes(:student, :section, section: :ta)
                               .order(:exam_number, :week_number, :section_id, :start_time)

          if exam_slots.empty?
            return render json: { error: "No exam schedules found to export" }, status: :not_found
          end

          csv_data = CSV.generate(headers: true) do |csv|
            # Headers
            csv << [
              "Exam Number",
              "Week Number",
              "Week Type",
              "Section Code",
              "Section Name",
              "TA Name",
              "Student Name",
              "Student Email",
              "Date",
              "Start Time",
              "End Time",
              "Duration (min)",
              "Scheduled",
              "Locked"
            ]

            # Data rows
            exam_slots.each do |slot|
              # Skip slots without students (defensive check)
              next unless slot.student && slot.section

              csv << [
                slot.exam_number,
                slot.week_number,
                slot.student.week_group,
                slot.section.code,
                slot.section.name,
                slot.section.ta ? slot.section.ta.full_name : "No TA",
                slot.student.full_name,
                slot.student.email,
                slot.date ? slot.date.strftime("%Y-%m-%d") : "Not scheduled",
                slot.start_time ? slot.start_time.strftime("%H:%M") : "Not scheduled",
                slot.end_time ? slot.end_time.strftime("%H:%M") : "Not scheduled",
                slot.start_time && slot.end_time ? ((slot.end_time - slot.start_time) / 60).to_i : "N/A",
                slot.is_scheduled ? "Yes" : "No",
                slot.is_locked ? "Yes" : "No"
              ]
            end
          end

          send_data csv_data,
                    filename: "exam_schedules_#{Date.today.strftime('%Y%m%d')}.csv",
                    type: "text/csv",
                    disposition: "attachment"
        rescue => e
          render json: { error: e.message }, status: :internal_server_error
        end
      end

      def schedule_new_students
        # Find all students who have unscheduled slots or no slots at all
        total_exams = SystemConfig.get(SystemConfig::TOTAL_EXAMS, 5)
        exam_duration = SystemConfig.get(SystemConfig::EXAM_DURATION_MINUTES, 7)
        exam_buffer = SystemConfig.get(SystemConfig::EXAM_BUFFER_MINUTES, 1)
        exam_start_time_str = SystemConfig.get(SystemConfig::EXAM_START_TIME, "13:30")
        exam_end_time_str = SystemConfig.get(SystemConfig::EXAM_END_TIME, "14:50")
        exam_start_time = Time.parse("2000-01-01 #{exam_start_time_str}")
        exam_end_time = Time.parse("2000-01-01 #{exam_end_time_str}")
        quarter_start = SystemConfig.get(SystemConfig::QUARTER_START_DATE, Date.today.to_s)
        quarter_start_date = quarter_start.is_a?(Date) ? quarter_start : Date.parse(quarter_start.to_s)
        exam_day = SystemConfig.get(SystemConfig::EXAM_DAY, "friday")

        scheduled_count = 0
        unscheduled_count = 0
        students_processed = []

        ActiveRecord::Base.transaction do
          # Get all active students
          students = Student.active.includes(:exam_slots, :section, :constraints)

          # First, assign week groups to students who don't have one
          students_without_week_group = students.select { |s| s.section && s.week_group.nil? }

          students_without_week_group.group_by(&:section).each do |section, section_students|
            # Handle students with week_preference constraints first
            section_students.each do |student|
              week_constraint = student.constraints.active.find_by(constraint_type: "week_preference")
              if week_constraint && student.week_group != week_constraint.constraint_value
                student.update!(week_group: week_constraint.constraint_value)
              end
            end

            # Assign remaining students without week_group
            unassigned = section_students.select { |s| s.week_group.nil? }
            next if unassigned.empty?

            # Get existing week group distribution in this section
            existing_students = section.students.active.where.not(week_group: nil)
            odd_count = existing_students.where(week_group: "odd").count
            even_count = existing_students.where(week_group: "even").count

            # Assign new students to balance the groups
            unassigned.each do |student|
              if odd_count <= even_count
                student.update!(week_group: "odd")
                odd_count += 1
              else
                student.update!(week_group: "even")
                even_count += 1
              end
            end
          end

          students.each do |student|
            next unless student.section
            next unless student.week_group

            student_scheduled = 0
            student_unscheduled = 0

            (1..total_exams).each do |exam_number|
              existing_slot = student.exam_slots.find_by(exam_number: exam_number)

              # Skip if already scheduled or locked
              next if existing_slot && (existing_slot.is_scheduled || existing_slot.is_locked)

              # Delete unscheduled slot if it exists
              existing_slot&.destroy

              # Calculate week number
              base_week = (exam_number - 1) * 2 + 1
              week_number = student.week_group == "odd" ? base_week : base_week + 1

              # Calculate exam date
              days_until_exam = case exam_day.downcase
              when "monday" then 0
              when "tuesday" then 1
              when "wednesday" then 2
              when "thursday" then 3
              when "friday" then 4
              when "saturday" then 5
              when "sunday" then 6
              else 4
              end

              weeks_offset = week_number - 1
              target_week_monday = quarter_start_date + (weeks_offset * 7).days
              days_since_monday = (target_week_monday.wday - 1) % 7
              actual_monday = target_week_monday - days_since_monday.days
              exam_date = actual_monday + days_until_exam.days

              # Find last slot for this section/date/week
              section = student.section
              existing_slots = ExamSlot.joins(:student)
                                      .where(section: section, date: exam_date, is_scheduled: true)
                                      .where.not(end_time: nil)
                                      .order(end_time: :desc)

              # Determine start time
              if existing_slots.any?
                last_end_time = existing_slots.first.end_time
                new_start_time = last_end_time + (exam_buffer * 60)
              else
                new_start_time = exam_start_time
              end

              new_end_time = new_start_time + (exam_duration * 60)

              # Create slot
              if new_end_time > exam_end_time
                # Unscheduled
                ExamSlot.create!(
                  student: student,
                  section: section,
                  exam_number: exam_number,
                  week_number: week_number,
                  date: nil,
                  start_time: nil,
                  end_time: nil,
                  is_scheduled: false,
                  is_locked: false
                )
                student_unscheduled += 1
                unscheduled_count += 1
              else
                # Scheduled
                ExamSlot.create!(
                  student: student,
                  section: section,
                  exam_number: exam_number,
                  week_number: week_number,
                  date: exam_date,
                  start_time: new_start_time,
                  end_time: new_end_time,
                  is_scheduled: true,
                  is_locked: false
                )
                student_scheduled += 1
                scheduled_count += 1
              end
            end

            if student_scheduled > 0 || student_unscheduled > 0
              students_processed << {
                id: student.id,
                full_name: student.full_name,
                scheduled: student_scheduled,
                unscheduled: student_unscheduled
              }
            end
          end
        end

        render json: {
          message: "New students scheduled successfully",
          scheduled_count: scheduled_count,
          unscheduled_count: unscheduled_count,
          students_processed: students_processed
        }, status: :ok
      rescue => e
        Rails.logger.error("Failed to schedule new students: #{e.message}")
        render json: { errors: [ e.message ] }, status: :internal_server_error
      end

      def overview
        # Auto-lock all slots scheduled for today
        today = Date.today
        ExamSlot.where(date: today, is_scheduled: true, is_locked: false)
                .update_all(is_locked: true)

        sections = Section.active.includes(:students, :ta)

        overview_data = sections.map do |section|
          # Get unscheduled slots with full details
          unscheduled_slots = ExamSlot.where(section: section, is_scheduled: false)
                                      .includes(:student)
                                      .map do |slot|
            {
              id: slot.id,
              exam_number: slot.exam_number,
              week_number: slot.week_number,
              week_type: slot.student.week_group,
              is_locked: slot.is_locked,
              student: {
                id: slot.student.id,
                full_name: slot.student.full_name,
                email: slot.student.email
              },
              section: {
                id: section.id,
                name: section.name,
                code: section.code
              }
            }
          end

          {
            section: {
              id: section.id,
              code: section.code,
              name: section.name
            },
            ta: section.ta ? {
              id: section.ta.id,
              full_name: section.ta.full_name
            } : nil,
            students_count: section.students.active.count,
            scheduled_slots: ExamSlot.where(section: section, is_scheduled: true).count,
            unscheduled_slots_count: unscheduled_slots.count,
            unscheduled_slots: unscheduled_slots
          }
        end

        render json: {
          sections: overview_data,
          overview: overview_data,
          total_students: Student.active.count,
          total_scheduled: ExamSlot.where(is_scheduled: true).count,
          total_unscheduled: ExamSlot.where(is_scheduled: false).count
        }, status: :ok
      end

      private

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
    end
  end
end
