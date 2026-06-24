# Naloga 32: Uvoz telefonskih številk iz stare table v imenik

## Cilj
Uvozi telefonske številke iz stare table (4 bloki: SIKLND/NOE × zunanje/interne + GSM) v
imenik. Osebe ujemi s polnimi imeni uporabnikov iz Prisotnosti; oddelke ustvari kot "osebe"
z imenom oddelka; GSM osebne na osebo, službene/skupne na lokacijo. Idempotentno.

## Vir podatkov
HTML: `docs/KKC Lendava - Lendvai KKK  Vstopna stran za zaposlene.htm`, bloki `<ul id="intro">`
(SIKLND) in `<ul id="intro8">` (NOE). Struktura:
- `#mission` / `#mission8` — [SIKLND/NOE] Zunanje tel. št.
- `#services` / `#services8` — [SIKLND/NOE] Interne tel. št.
- `#services6` / `#services81` — [SIKLND/NOE] Ostale (centrala, GSM, službeni)

Vsak `<p>` ima vrstice `<b>ŠTEVILKA</b> - opis<br>`. Parsiraj številko (bold) + opis (za " - ").

## Odločitve (potrjene)
1. **Osebe:** ujemi skrajšano ime ("Dejan V.") s polnim uporabnikom iz Prisotnosti (User.ime + priimek)
2. **Oddelki/mesta:** ustvari kot Person z imenom oddelka (NE na lokacijo)
3. **GSM:** osebne na osebo (mobile kind); službene/skupne (031-333-401, izrecno "službeni")
   na lokacijo

## Podatki za uvoz (razčlenjeno)

### SIKLND (knjižnica, location short_code "SIKLND")
**Pari oseba/oddelek — zunanja + interna (ujemanje po imenu):**
| Ime/opis           | Zunanja      | Interna | Tip     |
|--------------------|--------------|---------|---------|
| dr. Judit Z. Cs.   | 574-25-80    | 580     | oseba   |
| Andreja S.         | 574-25-81    | 581     | oseba   |
| Dejan V.           | 574-25-82    | 582     | oseba   |
| odrasli izp.       | 574-25-83    | 583     | oddelek |
| Brigita F.         | 574-25-85    | 585     | oseba   |
| Sabina D.          | 574-25-86    | 586     | oseba   |
| mladinski izp.     | 574-25-87    | 587     | oddelek |
| Gordan G.          | 574-25-88    | 588     | oseba   |
| Klara T.           | 574-25-89    | 589     | oseba   |
| Melita D.          | 621-36-50    | 650     | oseba   |
| Ines               | 621-36-51    | 651     | oseba   |
| SM oddelek         | 621-36-52    | 652     | oddelek |

**Ostale:**
- 575-13-53 - centrala → lokacija SIKLND (že v seedu — find_or_create po label, ne podvajaj)
- GSM: 040-701-515 - dr. Judit Z. Cs. (mobile → oseba)
- GSM: 040-475-457 - Sabina D. (mobile → oseba)
- GSM: 031-333-401 - službeni (mobile → lokacija SIKLND, label "Službeni")
- A1 Xpert linki (uc.a1.si...) — PRESKOČI (niso telefonske; lahko ločen uvoz povezav, a ne tu)

### NOE (gledališče, location short_code "NOE")
| Ime/opis      | Zunanja    | Interna | Tip     |
|---------------|------------|---------|---------|
| pisarna zg.   | 577-60-20  | 220     | oddelek |
| Sanja B. H.   | 577-60-22  | 222     | oseba   |
| blagajna      | 577-60-24  | 224     | oddelek |
| Nikolaj B.    | 577-60-26  | 226     | oseba   |
| kavarna       | 577-60-28  | 228     | oddelek |
| Gordana Š.    | 577-60-30  | 230     | oseba   |

**Ostale:**
- 577-60-24 - blagajna (DUP z zgornjo blagajno — idempotentno preskoči)
- GSM: 041-680-501 - Nikolaj B. (mobile → oseba, ker je naveden kot oseba, NE službeni)

## Koraki

### 1. Razlikovanje oseba vs oddelek
Oddelki (NE osebe): "odrasli izp.", "mladinski izp.", "SM oddelek", "pisarna zg.", "blagajna",
"kavarna", "centrala". Heuristika: če opis NE ustreza vzorcu osebnega imena (Ime + Priimek/
začetnica, npr. velika začetnica + presledek + velika začetnica s piko), je oddelek. PRIPOROČILO:
ker je naborov malo (~18), uporabi EKSPLICITEN seznam oddelkov (konstanta) — zanesljivejše kot
heuristika. Vse, kar ni v seznamu oddelkov in ima obliko imena, je oseba.

### 2. Ujemanje osebe → uporabnik (polno ime)
Za osebo s skrajšanim imenom "Dejan V.":
- Razčleni: prvo besedo = ime ("Dejan"), preostale = priimek začetnice ("V.")
- Za "dr. Judit Z. Cs.": odstrani naziv "dr.", ime = "Judit", priimek začetnice "Z. Cs."
- Najdi uporabnike: `User.where("LOWER(ime) = ?", ime.downcase)` in priimek se začne z začetnico
  prve črke priimka (npr. "V" → `priimek ILIKE 'V%'`)
- **Natanko en zadetek** → uporabi polno ime uporabnika (User.ime, User.priimek)
- **Nič ali več zadetkov** → uporabi skrajšano ime KOT JE + zabeleži v povzetku "ročni pregled"
- POZOR: ujemanje samo predlaga; ob dvoumnosti NE ugibaj (raje skrajšano ime)

