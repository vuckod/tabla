# Naloga 40: Polish + manjkajoč uvoz (barva povezav, footer, NOE zapisniki)

## Cilj
Tri ločene stvari po pripravi za uradno predajo:
- **A) Barva bloka "povezave"** — trenutno `blue`, dokumenti `indigo`, preveč podobni. Spremenimo v `teal`.
- **B) Footer z verzijo** — kopiraj vzorec iz Delovodnika (BASE_VERSION, git hash, datum zagona, copyright).
- **C) Manjkajoč uvoz: NOE zapisniki** — naloga 25 je uvozila samo SIKLND zapisniki (`#tabs-3`), spregledala NOE (`#tabs-4`). 4 dokumenti.

POMEMBNO: naloga 25 je že commitana in deployana — NE spreminjaj nje. Naloga 40 dopolni z manjkajočim
uvozom (idempotenten — obstoječi SIKLND zapisniki bodo preskočeni prek `source_url`).

## Del A: Barva bloka povezav (indigo → teal)

### A1. Preveri obstoječo paleto v helperju
Glej `app/helpers/blocks_helper.rb` (ali kjer so `block_header_classes` / `block_body_classes`).
Helper verjetno podpira nekaj barv (`indigo`, `blue`, `yellow`, `green`, `red`, ...). Preveri,
ali `teal` že obstaja. Če ne, dodaj.

Pričakovan vzorec (po obstoječih):
```ruby
COLOR_CLASSES = {
  # ...
  teal: {
    header: "bg-teal-600 text-white dark:bg-teal-700",
    body: "bg-teal-50 text-slate-900 dark:bg-teal-950/40 dark:text-slate-100"
  }
}
```
Točne odtenki naj se ujemajo z obstoječim stilom (npr. yellow uporablja `bg-yellow-200`/`bg-yellow-100`,
indigo `bg-indigo-700` ipd. — naj bo teal v sorodni intenziteti).

### A2. Spremeni klic v `home/_external_links.html.erb`
```erb
<%= render layout: "shared/block",
    locals: { title: t("views.home.links_block"), color: :teal } do %>
```
(Spremeni `:blue` v `:teal`.)

### A3. Posodobi notranje obrobe (border-teal namesto border-blue)
V `home/_external_links.html.erb` so verjetno `border-blue-300/50` ali podobne — zamenjaj
z `border-teal-300/50` (in `dark:border-teal-700/50`). Preveri tudi spodnji link "Vse povezave →"
(verjetno `border-blue-...`).

POZOR: tudi `link_to` za "Vse povezave →" lahko ima `hover:text-blue-*` — zamenjaj z `hover:text-teal-*`.

### A4. Tailwind build
```bash
docker compose run --rm rails_app bin/rails tailwindcss:build
```
(Razredi teal-* niso bili še uporabljeni, treba je rebuildati CSS.)

## Del B: Footer z verzijo (vzorec Delovodnik)

### B1. `config/initializers/constants.rb` (novi file)
```ruby
# frozen_string_literal: true

# Hash revizije: v produkciji (Kamal) iz KAMAL_REVISION env, lokalno iz git.
git_hash = ENV["KAMAL_REVISION"].presence
git_hash ||= begin
  `git rev-parse --short HEAD 2>/dev/null`.strip
rescue StandardError
  nil
end
git_hash = nil if git_hash.blank?

BASE_VERSION = "0.1.0"

short_hash = git_hash.present? ? git_hash[0..6] : nil
TABLA_VERSION = short_hash.present? ? "#{BASE_VERSION} (#{short_hash})" : BASE_VERSION

# Datum in čas zagona procesa (ob deployu / restartu strežnika).
RELEASE_DATE = Time.current.strftime("%d. %m. %Y %H:%M")
```
Predlog `BASE_VERSION = "0.1.0"` — Tabla je nova, lahko začnemo s 0.1.0. Lahko prilagodiš
po želji (npr. "1.0.0" ob uradni predaji).

