# Tabla — Intranet KKC Lendava (Lendvai KKK)

Interna intranetna aplikacija za Knjižnico Lendava. Nadomešča staro PHP "tablo".
Produkcija: **https://i.kl-kl.si**

## Tehnologija

- **Ruby** 3.4.2, **Rails** 8.1
- **PostgreSQL** 16
- **Hotwire** (Turbo + Stimulus), **Tailwind CSS** v4
- **Solid Queue / Cache / Cable** (database-backed)
- **Meilisearch** (iskanje, deljena instanca z Delovodnikom)
- **Pundit** (avtorizacija), **Ahoy** (analitika), **audited** (revizijska sled)
- **Tesseract** OCR (slv + hun), **libvips** (slike/thumbnaili)
- Razvoj v Dockerju; produkcija prek **Kamal**

## Razvojno okolje

Projekt teče v Dockerju (`docker-compose.yml`):

```bash
# Zagon
docker compose up -d

# Rails konzola
docker compose exec rails_app bin/rails console

# Migracije
docker compose exec rails_app bin/rails db:migrate

# Tailwind build (po spremembi view/helper datotek)
bin/tailwind-build
```

Dev aplikacija: `http://localhost:3002`. Pošta v razvoju: `letter_opener_web` na `/letter_opener`.

## Avtentikacija

Prijava se **vedno** preverja prek Prisotnost API-ja (`PrisotnostApiClient`) — gesla se NIKOLI
ne shranjujejo lokalno. Uporabniki in vloge (admin / urednik / bralec) ter enota
(knjižnica / gledališče / uprava) se sinhronizirajo iz Prisotnosti.

## Dokumentacija

- `docs/00_overview.md` — pregled projekta
- `docs/01_data_model.md` — podatkovni model
- `docs/02_authentication_api.md` — avtentikacija in Prisotnost API
- `docs/04_ui_design.md` — UI smernice
- `docs/tasks/*.md` — posamezne naloge (z acceptance criteriji)
- `docs/admin_guide.md` — priročnik za administratorje/urednike
- `docs/cursor_log.md` — tehnični dnevnik sej
- `CHANGELOG.md` — pregled sprememb po verzijah

## Konvencije

- Koda (modeli, kontrolerji, metode) v **angleščini**; komentarji in commit sporočila v **slovenščini**.
- Naloge se pišejo kot `docs/tasks/NN_ime.md` pred implementacijo.
- Git ukaze izvaja razvijalec ročno.

## Deployment (Kamal)

Podroben postopek je v `docs/tasks/33_kamal_deploy.md`. Na kratko:

```bash
git push
kamal deploy
```

**Pomembno — enkratni ukazi na produkciji:** vedno z `-r web`, sicer tečejo vzporedno na
web + jobs rolih (race condition):

```bash
kamal app exec -r web "bin/rails <naloga>"
```

## Pogoste pasti (zabeležke)

### Dodajanje gema — vrstni red je pomemben

`docker-compose.yml` NIMA ločenega volumna za `/usr/local/bundle`, zato so geme, nameščeni z
`bundle install` znotraj enkratnega `docker compose run --rm`, **efemerni** (izgubijo se ob
brisanju kontejnerja). Ob dodajanju gema sledi temu zaporedju:

1. Dodaj gem v `Gemfile`.
2. `docker compose run --rm rails_app bundle install`
3. **Preveri, da je gem v `specs` sekciji `Gemfile.lock`, ne le v `DEPENDENCIES`:**
   ```bash
   grep -A2 "ime_gema" Gemfile.lock
   ```
   Če je gem samo v `DEPENDENCIES` (spodaj) in NE v `specs` (zgoraj), resolucija ni dokončana —
   ponovi `bundle install` (pogosto vzrok: prekinjen prenos ali omrežna težava do rubygems.org).
4. `docker compose build rails_app` — vpeče gem v dev sliko (obvezno, ker ni bundle volumna).
5. `docker compose up -d rails_app` — zaženi nov kontejner iz posodobljene slike (sicer še teče
   stari brez gema → `LoadError`).

V produkciji to ni problem — `kamal deploy` zgradi svežo sliko z `bundle install` v Dockerfile.

### master.key se izgublja ob sinhronizaciji med okolji

`config/master.key` ni v gitu (pravilno). Ob selitvi med WSL → git → macOS se lahko izgubi.
Regeneracija prek Dockerja:

```bash
docker compose run --rm -e EDITOR="cat" rails_app bin/rails credentials:edit
```

### Initializerji se ne reloadajo v dev

Spremembe v `config/initializers/*.rb` (npr. `constants.rb`) zahtevajo restart:

```bash
docker compose restart rails_app
```

## Sorodna projekta (vzorci)

- **`prisotnost_028`** — sistem evidence prisotnosti; vir resnice za uporabnike.
- **`delovodnik_rails`** — dokumentni workflow; vzorci za e-mail, Kamal, footer, PWA, analitiko.
