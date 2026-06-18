# Naloga: API endpoint v Prisotnosti za Tablo

## Cilj
Dodaj read-only API v Prisotnost, ki omogoča Tabli (intranetu) preverjanje uporabniških
credentials in periodično sinhronizacijo uporabnikov z vlogami.

## Predpogoji
- Prisotnost deluje v Docker development okolju
- Imaš admin dostop za urejanje vlog

## Koraki

### 1. Ustvari intranet vloge
```bash
docker compose run --rm rails_app bin/rails console
```
```ruby
Role.find_or_create_by!(name: "intranet_admin")
Role.find_or_create_by!(name: "intranet_urednik")
```
Dodeli `intranet_admin` svojemu test uporabniku.

### 2. Generiraj API token
```bash
docker compose run --rm rails_app ruby -e "require 'securerandom'; puts SecureRandom.hex(32)"
```
Shrani rezultat v `.env` kot `INTRANET_API_TOKEN=...`

### 3. Ustvari datoteke

Ustvari mapo `app/controllers/api/v1/` in tri kontrolerje:

**`app/controllers/api/v1/base_controller.rb`**
- Deduje od `ActionController::API` (ne ActionController::Base — brez sej, CSRF)
- `before_action :authenticate_api_token!`
- Primerja Bearer token iz headerja z `ENV["INTRANET_API_TOKEN"]`
- Uporabi `ActiveSupport::SecurityUtils.secure_compare` (timing-safe primerjava)
- Vrne 401 JSON če token ne ustreza

**`app/controllers/api/v1/authenticate_controller.rb`**
- `POST #create`: sprejme `username` in `password`
- Poišče uporabnika, preveri `!user.onemogocen`, kliče `user.authenticate(password)`
- Posodobi `login_count` in `last_login_at` (enako kot obstoječi SessionsController)
- Vrne JSON: `{ user: { id, username, ime, priimek, email, onemogocen, roles: [...] } }`
- Ob neuspehu vrne `401 { error: "Napačno uporabniško ime ali geslo." }`

**`app/controllers/api/v1/users_controller.rb`**
- `GET #index`: vrne vse aktivne uporabnike (onemogocen: false, sistemski_racun: false/nil)
- Vključi `roles.pluck(:name)` za vsakega
- Vrne JSON: `{ users: [...], synced_at: "ISO8601" }`
- `GET #show`: vrne enega uporabnika po ID-ju
- 404 JSON če ne obstaja

### 4. Dodaj routes
V `config/routes.rb` dodaj **pred** catch-all routes:
```ruby
namespace :api do
  namespace :v1 do
    post "authenticate", to: "authenticate#create"
    resources :users, only: [:index, :show]
  end
end
```

### 5. Testiraj
```bash
# Generiraj token (ali uporabi tistega iz .env)
TOKEN="tvoj_hex_token"

# Prijava
curl -s -X POST http://localhost:3000/api/v1/authenticate \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"username":"test_vucko","password":"geslo123"}' | python3 -m json.tool

# Seznam uporabnikov
curl -s http://localhost:3000/api/v1/users \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool

# Napačen token (mora vrniti 401)
curl -s http://localhost:3000/api/v1/users \
  -H "Authorization: Bearer napacen" | python3 -m json.tool

# Napačno geslo (mora vrniti 401)
curl -s -X POST http://localhost:3000/api/v1/authenticate \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"username":"test_vucko","password":"napacno"}' | python3 -m json.tool
```

## Reference
- `prisotnost_028/app/controllers/sessions_controller.rb` — obstoječa login logika
- `prisotnost_028/app/models/user.rb` — `has_secure_password`, `authenticate`, `roles`
- `delovodnik_rails/app/controllers/api/v1/documents_controller.rb` — vzorec API kontrolerja
- `delovodnik_rails/app/controllers/api/scans_controller.rb` — vzorec API kontrolerja

## Acceptance criteria
- [ ] `POST /api/v1/authenticate` z veljavnim tokenom + credentials vrne 200 + user JSON
- [ ] `POST /api/v1/authenticate` z napačnim geslom vrne 401
- [ ] `POST /api/v1/authenticate` brez Bearer tokena vrne 401
- [ ] `GET /api/v1/users` vrne seznam aktivnih uporabnikov z vlogami
- [ ] `GET /api/v1/users/:id` vrne posameznega uporabnika
- [ ] Sistemski računi (sistemski_racun: true) niso v seznamu
- [ ] Onemogočeni uporabniki (onemogocen: true) niso v seznamu
- [ ] API ne vpliva na obstoječe delovanje Prisotnosti (seje, obrazci, ...)

## Out of scope
- Spremembe v Tabli (SessionsController, UserSyncJob) — to je ločena naloga
- Rate limiting — faza 2
- OAuth / JWT — morebitna faza 3
