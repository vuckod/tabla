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
      get :preview
    end
  end

  # --- Admin ---
  namespace :admin do
    root to: redirect("/admin/persons")

    get "analytics", to: "analytics#index", as: :analytics
    get "document_audits", to: "document_audits#index", as: :document_audits
    get "document_popularity", to: "document_popularity#index", as: :document_popularity

    resources :persons
    resources :locations
    resources :link_categories
    resources :links
    resources :document_categories, except: :show do
      collection do
        get :inline_cancel
      end
    end
    resources :documents do
      member do
        get :audit_history
      end
    end
    resources :announcements
  end

  # --- Iskanje ---
  get "search", to: "search#index"
end
