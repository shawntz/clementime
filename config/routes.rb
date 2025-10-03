Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    # Version
    get "version", to: "version#show"

    # Authentication
    post "auth/login", to: "auth#login"
    post "auth/logout", to: "auth#logout"
    post "auth/change_password", to: "auth#change_password"
    get "auth/current_user", to: "auth#current_user"

    # Profile
    get "profile", to: "profile#show"
    put "profile", to: "profile#update"
    put "profile/password", to: "profile#update_password"

    # Admin routes
    namespace :admin do
      # Canvas roster
      post "canvas/upload", to: "canvas#upload"

      # Slack roster and matching
      post "slack/upload", to: "slack#upload"
      get "slack/unmatched", to: "slack#unmatched"
      put "slack/match/:student_id", to: "slack#match"

      # Users (TAs)
      resources :users, only: [ :index, :show, :create, :update, :destroy ] do
        member do
          post "send_welcome_email", to: "users#send_welcome_email"
          post "send_slack_credentials", to: "users#send_slack_credentials"
        end
      end

      # Sections
      resources :sections, only: [ :index, :show, :create, :update ] do
        member do
          put "assign_ta", to: "sections#assign_ta"
          get "time_slots", to: "sections#time_slots"
        end
      end

      # Exam Slots
      put "exam_slots/:id/update_time", to: "exam_slots#update_time"
      post "exam_slots/:id/manual_schedule", to: "exam_slots#manual_schedule"
      post "exam_slots/swap", to: "exam_slots#swap_slots"
      post "exam_slots/:id/unlock", to: "exam_slots#unlock"
      post "exam_slots/bulk_unlock", to: "exam_slots#bulk_unlock"

      # Students
      resources :students, only: [ :index, :show, :update ] do
        collection do
          delete "clear_all", to: "students#clear_all"
          get "export_by_section", to: "students#export_by_section"
        end
        member do
          put "deactivate", to: "students#deactivate"
          post "transfer_week_group", to: "students#transfer_week_group"
        end
      end

      # Constraints
      resources :constraints, only: [ :index, :create, :update, :destroy ]

      # Schedules
      post "schedules/generate", to: "schedules#generate"
      delete "schedules/clear", to: "schedules#clear"
      post "schedules/regenerate_student/:student_id", to: "schedules#regenerate_student"
      get "schedules/overview", to: "schedules#overview"
      get "schedules/export_csv", to: "schedules#export_csv"

      # Exam Slot Histories
      get "students/:student_id/exam_slots/:exam_number/histories", to: "exam_slot_histories#index"
      post "students/:student_id/exam_slots/:exam_number/histories/:id/revert", to: "exam_slot_histories#revert"

      # System configuration
      get "config", to: "config#index"
      put "config", to: "config#update"
      post "config/test_google_drive", to: "config#test_google_drive"

      # Slack messages
      post "slack_messages/send_ta_schedules", to: "slack_messages#send_ta_schedules"
      post "slack_messages/send_student_schedules", to: "slack_messages#send_student_schedules"
      post "slack_messages/test_recording", to: "slack_messages#test_recording"
      post "slack_messages/test_message", to: "slack_messages#test_message"
    end

    # TA routes
    namespace :ta do
      # Configuration (public values only)
      get "config", to: "config#index"

      # Schedules
      get "schedules", to: "schedules#index"

      # Students (read-only, limited to TA's sections)
      get "students", to: "students#index"
      get "students/export_by_section", to: "students#export_by_section"

      # Sections (read-only, limited to TA's sections)
      get "sections", to: "sections#index"

      # Recordings
      post "recordings", to: "recordings#create"
      post "recordings/:id/upload", to: "recordings#upload"
      post "recordings/test", to: "recordings#test"
    end
  end

  # Serve React app (all non-API routes)
  get "*path", to: "application#index", constraints: ->(req) { !req.xhr? && req.path !~ /\.\w+$/ }
  root "application#index"
end
