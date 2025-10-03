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
        require "zip"

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

        # Create a temporary file for the zip
        temp_file = Tempfile.new([ "roster_by_section", ".zip" ])

        begin
          Zip::File.open(temp_file.path, ::Zip::File::CREATE) do |zipfile|
            sections.each do |section|
              csv_string = CSV.generate do |csv|
                csv << [ "Full Name", "Email", "Section", "Week Group", "Active" ]
                section.students.order(:full_name).each do |student|
                  csv << [
                    student.full_name,
                    student.email,
                    section.name,
                    student.week_group,
                    student.is_active ? "Yes" : "No"
                  ]
                end
              end

              zipfile.get_output_stream("#{section.name.gsub(/[^0-9A-Za-z.\-]/, '_')}.csv") do |f|
                f.write csv_string
              end
            end
          end

          send_file temp_file.path, type: "application/zip", filename: "roster_by_section_#{Date.today}.zip"
        ensure
          temp_file.close
          temp_file.unlink
        end
      end

      private

      def student_response(student)
        {
          id: student.id,
          full_name: student.full_name,
          email: student.email,
          week_group: student.week_group,
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
