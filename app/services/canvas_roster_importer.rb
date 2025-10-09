require "csv"

class CanvasRosterImporter
  attr_reader :errors, :success_count, :sections_created, :added_count, :dropped_count, :updated_count

  def initialize(file_path_or_content)
    @file_path_or_content = file_path_or_content
    @errors = []
    @success_count = 0
    @sections_created = []
    @added_count = 0
    @dropped_count = 0
    @updated_count = 0
    @processed_student_ids = Set.new
  end

  def import
    csv_data = load_csv_data
    return false unless csv_data

    ActiveRecord::Base.transaction do
      # Get all currently active student IDs before processing
      @existing_student_ids = Student.where(is_active: true).pluck(:sis_user_id).to_set

      csv_data.each_with_index do |row, index|
        next if index < 3 # Skip header rows

        process_student_row(row, index + 1)
      rescue => e
        @errors << "Row #{index + 1}: #{e.message}"
        raise ActiveRecord::Rollback
      end

      # Handle students who dropped (not in new roster)
      handle_dropped_students
    end

    @errors.empty?
  end

  private

  def load_csv_data
    if @file_path_or_content.is_a?(String) && File.exist?(@file_path_or_content)
      CSV.read(@file_path_or_content, headers: false)
    elsif @file_path_or_content.respond_to?(:read)
      CSV.parse(@file_path_or_content.read, headers: false)
    else
      CSV.parse(@file_path_or_content.to_s, headers: false)
    end
  rescue => e
    @errors << "CSV parsing error: #{e.message}"
    nil
  end

  def process_student_row(row, row_number)
    return if row[0].blank? # Skip empty rows

    student_data = extract_student_data(row)
    return if student_data[:sis_user_id].blank?

    # Skip students with blank or invalid SU ID (not actively enrolled)
    return if student_data[:su_id].blank? || !student_data[:su_id].match?(/^\d+$/)

    # Parse section codes
    section_codes = parse_section_codes(student_data[:section_raw])
    return if section_codes.empty?

    # Filter out lecture sections (-01), we only care about discussion sections
    discussion_codes = section_codes.reject { |code| code.end_with?("-01") }

    # If only enrolled in lecture (no discussion), skip this student
    return if discussion_codes.empty?

    # Create or find sections
    sections = ensure_sections_exist(discussion_codes)
    primary_section = sections.first

    # Create or update student
    student = Student.find_or_initialize_by(sis_user_id: student_data[:sis_user_id])
    is_new_student = student.new_record?
    was_inactive = !student.is_active if student.persisted?

    # Build attributes hash
    attributes = {
      canvas_id: student_data[:canvas_id],
      sis_login_id: student_data[:sis_login_id],
      email: student_data[:email],
      full_name: student_data[:full_name],
      is_active: true  # Ensure student is active when in roster
    }

    # Only update section if not manually overridden
    unless student.section_override
      attributes[:section] = primary_section
    end

    student.assign_attributes(attributes)

    if student.save
      @success_count += 1
      @processed_student_ids << student.sis_user_id

      # Track what happened
      if is_new_student
        @added_count += 1
      elsif was_inactive
        @added_count += 1  # Reactivated student counts as added
      else
        @updated_count += 1
      end
    else
      @errors << "Row #{row_number}: #{student.errors.full_messages.join(', ')}"
    end
  end

  def handle_dropped_students
    # Find students who were active but not in the new roster
    dropped_student_ids = @existing_student_ids - @processed_student_ids
    return if dropped_student_ids.empty?

    dropped_students = Student.where(sis_user_id: dropped_student_ids, is_active: true)

    dropped_students.each do |student|
      # Check if student has any locked exam slots
      locked_slots = student.exam_slots.where(is_locked: true)
      unlocked_slots = student.exam_slots.where(is_locked: false)

      # Always delete unlocked slots (future exams they won't attend)
      unlocked_slots.destroy_all

      # Mark student as inactive
      student.update!(is_active: false)
      @dropped_count += 1

      # Add warning if they had locked slots that we're keeping
      if locked_slots.any?
        @errors << "Warning: #{student.full_name} (#{student.sis_user_id}) dropped but has #{locked_slots.count} locked exam slots (past exams). These slots are retained. #{unlocked_slots.count} future exam slots were cleared."
      end
    end
  end

  def extract_student_data(row)
    {
      full_name: row[0].to_s.strip,
      canvas_id: row[1].to_s.strip,
      sis_user_id: row[2].to_s.strip,
      sis_login_id: row[3].to_s.strip,
      section_raw: row[4].to_s.strip,
      su_id: row[5].to_s.strip,
      email: "#{row[3].to_s.strip}@stanford.edu" # Construct email from SIS login
    }
  end

  def parse_section_codes(section_string)
    # Handle formats like "F25-STATS-60-01 and F25-STATS-60-04"
    return [] if section_string.blank?

    section_string.split(/\s+and\s+/).map do |code|
      code.strip
    end.reject(&:blank?)
  end

  def ensure_sections_exist(section_codes)
    section_codes.map do |code|
      # Normalize code to always use PSYCH prefix for cross-listed sections
      normalized_code = normalize_section_code(code)

      section = Section.find_or_create_by!(code: normalized_code) do |s|
        s.name = generate_section_name(normalized_code)
        s.is_active = true
      end

      @sections_created << normalized_code unless Section.exists?(code: normalized_code)
      section
    end
  end

  def normalize_section_code(code)
    # Convert F25-STATS-60-XX to F25-PSYCH-10-XX (normalize cross-listed sections)
    # This ensures all students in the same discussion section share one section record
    parts = code.split("-")
    return code unless parts.length >= 4

    term = parts[0]
    course = parts[1]
    number = parts[2]
    section = parts[3]

    # Normalize section number (remove leading zeros)
    section_num = section.to_i.to_s.rjust(2, "0")

    # Always use PSYCH-10 as the canonical code
    "#{term}-PSYCH-10-#{section_num}"
  end

  def generate_section_name(code)
    # Parse code like "F25-STATS-60-02" into "Section 2"
    # Strip leading zeros from section numbers
    parts = code.split("-")
    if parts.length >= 4
      section = parts[3]
      # Strip leading zeros to normalize section numbers (010 -> 10, 02 -> 2)
      section_num = section.to_i.to_s
      "Section #{section_num}"
    else
      code
    end
  end
end
