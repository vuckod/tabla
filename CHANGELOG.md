# Changelog — Tabla (Intranet KL-KL)

Vse pomembne spremembe so dokumentirane v tej datoteki.

## [Unreleased]

### Dodano
- Prenova postavitve: mreža 8:2:2 na domači strani, ~90% širina vsebine, živahni barvni bloki
- Ime aplikacije: "Intranet (tabla) KKC Lendava — Lendvai KKK"
- Nujna obvestila (`Announcement`): model, admin CRUD, prikaz na domači strani z avtomatskim potekom po 7 dneh
- Politika `AnnouncementPolicy`
- Dokumenti: javni prikaz (`/documents`) z zavihki po kategorijah (Turbo Frame), paginacija in prenos PDF
- Admin CRUD za dokumente (upload PDF, kategorija, datum objave, internal_only, notify_staff)
- Politika `DocumentPolicy` z defense-in-depth za `internal_only` dokumente
- Domača stran: zadnjih 5 objavljenih dokumentov
- Povezave: javni prikaz (`/links`) s kategoriziranim gridom in izpostavljenimi internimi aplikacijami
- Domača stran: sekcija hitre povezave (`internal_app`) z linkom na vse povezave
- Admin CRUD za kategorije povezav in povezave (vrstni red, internal_app, new_tab)
- Politiki `LinkPolicy` in `LinkCategoryPolicy`
- Telefonski imenik: javni prikaz (`/persons`) z iskanjem, filtrom po lokaciji in prikazom lokacij
- Admin CRUD za osebe in lokacije z nested telefonskimi številkami
- Stimulus kontrolerja `auto_submit` in `nested_form`
- Politike `PersonPolicy`, `LocationPolicy`, `PhoneNumberPolicy`
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
- `Person` model — `self.table_name = "persons"` (Rails privzeto išče `people`)
- `Person` pluralizacija prek `inflections.rb` (`irregular "person", "persons"`) — popravek `admin_people_path` napake
- Ahoy duplicate key race condition (tiho prezrt `RecordNotUnique` v `track_ahoy_visit`)
- Admin route preusmeritev na domov dokler kontrolerji ne obstajajo
- `audited` Psych::DisallowedClass — `yaml_column_permitted_classes` vključuje `TimeWithZone`
- `set_document` v javnem DocumentsController uporablja `visible_to` (defense-in-depth za internal_only)
- `Gemfile.lock` — dodana `aarch64-linux` platforma (MacBook Apple Silicon)
- Odstranjen napačen `WebConsole.whiny_requests=` klic (metoda ne obstaja v 4.3.0)
- `CreatePhoneNumbers` migracija — pravilna `to_table: :persons` referenca

### Načrtovano — UI prenova (naloge 13-18)
- Preimenovanje: "Intranet (tabla) KKC Lendava — Lendvai KKK"
- Nujna obvestila (`Announcement` model, 7-dnevni privzeti potek, vezava na enoto)
- Nova mreža blokov (8:2:2), ~90% širina, živahne barve blokov
- Tabelaričen imenik (interna/zunanja/mesto/enota)
- Ločena živa bloka za interne aplikacije (zeleno) in zunanje povezave (modro)
- Dokumenti z barvnimi značkami in filtrom
- Globalni iskalnik po dokumentih

### Še ni narejeno (kasnejše faze)
- OCR ekstrakcija besedila (`10_ocr_pipeline.md`)
- Iskanje po vsebini (Meilisearch, `11_meilisearch_setup.md`)
- E-mail obvestila ob objavi dokumenta (`DocumentNotificationJob`)
