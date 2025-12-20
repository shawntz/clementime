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

        # Check for and clean up any duplicate slots for this student/exam combination
        duplicates = ExamSlot.where(
          student_id: slot.student_id,
          exam_number: slot.exam_number
        ).where.not(id: slot.id)

        if duplicates.any?
          Rails.logger.warn("Found #{duplicates.count} duplicate slots for student #{slot.student_id}, exam #{slot.exam_number}. Removing duplicates.")
          duplicates.destroy_all
        end

        new_start_time = Time.parse("2000-01-01 #{params[:start_time]}")
        new_end_time = Time.parse("2000-01-01 #{params[:end_time]}")
        new_date = Date.parse(params[:date])

        # Get exam duration and buffer from config
        exam_duration_minutes = SystemConfig.get(SystemConfig::EXAM_DURATION_MINUTES, 7)
        exam_buffer_minutes = SystemConfig.get(SystemConfig::EXAM_BUFFER_MINUTES, 1)

        # Find all other unlocked slots in the same section/date/week that are scheduled at or after this time
        slots_to_adjust = ExamSlot.where(
          section_id: slot.section_id,
          exam_number: slot.exam_number,
          week_number: slot.week_number,
          date: new_date,
          is_scheduled: true,
          is_locked: false
        ).where("start_time >= ?", new_start_time)
         .where.not(id: slot.id)
         .order(:start_time)

        # Update the manually scheduled slot first
        slot.update!(
          date: new_date,
          start_time: new_start_time,
          end_time: new_end_time,
          is_scheduled: true
        )

        # Push back all subsequent slots
        current_time = new_end_time + (exam_buffer_minutes * 60)
        slots_to_adjust.each do |other_slot|
          next_end_time = current_time + (exam_duration_minutes * 60)
          other_slot.update!(
            start_time: current_time,
            end_time: next_end_time
          )
          current_time = next_end_time + (exam_buffer_minutes * 60)
        end

        render json: {
          message: "Slot scheduled successfully. #{slots_to_adjust.count} subsequent slot(s) adjusted.",
          slot: slot_response(slot),
          adjusted_count: slots_to_adjust.count
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

        # Swap times and dates, but calculate week_number based on student's week_group
        slot1_data = {
          date: slot1.date,
          start_time: slot1.start_time,
          end_time: slot1.end_time
        }

        # Calculate correct week_number based on exam_number and student's week_group
        # Formula: week_number = (exam_number - 1) * 2 + (week_group == "odd" ? 1 : 2)
        slot1_week_number = calculate_week_number(slot1.exam_number, slot1.student.week_group)
        slot2_week_number = calculate_week_number(slot2.exam_number, slot2.student.week_group)

        slot1.update!(
          date: slot2.date,
          start_time: slot2.start_time,
          end_time: slot2.end_time,
          week_number: slot1_week_number
        )

        slot2.update!(
          date: slot1_data[:date],
          start_time: slot1_data[:start_time],
          end_time: slot1_data[:end_time],
          week_number: slot2_week_number
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

      def calculate_week_number(exam_number, week_group)
        base_week = (exam_number - 1) * 2 + 1
        week_group == "odd" ? base_week : base_week + 1
      end

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