Razčlenjevanje začetnic: "Z. Cs." → prva črka priimka "Z" (ali poskusi obe: "Z" in "Cs").
Robustno: vzemi prvo veliko črko prvega dela priimka.

### 3. Ustvari/posodobi Person + telefonske številke
Za vsako osebo/oddelek:
```ruby
# Idempotentnost: ujemi po imenu (ali po številki, če oseba že obstaja)
person = find_or_create_person(name_data, location)
# name_data: { first_name:, last_name:, is_department:, matched_user: }

# Telefonske številke (idempotentno po številki)
[external, internal, mobile].compact.each do |num_data|
  next if person.phone_numbers.exists?(number: num_data[:number])
  person.phone_numbers.create!(number: num_data[:number], kind: num_data[:kind], label: num_data[:label])
end
```
- Oseba: `first_name` + `last_name` (iz ujemanja ali skrajšano)
- Oddelek: `last_name` = ime oddelka (npr. "Odrasli izposoja"), `first_name` prazen, morda
  `position_title` = "Oddelek" za razlikovanje
- `location_id` = SIKLND ali NOE lokacija
- `active: true`
- Idempotentnost: `Person.find_or_initialize_by` po (first_name, last_name, location_id) ALI
  preveri obstoj prek telefonske številke (če številka že obstaja, oseba je uvožena)

### 4. Lokacijske številke (centrala, službeni GSM)
- 575-13-53 centrala → SIKLND lokacija (že v seedu kot "Centrala" — preveri, ne podvajaj)
- 031-333-401 službeni → SIKLND, label "Službeni", kind mobile
- find_or_create_by(number:) na location.phone_numbers (idempotentno)

### 5. Importer service
`app/services/legacy_phone_importer.rb`:
```ruby
class LegacyPhoneImporter
  DEPARTMENTS = ["odrasli izp.", "mladinski izp.", "sm oddelek", "pisarna zg.",
                 "blagajna", "kavarna", "centrala"].freeze
  LOCATION_NUMBERS = { "031-333-401" => "Službeni" }.freeze   # na lokacijo, ne osebo

  def self.call(html_path, dry_run: false)
    new(html_path, dry_run: dry_run).call
  end
  # parsira intro (SIKLND) + intro8 (NOE), ujema pare zunanja/interna po imenu,
  # ujema osebe z uporabniki, ustvari Person + phone_numbers, per-record rescue,
  # izpiše povzetek (osebe/oddelki/lokacijske št., ujemanja, ročni pregled)
end
```
Suhi tek (`dry_run: true`) — izpiše, kaj BI uvozil + ujemanja, brez shranjevanja.

### 6. Rake task
`lib/tasks/import.rake` (dodaj k obstoječemu):
```ruby
namespace :import do
  desc "Uvoz telefonskih iz stare table"
  task :phones, [:path] => :environment do |_t, args|
    LegacyPhoneImporter.call(args[:path] || DEFAULT_HTML_PATH)
  end
  desc "Suhi tek telefonskih"
  task :phones_dry, [:path] => :environment do |_t, args|
    LegacyPhoneImporter.call(args[:path] || DEFAULT_HTML_PATH, dry_run: true)
  end
end
```

### 7. Predpogoj: enote uporabnikov sinhronizirane
Ujemanje oseb z uporabniki zahteva, da so uporabniki v bazi (so — 18 sinhroniziranih). Enota
ni potrebna za ujemanje imen, samo ime + priimek.

## Reference
- HTML: `docs/KKC Lendava...htm` (`#intro`, `#intro8`)
- `app/models/person.rb` (first_name, last_name, location_id, position_title, active)
- `app/models/phone_number.rb` (kind enum external/internal/mobile/fax, person/location)
- `app/models/user.rb` (ime, priimek — za ujemanje)
- `app/services/legacy_table_importer.rb` (vzorec parsiranja + idempotentnosti)
- `db/seeds.rb` (obstoječe SIKLND številke — ne podvajaj)

## Acceptance criteria
- [ ] Suhi tek (`import:phones_dry`) izpiše osebe/oddelke/številke + ujemanja, brez shranjevanja
- [ ] Osebe ujete s polnimi imeni uporabnikov (kjer zanesljivo); dvoumne → skrajšano + opozorilo
- [ ] Oddelki ustvarjeni kot Person z imenom oddelka
- [ ] Pari zunanja+interna pravilno združeni po imenu na isto osebo
- [ ] Osebne GSM na osebo (mobile); službeni 031-333-401 na lokacijo
- [ ] Lokacijske številke (centrala) ne podvojene z obstoječim seedom
- [ ] Idempotentno (ponovni zagon ne podvaja — po številki)
- [ ] Per-record rescue + povzetek (osebe/oddelki/ujemanja/ročni pregled/napake)
- [ ] A1 Xpert linki preskočeni

## Test
1. `import:phones_dry` → preglej ujemanja imen (zlasti, ali so polna imena pravilna)
2. Po potrditvi: `import:phones`
3. Preveri imenik (`/` ali `/persons`) → osebe s polnimi imeni + zunanja/interna/GSM, oddelki

## Out of scope
- A1 Xpert povezave (ločeno, če želeno)
- Povezovanje Person ↔ User (ostajata ločena; samo ime kopiramo)
- Ročno čiščenje dvoumnih ujemanj (admin to uredi prek UI po uvozu)
