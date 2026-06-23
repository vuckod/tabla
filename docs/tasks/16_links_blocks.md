# Naloga 16: Povezave kot živahna bloka (interne app + zunanje)

## Cilj
Dva ozka stolpca (vsak 2/12) na desni strani zgornjega dela: zeleni blok z internimi
aplikacijami (Prisotnost, Delovodnik, SharePoint...) in modri blok z zunanjimi povezavami
(IZUM, občine, NUK...). Uporablja obstoječi `Link`/`LinkCategory` model iz naloge 08.

## Predpogoji
- Naloga 14 (layout, barvni bloki) končana
- Modeli `Link`, `LinkCategory` + seed obstajajo (iz naloge 08)

## Koraki

### 1. Razlikovanje internih in zunanjih povezav
Obstoječi `Link` ima `internal_app: boolean`. Uporabi to za delitev:
- **Interne aplikacije** (zeleni blok): `Link.internal_apps` (`where(internal_app: true)`)
- **Zunanje povezave** (modri blok): `Link.where(internal_app: false)`, grupirane po
  `LinkCategory` (IZUM, občine, NUK, pravni viri...)

### 2. Partial `home/_internal_apps.html.erb` — zeleni blok
- `shared/_block` z `color: green`, naslov "Aplikacije"
- Seznam internih app povezav z ikono (🏠 ali Heroicon), večji klikalni elementi
- Vsaka povezava odpre v novem zavihku če `new_tab?`

### 3. Partial `home/_external_links.html.erb` — modri blok
- `shared/_block` z `color: blue`, naslov "Povezave"
- Povezave grupirane po kategoriji (manjši podnaslovi znotraj bloka)
- Kompakten seznam (ozek stolpec — pazi na dolge nazive, uporabi `truncate` ali manjšo pisavo)
- Link "Vse povezave →" na `links_path` v nogi

### 4. Seed dopolnitev
Preveri, da seed (`db/seeds.rb`) vsebuje dovolj realnih povezav za oba bloka:
- Interne: Prisotnost, Delovodnik, SharePoint (dodaj če manjka), Statistika, Naslovi...
- Zunanje: IZUM, NUK, COBISS, občine (Lendava, Dobrovnik...), pravni viri
Glej originalni PHP screenshot za poln seznam zunanjih povezav (rumeni stolpec).
Seed naj bo idempotenten (`find_or_create_by`).

## Reference
- `docs/04_ui_design.md` — zelena/modra barva, 2/2 stolpca
- `app/models/link.rb`, `link_category.rb`
- `app/helpers/links_helper.rb` (iz naloge 08) — `link_to_entry` helper
- Priložen PHP screenshot — poln seznam zunanjih povezav

## Acceptance criteria
- [ ] Zeleni blok z internimi aplikacijami (desni stolpec 1)
- [ ] Modri blok z zunanjimi povezavami, grupiranimi po kategoriji (desni stolpec 2)
- [ ] Interne povezave odprejo prave aplikacije (Prisotnost, Delovodnik...)
- [ ] Zunanje povezave odprejo v novem zavihku
- [ ] Oba bloka responsive (na mobilnem pod imenikom, polna širina)
- [ ] SharePoint povezava dodana (če je še ni)

## Out of scope
- Admin CRUD povezav (že obstaja iz naloge 08)
- Štetje klikov (Ahoy) — morebitna kasnejša faza
