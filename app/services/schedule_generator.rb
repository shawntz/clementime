class ScheduleGenerator
  attr_reader :errors, :generated_count

  def initialize(options = {})
    @options = options
    @errors = []
    @generated_count = 0
    @start_exam = options[:start_exam] || 1  # Default to exam 1, or start from specified exam
    load_config
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

    # Assign week groups if not already assigned
    assign_week_groups(students, section)

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

    # Assign week groups to students who don't have one (respecting constraints)
    assign_balanced_week_groups(all_students)

    # Group students by week_group
    odd_students = all_students.select { |s| s.week_group == "odd" }
    even_students = all_students.select { |s| s.week_group == "even" }

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

  def assign_balanced_week_groups(students)
    # First, handle students with week_preference constraints
    students.each do |student|
      week_constraint = student.constraints.active.find_by(constraint_type: "week_preference")
      if week_constraint
        if student.week_group != week_constraint.constraint_value
          student.update!(week_group: week_constraint.constraint_value)
        end
      end
    end

    # Then handle students without week_group assignment
    # Distribute evenly across odd/even
    unassigned = students.select { |s| s.week_group.nil? }
    return if unassigned.empty?

    shuffled = unassigned.shuffle
    shuffled.each_with_index do |student, index|
      week_group = index.even? ? "odd" : "even"
      student.update!(week_group: week_group)
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
  end

  def assign_week_groups(students, section)
    # First, handle all students with week_preference constraints
    # This overrides any existing week_group assignment
    students.each do |student|
      week_constraint = student.constraints.active.find_by(constraint_type: "week_preference")
      if week_constraint
        # Update week group if it doesn't match the constraint
        if student.week_group != week_constraint.constraint_value
          student.update!(week_group: week_constraint.constraint_value)
        end
      end
    end

    # Then handle students without week_group assignment
    unassigned = students.select { |s| s.week_group.nil? }
    return if unassigned.empty?

    # Randomly assign remaining students to odd/even
    shuffled = unassigned.shuffle
    shuffled.each_with_index do |student, index|
      week_group = index.even? ? "odd" : "even"
      student.update!(week_group: week_group)
    end
  end

  def generate_exam_slots(section, students, exam_number)
    # Calculate which weeks this exam falls on
    base_week = (exam_number - 1) * 2 + 1
    odd_week = base_week
    even_week = base_week + 1

    # Separate students by week group
    odd_students = students.select { |s| s.week_group == "odd" }
    even_students = students.select { |s| s.week_group == "even" }

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
    # Determine which week based on week_group
    base_week = (exam_number - 1) * 2 + 1
    week_number = student.week_group == "odd" ? base_week : base_week + 1

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
    # Find the Nth occurrence of exam_day after quarter start
    target_day = day_name_to_wday(@exam_day)
    current_date = @quarter_start_date

    # Advance to first occurrence of exam_day
    until current_date.wday == target_day
      current_date += 1
    end

    # Advance to target week
    current_date + ((week_number - 1) * 7)
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
