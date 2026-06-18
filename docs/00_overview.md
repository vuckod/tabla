# Intranet KL-KL — Pregled projekta

## Kratek opis

Interna spletna stran (intranet) Knjižnice Lendava, ki nadomešča obstoječo PHP "tablo" (`tabla.kl-kl.si`).
Namenjena je **izključno zaposlenim** znotraj organizacije.

Glavne funkcionalnosti:
- **Telefonski imenik** (interne/eksterne številke, GSM, e-pošta) z admin urejanjem
- **Povezave** do internih aplikacij (Prisotnost, Delovodnik, COBISS, SharePoint…) in zunanjih virov
- **Dokumenti** — nalaganje, kategorizacija, OCR, iskanje in objava internih aktov, zapisnikov, obvestil (PDF)
- **Obvestila** — opcijsko e-mail obvestilo zaposlenim ob objavi novega dokumenta

## Tehnološki stack

| Komponenta         | Tehnologija                                | Opomba                                                          |
| ------------------- | ------------------------------------------ | --------------------------------------------------------------- |
| Framework           | Ruby on Rails 8.1.2                        | Identično Prisotnosti in Delovodniku                            |
| Ruby                | 3.4.x (enako kot ostala projekta)          |                                                                 |
| Baza                | PostgreSQL 16                              | Nov accessory v Kamal, ločen port                               |
| Asset pipeline      | Propshaft + Importmap                      |                                                                 |
| Frontend            | Hotwire (Turbo + Stimulus) + Tailwind CSS  |                                                                 |
| Iskanje             | Meilisearch (deljena instanca z Delovodn.) | Isti URL/key, ločeni indeksi                                    |
| OCR                 | Tesseract (`slv+hun`) + pdftoppm/pdfunite  | Ista koda kot v Delovodniku                                     |
| Asinhronska opravila| Solid Queue                                |                                                                 |
| Cache / Cable       | Solid Cache / Solid Cable                  |                                                                 |
| Avtentikacija       | has_secure_password + API sync s Prisotnostjo | Pot A: read-only API endpoint                                |
| Avtorizacija        | Pundit                                     |                                                                 |
| Revizijska sled     | Audited gem                                | Na dokumentih in spremembah kontaktov                           |
| Analitika           | Ahoy (obiski, prenosi dokumentov)          |                                                                 |
| Deploy              | Kamal 2 → Docker na 193.2.53.52            |                                                                 |
| Domena              | `i.kl-kl.si`                               | Kamal proxy, SSL prek Nginx                                     |

## Strežniška infrastruktura

Vse tri aplikacije (Prisotnost, Delovodnik, Intranet) tečejo na **istem strežniku** `193.2.53.52`.

```
┌─────────────────────────────────────────────────────────┐
│  193.2.53.52  (Ubuntu, Kamal 2, Docker)                 │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ Prisotnost   │  │ Delovodnik   │  │  Intranet    │   │
│  │ p.kl-kl.si   │  │ d.kl-kl.si   │  │ i.kl-kl.si   │   │
│  │ port: 3000   │  │ port: 4000   │  │ port: 5000   │   │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘   │
│         │                 │                 │            │
│  ┌──────┴───────┐  ┌──────┴───────┐  ┌──────┴───────┐   │
│  │ PG :5433     │  │ PG :5434     │  │ PG :5435     │   │
│  │ prisotnost_  │  │ delovodnik_  │  │ intranet_    │   │
│  │ production   │  │ production   │  │ production   │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
│                                                         │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Meilisearch :7700 (deljena instanca)              │  │
│  │  indeksi: Document, IncomingMail, OutgoingMail,    │  │
│  │           IntranetDocument                         │  │
│  └────────────────────────────────────────────────────┘  │
│                                                         │
│  ┌──────────────┐                                       │
│  │ Nginx        │  → reverse proxy → Kamal proxy       │
│  │ :80 / :443   │  → SSL termination                   │
│  └──────────────┘                                       │
└─────────────────────────────────────────────────────────┘
```

## Avtentikacija — API sync s Prisotnostjo

### Princip

Prisotnost je **single source of truth** za zaposlene. Intranet ne upravlja uporabnikov sam,
temveč jih pridobi in sinhronizira prek read-only API-ja.

### Flow

```
1. Uporabnik odpre i.kl-kl.si → vidi login formo
2. Vnese username + geslo
3. Intranet pošlje POST /api/v1/authenticate na Prisotnost
   - body: { username, password }
   - header: Authorization: Bearer <INTRANET_API_TOKEN>
4. Prisotnost preveri credentials, vrne:
   - 200 + { user: { id, username, ime, priimek, email, roles: [...] } }
   - 401 če napačno geslo
5. Intranet ustvari/posodobi lokalni User zapis (mirror)
6. Shrani session[:user_id]
```

