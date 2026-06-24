# Naloga 33: Produkcijski deploy prek Kamal (i.kl-kl.si)

## Cilj
Postavi Tablo v produkcijo na strežnik 193.2.53.52 prek Kamal, po vzorcu Delovodnika (isti
strežnik, ista metoda). Domena i.kl-kl.si, SSL termina nginx na strežniku (Kamal proxy ssl:false).

## Stanje — KAJ JE ŽE PRIPRAVLJENO (Claude)
- `config/deploy.yml` — prilagojen po Delovodniku z LOČENIMI porti (PG 5436, Meili 7701, proxy 4002)
- `.gitignore` — dodan `/.kamal/secrets` (gesla NIKOLI v git)
- `.kamal/secrets.example` — vzorec (v git, brez pravih gesel)
- `config/environments/production.rb` — SMTP, mailer host, `public_file_server.enabled` (assets)
- `Dockerfile` (produkcijski) — že vključuje tesseract slv+hun, libvips, poppler-utils (OCR + thumbnaili)
- `config/database.yml` — vse 4 povezave na DATABASE_URL (kot razvoj)

## POMEMBNO — ločeni porti (sobivanje z Delovodnikom + Prisotnostjo na istem strežniku)
| Storitev          | Delovodnik | Tabla  |
|-------------------|-----------|--------|
| PG accessory host | 5434      | 5436   |
| Meilisearch host  | 7700      | 7701   |
| proxy http_port   | 4000      | 4002   |
| proxy https_port  | 8443      | 8445   |
Container imena (Kamal): `tabla-db`, `tabla-meilisearch` (app se poveže prek teh + NOTRANJI port).

## Koraki

### 1. Preveri/uskladi master.key
`config/master.key` mora obstajati lokalno (je v .gitignore). Če ga ni, ga generiraj ali kopiraj.
`RAILS_MASTER_KEY=$(cat config/master.key)` v secrets.

### 2. Ustvari .kamal/secrets (lokalno, NE v git)
Kopiraj `.kamal/secrets.example` v `.kamal/secrets` in izpolni prave vrednosti:
```bash
cp .kamal/secrets.example .kamal/secrets
```
Nato uredi `.kamal/secrets` z dejanskimi vrednostmi (ali jih daj v ENV, na katere se sklicuje):
- `KAMAL_REGISTRY_PASSWORD` — Gitea dostopni žeton (isti kot Delovodnik: glej delovodnik .kamal/secrets)
- `TABLA_POSTGRES_PASSWORD` — novo močno geslo za tabla_production bazo
- `TABLA_MEILI_MASTER_KEY` — nov močan ključ (generiraj: `openssl rand -hex 32`)
- `TABLA_PRISOTNOST_API_TOKEN` — žeton za Prisotnost API (produkcijski)
- `TABLA_SMTP_USERNAME` / `TABLA_SMTP_PASSWORD` — če mail.arnes.si zahteva avtentikacijo (sicer prazno)
- `DATABASE_URL` — sestavljen iz POSTGRES_PASSWORD (glej example)

POZOR: preveri pravi `PRISOTNOST_API_URL` v deploy.yml — postavil sem `https://p.kl-kl.si/api/v1`,
a preveri dejansko produkcijsko domeno Prisotnosti (morda druga poddomena).

