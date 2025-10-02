Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
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

      # Students
      resources :students, only: [ :index, :show, :update ] do
        collection do
          delete "clear_all", to: "students#clear_all"
        end
        member do
          put "deactivate", to: "students#deactivate"
        end
      end

      # Constraints
      resources :constraints, only: [ :index, :create, :update, :destroy ]

      # Schedules
      post "schedules/generate", to: "schedules#generate"
      delete "schedules/clear", to: "schedules#clear"
      post "schedules/regenerate_student/:student_id", to: "schedules#regenerate_student"
      get "schedules/overview", to: "schedules#overview"

      # Exam Slot Histories
      get "students/:student_id/exam_slots/:exam_number/histories", to: "exam_slot_histories#index"
      post "students/:student_id/exam_slots/:exam_number/histories/:id/revert", to: "exam_slot_histories#revert"

      # System configuration
      get "config", to: "config#index"
      put "config", to: "config#update"
    end

    # TA routes
    namespace :ta do
      # Schedules
      get "schedules", to: "schedules#index"

      # Recordings
      post "recordings", to: "recordings#create"
      post "recordings/:id/upload", to: "recordings#upload"
    end
  end

  # Serve React app (all non-API routes)
  get "*path", to: "application#index", constraints: ->(req) { !req.xhr? && req.path !~ /\.\w+$/ }
  root "application#index"
end
