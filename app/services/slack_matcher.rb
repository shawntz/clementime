require "csv"
require "fuzzy_match"

class SlackMatcher
  attr_reader :errors, :matched_count, :slack_users

  def initialize(file_path_or_content)
    @file_path_or_content = file_path_or_content
    @errors = []
    @matched_count = 0
    @slack_users = []
  end

  def load_slack_users
    csv_data = load_csv_data
    return false unless csv_data

    # Validate CSV format before processing
    return false unless validate_csv_format(csv_data)

    # Skip header row
    csv_data.each_with_index do |row, index|
      next if index == 0
      next if row[0].blank?

      @slack_users << {
        username: row[0].to_s.strip,
        email: row[1].to_s.strip.downcase,
        status: row[2].to_s.strip,
        userid: row[5].to_s.strip,
        fullname: row[6].to_s.strip,
        displayname: row[7].to_s.strip
      }
    rescue => e
      @errors << "Row #{index + 1}: #{e.message}"
    end

    # Filter out bots and deactivated users
    @slack_users.reject! { |u| u[:status] == "Bot" || u[:status] == "Deactivated" }

    @errors.empty?
  end

  def auto_match_by_email
    return false if @slack_users.empty?

    begin
      students = Student.all.includes(:section)
      Rails.logger.info "Auto-matching #{students.count} students with #{@slack_users.count} Slack users"
    rescue => e
      Rails.logger.error "Error loading students: #{e.class} - #{e.message}"
      @errors << "Database error loading students: #{e.message}"
      return false
    end

    students.each do |student|
      slack_user = @slack_users.find { |u| u[:email].downcase == student.email.downcase }

      if slack_user
        student.update!(
          slack_user_id: slack_user[:userid],
          slack_username: slack_user[:username],
          slack_matched: true
        )
        @matched_count += 1
      end
    rescue => e
      Rails.logger.error "Error matching student #{student.id} (#{student.full_name}): #{e.class} - #{e.message}"
      @errors << "Error matching student #{student.full_name}: #{e.message}"
    end

    true
  end

  def fuzzy_match_unmatched
    unmatched_students = Student.where(slack_matched: false)

    # Create fuzzy matcher on Slack emails
    slack_emails = @slack_users.map { |u| u[:email] }
    matcher = FuzzyMatch.new(slack_emails)

    unmatched_students.each do |student|
      best_match = matcher.find(student.email)

      if best_match
        slack_user = @slack_users.find { |u| u[:email] == best_match }
        if slack_user
          student.update!(
            slack_user_id: slack_user[:userid],
            slack_username: slack_user[:username],
            slack_matched: false # Keep as false so admin can verify
          )
        end
      end
    rescue => e
      @errors << "Error fuzzy matching #{student.full_name}: #{e.message}"
    end

    true
  end

  def get_unmatched_students
    Student.slack_unmatched.includes(:section).map do |student|
      {
        id: student.id,
        full_name: student.full_name,
        email: student.email,
        section: student.section&.code || "N/A",
        suggested_match: find_suggestion(student),
        slack_user_id: student.slack_user_id,
        slack_username: student.slack_username
      }
    end
  end

  def manual_match(student_id, slack_user_id)
    student = Student.find(student_id)
    slack_user = @slack_users.find { |u| u[:userid] == slack_user_id }

    return false unless slack_user

    student.update!(
      slack_user_id: slack_user[:userid],
      slack_username: slack_user[:username],
      slack_matched: true
    )

    true
  rescue => e
    @errors << "Error manually matching: #{e.message}"
    false
  end

  def searchable_slack_users
    @slack_users.map do |user|
      {
        value: user[:userid],
        label: "#{user[:fullname] || user[:displayname]} (#{user[:email]})",
        email: user[:email],
        username: user[:username]
      }
    end.sort_by { |u| u[:label] }
  end

  private

  def validate_csv_format(csv_data)
    # Check if CSV has at least 2 rows (header + 1 data row)
    if csv_data.length < 2
      @errors << "Invalid CSV format: File must have at least 2 rows (1 header row + 1 data row)"
      @errors << "Expected Slack member list CSV format exported from Slack workspace admin panel."
      return false
    end

    # Check if CSV has enough columns by examining the header row
    header_row = csv_data[0]
    if header_row.nil? || header_row.length < 8
      @errors << "Invalid CSV format: Each row must have at least 8 columns"
      @errors << "Expected Slack member list CSV format with the following columns:"
      @errors << "  Column 1: username"
      @errors << "  Column 2: email"
      @errors << "  Column 3: status"
      @errors << "  Column 6: user id"
      @errors << "  Column 7: full name"
      @errors << "  Column 8: display name"
      @errors << ""
      @errors << "To export this file:"
      @errors << "  1. Go to your Slack workspace admin panel (e.g., yourworkspace.slack.com/admin)"
      @errors << "  2. Click 'Manage members'"
      @errors << "  3. Click 'Export full member list'"
      return false
    end

    true
  end

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
    @errors << "Please ensure the file is a valid CSV file exported from Slack workspace admin panel."
    nil
  end

  def find_suggestion(student)
    # Try to find best fuzzy match
    slack_emails = @slack_users.map { |u| u[:email] }
    matcher = FuzzyMatch.new(slack_emails)
    best_match_email = matcher.find(student.email)

    return nil unless best_match_email

    slack_user = @slack_users.find { |u| u[:email] == best_match_email }
    return nil unless slack_user

    {
      userid: slack_user[:userid],
      username: slack_user[:username],
      email: slack_user[:email],
      fullname: slack_user[:fullname] || slack_user[:displayname]
    }
  end
end
