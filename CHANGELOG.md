# Changelog — Tabla (Intranet KL-KL)

Vse pomembne spremembe so dokumentirane v tej datoteki.

## [Unreleased]

### Dodano
- Osnovni layout z header navigacijo, flash sporočili in dark mode preklopom (Stimulus)
- Responsive hamburger meni za mobilne naprave (< 640px)
- `admin_root_path` — preusmeritev na admin osebe
- Začetni skelet projekta (Rails 8.1.3, Docker, devcontainer)
- Projektna dokumentacija (`docs/00_overview.md`, `docs/01_data_model.md`, `docs/02_authentication_api.md`)
- Cursor pravila (`.cursor/rules/`)
- Ločen `Dockerfile` (produkcija, Kamal) in `Dockerfile.dev` (razvoj, brez frozen mode)
- Vsi modeli in migracije: `Location`, `Role`, `User`, `Person`, `PhoneNumber`,
  `LinkCategory`, `Link`, `DocumentCategory`, `Document`, `OcrLog`, `Ahoy::Visit`, `Ahoy::Event`
- Seed podatki: vloge, lokacije (SIKLND/NOE/krajevne knjižnice), kategorije povezav,
  začetne povezave, kategorije dokumentov
- API v1 v Prisotnosti (`POST /api/v1/authenticate`, `GET /api/v1/users`) — zaščiten
  z Bearer tokenom, deployano v produkcijo
- `PrisotnostApiClient` (Faraday) — komunikacija s Prisotnost API-jem
- `SessionsController` — pravi login flow prek Prisotnost API-ja (brez lokalnega gesla)
- `UserSyncJob` + `config/recurring.yml` — periodična sinhronizacija uporabnikov
- Concerns: `UserStampable`, `UnaccentSearchable`
- `ApplicationPolicy` (Pundit) — admin/urednik/bralec vloge
- Slovenski prevodi (`config/locales/sl.yml`)
- `host.docker.internal` dovoljen v Prisotnosti (development) za API dostop iz Table

### Popravljeno
- `Gemfile.lock` — dodana `aarch64-linux` platforma (MacBook Apple Silicon)
- Odstranjen napačen `WebConsole.whiny_requests=` klic (metoda ne obstaja v 4.3.0)
- `CreatePhoneNumbers` migracija — pravilna `to_table: :persons` referenca

### Še ni narejeno (naslednje faze)
- UI: domača stran z dejanskimi podatki (imenik, povezave, dokumenti)
- Admin CRUD vmesniki
- Upload in OCR pipeline za dokumente
- Meilisearch integracija in iskanje
- E-mail obvestila ob objavi dokumenta
