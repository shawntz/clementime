# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create default admin user if none exists
if User.where(role: 'admin').empty?
  User.create!(
    username: 'admin',
    email: 'admin@clementime.app',
    password: 'admin123',
    password_confirmation: 'admin123',
    role: 'admin',
    first_name: 'Admin',
    last_name: 'User',
    must_change_password: true
  )
  puts "Created default admin user (username: admin, password: admin123)"
end