### 3. DNS + nginx (TI, ročno na strežniku — izven Kamala)
- DNS: i.kl-kl.si → 193.2.53.52 (A zapis)
- nginx na strežniku: nov server block za i.kl-kl.si, ki:
  - termina HTTPS (Let's Encrypt certifikat — certbot, kot za d.kl-kl.si)
  - proxy_pass na Kamal proxy http_port: `http://127.0.0.1:4002`
  - vzorec: kopiraj nginx config od d.kl-kl.si (Delovodnik), spremeni server_name na i.kl-kl.si
    in proxy_pass port na 4002
- To naredi ročno (ali poglej, kako je za d.kl-kl.si nastavljeno v /etc/nginx/sites-available/)

### 4. Preveri Kamal nameščen + dostop do strežnika
```bash
kamal version
ssh deploy@193.2.53.52 "docker ps"   # preveri SSH + Docker dostop
```

### 5. Prvi deploy — setup
```bash
# Inicialni setup (namesti Docker če treba, ustvari omrežje, zažene accessories)
kamal setup
```
To: zgradi sliko (remote builder na strežniku), potisne v registry, zažene PG + Meilisearch
accessories, zažene app + jobs kontejnerje. PRVIČ lahko traja dolgo (build + tesseract paketi).

Če `kamal setup` spodleti na accessory, ju lahko zaženeš ločeno:
```bash
kamal accessory boot db
kamal accessory boot meilisearch
```

### 6. Baza — migracije + Solid sheme
Produkcijska baza je prazna. Po prvem deployu:
```bash
# Primarne migracije
kamal app exec "bin/rails db:migrate"
```
POZOR Solid Queue/Cache/Cable: ker vse 4 povezave delijo bazo (DATABASE_URL), `db:migrate`
NE ustvari solid_* tabel (te so v ločenih *_schema.rb). Naloži jih (kot v sync.sh):
```bash
kamal app exec "bin/rails runner '
  conn = ActiveRecord::Base.connection
  unless conn.table_exists?(\"solid_queue_jobs\")
    load Rails.root.join(\"db/queue_schema.rb\")
    load Rails.root.join(\"db/cache_schema.rb\")
    load Rails.root.join(\"db/cable_schema.rb\")
    puts \"Solid sheme naložene.\"
  end
'"
```
PREVERI, da so solid_queue_jobs, solid_cache_entries, solid_cable_messages ustvarjene, sicer
jobs kontejner (bin/jobs) ne bo deloval.

### 7. Seed (vloge, lokacije, kategorije)
```bash
kamal app exec "bin/rails db:seed"
```
Idempotenten — ustvari vloge, lokacije, kategorije povezav/dokumentov.

### 8. Sinhronizacija uporabnikov iz Prisotnosti
```bash
kamal app exec "bin/rails runner 'UserSyncJob.perform_now'"
kamal app exec "bin/rails runner 'puts User.count'"
```
Preveri, da so uporabniki (in enote) sinhronizirani. Potrebuje dosegljiv PRISOTNOST_API_URL +
veljaven PRISOTNOST_API_TOKEN.

### 9. Uvoz vsebine (dokumenti, povezave, telefoni) — NEOBVEZNO
Če želiš produkcijsko bazo napolniti z uvozom (kot v razvoju), poženi uvoze. AMPAK: stari
strežnik tabla.knjiznica-lendava.si mora biti dosegljiv iz produkcijskega kontejnerja, in HTML
datoteka mora biti v sliki (docs/ je COPY-jan v Docker build). Razmisli:
- ALI uvozi v produkciji (kot razvoj): `kamal app exec "bin/rails import:legacy"` itd.
- ALI prenesi podatke iz razvojne baze (pg_dump → restore) — a to prinese tudi storage datoteke
PRESODI z uporabnikom. Najčisteje: uvozi v produkciji (idempotentno prek source_url), nato
poženi thumbnaile (`thumbnails:generate_missing`). OCR bo tekel v jobs kontejnerju.

### 10. Preveri delovanje
```bash
kamal app logs -f          # spremljaj loge
kamal app exec "bin/rails runner 'puts Document.count'"
```
- Odpri https://i.kl-kl.si → domača stran (po DNS + nginx)
- Preveri /up (healthcheck) vrne 200
- Prijava (Prisotnost API)
- Iskanje (Meilisearch)
- Predogled dokumenta (OCR/thumbnail)

### 11. Naslednji deployi
Po prvem setupu so nadaljnji deployi preprosti:
```bash
git push                   # commitaj spremembe
kamal deploy               # zgradi, potisne, zamenja kontejnerje (zero-downtime)
```

## Varnostni dolg (NASLOVI)
- `.kamal/secrets` je ZDAJ v .gitignore (popravljeno). Če je bil prej kdaj commitan z gesli,
  razmisli o rotaciji gesel (zlasti če je repo deljen). Za zdaj: nova produkcijska gesla so
  sveža (jih ustvariš v koraku 2), torej niso v git zgodovini.
- Meilisearch master key: nov, močan (openssl rand -hex 32), NE isti kot Delovodnik.
- PG geslo: novo, močno, NE deljeno.

## Reference
- `delovodnik_rails/config/deploy.yml` — vzorec (Tabla prilagojen z ločenimi porti)
- `delovodnik_rails/.kamal/secrets` — vzorec (a Tabla bere iz ENV, ne plain text)
- nginx config za d.kl-kl.si na strežniku — vzorec za i.kl-kl.si
- `config/deploy.yml`, `.kamal/secrets.example` (že pripravljena)

## Acceptance criteria
- [ ] DNS i.kl-kl.si → 193.2.53.52
- [ ] nginx server block za i.kl-kl.si (HTTPS → 127.0.0.1:4002)
- [ ] `.kamal/secrets` izpolnjen (lokalno, ne v git)
- [ ] `kamal setup` uspešen (app + jobs + db + meilisearch kontejnerji tečejo)
- [ ] db:migrate + solid sheme naložene (solid_queue_jobs obstaja)
- [ ] db:seed (vloge, lokacije, kategorije)
- [ ] UserSyncJob (uporabniki + enote sinhronizirani)
- [ ] https://i.kl-kl.si dostopen, /up vrne 200
- [ ] Prijava, iskanje, predogled, OCR, thumbnaili delujejo v produkciji
- [ ] jobs kontejner obdeluje opravila (OCR, thumbnaili, e-mail)

## Out of scope (kasneje)
- S3 za Active Storage (zaenkrat lokalni disk + volume tabla_storage)
- Backup strategija (PG dump + storage volume)
- Monitoring / alerting
