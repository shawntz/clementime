#!/usr/bin/env ruby
# Test script for debugging Slack endpoints

# Test 1: Check if Student.slack_unmatched works
puts "=" * 60
puts "Test 1: Student.slack_unmatched scope"
puts "=" * 60

begin
  students = Student.slack_unmatched.includes(:section)
  puts "✓ Successfully queried #{students.count} unmatched students"

  students.first(3).each do |student|
    puts "  - #{student.full_name} (section: #{student.section&.code || 'N/A'})"
  end
rescue => e
  puts "✗ Error: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end

# Test 2: Check if section can be nil
puts "\n" + "=" * 60
puts "Test 2: Students with nil sections"
puts "=" * 60

begin
  students_without_sections = Student.where(section_id: nil).count
  puts "Students without sections: #{students_without_sections}"
rescue => e
  puts "✗ Error: #{e.message}"
end

# Test 3: Check Rails cache
puts "\n" + "=" * 60
puts "Test 3: Rails cache availability"
puts "=" * 60

begin
  # Get first admin user
  admin = User.where(role: 'admin').first
  if admin
    cached_users = Rails.cache.read("slack_users_#{admin.id}")
    if cached_users
      puts "✓ Found #{cached_users.count} cached Slack users for admin #{admin.username}"
    else
      puts "⚠ No cached Slack users found for admin #{admin.username}"
    end
  else
    puts "⚠ No admin users found in database"
  end
rescue => e
  puts "✗ Error: #{e.message}"
end

# Test 4: Test the full unmatched endpoint logic
puts "\n" + "=" * 60
puts "Test 4: Full unmatched endpoint logic"
puts "=" * 60

begin
  students = Student.slack_unmatched.includes(:section).map do |student|
    {
      id: student.id,
      full_name: student.full_name,
      email: student.email,
      section: student.section&.code || "N/A",
      slack_user_id: student.slack_user_id,
      slack_username: student.slack_username
    }
  end

  puts "✓ Successfully mapped #{students.count} students"
  puts "First student: #{students.first.inspect}" if students.any?
rescue => e
  puts "✗ Error: #{e.message}"
  puts e.backtrace.first(10).join("\n")
end

puts "\n" + "=" * 60
puts "Tests completed"
puts "=" * 60
