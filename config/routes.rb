Rails.application.routes.draw do
  resource :session
  resources :users, only: [:new, :create]
  resources :passwords, param: :token
  resources :websites do
    collection do
      post :scrape_content
    end
    
    resources :novels, except: [:index], shallow: true do
      member do
        post :batch_scrape
      end
      resources :chapters, except: [:index], shallow: true
    end
  end

  root "websites#index"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"

end
