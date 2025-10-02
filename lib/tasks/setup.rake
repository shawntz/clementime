namespace :setup do
  desc "Create default admin user"
  task create_admin: :environment do
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
      puts "✓ Created admin user (username: admin, password: admin123)"
    else
      puts "✓ Admin user already exists"
    end
  end
end
