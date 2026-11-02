Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "playground#index"

  get "playground", to: "playground#index"
  post "playground/generate_packet", to: "playground#generate_packet"
  post "playground/submit_packet", to: "playground#submit_packet"
  post "playground/reset_ledger", to: "playground#reset_ledger"

  namespace :api do
    namespace :v1 do
      resources :products, only: [:index, :show]
      resources :orders, only: [:index, :show, :create]
      post "verify", to: "orders#verify_only"
    end
  end
end
