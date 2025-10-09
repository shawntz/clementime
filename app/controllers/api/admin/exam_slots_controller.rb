module Api
  module Admin
    class ExamSlotsController < Api::BaseController
      before_action :authorize_admin!

      def update_time
        slot = ExamSlot.find(params[:id])

        # Check if slot is locked
        if slot.is_locked
          return render json: {
            errors: "This schedule is locked. Please unlock it first to make changes."
          }, status: :forbidden
        end

        # Parse time strings to Time objects
        start_time_str = params[:start_time]
        end_time_str = params[:end_time]

        start_time = Time.parse("2000-01-01 #{start_time_str}")
        end_time = Time.parse("2000-01-01 #{end_time_str}")

        if slot.update(start_time: start_time, end_time: end_time)
          render json: {
            message: "Time slot updated successfully",
            slot: {
              id: slot.id,
              start_time: slot.start_time.strftime("%H:%M"),
              end_time: slot.end_time.strftime("%H:%M")
            }
          }, status: :ok
        else
          render json: { errors: slot.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { errors: "Exam slot not found" }, status: :not_found
      rescue => e
        render json: { errors: [ e.message ] }, status: :internal_server_error
      end

      # Manual scheduling - assign time to unscheduled slot
      def manual_schedule
        slot = ExamSlot.find(params[:id])

        if slot.is_locked
          return render json: {
            errors: "This schedule is locked. Please unlock it first to make changes."
          }, status: :forbidden
        end

        slot.update!(
          date: params[:date],
          start_time: Time.parse("2000-01-01 #{params[:start_time]}"),
          end_time: Time.parse("2000-01-01 #{params[:end_time]}"),
          is_scheduled: true
        )

        render json: {
          message: "Slot scheduled successfully",
          slot: slot_response(slot)
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { errors: "Exam slot not found" }, status: :not_found
      rescue => e
        render json: { errors: [ e.message ] }, status: :internal_server_error
      end

      # Swap two exam slots (for drag-and-drop reordering)
      def swap_slots
        slot1 = ExamSlot.find(params[:slot1_id])
        slot2 = ExamSlot.find(params[:slot2_id])

        if slot1.is_locked || slot2.is_locked
          return render json: {
            errors: "One or both schedules are locked. Please unlock them first."
          }, status: :forbidden
        end

        # Swap times and dates
        slot1_data = {
          date: slot1.date,
          start_time: slot1.start_time,
          end_time: slot1.end_time
        }

        slot1.update!(
          date: slot2.date,
          start_time: slot2.start_time,
          end_time: slot2.end_time
        )

        slot2.update!(
          date: slot1_data[:date],
          start_time: slot1_data[:start_time],
          end_time: slot1_data[:end_time]
        )

        render json: {
          message: "Slots swapped successfully",
          slot1: slot_response(slot1),
          slot2: slot_response(slot2)
        }, status: :ok
      rescue => e
        render json: { errors: [ e.message ] }, status: :internal_server_error
      end

      # Unlock a locked schedule (emergency use)
      def unlock
        slot = ExamSlot.find(params[:id])

        slot.update!(is_locked: false)

        render json: {
          message: "Schedule unlocked successfully",
          slot: slot_response(slot)
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { errors: "Exam slot not found" }, status: :not_found
      rescue => e
        render json: { errors: [ e.message ] }, status: :internal_server_error
      end

      # Bulk unlock for an entire exam
      def bulk_unlock
        exam_number = params[:exam_number].to_i
        week_type = params[:week_type] # 'odd' or 'even'

        slots = ExamSlot.joins(:student)
                       .where(exam_number: exam_number, is_locked: true)
                       .where(students: { week_group: week_type })

        count = slots.update_all(is_locked: false)

        render json: {
          message: "#{count} schedules unlocked successfully",
          count: count
        }, status: :ok
      rescue => e
        render json: { errors: [ e.message ] }, status: :internal_server_error
      end

      # Auto-lock all slots that are scheduled for today
      def auto_lock_today
        today = Date.today

        # Find all scheduled slots for today that aren't already locked
        slots = ExamSlot.where(date: today, is_scheduled: true, is_locked: false)

        count = slots.update_all(is_locked: true)

        render json: {
          message: "#{count} schedules auto-locked for today (#{today})",
          count: count,
          date: today
        }, status: :ok
      rescue => e
        render json: { errors: [ e.message ] }, status: :internal_server_error
      end

      private

      def slot_response(slot)
        {
          id: slot.id,
          exam_number: slot.exam_number,
          student: {
            id: slot.student.id,
            full_name: slot.student.full_name
          },
          date: slot.date,
          start_time: slot.start_time&.strftime("%H:%M"),
          end_time: slot.end_time&.strftime("%H:%M"),
          is_scheduled: slot.is_scheduled,
          is_locked: slot.is_locked
        }
      end
    end
  end
end
