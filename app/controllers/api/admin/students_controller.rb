module Api
  module Admin
    class StudentsController < Api::BaseController
      before_action :authorize_admin!
      before_action :set_student, only: [ :show, :update, :deactivate ]

      def index
        students = Student.includes(:section, :constraints)
                         .order(:full_name)

        # Filter by section if provided
        students = students.where(section_id: params[:section_id]) if params[:section_id].present?

        # Filter by active status
        students = students.where(is_active: params[:is_active]) if params[:is_active].present?

        render json: {
          students: students.map { |s| student_response(s) }
        }, status: :ok
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
        @student.update(is_active: false)
        render json: { message: "Student deactivated successfully" }, status: :ok
      end

      def clear_all
        Student.destroy_all
        render json: { message: "All students deleted successfully" }, status: :ok
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
          week_group: student.week_group,
          slack_matched: student.slack_matched,
          slack_username: student.slack_username,
          slack_user_id: student.slack_user_id,
          is_active: student.is_active,
          constraints_count: student.constraints.active.count
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
    end
  end
end
