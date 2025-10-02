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
        require "zip"

        # Get all sections with students
        sections = Section.includes(students: :section, ta: nil)
                         .where.not(students: { id: nil })
                         .order(:name)

        # Create a temporary file for the zip
        temp_file = Tempfile.new([ "roster_export", ".zip" ])

        begin
          Zip::File.open(temp_file.path, Zip::File::CREATE) do |zipfile|
            sections.each do |section|
              students = section.students.where(is_active: true).order(:full_name)
              next if students.empty?

              # Generate CSV for this section
              csv_data = CSV.generate(headers: true) do |csv|
                csv << [ "Name", "Email", "Slack ID", "SIS ID", "Section Number", "Section Name", "TA Name" ]

                students.each do |student|
                  csv << [
                    student.full_name,
                    student.email,
                    student.slack_user_id || "",
                    student.sis_user_id || "",
                    section.code,
                    section.name,
                    section.ta ? section.ta.full_name : "No TA"
                  ]
                end
              end

              # Add CSV to zip with sanitized section name
              safe_section_name = section.name.gsub(/[^a-zA-Z0-9\-_]/, "_")
              zipfile.get_output_stream("#{safe_section_name}.csv") { |f| f.write(csv_data) }
            end
          end

          # Send the zip file
          send_file temp_file.path,
                    filename: "roster_by_section_#{Date.today.strftime('%Y%m%d')}.zip",
                    type: "application/zip",
                    disposition: "attachment"
        ensure
          # Clean up temp file after sending
          temp_file.close
          temp_file.unlink
        end
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

        # Update student's week group
        @student.update!(week_group: new_week_group)

        # Regenerate schedules for affected exams
        slots_updated = @student.exam_slots
                                .where("exam_number >= ?", from_exam)
                                .update_all(
                                  is_scheduled: false,
                                  date: nil,
                                  start_time: nil,
                                  end_time: nil
                                )

        render json: {
          message: "Student transferred to #{new_week_group} week group",
          student: student_detail_response(@student),
          slots_cleared: slots_updated
        }, status: :ok
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
