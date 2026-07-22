Rails.application.routes.draw do
  devise_for :users

  get "up" => "rails/health#show", as: :rails_health_check
  get "/privacy", to: "pages#privacy", as: :privacy
  get "/delete-account", to: "pages#delete_account", as: :delete_account
  get "/manifest.json", to: "pwa#manifest", as: :pwa_manifest, defaults: { format: :json }
  get "/service-worker.js", to: "pwa#service_worker", as: :pwa_service_worker, defaults: { format: :js }
  post "/analytics/events", to: "analytics/events#create", as: :analytics_events, defaults: { format: :json }
  post "/push/subscriptions", to: "push_subscriptions#create", as: :push_subscriptions, defaults: { format: :json }
  delete "/push/subscriptions", to: "push_subscriptions#destroy", defaults: { format: :json }
  resource :password, only: %i[edit update]
  resource :my_pump, only: %i[show update], controller: "my_pumps"

  # JSON API for the native mobile apps (token auth). See docs/native-handoff/11.
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      post "auth/login", to: "auth/sessions#create"
      post "auth/refresh", to: "auth/sessions#refresh"
      delete "auth/logout", to: "auth/sessions#destroy"
      get "auth/me", to: "auth/sessions#me"

      get "theme", to: "theme#show"
      post "loyalty/lookup", to: "loyalty#lookup"

      resource :my_pump, only: %i[show update], controller: "my_pump"
      resource :password, only: :update, controller: "password"

      namespace :staff do
        get "catalog", to: "catalog#show"
        resources :customers, only: %i[index show create update] do
          collection do
            get :lookup
          end
          member do
            get :ledger
            patch :activate
            patch :deactivate
            patch :pause_rewards
            patch :resume_rewards
          end
          resources :vehicles, only: %i[create update destroy]
        end
        post "redemptions", to: "redemptions#create"
        get "transactions/lookup", to: "transactions#lookup"
        post "transactions", to: "transactions#create"
        post "transactions/recognize_plate", to: "transactions#recognize_plate"
        post "transactions/register_customer", to: "transactions#register_customer"
        resources :visit_entries, only: %i[index create]
        # E7 — FSMs can capture a rating at the pump.
        resources :customers, only: [] do
          resources :feedbacks, only: %i[index create], controller: "customer_feedbacks"
        end
        # Declared before the resource so /settlements/new is not captured as
        # /settlements/:id (and to avoid Rails' reserved-`new` collection quirk).
        get "settlements/new", to: "settlements#new", as: :new_settlement
        resources :settlements, only: %i[index show create update]
      end

      namespace :admin do
        post "points_adjustments", to: "points_adjustments#create"
        get "dashboard", to: "dashboard#data"
        # E6 — lost-customer / reach-out list.
        get "dashboard/churn", to: "dashboard#churn"
        get "reports", to: "reports#index"
        get "transactions", to: "transactions#index"
        # E3/E5/E7 — per-customer CRM: insight, outreach log, feedback.
        resources :customers, only: [] do
          member { get :insight }
          resources :contact_logs, only: %i[index create]
          resources :feedbacks, only: %i[index create], controller: "customer_feedbacks"
        end
        resources :users, only: %i[index show create update] do
          member do
            get :kyc_reveal
            delete :kyc, action: :destroy_kyc
          end
        end
        resources :fuel_types, only: %i[index create update destroy]
        resources :vehicle_types, only: %i[index create update destroy]
        resources :products, only: %i[index create update destroy] do
          get :catalog, on: :collection
        end
        resources :fuel_pumps, only: %i[index create update destroy] do
          patch :feature_settings, on: :collection
        end
        resources :settlements, only: %i[index show update] do
          patch :reconcile, on: :member
          get :summary, on: :collection
        end
        get "reward_rates", to: "reward_rates#show"
        match "reward_rates", to: "reward_rates#update", via: %i[patch put]
        get "theme_settings", to: "theme_settings#show"
        match "theme_settings", to: "theme_settings#update", via: %i[patch put]
        resources :staff_members, only: %i[index update destroy] do
          resources :shift_assignments, only: :create
          member do
            get :pump
            patch :pump, action: :update_pump
          end
        end
        resources :shift_templates, only: %i[index create update]
        resources :shift_cycles, only: %i[index create update destroy] do
          member do
            patch :activate
            patch :deactivate
          end
        end
        resources :attendance_runs, only: %i[index new create show destroy] do
          member do
            patch :invalidate
            patch :mark_valid
          end
        end
        resources :schedules, only: %i[index create update destroy] do
          post :send_now, on: :member
        end
        post "schedules/run", to: "schedules#run"
        post "notifications/send", to: "notifications#deliver"
        get "notifications", to: "notifications#index"
        get "notifications/:id/recipients", to: "notifications#recipients"
        resources :campaigns, only: %i[index show create update destroy] do
          member do
            post :preview
            post :run
            patch :activate
            patch :pause
          end
        end
      end
    end
  end

  root "dashboard#show"

  get "/loyalty", to: "loyalty#new", as: :new_loyalty
  post "/loyalty", to: "loyalty#create", as: :loyalty
  get "/loyalty/result", to: "loyalty#show", as: :loyalty_result
  post "/loyalty/opt_in", to: "loyalty#opt_in", as: :loyalty_opt_in

  namespace :staff do
    resource :notifications, only: :show, controller: "notifications"
    resources :customers, only: %i[index new create] do
      get :lookup, on: :collection
      patch :activate, on: :member
      patch :deactivate, on: :member
      patch :pause_rewards, on: :member
      patch :resume_rewards, on: :member
    end
    resources :redemptions, only: %i[new create]
    resources :transactions, only: %i[new create] do
      get :lookup, on: :collection
      post :recognize_plate, on: :collection
      post :register_customer, on: :collection
    end
    resources :visit_entries, only: %i[index new create]
    resources :settlements, only: %i[index new create show edit update]
  end

  namespace :admin do
    resource :dashboard, only: :show, controller: "dashboard" do
      get :data
    end
    resource :notifications, only: :show, controller: "notifications"
    post "notifications/send", to: "notification_deliveries#create", as: :send_notifications
    resources :staff_members, only: %i[index update destroy] do
      resources :shift_assignments, only: :create
      member do
        get :pump
        patch :pump, action: :update_pump
      end
    end
    resources :shift_templates, only: %i[index create update]
    resources :shift_cycles, only: %i[index create update destroy] do
      patch :activate, on: :member
      patch :deactivate, on: :member
    end
    resources :attendance_runs, only: %i[index new create show destroy] do
      patch :invalidate, on: :member
      patch :mark_valid, on: :member
    end
    resources :users, only: %i[index new create show edit update] do
      member do
        post :reveal_aadhaar
        get :id_card_photo
        delete :purge_kyc
      end
    end
    resources :fuel_types, only: %i[index create edit update destroy]
    resources :fuel_pumps, only: %i[index create edit update destroy] do
      patch :feature_settings, on: :collection
    end
    resources :vehicle_types, only: %i[index create edit update destroy]
    resources :products, only: %i[index create edit update destroy]
    resource :fuel_reward_rates, only: %i[show update], controller: "fuel_reward_rates"
    resource :theme_settings, only: %i[show update], controller: "theme_settings"
    resources :schedules, only: %i[index create update destroy] do
      post :send_now, on: :member
    end
    post "schedules/run", to: "schedules#run", as: :run_schedules
    resources :customers, only: %i[index show new create edit update destroy] do
      get :points_ledger, on: :member
      get :transaction_history, on: :member
      # E5 outreach log + E7 feedback capture (server-rendered).
      resources :contact_logs, only: :create
      resources :feedbacks, only: :create
    end
    resources :transactions, only: :index
    resources :reports, only: :index
    # E6 — lost-customer / reach-out list.
    resources :reach_out, only: :index, controller: "reach_out"
    resources :campaigns do
      member do
        post :preview
        post :run
        patch :activate
        patch :pause
      end
    end
    resources :settlements, only: %i[index show edit update] do
      patch :reconcile, on: :member
    end
    resources :points_adjustments, only: %i[new create]
  end

  resources :customers, only: %i[show edit update] do
    get :points_ledger, on: :member
    get :transaction_history, on: :member
    resources :vehicles, only: %i[create edit update destroy]
  end
end
