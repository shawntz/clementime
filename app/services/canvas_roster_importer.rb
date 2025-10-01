require 'csv'

class CanvasRosterImporter
  attr_reader :errors, :success_count, :sections_created

  def initialize(file_path_or_content)
    @file_path_or_content = file_path_or_content
    @errors = []
    @success_count = 0
    @sections_created = []
  end

  def import
    csv_data = load_csv_data
    return false unless csv_data

    ActiveRecord::Base.transaction do
      csv_data.each_with_index do |row, index|
        next if index < 3 # Skip header rows

        process_student_row(row, index + 1)
      rescue => e
        @errors << "Row #{index + 1}: #{e.message}"
        raise ActiveRecord::Rollback
      end
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

    # Parse section codes
    section_codes = parse_section_codes(student_data[:section_raw])
    return if section_codes.empty?

    # Filter out lecture sections (-01), we only care about discussion sections
    discussion_codes = section_codes.reject { |code| code.end_with?('-01') }

    # If only enrolled in lecture (no discussion), skip this student
    return if discussion_codes.empty?

    # Create or find sections
    sections = ensure_sections_exist(discussion_codes)
    primary_section = sections.first

    # Create or update student
    student = Student.find_or_initialize_by(sis_user_id: student_data[:sis_user_id])
    student.assign_attributes(
      canvas_id: student_data[:canvas_id],
      sis_login_id: student_data[:sis_login_id],
      email: student_data[:email],
      full_name: student_data[:full_name],
      section: primary_section
    )

    if student.save
      @success_count += 1
    else
      @errors << "Row #{row_number}: #{student.errors.full_messages.join(', ')}"
    end
  end

  def extract_student_data(row)
    {
      full_name: row[0].to_s.strip,
      canvas_id: row[1].to_s.strip,
      sis_user_id: row[2].to_s.strip,
      sis_login_id: row[3].to_s.strip,
      section_raw: row[4].to_s.strip,
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
    parts = code.split('-')
    return code unless parts.length >= 4

    term = parts[0]
    course = parts[1]
    number = parts[2]
    section = parts[3]

    # Normalize section number (remove leading zeros)
    section_num = section.to_i.to_s.rjust(2, '0')

    # Always use PSYCH-10 as the canonical code
    "#{term}-PSYCH-10-#{section_num}"
  end

  def generate_section_name(code)
    # Parse code like "F25-STATS-60-02" into "Section 2"
    # Strip leading zeros from section numbers
    parts = code.split('-')
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
