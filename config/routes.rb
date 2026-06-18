# Tabla — Routes
Rails.application.routes.draw do
  # --- Zdravje (Kamal healthcheck) ---
  get "up" => "rails/health#show", as: :rails_health_check

  # --- PWA ---
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # --- Avtentikacija ---
  get  "login",  to: "sessions#new"
  post "login",  to: "sessions#create"
  get  "logout", to: "sessions#destroy"

  # --- Domov (dashboard) ---
  root "home#index"

  # --- Letter Opener (development) ---
  if defined?(LetterOpenerWeb)
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  # --- Telefonski imenik ---
  resources :persons, only: [:index, :show]
  resources :locations, only: [:index, :show]

  # --- Povezave ---
  resources :links, only: [:index]

  # --- Dokumenti ---
  resources :documents, only: [:index, :show] do
    member do
      get :download
    end
  end

  # --- Admin ---
  namespace :admin do
    resources :persons
    resources :phone_numbers, only: [:create, :update, :destroy]
    resources :locations
    resources :link_categories
    resources :links
    resources :document_categories
    resources :documents
    resources :users, only: [:index, :show]
  end

  # --- Iskanje ---
  get "search", to: "search#index"
end
