#!/usr/bin/env ruby

admin = User.find_or_create_by!(username: 'test_admin') do |u|
  u.email = 'admin@test.com'
  u.password = 'testpassword123'
  u.role = 'admin'
  u.first_name = 'Test'
  u.last_name = 'Admin'
end

puts "Admin user created/found:"
puts "ID: #{admin.id}"
puts "Username: #{admin.username}"
puts "Role: #{admin.role}"

# Generate a JWT token
require_relative 'app/lib/json_web_token'
token = JsonWebToken.encode(user_id: admin.id)
puts "\nJWT Token:"
puts token
