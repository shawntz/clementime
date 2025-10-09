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

      def overview
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
