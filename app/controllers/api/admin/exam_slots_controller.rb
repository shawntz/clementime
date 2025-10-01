module Api
  module Admin
    class ExamSlotsController < Api::BaseController
      before_action :authorize_admin!

      def update_time
        slot = ExamSlot.find(params[:id])

        # Parse time strings to Time objects
        start_time_str = params[:start_time]
        end_time_str = params[:end_time]

        start_time = Time.parse("2000-01-01 #{start_time_str}")
        end_time = Time.parse("2000-01-01 #{end_time_str}")

        if slot.update(start_time: start_time, end_time: end_time)
          render json: {
            message: 'Time slot updated successfully',
            slot: {
              id: slot.id,
              start_time: slot.start_time.strftime('%H:%M'),
              end_time: slot.end_time.strftime('%H:%M')
            }
          }, status: :ok
        else
          render json: { errors: slot.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { errors: 'Exam slot not found' }, status: :not_found
      rescue => e
        render json: { errors: [e.message] }, status: :internal_server_error
      end
    end
  end
end
