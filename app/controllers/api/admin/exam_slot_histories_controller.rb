module Api
  module Admin
    class ExamSlotHistoriesController < Api::BaseController
      before_action :authorize_admin!

      def index
        student = Student.find(params[:student_id])
        exam_slot = student.exam_slots.find_by(exam_number: params[:exam_number])

        if exam_slot
          histories = exam_slot.histories.order(changed_at: :desc)

          render json: {
            current: exam_slot_response(exam_slot),
            histories: histories.map { |h| history_response(h) }
          }, status: :ok
        else
          render json: {
            current: nil,
            histories: []
          }, status: :ok
        end
      rescue ActiveRecord::RecordNotFound
        render json: { errors: 'Student not found' }, status: :not_found
      end

      def revert
        student = Student.find(params[:student_id])
        exam_slot = student.exam_slots.find_by(exam_number: params[:exam_number])
        history = ExamSlotHistory.find(params[:id])

        unless history.exam_slot_id == exam_slot&.id
          render json: { errors: 'History does not match exam slot' }, status: :unprocessable_entity
          return
        end

        ActiveRecord::Base.transaction do
          exam_slot.update!(
            section_id: history.section_id,
            week_number: history.week_number,
            date: history.date,
            start_time: history.start_time,
            end_time: history.end_time,
            is_scheduled: history.is_scheduled
          )
        end

        render json: {
          message: 'Schedule reverted successfully',
          exam_slot: exam_slot_response(exam_slot)
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { errors: 'Record not found' }, status: :not_found
      rescue => e
        render json: { errors: [e.message] }, status: :internal_server_error
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
          section: {
            id: slot.section.id,
            name: slot.section.name,
            code: slot.section.code
          },
          formatted_time: slot.formatted_time_range
        }
      end

      def history_response(history)
        {
          id: history.id,
          exam_number: history.exam_number,
          week_number: history.week_number,
          date: history.date,
          start_time: history.start_time,
          end_time: history.end_time,
          is_scheduled: history.is_scheduled,
          changed_at: history.changed_at,
          changed_by: history.changed_by,
          reason: history.reason,
          section: history.section ? {
            id: history.section.id,
            name: history.section.name,
            code: history.section.code
          } : nil
        }
      end
    end
  end
end