### B2. Footer v `app/views/layouts/application.html.erb`
Dodaj **pred zaključno `</body>`** (ali za main, pred turbo_frame "modal"):
```erb
<footer class="border-t border-slate-200 bg-white/50 py-4 text-center text-xs text-slate-400
               print:hidden dark:border-slate-800 dark:bg-slate-900/50 dark:text-slate-500"
        role="contentinfo">
  <div class="flex flex-wrap items-center justify-center gap-x-4 gap-y-1 px-4">
    <span><span class="font-medium text-slate-500 dark:text-slate-400">Verzija</span> <%= TABLA_VERSION %></span>
    <span><span class="font-medium text-slate-500 dark:text-slate-400">Zagon</span> <%= RELEASE_DATE %></span>
    <span>© <%= Time.zone.now.year %> Dejan Vučko</span>
  </div>
</footer>
```

### B3. body class flexbox (da footer ostane spodaj)
Da footer ne lebdi sredi strani na kratkih straneh, body mora biti flex column z min-h-screen:
```erb
<body class="bg-slate-50 dark:bg-slate-900 text-slate-900 dark:text-slate-100
             min-h-screen flex flex-col">
```
In `main` naj ima `flex-1`:
```erb
<main class="<%= page_container_classes %> py-6 flex-1">
```

## Del C: NOE zapisniki uvoz

### C1. Razširi `DOCUMENT_TABLES` v `LegacyTableImporter`
V `app/services/legacy_table_importer.rb` dodaj nov vnos za NOE zapisniki:
```ruby
DOCUMENT_TABLES = [
  {
    selector: "table#dokumenti",
    label: "Pravilniki, navodila, ukrepi",
    layout: :full,
    document_unit: :both
  },
  {
    selector: "#tabs-3 table#zapisniki",
    label: "Zapisniki sestankov delavcev - knjižnica",
    layout: :simple,
    default_category: "Zapisniki sestankov delavcev - knjižnica",
    document_unit: :library
  },
  {
    # NOVO — NOE zapisniki iz tabs-4
    selector: "#tabs-4 table#zapisniki",
    label: "Zapisniki sestankov delavcev - NOE",
    layout: :simple,
    default_category: "Zapisniki sestankov delavcev - NOE",
    document_unit: :theatre
  },
  {
    selector: "table#svet",
    label: "Zapisniki sej sveta zavoda",
    layout: :simple,
    default_category: "Zapisniki sej sveta zavoda",
    document_unit: :both
  },
  {
    selector: "table#obvestila",
    label: "Obvestila za zaposlene",
    layout: :full,
    document_unit: :both
  }
].freeze
```

POZOR: `ParsedDocument` `unit` polje že obstaja (vsebuje sufiks iz "Vrsta" stolpca, npr. "KKCL–LKKK"),
NE meša z Document.unit enum. Dodaj **NOVO** polje `document_unit` v `ParsedDocument`:
```ruby
ParsedDocument = Data.define(
  :table_label, :title, :url, :category_name, :unit, :document_unit, :published_at, :pdf
)
```

V `parse_document_row` posreduj `config[:document_unit] || :both`:
```ruby
ParsedDocument.new(
  # ...
  document_unit: config[:document_unit] || :both,
  # ...
)
```

V `import_document_record` nastavi `unit:`:
```ruby
document = Document.new(
  title: parsed.title,
  description: parsed.unit.present? ? "Enota: #{parsed.unit}" : nil,
  document_category: category,
  unit: parsed.document_unit,   # NOVO
  published_at: parsed.published_at&.in_time_zone || Time.current,
  source_url: parsed.url,
  internal_only: false,
  notify_staff: false
)
```

### C2. Posodobi obstoječe SIKLND zapisniki (rake task)
Obstoječi SIKLND zapisniki imajo zdaj verjetno `unit: :both` (privzeti). Po nalogi 40 jih posodobimo
na `unit: :library`. Dodaj rake task v `lib/tasks/import.rake`:

