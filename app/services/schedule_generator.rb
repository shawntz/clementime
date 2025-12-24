class ScheduleGenerator
  attr_reader :errors, :generated_count

  def initialize(options = {})
    @options = options
    @errors = []
    @generated_count = 0
    @start_exam = options[:start_exam] || 1  # Default to exam 1, or start from specified exam
    load_config
  end

  # Class method to update exam slots when exam dates change in config
  #
  # Updates exam slots for students based on the provided exam dates configuration.
  #
  # @param exam_dates_config [Hash] A hash mapping exam identifiers to date strings.
  #   Keys should be in the format "1_odd", "2_even", etc., where the number is the exam number
  #   and "odd"/"even" refers to the student's week group. Values should be date strings (e.g., "2024-06-15").
  # @return [Integer] The number of exam slots updated.
  # @raise [ActiveRecord::RecordInvalid] If a slot update fails validation.
  # @raise [ArgumentError] If a date string cannot be parsed.
  # @note This method updates the database (ExamSlot records) and logs info/errors via Rails.logger.
  def self.update_exam_dates_for_students(exam_dates_config)
    return 0 if exam_dates_config.blank?
    
    unless exam_dates_config.is_a?(Hash)
      Rails.logger.error("exam_dates_config must be a Hash")
      return 0
    end

    generator = new
    updated_count = 0

    ActiveRecord::Base.transaction do
      # Process each configured exam date
      exam_dates_config.each do |key, date_str|
        next if date_str.blank?

        # Parse key (format: "1_odd", "2_even", etc.)
        match = key.match(/^(\d+)_(odd|even)$/)
        next unless match

        exam_number = match[1].to_i
        cohort = match[2]

        # Parse the new date
        begin
          new_date = Date.parse(date_str.to_s)

          # Calculate week_number from the actual date
          week_number = generator.send(:calculate_week_from_date, new_date)
          
          # Check if week_number calculation failed
          if week_number.nil?
            Rails.logger.error("Failed to calculate week number for date #{new_date} (key: #{key})")
            next
          end

          # Find all exam slots for this exam number where students have this cohort
          # Only update unlocked slots to avoid changing confirmed exams
          ExamSlot.joins(:student)
            .where(exam_number: exam_number)
            .where(students: { cohort: cohort })
            .where(is_locked: false)
            .find_each do |slot|
              # Update the slot's date and week_number
              slot.update!(date: new_date, week_number: week_number)
              updated_count += 1
            end
        rescue => e
          Rails.logger.error("Error updating exam dates for #{key}: #{e.message}")
          raise  # Ensure transaction is rolled back on error
        end
      end
    end

    Rails.logger.info("Updated #{updated_count} exam slots after exam_dates config change")
    updated_count
  end

  def generate_all_schedules
    # Check if balanced TA scheduling is enabled
    balanced_scheduling = SystemConfig.get(SystemConfig::BALANCED_TA_SCHEDULING, false)

    ActiveRecord::Base.transaction do
      if balanced_scheduling
        generate_balanced_ta_schedules
      else
        sections = Section.active.includes(:students, :ta)

        sections.each do |section|
          generate_section_schedule(section)
        end
      end
    end

    @errors.empty?
  rescue => e
    @errors << "Transaction failed: #{e.message}"
    Rails.logger.error("Schedule generation failed: #{e.class}: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))
    false
  end

  def generate_section_schedule(section)
    students = section.students.active.includes(:constraints, :exam_slots)

    # Assign cohorts if not already assigned
    assign_cohorts(students, section)

    # Generate slots for each exam (starting from @start_exam)
    (@start_exam..@total_exams).each do |exam_number|
      generate_exam_slots(section, students, exam_number)
    end
  end

  def regenerate_student_schedule(student_id)
    student = Student.find(student_id)
    section = student.section

    ActiveRecord::Base.transaction do
      # Mark existing unlocked slots as unscheduled but keep them (to maintain gaps)
      # Don't touch locked slots - they've already been sent to students
      # Only affect slots from @start_exam onwards
      student.exam_slots.where(is_locked: false).where("exam_number >= ?", @start_exam).update_all(is_scheduled: false)

      # Generate new slots only for unlocked exams (starting from @start_exam)
      (@start_exam..@total_exams).each do |exam_number|
        # Skip if this exam slot is locked
        existing_slot = student.exam_slots.find_by(exam_number: exam_number)
        next if existing_slot && existing_slot.is_locked

        generate_single_student_slot(student, section, exam_number)
      end
    end

    true
  rescue => e
    @errors << "Error regenerating schedule: #{e.message}"
    false
  end

  private

  def generate_balanced_ta_schedules
    # Get all active students and sections
    all_students = Student.active.includes(:constraints, :exam_slots, :section)
    sections_with_tas = Section.active.includes(:ta).where.not(ta_id: nil)

    if sections_with_tas.empty?
      @errors << "No sections with assigned TAs found. Cannot generate balanced schedule."
      return
    end

    # Assign cohorts to students who don't have one (respecting constraints)
    assign_balanced_cohorts(all_students)

    # Group students by cohort
    odd_students = all_students.select { |s| s.cohort == "odd" }
    even_students = all_students.select { |s| s.cohort == "even" }

    # Distribute students across TAs for each exam (starting from @start_exam)
    (@start_exam..@total_exams).each do |exam_number|
      # Calculate which weeks this exam falls on
      base_week = (exam_number - 1) * 2 + 1
      odd_week = base_week
      even_week = base_week + 1

      # Distribute odd week students across all TAs
      distribute_students_to_tas(odd_students, sections_with_tas, exam_number, odd_week)

      # Distribute even week students across all TAs
      distribute_students_to_tas(even_students, sections_with_tas, exam_number, even_week)
    end
  end

  def assign_balanced_cohorts(students)
    # First, handle students with week_preference constraints
    students.each do |student|
      week_constraint = student.constraints.active.find_by(constraint_type: "week_preference")
      if week_constraint
        if student.cohort != week_constraint.constraint_value
          student.update!(cohort: week_constraint.constraint_value)
        end
      end
    end

    # Then handle students without cohort assignment
    # Distribute evenly across odd/even
    unassigned = students.select { |s| s.cohort.nil? }
    return if unassigned.empty?

    shuffled = unassigned.shuffle
    shuffled.each_with_index do |student, index|
      cohort = index.even? ? "odd" : "even"
      student.update!(cohort: cohort)
    end
  end

  def distribute_students_to_tas(students, sections, exam_number, week_number)
    return if students.empty? || sections.empty?

    exam_date = calculate_exam_date(week_number)

    # Prioritize students with time constraints first, shuffling within each priority group
    ordered_students = prioritize_constrained_students(students, exam_number * 100 + week_number)

    # Round-robin distribute students across sections
    section_index = 0
    section_assignments = Hash.new { |h, k| h[k] = [] }

    ordered_students.each do |student|
      section = sections[section_index % sections.size]
      section_assignments[section] << student
      section_index += 1
    end

    # Schedule each section's assigned students
    section_assignments.each do |section, assigned_students|
      schedule_students_for_section(section, assigned_students, exam_number, week_number, exam_date)
    end
  end

  def schedule_students_for_section(section, students, exam_number, week_number, exam_date)
    current_time = @exam_start_time.dup

    # Prioritize students with time constraints first, shuffling within each priority group
    # Use deterministic seed for reproducibility
    ordered_students = prioritize_constrained_students(students, section.id * 1000 + exam_number * 100 + week_number)

    ordered_students.each do |student|
      # Check if student already has a slot for this exam
      existing_slot = student.exam_slots.find_by(exam_number: exam_number)

      # Skip if slot is locked (already sent to student)
      if existing_slot && existing_slot.is_locked
        if existing_slot.is_scheduled && existing_slot.end_time
          current_time = [ current_time, existing_slot.end_time + (@exam_buffer_minutes * 60) ].max
        end
        next
      end

      # Skip if constraints indicate this slot should remain unscheduled
      if existing_slot && !existing_slot.is_scheduled
        next
      end

      # Calculate slot end time first so we can check constraints against it
      slot_end_time = current_time + (@exam_duration_minutes * 60)

      # Check if we have time remaining
      if slot_end_time > @exam_end_time
        Rails.logger.debug("Student #{student.full_name} unscheduled: no time remaining (end=#{slot_end_time.strftime('%H:%M')}, max=#{@exam_end_time.strftime('%H:%M')})")
        create_unscheduled_slot(student, section, exam_number, week_number)
        next
      end

      # Check constraints (pass both start and end time)
      unless can_schedule_student(student, exam_date, current_time, slot_end_time)
        Rails.logger.debug("Student #{student.full_name} unscheduled: constraint violation (start=#{current_time.strftime('%H:%M')}, end=#{slot_end_time.strftime('%H:%M')})")
        create_unscheduled_slot(student, section, exam_number, week_number)
        next
      end

      # Create or update the slot
      slot = ExamSlot.find_or_initialize_by(
        student: student,
        exam_number: exam_number
      )

      slot.assign_attributes(
        section: section,
        week_number: week_number,
        date: exam_date,
        start_time: current_time,
        end_time: slot_end_time,
        is_scheduled: true
      )

      if slot.save
        @generated_count += 1
      else
        @errors << "Error creating slot for #{student.full_name}: #{slot.errors.full_messages.join(', ')}"
      end

      # Advance time for next student
      current_time = slot_end_time + (@exam_buffer_minutes * 60)
    end
  end

  def load_config
    @exam_day = SystemConfig.get(SystemConfig::EXAM_DAY, "friday")

    # Parse time strings (format: "HH:MM") into Time objects for today
    start_time_str = SystemConfig.get(SystemConfig::EXAM_START_TIME, "13:30")
    end_time_str = SystemConfig.get(SystemConfig::EXAM_END_TIME, "14:50")
    @exam_start_time = Time.parse("2000-01-01 #{start_time_str}")
    @exam_end_time = Time.parse("2000-01-01 #{end_time_str}")

    @exam_duration_minutes = SystemConfig.get(SystemConfig::EXAM_DURATION_MINUTES, 7)
    @exam_buffer_minutes = SystemConfig.get(SystemConfig::EXAM_BUFFER_MINUTES, 1)

    quarter_start = SystemConfig.get(SystemConfig::QUARTER_START_DATE, Date.today.to_s)
    @quarter_start_date = quarter_start.is_a?(Date) ? quarter_start : Date.parse(quarter_start.to_s)

    @total_exams = SystemConfig.get(SystemConfig::TOTAL_EXAMS, 5)

    # Load configured exam dates for overrides
    @exam_dates = SystemConfig.get("exam_dates", {})
  end

  def assign_cohorts(students, section)
    # First, handle all students with week_preference constraints
    # This overrides any existing cohort assignment
    students.each do |student|
      week_constraint = student.constraints.active.find_by(constraint_type: "week_preference")
      if week_constraint
        # Update cohort if it doesn't match the constraint
        if student.cohort != week_constraint.constraint_value
          student.update!(cohort: week_constraint.constraint_value)
        end
      end
    end

    # Then handle students without cohort assignment
    unassigned = students.select { |s| s.cohort.nil? }
    return if unassigned.empty?

    # Randomly assign remaining students to odd/even
    shuffled = unassigned.shuffle
    shuffled.each_with_index do |student, index|
      cohort = index.even? ? "odd" : "even"
      student.update!(cohort: cohort)
    end
  end

  def generate_exam_slots(section, students, exam_number)
    # Calculate which weeks this exam falls on
    base_week = (exam_number - 1) * 2 + 1
    odd_week = base_week
    even_week = base_week + 1

    # Separate students by cohort
    odd_students = students.select { |s| s.cohort == "odd" }
    even_students = students.select { |s| s.cohort == "even" }

    # Generate slots for odd week
    generate_week_slots(section, odd_students, exam_number, odd_week)

    # Generate slots for even week
    generate_week_slots(section, even_students, exam_number, even_week)
  end

  def generate_week_slots(section, students, exam_number, week_number)
    exam_date = calculate_exam_date(week_number)
    current_time = @exam_start_time.dup

    # Prioritize students with time constraints first, shuffling within each priority group
    ordered_students = prioritize_constrained_students(students, exam_number + week_number)

    ordered_students.each do |student|
      # Check if student already has a slot for this exam
      existing_slot = student.exam_slots.find_by(exam_number: exam_number)

      # Skip if slot is locked (already sent to student)
      # But still advance time to avoid overlaps
      if existing_slot && existing_slot.is_locked
        if existing_slot.is_scheduled && existing_slot.end_time
          # Advance past the locked slot's time
          current_time = [ current_time, existing_slot.end_time + (@exam_buffer_minutes * 60) ].max
        end
        next
      end

      # Skip if constraints indicate this slot should remain unscheduled
      if existing_slot && !existing_slot.is_scheduled
        next
      end

      # Calculate slot end time first so we can check constraints against it
      slot_end_time = current_time + (@exam_duration_minutes * 60)

      # Check if we have time remaining
      if slot_end_time > @exam_end_time
        Rails.logger.debug("Student #{student.full_name} unscheduled: no time remaining (end=#{slot_end_time.strftime('%H:%M')}, max=#{@exam_end_time.strftime('%H:%M')})")
        create_unscheduled_slot(student, section, exam_number, week_number)
        next
      end

      # Check constraints (pass both start and end time)
      unless can_schedule_student(student, exam_date, current_time, slot_end_time)
        Rails.logger.debug("Student #{student.full_name} unscheduled: constraint violation (start=#{current_time.strftime('%H:%M')}, end=#{slot_end_time.strftime('%H:%M')})")
        create_unscheduled_slot(student, section, exam_number, week_number)
        next
      end

      # Create or update the slot
      slot = ExamSlot.find_or_initialize_by(
        student: student,
        exam_number: exam_number
      )

      slot.assign_attributes(
        section: section,
        week_number: week_number,
        date: exam_date,
        start_time: current_time,
        end_time: slot_end_time,
        is_scheduled: true
      )

      if slot.save
        @generated_count += 1
      else
        @errors << "Error creating slot for #{student.full_name}: #{slot.errors.full_messages.join(', ')}"
      end

      # Advance time for next student
      current_time = slot_end_time + (@exam_buffer_minutes * 60)
    end
  end

  def generate_single_student_slot(student, section, exam_number)
    # Determine which week based on cohort
    base_week = (exam_number - 1) * 2 + 1
    week_number = student.cohort == "odd" ? base_week : base_week + 1

    exam_date = calculate_exam_date(week_number)

    # Find available time slot
    existing_slots = ExamSlot.where(
      section: section,
      exam_number: exam_number,
      week_number: week_number,
      is_scheduled: true
    ).order(:start_time)

    # Try to find a gap or append to end
    current_time = @exam_start_time.dup

    existing_slots.each do |slot|
      gap_start = current_time
      gap_end = slot.start_time

      if (gap_end - gap_start) >= (@exam_duration_minutes + @exam_buffer_minutes) * 60
        # Found a gap, use it
        slot_end_time = gap_start + (@exam_duration_minutes * 60)

        if can_schedule_student(student, exam_date, gap_start, slot_end_time)
          create_slot(student, section, exam_number, week_number, exam_date, gap_start, slot_end_time)
          return true
        end
      end

      current_time = slot.end_time + (@exam_buffer_minutes * 60)
    end

    # No gap found, try to append at end
    slot_end_time = current_time + (@exam_duration_minutes * 60)
    if slot_end_time <= @exam_end_time && can_schedule_student(student, exam_date, current_time, slot_end_time)
      create_slot(student, section, exam_number, week_number, exam_date, current_time, slot_end_time)
      return true
    end

    # Cannot schedule, create unscheduled slot
    create_unscheduled_slot(student, section, exam_number, week_number)
    false
  end

  def calculate_exam_date(week_number)
    # First, check if there's a configured date override for this week
    configured_date = get_configured_exam_date(week_number)
    return configured_date if configured_date

    # Fall back to calculated date based on quarter start and exam day
    target_day = day_name_to_wday(@exam_day)
    current_date = @quarter_start_date

    # Advance to first occurrence of exam_day
    until current_date.wday == target_day
      current_date += 1
    end

    # Advance to target week
    current_date + ((week_number - 1) * 7)
  end

  def get_configured_exam_date(week_number)
    return nil if @exam_dates.blank?

    # Determine exam number and cohort from week_number
    # Week 1 = Exam 1 odd, Week 2 = Exam 1 even
    # Week 3 = Exam 2 odd, Week 4 = Exam 2 even, etc.
    exam_number = ((week_number - 1) / 2) + 1
    cohort = week_number.odd? ? "odd" : "even"

    # Look up configured date
    key = "#{exam_number}_#{cohort}"
    date_str = @exam_dates[key]

    return nil if date_str.blank?

    # Parse and return the date
    Date.parse(date_str.to_s)
  rescue ArgumentError => e
    Rails.logger.error("Error parsing configured exam date for #{key}: #{e.message}")
    nil
  end

  # Maps a given date to its corresponding week number in the exam schedule.
  # 
  # Parameters:
  #   date (Date): The date to map. Should be a Date object, and should be on or after
  #                the first occurrence of @exam_day after @quarter_start_date.
  #
  # Returns:
  #   Integer: The week number (starting from 1) corresponding to the exam schedule.
  #
  # Relationship:
  #   This method is the inverse of `calculate_exam_date`, which maps a week number to its exam date.
  #   The calculation is based on the first occurrence of @exam_day after @quarter_start_date.
  def calculate_week_from_date(date)
    # Calculate what week number this date represents
    # based on quarter start date and exam day
    target_day = day_name_to_wday(@exam_day)
    current_date = @quarter_start_date

    # Find the first occurrence of exam_day after quarter start
    until current_date.wday == target_day
      current_date += 1
    end

    # Validate that the given date falls on the expected exam day
    if date.wday != target_day
      Rails.logger.error("Exam date #{date} does not fall on the expected exam day (#{@exam_day}).")
      return nil
    end
    # Calculate how many weeks from first exam_day to the given date
    days_diff = (date - current_date).to_i
    week_number = (days_diff / 7) + 1

    week_number
  end

  def day_name_to_wday(day_name)
    {
      "sunday" => 0,
      "monday" => 1,
      "tuesday" => 2,
      "wednesday" => 3,
      "thursday" => 4,
      "friday" => 5,
      "saturday" => 6
    }[day_name.downcase] || 5
  end

  def prioritize_constrained_students(students, seed = 0)
    # Group students by constraint priority and shuffle within each group
    # Priority order:
    # 1. Students with time_before constraints (narrowest window at start of day)
    # 2. Students with time_after constraints (narrowest window at end of day)
    # 3. Students with other constraints (date-based)
    # 4. Students without constraints

    groups = {
      time_before: [],
      time_after: [],
      other_constraints: [],
      no_constraints: []
    }

    students.each do |student|
      constraints = student.constraints.to_a # Convert to array to avoid N+1
      has_time_before = constraints.any? { |c| c.constraint_type == "time_before" }
      has_time_after = constraints.any? { |c| c.constraint_type == "time_after" }
      has_other_constraints = constraints.any? { |c| c.constraint_type.in?([ "specific_date", "exclude_date" ]) }

      if has_time_before
        groups[:time_before] << student
      elsif has_time_after
        groups[:time_after] << student
      elsif has_other_constraints
        groups[:other_constraints] << student
      else
        groups[:no_constraints] << student
      end
    end

    # Shuffle within each group and concatenate in priority order
    [
      groups[:time_before].shuffle(random: Random.new(seed.hash ^ :time_before.hash)),
      groups[:time_after].shuffle(random: Random.new(seed.hash ^ :time_after.hash)),
      groups[:other_constraints].shuffle(random: Random.new(seed.hash ^ :other_constraints.hash)),
      groups[:no_constraints].shuffle(random: Random.new(seed.hash ^ :no_constraints.hash))
    ].flatten
  end

  def can_schedule_student(student, date, start_time, end_time = nil)
    constraints = student.constraints.active

    constraints.each do |constraint|
      case constraint.constraint_type
      when "time_before"
        # Student must be scheduled BEFORE this time (exam should start before this time)
        max_time = Time.parse("2000-01-01 #{constraint.constraint_value}")
        if start_time >= max_time
          Rails.logger.debug("Constraint violation for #{student.full_name}: time_before #{constraint.constraint_value}, start=#{start_time.strftime('%H:%M')}")
          return false
        end
      when "time_after"
        # Student must be scheduled AFTER this time (exam can start after this time)
        min_time = Time.parse("2000-01-01 #{constraint.constraint_value}")
        if start_time < min_time
          Rails.logger.debug("Constraint violation for #{student.full_name}: time_after #{constraint.constraint_value}, start=#{start_time.strftime('%H:%M')}")
          return false
        end
      when "specific_date"
        required_date = Date.parse(constraint.constraint_value)
        if date != required_date
          Rails.logger.debug("Constraint violation for #{student.full_name}: specific_date #{constraint.constraint_value}, actual=#{date}")
          return false
        end
      when "exclude_date"
        excluded_date = Date.parse(constraint.constraint_value)
        if date == excluded_date
          Rails.logger.debug("Constraint violation for #{student.full_name}: exclude_date #{constraint.constraint_value}")
          return false
        end
      end
    end

    Rails.logger.debug("Constraint check passed for #{student.full_name}: start=#{start_time.strftime('%H:%M')}")
    true
  rescue => e
    Rails.logger.error("Error checking constraints for student #{student.id}: #{e.message}")
    Rails.logger.error(e.backtrace.first(5).join("\n"))
    true # Default to allowing if error
  end

  def create_slot(student, section, exam_number, week_number, date, start_time, end_time)
    # Clean up any duplicate slots first (shouldn't happen with unique constraint, but defensive)
    duplicates = ExamSlot.where(student_id: student.id, exam_number: exam_number)
    if duplicates.count > 1
      Rails.logger.warn("Found #{duplicates.count} duplicate slots for student #{student.id}, exam #{exam_number}. Keeping oldest.")
      # Keep the oldest one (by ID), delete the rest
      oldest = duplicates.order(:id).first
      duplicates.where.not(id: oldest.id).destroy_all
    end

    slot = ExamSlot.find_or_initialize_by(
      student: student,
      exam_number: exam_number
    )

    # Don't overwrite locked slots
    return false if slot.is_locked

    slot.assign_attributes(
      section: section,
      week_number: week_number,
      date: date,
      start_time: start_time,
      end_time: end_time,
      is_scheduled: true
    )

    slot.save!
    @generated_count += 1
  end

  def create_unscheduled_slot(student, section, exam_number, week_number)
    # Clean up any duplicate slots first (shouldn't happen with unique constraint, but defensive)
    duplicates = ExamSlot.where(student_id: student.id, exam_number: exam_number)
    if duplicates.count > 1
      Rails.logger.warn("Found #{duplicates.count} duplicate slots for student #{student.id}, exam #{exam_number}. Keeping oldest.")
      oldest = duplicates.order(:id).first
      duplicates.where.not(id: oldest.id).destroy_all
    end

    slot = ExamSlot.find_or_initialize_by(
      student: student,
      exam_number: exam_number
    )

    # Don't overwrite locked slots
    return false if slot.is_locked

    slot.assign_attributes(
      section: section,
      week_number: week_number,
      is_scheduled: false
    )

    slot.save
  end
end
