module Api
  module Ta
    class SectionsController < Api::BaseController
      before_action :authenticate_user!

      def index
        unless current_user.ta?
          return render json: { errors: "Access denied" }, status: :forbidden
        end

        sections = current_user.sections.active.order(:name)

        render json: {
          sections: sections.map { |s| section_response(s) }
        }, status: :ok
      end

      private

      def section_response(section)
        {
          id: section.id,
          code: section.code,
          name: section.name,
          location: section.location,
          student_count: section.students.where(is_active: true).count
        }
      end
    end
  end
end