```ruby
desc "Posodobi unit obstoječih uvoženih dokumentov glede na kategorijo"
task update_units: :environment do
  updated = 0
  Document.find_each do |doc|
    next unless doc.document_category

    new_unit = case doc.document_category.name
               when /knjižnica/i then :library
               when /noe/i       then :theatre
               else                   :both
               end
    next if doc.unit.to_s == new_unit.to_s

    doc.update_column(:unit, Document.units[new_unit])
    updated += 1
    puts "  Posodobil: #{doc.title} → #{new_unit}"
  end
  puts "Posodobljeno #{updated} dokumentov."
end
```
Zaženi enkrat po uvozu NOE: `bin/rails import:update_units`.

### C3. Zaženi uvoz v produkciji
Najprej suhi tek:
```bash
kamal app exec "bin/rails import:legacy_dry"
```
Pričakuj: 4 NOE zapisniki "BI UVOZIL", obstoječi (SIKLND zapisniki, dokumenti, obvestila, povezave)
"PRESKOČENO (že v bazi)".

Nato dejanski uvoz:
```bash
kamal app exec "bin/rails import:legacy"
kamal app exec "bin/rails import:update_units"
kamal app exec "bin/rails thumbnails:generate_missing"
```
4 novi PDF-ji bodo dobili OCR + thumbnail v ozadju (Solid Queue jobs kontejner, ~2 min).

### C4. Preverba
- `/documents?category_id=<NOE zapisniki ID>` → 4 dokumenti vidni
- Mailer obvestilo: če bi se ti dokumenti naložili z `notify_staff: true`, bi e-mail šel
  v NOE enoto (`unit: :theatre` → knjiznica + uprava + gledalisce, glede na for_document_unit).
  Pri uvozu je `notify_staff: false`, torej obvestila ne pošlje — to je pravilno za uvoz.

## Reference
- `delovodnik_rails/config/initializers/constants.rb` (del B vzorec)
- `delovodnik_rails/app/views/layouts/application.html.erb` (footer vzorec)
- `app/services/legacy_table_importer.rb` (del C)
- `app/helpers/blocks_helper.rb` ali kjer so block color classes (del A)

## Acceptance criteria

### Del A
- [ ] Helper podpira `:teal` (dodano, če ni)
- [ ] `_external_links.html.erb` uporablja `color: :teal`
- [ ] Obrobe in hover povezav v notranjosti uporabljajo `teal-*` namesto `blue-*`
- [ ] Tailwind rebuild pognan — teal razredi v CSS

### Del B
- [ ] `config/initializers/constants.rb` z `BASE_VERSION`, `TABLA_VERSION`, `RELEASE_DATE`
- [ ] Footer v layoutu prikazuje verzijo, datum zagona, copyright
- [ ] Footer skrit pri tisku (`print:hidden`)
- [ ] Body flex column + main flex-1 (footer ostane na dnu)
- [ ] V produkciji (Kamal): `TABLA_VERSION` vključuje `KAMAL_REVISION` (npr. "0.1.0 (6e24477)")

### Del C
- [ ] `LegacyTableImporter::DOCUMENT_TABLES` ima nov vnos za `#tabs-4 table#zapisniki`
- [ ] `ParsedDocument` razširjen z `document_unit`
- [ ] `Document.new` nastavi `unit: parsed.document_unit`
- [ ] `import:update_units` rake task posodobi obstoječe
- [ ] Suhi tek pokaže 4 NOE zapisniki kot "BI UVOZIL"
- [ ] Dejanski uvoz v produkciji ustvari 4 dokumente v kategoriji "Zapisniki sestankov delavcev - NOE"
- [ ] OCR + thumbnaili tečejo v ozadju
- [ ] SIKLND zapisniki dobijo `unit: :library`, NOE zapisniki `unit: :theatre`

## Test
1. Domača stran: blok povezav je teal (vidno različen od indigo dokumentov)
2. Footer: verzija + zagon + © prikazani (skrito pri tisku)
3. `/documents?category_id=...` (NOE kategorija): 4 dokumenti
4. Document admin: `unit` polje pravilno za SIKLND/NOE zapisniki

## Out of scope
- Sprememba barve bloka "Aplikacije" (zelena ostane)
- Sprememba bloka "Dokumenti" (indigo ostane)
- Razširitev na druge `unit` posodobitve (samo iz kategorije)