### Periodična sinhronizacija

- Solid Queue recurring job (`recurring.yml`): vsako uro kliče `GET /api/v1/users`
- Posodobi ime, priimek, email, vloge, status (onemogočen/aktiven)
- Nove uporabnike doda, deaktivirane označi

### Vloge (preslikava)

V Prisotnosti se ustvarijo dodatne vloge, ki se preslikajo v Intranet:

| Vloga v Prisotnosti     | Vloga v Intranetu | Pravice                                      |
| ------------------------ | ----------------- | -------------------------------------------- |
| `intranet_admin`         | admin             | Vse: CRUD kontaktov, povezav, dokumentov, uporabnikov |
| `intranet_urednik`       | urednik           | Objava dokumentov, urejanje kontaktov/povezav |
| `intranet_bralec` (ali privzeto vsi) | bralec | Branje vsega, prenos dokumentov              |

## Vloge in pravice (Pundit)

| Vir / akcija               | admin | urednik | bralec |
| --------------------------- | ----- | ------- | ------ |
| Kontakti — branje          | ✓     | ✓       | ✓      |
| Kontakti — urejanje        | ✓     | ✓       | ✗      |
| Povezave — branje          | ✓     | ✓       | ✓      |
| Povezave — urejanje        | ✓     | ✓       | ✗      |
| Dokumenti — branje         | ✓     | ✓       | ✓ *    |
| Dokumenti — branje (internal_only) | ✓ | ✓   | ✗      |
| Dokumenti — objava/urejanje| ✓     | ✓       | ✗      |
| Dokumenti — brisanje       | ✓     | ✗       | ✗      |
| Admin panel                 | ✓     | ✗       | ✗      |

\* `internal_only` dokumenti so vidni le admin in urednik vlogam.

## UI/UX smer

### Načela
- **Čist, moderen dizajn** — ne kopiramo starega PHP layouta
- **Ključne sekcije morajo biti takoj vidne**: telefonske številke, hitre povezave, zadnji dokumenti
- **Responsive** — prilagojeno za široke (desktop) in ozke (telefon/tablica) zaslone
- **Dark mode** — Tailwind `dark:` razredi, preklop v headeru (kot Delovodnik)
- **Tailwind barvna paleta** — Indigo za primarne akcije (konsistentno z Delovodnikom)

### Osnovna struktura strani

```
┌─────────────────────────────────────────────────────┐
│  Header: logo + nav + iskanje + dark mode + user    │
├────────────────────────┬────────────────────────────┤
│                        │                            │
│  Telefonski imenik     │  Hitre povezave            │
│  (po lokacijah,        │  (Prisotnost, Delovodnik,  │
│   filtriraj/išči)      │   COBISS, SharePoint, …)   │
│                        │                            │
├────────────────────────┴────────────────────────────┤
│                                                     │
│  Dokumenti — zadnje objave                          │
│  [tabbed: Vsi | Interni akti | Obvestila |          │
│   Zapisniki SSZ | Zapisniki NOE | …]                │
│  Iskanje po naslovu / vsebini (OCR)                │
│                                                     │
├─────────────────────────────────────────────────────┤
│  Vse povezave (kategorizirane)                      │
│  COBISS | Pravni viri | Občine | NUK/IZUM | …      │
└─────────────────────────────────────────────────────┘
```

Na mobilnih napravah se stolpci zložijo vertikalno (imenik → povezave → dokumenti).

## Migracija s PHP

1. Nova Rails aplikacija se razvija vzporedno na `i.kl-kl.si`
2. Stara PHP tabla ostane na `tabla.kl-kl.si` brez sprememb
3. Ko je nova aplikacija pripravljena in testirana:
   - DNS preusmeritev `tabla.kl-kl.si` → `i.kl-kl.si` (ali HTTP 301 redirect)
   - Stara PHP stran se ugasne
4. Ni potrebe po avtomatski migraciji podatkov — kontakte, povezave in kategorije dokumentov
   se ročno vnese (seedanje) ali uvozi iz preprostih CSV/YAML datotek

## Razvojno okolje

Enako kot Delovodnik:
- **Docker Compose** za development (PostgreSQL, opcijsko Meilisearch)
- **.devcontainer** za VS Code / Cursor (Ruby, Node, Tesseract, Poppler)
- **Dockerfile** produkcijski (multi-stage, vključuje tesseract-ocr, tesseract-ocr-slv, tesseract-ocr-hun, poppler-utils)

