# Avtentikacija — API sync s Prisotnostjo

## Pregled

Prisotnost (`p.kl-kl.si`) je **single source of truth** za zaposlene. Tabla (intranet) ne upravlja
uporabnikov, gesla ali vlog sama — vse pridobi prek API-ja iz Prisotnosti.

Potrebne spremembe v **dveh** projektih:
1. **Prisotnost** — nov API namespace z dvema endpointoma
2. **Tabla** — login flow, user sync, recurring job

---

## SPREMEMBE V PRISOTNOSTI

### 1. Vloge za intranet

V Prisotnosti ustvariš dodatne vloge (prek admin panela ali seed):

```ruby
# db/seeds.rb (ali ročno v admin panelu)
Role.find_or_create_by!(name: "intranet_admin")
Role.find_or_create_by!(name: "intranet_urednik")
# bralec je implicitna vloga — vsak prijavljen uporabnik brez zgornjih dveh
```

Te vloge dodeliš posameznim uporabnikom prek obstoječega roles admin panela v Prisotnosti.
Vloge `intranet_*` ne vplivajo na delovanje Prisotnosti same — so samo metadata za Tablo.

### 2. API token (Bearer)

API klic iz Table mora biti zaščiten s statičnim tokenom, da ne more kdorkoli
poizvedovati po uporabnikih. Token se hrani v Rails credentials ali ENV.

```bash
# V Prisotnosti — dodaj v credentials ali .env:
INTRANET_API_TOKEN=nek_dolg_nakljucen_niz_32_znakov
```

Generiranje tokena:
```bash
docker compose run --rm rails_app ruby -e "require 'securerandom'; puts SecureRandom.hex(32)"
```

### 3. API kontrolerji

Ustvari nov namespace `Api::V1` v Prisotnosti:

```
app/controllers/api/
  v1/
    base_controller.rb
    authenticate_controller.rb
    users_controller.rb
```

#### `app/controllers/api/v1/base_controller.rb`

```ruby
# frozen_string_literal: true

# Bazni kontroler za API — vsi API kontrolerji dedujejo od tega.
# Brez sej, brez CSRF, samo Bearer token.
module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_api_token!

      private

      def authenticate_api_token!
        token = request.headers["Authorization"]&.remove("Bearer ")
        expected = ENV.fetch("INTRANET_API_TOKEN") { Rails.application.credentials.dig(:intranet_api_token) }

        unless ActiveSupport::SecurityUtils.secure_compare(token.to_s, expected.to_s)
          render json: { error: "Unauthorized" }, status: :unauthorized
        end
      end
    end
  end
end
```

#### `app/controllers/api/v1/authenticate_controller.rb`

```ruby
# frozen_string_literal: true

# POST /api/v1/authenticate
# Tabla pošlje username + geslo, Prisotnost preveri in vrne podatke o uporabniku.
module Api
  module V1
    class AuthenticateController < BaseController
      # Prijava uporabnika — preveri credentials.
      def create
        user = User.find_by(username: params[:username])

        if user && !user.onemogocen && user.authenticate(params[:password])
          # Posodobi login statistiko (enako kot SessionsController)
          user.update!(
            login_count: user.login_count + 1,
            last_login_at: Time.current,
            last_login_ip: request.remote_ip
          )

          render json: {
            user: user_json(user)
          }, status: :ok
        else
          render json: { error: "Napačno uporabniško ime ali geslo." }, status: :unauthorized
        end
      end

      private

      def user_json(user)
        {
          id: user.id,
          username: user.username,
          ime: user.ime,
          priimek: user.priimek,
          email: user.email,
          onemogocen: user.onemogocen,
          roles: user.roles.pluck(:name)
        }
      end
    end
  end
end
```

#### `app/controllers/api/v1/users_controller.rb`

```ruby
# frozen_string_literal: true

# GET /api/v1/users
# Tabla periodično kliče ta endpoint za sinhronizacijo uporabnikov.
module Api
  module V1
    class UsersController < BaseController
      # Seznam vseh aktivnih uporabnikov z vlogami.
      def index
        users = User.where(onemogocen: false, sistemski_racun: [false, nil])
                     .includes(:roles)
                     .order(:priimek, :ime)

        render json: {
          users: users.map { |u| user_json(u) },
          synced_at: Time.current.iso8601
        }, status: :ok
      end

      # Podrobnosti enega uporabnika.
      def show
        user = User.find(params[:id])

        render json: { user: user_json(user) }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Uporabnik ne obstaja." }, status: :not_found
      end

      private

      def user_json(user)
        {
          id: user.id,
          username: user.username,
          ime: user.ime,
          priimek: user.priimek,
          email: user.email,
          onemogocen: user.onemogocen,
          enota: user.enota,
          delovnomesto: user.delovnomesto,
          roles: user.roles.pluck(:name)
        }
      end
    end
  end
end
```

