module Api
  module Ta
    class StudentsController < Api::BaseController
      before_action :authenticate_user!

      def index
        unless current_user.ta?
          return render json: { errors: "Access denied" }, status: :forbidden
        end

        # Get all students from TA's sections
        students = Student.joins(:section)
                         .where(sections: { id: current_user.section_ids })
                         .includes(:section, :constraints)
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
          constraint_types: get_active_constraint_types(students)
        }, status: :ok
      end

      def export_by_section
        require "csv"

        unless current_user.ta?
          return render json: { errors: "Access denied" }, status: :forbidden
        end

        # Get only the TA's sections with students
        sections = Section.where(id: current_user.section_ids)
                         .includes(students: :section, ta: nil)
                         .where.not(students: { id: nil })
                         .order(:name)

        if sections.empty?
          return render json: { error: "No sections with students found" }, status: :not_found
        end

        # Generate CSV data for all TA's sections combined
        csv_data = CSV.generate(headers: true) do |csv|
          csv << [ "Full Name", "Email", "Section", "Week Group", "Active" ]

          sections.each do |section|
            section.students.order(:full_name).each do |student|
              csv << [
                student.full_name,
                student.email,
                section.name,
                student.cohort,
                student.is_active ? "Yes" : "No"
              ]
            end
          end
        end

        # Send the CSV file
        send_data csv_data,
                  filename: "roster_by_section_#{Date.today.strftime('%Y%m%d')}.csv",
                  type: "text/csv",
                  disposition: "attachment"
      rescue => e
        render json: { error: e.message }, status: :internal_server_error
      end

      private

      def student_response(student)
        {
          id: student.id,
          full_name: student.full_name,
          email: student.email,
          cohort: student.cohort,
          is_active: student.is_active,
          section: student.section ? {
            id: student.section.id,
            name: student.section.name,
            code: student.section.code
          } : nil,
          constraints_count: student.constraints.where(is_active: true).count,
          constraint_types: student.constraints.where(is_active: true).pluck(:constraint_type).uniq,
          slack_matched: student.slack_user_id.present?
        }
      end

      def get_active_constraint_types(students)
        types = {}
        students.each do |student|
          student.constraints.where(is_active: true).each do |constraint|
            types[constraint.constraint_type] ||= 0
            types[constraint.constraint_type] += 1
          end
        end

        types.map { |type, count| { value: type, label: type.titleize, count: count } }
             .sort_by { |t| t[:label] }
      end
    end
  end
end