## Faze razvoja

### Faza 1 — MVP (cilj: delujoča zamenjava PHP table)
- [ ] Skelet projekta (Rails new, Gemfile, Docker, Kamal)
- [ ] API endpoint v Prisotnosti + auth flow v Intranetu
- [ ] Modeli: Location, Person, PhoneNumber, LinkCategory, Link, DocumentCategory, Document
- [ ] Osnovni layout (header, responsive mreža, dark mode)
- [ ] Telefonski imenik (prikaz + admin CRUD)
- [ ] Povezave (prikaz po kategorijah + admin CRUD)
- [ ] Dokumenti (upload PDF, kategorije, prikaz seznama, prenos)
- [ ] OCR pipeline (Tesseract slv+hun, asinhrono)
- [ ] Iskanje po dokumentih (Meilisearch)
- [ ] Seed podatkov (kontakti, povezave iz obstoječe PHP table)
- [ ] Deploy na i.kl-kl.si

### Faza 2 — Izboljšave
- [ ] E-mail obvestila ob objavi dokumenta ("obvesti delavce")
- [ ] Globalni iskalnik (Cmd+K paleta — kot v Delovodniku)
- [ ] Ahoy analitika (kdo je prenesel dokument, obiskanost)
- [ ] Krajevne knjižnice — urnik z lokacijami
- [ ] RSS feed za nove dokumente

### Faza 3 — Napredne funkcionalnosti
- [ ] SSO med Prisotnostjo, Delovodnikom in Intranetom (skupni JWT)
- [ ] Obvestila v realnem času (Turbo Streams prek Action Cable)
- [ ] Integracija s SharePoint (prikaz zadnjih deljenih datotek)

## Imenovanje projekta

- **Ime repozitorija:** `intranet_rails`
- **Kamal service:** `intranet-app`
- **Docker image:** `vucko/intranet-app`
- **Baza:** `intranet_production`
- **Gitea repo:** `git.kl-kl.si/vucko/intranet_rails`

## Datotečna struktura docs/

```
docs/
  00_overview.md                  ← ta dokument
  01_data_model.md                — modeli, migracije, relacije, indeksi
  02_authentication_api.md        — API v Prisotnosti, auth flow, sync
  03_documents_ocr.md             — upload, OCR, Meilisearch, searchable PDF
  04_ui_design.md                 — layout, komponente, barvna shema, responsive
  05_deployment.md                — deploy.yml, Dockerfile, DNS, Nginx
  
  tasks/                          — naloge za Cursor
    01_skeleton.md                — Rails new, Gemfile, Docker, .devcontainer
    02_api_prisotnost.md          — API endpoint v projektu Prisotnost
    03_auth_flow.md               — Login, session, user sync v Intranetu
    04_models_migrations.md       — Vsi modeli in migracije
    05_seeds.md                   — Začetni podatki (kontakti, povezave)
    06_layout_nav.md              — Application layout, header, dark mode
    07_contacts_ui.md             — Telefonski imenik: prikaz + admin CRUD
    08_links_ui.md                — Povezave: prikaz + admin CRUD
    09_documents_upload.md        — Upload, kategorije, seznam, prenos
    10_ocr_pipeline.md            — OCR job, service, log
    11_meilisearch_setup.md       — Meilisearch indeks, iskanje
    12_deploy_kamal.md            — Kamal deploy, DNS, first deploy
    ...
```

Vsak `tasks/XX_*.md` ima obvezno strukturo:
- **Cilj**: v dveh stavkih
- **Predpogoji**: kaj mora biti končano
- **Koraki**: oštevilčen seznam z natančnimi navodili
- **Reference**: kateri fajli iz Delovodnika/Prisotnosti so vzorec
- **Acceptance criteria**: kako preveriš uspešnost
- **Out of scope**: kaj NE sodi v to nalogo

## Konvencije (prenešene iz Delovodnika)

- Vsi komentarji v kodi in commit messages: **slovensko**
- Imena modelov, kontrolerjev, metod: **angleško** (Rails konvencija)
- UI prevodi: `config/locales/sl.yml`
- Iskanje vedno z `unaccent` + trigram indeksi
- Audited na vseh modelih z uporabniškimi podatki
- UserStampable concern za `created_by_id` / `updated_by_id`
- Pundit policy za vsak kontroler, `policy_scope` za sezname
- Tailwind z `dark:` razredi povsod
- Responsive: `sm:` / `md:` / `lg:` breakpointi
