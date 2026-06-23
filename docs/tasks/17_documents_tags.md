# Naloga 17: Dokumenti z značkami in filtrom

## Cilj
Spodnji široki blok z vsemi dokumenti na enem mestu. Vsak dokument ima barvno značko
(kategorija: interni akt, aneks, obvestilo delavcem...). Na vrhu filter po značkah. Privzeto
najnovejši dokument na vrhu. Ena značka na dokument (prek obstoječega `document_category_id`).

## Predpogoji
- Naloga 14 (layout) končana
- Modeli `Document`, `DocumentCategory` + admin CRUD obstajajo (iz naloge 09)

## Kontekst
- "Značka" = `DocumentCategory` (odločitev: ena značka na dokument prek obstoječega
  `document_category_id`). NE ustvarjaj novega Tag modela.
- `DocumentCategory` ima `color` stolpec (že v shemi) — uporabi za barvo značke.

## Koraki

### 1. Razširi seed kategorij z barvami
V `db/seeds.rb` dopolni obstoječe `DocumentCategory` zapise s `color` vrednostjo
(Tailwind barva ali hex), npr.:
- Interni akti → `red`
- Obvestila za zaposlene → `amber`
- Zapisniki sej sveta zavoda → `blue`
- Zapisniki knjižnica → `green`
- Zapisniki NOE → `purple`
- Pravilniki → `slate`
Dodaj tudi morebitne nove značke, ki jih je omenil uporabnik: "aneks", "obvestilo delavcem".
Seed idempotenten (posodobi `color` na obstoječih prek `find_or_create_by` + `update`).

### 2. Helper za barvo značke
`DocumentsHelper#category_badge(category)` — vrne `<span>` z ustrezno Tailwind barvo glede
na `category.color`. Mapa barv → razredi (npr. `red` → `bg-red-100 text-red-800
dark:bg-red-900/40 dark:text-red-200`).

### 3. Partial `home/_documents.html.erb` — spodnji blok
- Naslov "Dokumenti"
- **Filter značk na vrhu:** vrstica gumbov/čipov za vsako kategorijo + "Vse". Klik filtrira
  seznam. Uporabi Turbo Frame (`documents_list`), da filter ne osveži cele strani.
- **Seznam dokumentov:** najnovejši (`published_at DESC`) na vrhu. Vsak: značka (barvna),
  naslov, datum objave, gumb Prenesi. Oznaka "Interno" če `internal_only`.
- Paginacija s `pagy` (Turbo Frame aware, kot v nalogi 09).

### 4. Kontroler
Razširi obstoječi `home#index` ali uporabi obstoječi `DocumentsController#index` z Turbo Frame.
Filter prek `params[:category_id]`. Spoštuj `visible_to(current_user)` (internal_only varnost).
Najnovejši na vrhu: `Document.visible_to(current_user).published.recent`.

### 5. Polna stran `/documents` ostane
Obstoječi `/documents` (naloga 09) ostane kot samostojen pogled. Domača stran ima isto
funkcionalnost vgrajeno v spodnji blok. Razmisli o ponovni uporabi istega partiala za seznam,
da se logika ne podvaja (npr. `documents/_list.html.erb` deljen med home in documents#index).

## Reference
- `docs/04_ui_design.md` — spodnji široki blok, značke
- `app/controllers/documents_controller.rb` (iz naloge 09) — Turbo Frame, visible_to, pagy
- `app/policies/document_policy.rb` — varnostni scope
- Priložen PHP screenshot — referenca zavihkov dokumentov

## Acceptance criteria
- [ ] Spodnji blok prikaže vse vidne objavljene dokumente, najnovejši na vrhu
- [ ] Vsak dokument ima barvno značko (kategorijo)
- [ ] Filter po značkah deluje prek Turbo Frame (brez polnega reloada)
- [ ] `internal_only` dokumenti niso vidni bralcem (spoštovan `visible_to` scope)
- [ ] Prenos dokumenta deluje
- [ ] Paginacija deluje znotraj Turbo Frame
- [ ] Logika seznama ni podvojena med home in /documents (deljen partial)
- [ ] Responsive

## Out of scope
- OCR vsebina (naloga za pozneje)
- Iskanje po vsebini z Meilisearch — naloga 18 (osnovni iskalnik) + kasnejša Meilisearch naloga
- Novi Tag model (uporabljamo DocumentCategory)