### 4. Routes v Prisotnosti

Dodaj v `config/routes.rb`:

```ruby
# API za intranet (Tabla)
namespace :api do
  namespace :v1 do
    post "authenticate", to: "authenticate#create"
    resources :users, only: [:index, :show]
  end
end
```

To generira:
- `POST   /api/v1/authenticate` — prijava (username + geslo)
- `GET    /api/v1/users` — seznam vseh aktivnih uporabnikov
- `GET    /api/v1/users/:id` — posamezen uporabnik

### 5. Testiranje API-ja (curl)

```bash
# Prijava
curl -X POST http://localhost:3000/api/v1/authenticate \
  -H "Authorization: Bearer <tvoj_token>" \
  -H "Content-Type: application/json" \
  -d '{"username":"test_vucko","password":"geslo123"}'

# Odziv (200):
# {"user":{"id":1,"username":"test_vucko","ime":"Janez","priimek":"Vucko",
#   "email":"test@vucko.si","onemogocen":false,"roles":["admin","intranet_admin"]}}

# Seznam uporabnikov
curl http://localhost:3000/api/v1/users \
  -H "Authorization: Bearer <tvoj_token>"

# Napačen token
curl http://localhost:3000/api/v1/users \
  -H "Authorization: Bearer napacen_token"
# Odziv (401): {"error":"Unauthorized"}
```

---

## SPREMEMBE V TABLI

### 1. ENV spremenljivke

```bash
# .env (Tabla)
PRISOTNOST_API_URL=http://prisotnost-app:3000/api/v1   # Docker internal (produkcija)
# ali za development:
PRISOTNOST_API_URL=http://host.docker.internal:3000/api/v1
PRISOTNOST_API_TOKEN=isti_token_kot_v_prisotnosti
```

### 2. API client service

```ruby
# app/services/prisotnost_api_client.rb
class PrisotnostApiClient
  BASE_URL = ENV.fetch("PRISOTNOST_API_URL", "http://localhost:3000/api/v1")
  TOKEN = ENV.fetch("PRISOTNOST_API_TOKEN", "")

  class AuthenticationError < StandardError; end
  class ConnectionError < StandardError; end

  # Preveri credentials uporabnika prek Prisotnosti.
  # Vrne hash z uporabniškimi podatki ali nil.
  def self.authenticate(username, password)
    response = connection.post("authenticate") do |req|
      req.body = { username: username, password: password }.to_json
    end

    return nil unless response.status == 200

    JSON.parse(response.body)["user"]
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
    Rails.logger.error("[PrisotnostAPI] Connection failed: #{e.message}")
    raise ConnectionError, "Prisotnost ni dosegljiva. Poskusite znova."
  end

  # Pridobi seznam vseh aktivnih uporabnikov.
  def self.fetch_users
    response = connection.get("users")

    return [] unless response.status == 200

    JSON.parse(response.body)["users"]
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
    Rails.logger.error("[PrisotnostAPI] Connection failed: #{e.message}")
    []
  end

  def self.connection
    @connection ||= Faraday.new(url: BASE_URL) do |f|
      f.request :json
      f.response :raise_error
      f.headers["Authorization"] = "Bearer #{TOKEN}"
      f.headers["Content-Type"] = "application/json"
      f.options.timeout = 10
      f.options.open_timeout = 5
    end
  end
end
```

**Opomba:** Dodaj `gem "faraday"` v Gemfile Table.

### 3. Posodobljen SessionsController v Tabli

```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]

  def new
    redirect_to root_path if current_user
  end

  def create
    api_user = PrisotnostApiClient.authenticate(params[:username], params[:password])

    if api_user
      user = User.sync_from_api_data(api_user)
      session[:user_id] = user.id
      redirect_to root_path, notice: "Prijava uspešna."
    else
      flash.now[:alert] = "Napačno uporabniško ime ali geslo."
      render :new, status: :unprocessable_entity
    end
  rescue PrisotnostApiClient::ConnectionError => e
    flash.now[:alert] = e.message
    render :new, status: :service_unavailable
  end

  def destroy
    session.delete(:user_id)
    redirect_to login_path, notice: "Odjava uspešna."
  end
end
```

### 4. User sync job (periodično)

```ruby
# app/jobs/user_sync_job.rb
class UserSyncJob < ApplicationJob
  queue_as :default

  def perform
    api_users = PrisotnostApiClient.fetch_users
    return if api_users.blank?

    Rails.logger.info("[UserSyncJob] Sinhronizacija #{api_users.size} uporabnikov...")

    api_users.each do |user_data|
      User.sync_from_api_data(user_data)
    rescue StandardError => e
      Rails.logger.error("[UserSyncJob] Napaka pri #{user_data['username']}: #{e.message}")
    end

    # Deaktiviraj uporabnike, ki niso več v seznamu
    active_remote_ids = api_users.map { |u| u["id"] }
    User.where.not(remote_id: active_remote_ids).where(onemogocen: false).update_all(onemogocen: true)

    Rails.logger.info("[UserSyncJob] Sinhronizacija končana.")
  end
end
```

