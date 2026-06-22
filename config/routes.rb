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
  # OPOMBA: Admin::PersonsController in ostali admin kontrolerji še ne obstajajo
  # (pridejo v docs/tasks/07_contacts_ui.md, 08_links_ui.md, 09_documents_upload.md).
  # Dokler niso implementirani, admin namespace preusmeri na domov, da ne povzroča
  # NameError / 500 napak pri klikih na "Administracija".
  namespace :admin do
    root to: redirect("/")
  end

  # --- Iskanje ---
  get "search", to: "search#index"
end
