module Api
  module Admin
    class SchedulesController < Api::BaseController
      before_action :authorize_admin!

      def generate
        generator = ScheduleGenerator.new

        if generator.generate_all_schedules
          render json: {
            message: 'Schedules generated successfully',
            generated_count: generator.generated_count
          }, status: :ok
        else
          render json: {
            errors: generator.errors
          }, status: :unprocessable_entity
        end
      rescue => e
        render json: { errors: [e.message] }, status: :internal_server_error
      end

      def regenerate_student
        student = Student.find(params[:student_id])
        generator = ScheduleGenerator.new

        if generator.regenerate_student_schedule(student.id)
          render json: {
            message: 'Student schedule regenerated successfully',
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
        render json: { errors: 'Student not found' }, status: :not_found
      rescue => e
        render json: { errors: [e.message] }, status: :internal_server_error
      end

      def clear
        Recording.delete_all
        ExamSlot.delete_all
        Student.update_all(week_group: nil)

        render json: {
          message: 'All schedules cleared successfully'
        }, status: :ok
      rescue => e
        render json: { errors: [e.message] }, status: :internal_server_error
      end

      def overview
        sections = Section.active.includes(:students, :ta)

        overview_data = sections.map do |section|
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
            unscheduled_slots: ExamSlot.where(section: section, is_scheduled: false).count
          }
        end

        render json: {
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