### 5. Recurring schedule (Solid Queue)

```yaml
# config/recurring.yml
production:
  user_sync:
    class: UserSyncJob
    schedule: every hour
    description: "Sinhronizacija uporabnikov iz Prisotnosti"

development:
  user_sync:
    class: UserSyncJob
    schedule: every 6 hours
    description: "Sinhronizacija uporabnikov iz Prisotnosti (dev)"
```

---

## DIAGRAM KOMUNIKACIJE

```
┌─────────────────┐         ┌─────────────────────┐
│     TABLA       │         │     PRISOTNOST      │
│   i.kl-kl.si    │         │    p.kl-kl.si       │
│                 │         │                     │
│  1. Login form  │         │                     │
│     ↓           │         │                     │
│  2. POST ───────┼────────→│ /api/v1/authenticate│
│     username    │ Bearer  │   ↓                 │
│     password    │ token   │ has_secure_password  │
│                 │         │ User.authenticate()  │
│  3. ←───────────┼─────────│   ↓                 │
│   {user data}   │  200    │ JSON response        │
│     ↓           │         │                     │
│  4. User.sync_  │         │                     │
│     from_api    │         │                     │
│     ↓           │         │                     │
│  5. session[    │         │                     │
│     :user_id]   │         │                     │
│                 │         │                     │
│  ═══════════════│═════════│═════════════════════│
│  RECURRING JOB  │         │                     │
│  (vsako uro)    │         │                     │
│                 │         │                     │
│  GET ───────────┼────────→│ /api/v1/users       │
│                 │ Bearer  │   ↓                 │
│  ←──────────────┼─────────│ JSON: vsi userji    │
│  sync vseh      │         │                     │
│  uporabnikov    │         │                     │
└─────────────────┘         └─────────────────────┘
```

---

## DOCKER NETWORKING (development)

V razvoju Tabla teče v svojem Docker compose, Prisotnost v svojem.
Za komunikacijo med njima sta dve možnosti:

**Možnost A: `host.docker.internal` (priporočeno za razvoj)**
```yaml
# Tabla docker-compose.yml
environment:
  PRISOTNOST_API_URL: http://host.docker.internal:3000/api/v1
```
Deluje na Docker Desktop (Windows/Mac). Na Linux dodaj:
```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

**Možnost B: Skupna Docker network**
```yaml
# Tabla docker-compose.yml
networks:
  - default
  - prisotnost_default

networks:
  prisotnost_default:
    external: true
```
Potem: `PRISOTNOST_API_URL: http://prisotnost_rails_web:3000/api/v1`
(če je kontejner tako imenovan).

**Produkcija:** Oba kontejnerja sta na istem strežniku. Kamal ustvari skupno Docker network
ali pa uporabiš interni IP/port.

---

## VARNOSTNI PREMISLEKI

1. **Token ne sme biti v kodi** — samo v ENV ali credentials.
2. **HTTPS v produkciji** — API klici med kontejnerji na istem strežniku so interni (HTTP ok),
   ampak če bi kdaj ločil strežnike, mora biti HTTPS.
3. **Rate limiting** — za prvo fazo ni potreben (samo Tabla kliče), pozneje dodaj
   `rack-attack` na Prisotnost API namespace.
4. **Gesla se nikoli ne hranijo v Tabli** — potujejo samo v POST requestu do Prisotnosti,
   ki jih preveri z `bcrypt`. Tabla shrani le session.
5. **Token rotacija** — ob sumu kompromitacije zamenjaj token v obeh ENV-ih in restartaj.

---

## VRSTNI RED IMPLEMENTACIJE

1. **[Prisotnost]** Ustvari vloge `intranet_admin`, `intranet_urednik` v seedu
2. **[Prisotnost]** Dodaj `INTRANET_API_TOKEN` v ENV / credentials
3. **[Prisotnost]** Ustvari `Api::V1::BaseController`, `AuthenticateController`, `UsersController`
4. **[Prisotnost]** Dodaj API route
5. **[Prisotnost]** Testiraj s curl
6. **[Prisotnost]** Deploy (kamal deploy)
7. **[Tabla]** Dodaj `gem "faraday"`, `PrisotnostApiClient` service
8. **[Tabla]** Posodobi `SessionsController`
9. **[Tabla]** Dodaj `UserSyncJob` + `recurring.yml`
10. **[Tabla]** Testiraj login flow
