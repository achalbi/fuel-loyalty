Rails.application.routes.draw do
  devise_for :users

  get "up" => "rails/health#show", as: :rails_health_check
  get "/manifest.json", to: "pwa#manifest", as: :pwa_manifest, defaults: { format: :json }
  get "/service-worker.js", to: "pwa#service_worker", as: :pwa_service_worker, defaults: { format: :js }
  post "/analytics/events", to: "analytics/events#create", as: :analytics_events, defaults: { format: :json }
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
    end
  end

  namespace :admin do
    resource :dashboard, only: :show, controller: "dashboard" do
      get :data
    end
    resources :users, only: %i[index new create edit update]
    resource :fuel_reward_rates, only: %i[show update], controller: "fuel_reward_rates"
    resource :theme_settings, only: %i[show update], controller: "theme_settings"
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
