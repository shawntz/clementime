module Api
  module Ta
    class SchedulesController < Api::BaseController
      def index
        week_number = params[:week_number].to_i

        unless current_user.ta?
          return render json: { errors: "Access denied" }, status: :forbidden
        end

        sections = current_user.sections.active.includes(:students)

        schedules = sections.map do |section|
          slots = ExamSlot.where(section: section, week_number: week_number, is_scheduled: true)
                         .includes(:student, :recording)
                         .order(:start_time)

          {
            section: {
              id: section.id,
              code: section.code,
              name: section.name,
              location: current_user.location || section.location
            },
            slots: slots.map { |slot| slot_response(slot) }
          }
        end

        render json: {
          week_number: week_number,
          ta: {
            id: current_user.id,
            full_name: current_user.full_name
          },
          schedules: schedules
        }, status: :ok
      end

      private

      def slot_response(slot)
        {
          id: slot.id,
          student: {
            id: slot.student.id,
            full_name: slot.student.full_name,
            email: slot.student.email
          },
          exam_number: slot.exam_number,
          date: slot.date,
          start_time: slot.start_time&.strftime("%H:%M"),
          end_time: slot.end_time&.strftime("%H:%M"),
          formatted_time: slot.formatted_time_range,
          has_recording: slot.has_recording?,
          recording: slot.recording ? {
            id: slot.recording.id,
            recorded_at: slot.recording.recorded_at,
            uploaded: slot.recording.uploaded?
          } : nil
        }
      end
    end
  end
end
