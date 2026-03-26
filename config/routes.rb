Rails.application.routes.draw do
  devise_for :users

  get "up" => "rails/health#show", as: :rails_health_check
  get "/manifest.json", to: "pwa#manifest", as: :pwa_manifest, defaults: { format: :json }
  get "/service-worker.js", to: "pwa#service_worker", as: :pwa_service_worker, defaults: { format: :js }
  post "/analytics/events", to: "analytics/events#create", as: :analytics_events, defaults: { format: :json }
  post "/push/subscriptions", to: "push_subscriptions#create", as: :push_subscriptions, defaults: { format: :json }
  delete "/push/subscriptions", to: "push_subscriptions#destroy", defaults: { format: :json }
  resource :password, only: %i[edit update]

  root "dashboard#show"

  get "/loyalty", to: "loyalty#new", as: :new_loyalty
  post "/loyalty", to: "loyalty#create", as: :loyalty
  get "/loyalty/result", to: "loyalty#show", as: :loyalty_result

  namespace :staff do
    resources :customers, only: %i[index new create] do
      get :lookup, on: :collection
      patch :activate, on: :member
      patch :deactivate, on: :member
    end
    resources :redemptions, only: %i[new create]
    resources :transactions, only: %i[new create] do
      get :lookup, on: :collection
      post :register_customer, on: :collection
    end
  end

  namespace :admin do
    resource :dashboard, only: :show, controller: "dashboard" do
      get :data
    end
    resource :notifications, only: :show, controller: "notifications"
    post "notifications/send", to: "notification_deliveries#create", as: :send_notifications
    resources :users, only: %i[index new create edit update]
    resource :fuel_reward_rates, only: %i[show update], controller: "fuel_reward_rates"
    resource :theme_settings, only: %i[show update], controller: "theme_settings"
    resources :schedules, only: %i[index create update destroy] do
      post :send_now, on: :member
    end
    post "schedules/run", to: "schedules#run", as: :run_schedules
    resources :customers, only: %i[index show new create edit update destroy] do
      get :points_ledger, on: :member
      get :transaction_history, on: :member
    end
    resources :transactions, only: :index
    resources :points_adjustments, only: %i[new create]
  end

  resources :customers, only: %i[show edit update] do
    get :points_ledger, on: :member
    get :transaction_history, on: :member
    resources :vehicles, only: %i[create edit update destroy]
  end
end
