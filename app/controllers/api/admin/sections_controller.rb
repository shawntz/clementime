module Api
  module Admin
    class SectionsController < Api::BaseController
      before_action :authorize_admin!
      before_action :set_section, only: [ :show, :update, :assign_ta, :time_slots ]

      def index
        sections = Section.includes(:ta, :students)
                         .order(:code)

        render json: {
          sections: sections.map { |s| section_response(s) }
        }, status: :ok
      end

      def show
        render json: { section: section_response(@section) }, status: :ok
      end

      def create
        section = Section.new(section_params)

        if section.save
          render json: {
            message: "Section created successfully",
            section: section_response(section)
          }, status: :created
        else
          render json: { errors: section.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @section.update(section_params)
          render json: {
            message: "Section updated successfully",
            section: section_response(@section)
          }, status: :ok
        else
          render json: { errors: @section.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def assign_ta
        ta = User.find(params[:ta_id])

        unless ta.ta?
          return render json: { errors: "User is not a TA" }, status: :unprocessable_entity
        end

        if @section.update(ta: ta)
          render json: {
            message: "TA assigned successfully",
            section: section_response(@section)
          }, status: :ok
        else
          render json: { errors: @section.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { errors: "TA not found" }, status: :not_found
      end

      def time_slots
        exam_number = params[:exam_number].to_i

        slots = ExamSlot.where(section: @section, exam_number: exam_number)
                       .includes(:student)
                       .order(:start_time)

        render json: {
          slots: slots.map do |slot|
            {
              id: slot.id,
              student: {
                id: slot.student.id,
                full_name: slot.student.full_name
              },
              exam_number: slot.exam_number,
              week_number: slot.week_number,
              week_group: slot.student.week_group,
              date: slot.date,
              start_time: slot.start_time&.strftime("%H:%M"),
              end_time: slot.end_time&.strftime("%H:%M"),
              is_scheduled: slot.is_scheduled
            }
          end
        }, status: :ok
      end

      private

      def set_section
        @section = Section.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { errors: "Section not found" }, status: :not_found
      end

      def section_params
        params.require(:section).permit(:code, :name, :location, :is_active)
      end

      def section_response(section)
        {
          id: section.id,
          code: section.code,
          name: section.name,
          location: section.location,
          is_active: section.is_active,
          ta: section.ta ? {
            id: section.ta.id,
            full_name: section.ta.full_name,
            email: section.ta.email
          } : nil,
          students_count: section.students.active.count
        }
      end
    end
  end
end
