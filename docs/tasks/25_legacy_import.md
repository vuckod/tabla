# Naloga 25: Uvoz dokumentov in povezav iz stare PHP table

## Cilj
Enkratni (a ponovljiv/idempotenten) uvoz vsebine iz stare PHP "table" v Tablo:
- **Dokumenti** iz 5 HTML tabel (pravilniki, zapisniki knjižnica, zapisniki NOE, seje sveta,
  obvestila) — PRENESI dejanske PDF-je z URL-jev v Active Storage (sproži OCR + Meilisearch)
- **Značke**: ustvari novo `DocumentCategory` za vsako "Vrsta" vrednost
- **Povezave** iz bočnega stolpca (`<div id="side">`) → `Link` zapisi
- Idempotentno: ponovni zagon ne podvaja (prek novega `source_url` stolpca)

## Vir podatkov
HTML datoteka: `docs/KKC Lendava - Lendvai KKK  Vstopna stran za zaposlene.htm` (UTF-8).
Vsebuje 6 tablesorter tabel (po `id`) in bočni stolpec povezav.

## Predpogoji
- Naloge 22 (OCR), 23 (Meilisearch) končane in delujejo
- Stari strežnik `tabla.knjiznica-lendava.si` mora biti dosegljiv iz kontejnerja
  (preveri: `curl -I http://tabla.knjiznica-lendava.si/kl_index/files/pravilniki/...pdf`)
- Nokogiri (že na voljo prek Rails)

## Koraki

### 1. Migracija: `source_url` stolpec na documents
```ruby
# db/migrate/XXXX_add_source_url_to_documents.rb
class AddSourceUrlToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :source_url, :string
    add_index :documents, :source_url, unique: true, where: "source_url IS NOT NULL"
  end
end
```
Namen: idempotentnost (preskoči že uvožene) + provenanca. Unique partial index (samo kjer
source_url ni NULL, da ročno ustvarjeni dokumenti brez source_url ne trčijo).
Po migraciji posodobi `db/schema.rb` (NE queue/cache/cable_schema.rb!).

Dodaj `source_url` v `Document` model (NE v audited — dodaj v `except` seznam) in v
`Admin::DocumentsController` permit (neobvezno, ker se nastavlja programsko).

### 2. Mapiranje tabel (struktura)
Vsaka tabela ima `<table class="tablesorter" id="...">`. Stolpci se razlikujejo:

| Tabela id      | Tab    | Naslov razdelka                          | Stolpci                          | Privzeta kategorija (fallback) |
|----------------|--------|------------------------------------------|----------------------------------|-------------------------------|
| `dokumenti`    | tabs-2 | Pravilniki, navodila, ukrepi             | [#, Dokument+link, Vrsta, Datum] | po Vrsta                       |
| `zapisniki`    | tabs-3 | Zapisniki sestankov delavcev - knjižnica | [Dokument+link, Datum] ali [#,...]| "Zapisnik sestanka (knjižnica)"|
| `svet`         | tabs-5 | Zapisniki sej sveta zavoda               | [Seja+link, Datum]               | "Zapisnik seje sveta zavoda"   |
| `obvestila`    | tabs-8 | Obvestila za zaposlene                   | [#, Dokument+link, Vrsta, Datum] | po Vrsta                       |

NE UVAŽAMO: `urniki` in `urniki_noe` (tabs-4) — preskoči ju.

POMEMBNO: tabela `zapisniki` je v shranjeni HTML verziji morda PRAZNA (samo <thead>, brez
<tbody> vrstic) ali je sploh ni. Uvoznik mora to elegantno preživeti (preskoči prazno tabelo
brez napake).

### 3. Parsiranje stolpca "Vrsta"
Vrsta vsebuje TIP + (opcijsko) ENOTO, ločena z `<BR>`:
- `akt <BR>KKCL–LKKK` → tip="akt", enota="KKCL–LKKK"
- `pravilnik` → tip="pravilnik", brez enote
- `delovna uspešnost<BR>knjižnica` → tip="delovna uspešnost", enota="knjižnica"
- `delovna uspešnost<BR>NOE` → tip="delovna uspešnost", enota="NOE"

Za KATEGORIJO (DocumentCategory) uporabi **TIP** (prva vrstica pred `<BR>`), normaliziran:
`strip.downcase` za primerjavo, a shrani z lepo začetnico (npr. "Akt", "Pravilnik", "Navodilo",
"Sklep", "Načrt", "Obrazec", "Kodeks", "Ukrep", "Smernice", "Protokol", "Pravila", "Priloga",
"Interni akt", "Osebni podatki", "Razpis", "Delovna uspešnost", "Obvestilo").

`DocumentCategory.find_or_create_by(name: tip_capitalized)` z avtomatsko dodeljeno barvo
(rotiraj skozi nabor barv, ki jih `category_badge` pozna: blue, green, amber, red, purple,
indigo, orange, slate). slug se generira samodejno (model to že dela).

Enoto (KKCL–LKKK / knjižnica / NOE) lahko ZAENKRAT ignoriraš za dokumente (ali jo daš v
opis), ker Document nima polja za enoto. (Announcement ima `unit`, Document ne — ne dodajaj
novega polja zaradi tega.)

### 4. Naslov in datum
- **Naslov**: besedilo znotraj `<a>` — počisti presežne presledke/prelome (`squish`).
  Pri obvestilih naslov pogosto vsebuje prefiks "Knjižnica::" ali "NOE::" — OHRANI ga (del
  naslova) ALI ga premakni v opis; izberi ohranitev v naslovu (preprosteje, informativno).
- **URL**: `href` atribut `<a>`. POZOR: nekateri URL-ji so že delno enkodirani (`%20`, `%202020`)
  — NE enkodiraj dvojno. Uporabi URL kot je za prenos.
- **Datum**: zadnji `<td>`, format `YYYY-MM-DD` → `Date.parse`. Če prazen/neveljaven, pusti
  `published_at` na času uvoza ali nil — ne preskoči dokumenta zaradi manjkajočega datuma.
  Uvoženi dokumenti naj bodo OBJAVLJENI (`published_at` = datum iz tabele).

### 5. Prenos PDF-ja in ustvarjanje Document
Za vsako vrstico:
```ruby
next if Document.exists?(source_url: url)   # idempotentnost

# Prenos prek Net::HTTP (ne odpiraj prek URI.open zaradi varnosti)
# Obravnavaj: 404 (preskoči, logiraj), timeout, ne-PDF (.jpg, .PDF velike črke)
downloaded = download_file(url)   # vrne {io:, filename:, content_type:} ali nil
next unless downloaded

doc = Document.new(
  title: title,
  document_category: category,
  published_at: date || Time.current,
  source_url: url,
  internal_only: false   # ali presodi po enoti/razdelku
)
doc.file.attach(io: downloaded[:io], filename: downloaded[:filename],
                content_type: downloaded[:content_type] || "application/pdf")
doc.save!
# OCR se sproži samodejno prek after_commit (queue_ocr_extraction)
```

Opozorila za prenos:
- En dokument je `.jpg` (Navodila_za_predajo_iztrzka.jpg) — Document model validira PDF
  (`file_is_pdf`). Za .jpg bo validacija padla. Reši: ali preskoči ne-PDF (logiraj), ali
  začasno dovoli sliko. PRIPOROČILO: preskoči ne-PDF in izpiši v povzetku (uporabnik doda ročno).
- En URL ima velike črke `.PDF` (HW25897.PDF) — content_type določi po dejanski vsebini
  (Marcel) ali nastavi "application/pdf" eksplicitno.
- Filename: izlušči iz URL-ja (zadnji segment poti), URL-dekodiraj (`CGI.unescape`) za lepo ime.

### 6. Povezave iz bočnega stolpca
Parsiraj `<div id="side"><h3>Povezave</h3>...` — vse `<a href>` elemente. Mapiraj na `Link`:
- Najprej zagotovi LinkCategory (npr. "Zunanje povezave" / "Knjižnični viri" / "Občine") —
  ali daj vse v eno kategorijo "Uvožene povezave" (preprosteje). Presodi.
- `Link.find_or_create_by(url:)` (idempotentno po URL) z `title` iz besedila povezave.
- `new_tab: true` (vse so target="_blank"), `internal_app: false`.
- POZOR: nekatere povezave so že v seedu (naloga 11) — `find_or_create_by(url:)` prepreči
  duplikate.

### 7. Importer service
`app/services/legacy_table_importer.rb` — glavna logika (NE v rake tasku):
```ruby
class LegacyTableImporter
  def self.call(html_path, download: true)
    new(html_path, download: download).call
  end

  def call
    doc = Nokogiri::HTML(File.read(@html_path, encoding: "UTF-8"))
    import_document_table(doc, "dokumenti", ...)
    import_document_table(doc, "zapisniki", default_category: "...")
    import_document_table(doc, "svet", default_category: "...", no_vrsta: true)
    import_document_table(doc, "obvestila", ...)
    import_side_links(doc)
    print_summary
  end
  # ... per-record v rescue, da ena napaka ne ustavi celote
end
```
Vsaka vrstica naj bo v svojem `begin/rescue` — ena napaka (404, timeout) NE sme ustaviti
celotnega uvoza. Zbiraj statistiko: created / skipped (že obstaja) / failed (z razlogom).

### 8. Rake task (tanek ovoj)
`lib/tasks/import.rake`:
```ruby
namespace :import do
  desc "Uvoz dokumentov in povezav iz stare table (HTML)"
  task :legacy, [:path] => :environment do |_t, args|
    path = args[:path] || Rails.root.join("docs", "KKC Lendava - Lendvai KKK  Vstopna stran za zaposlene.htm").to_s
    LegacyTableImporter.call(path)
  end

  desc "Suhi tek — samo parsiraj in izpiši, brez prenosa in shranjevanja"
  task :legacy_dry, [:path] => :environment do |_t, args|
    path = args[:path] || Rails.root.join("docs", "...htm").to_s
    LegacyTableImporter.call(path, download: false)   # samo parsira, izpiše kaj BI uvozil
  end
end
```

### 9. Suhi tek najprej (obvezno)
Implementiraj `download: false` način, ki samo parsira HTML in izpiše, kaj BI uvozil
(naslov, kategorija, datum, URL) — BREZ prenosa in shranjevanja. To omogoči preverbo
parsiranja pred dejanskim uvozom 140+ datotek.

## Reference
- HTML: `docs/KKC Lendava - Lendvai KKK  Vstopna stran za zaposlene.htm`
- `app/models/document.rb` — validacije (PDF, velikost), OCR callback
- `app/models/document_category.rb` — auto slug, barve
- `app/models/link.rb`, `link_category.rb`
- `app/helpers/documents_helper.rb` — `category_badge` barvni nabor

## Acceptance criteria
- [ ] Migracija `source_url` (unique partial index) + schema.rb posodobljen
- [ ] Suhi tek (`import:legacy_dry`) izpiše vse dokumente brez prenosa — preverljivo
- [ ] `import:legacy` prenese PDF-je v Active Storage, ustvari Document zapise
- [ ] Nova DocumentCategory za vsako Vrsta vrednost (z barvo)
- [ ] Idempotentno: ponovni zagon preskoči obstoječe (source_url), ne podvaja
- [ ] Povezave iz bočnega stolpca uvožene (brez duplikatov z obstoječim seedom)
- [ ] Ena napaka (404/timeout) ne ustavi celote — per-record rescue
- [ ] Povzetek na koncu: created / skipped / failed (z razlogi)
- [ ] Ne-PDF (.jpg) elegantno preskočen in izpisan
- [ ] Prazna tabela (zapisniki) ne podre uvoza
- [ ] OCR se sproži za uvožene PDF-je (asinhrono, ~140 × 10s — opozori uporabnika)

## Opozorila za uporabnika (v povzetku rake taska)
- OCR bo obdelal ~140 dokumentov asinhrono — Solid Queue bo nekaj časa zaseden (~20-30 min).
- Stari strežnik mora biti dosegljiv ves čas uvoza.
- En .jpg dokument je treba dodati ročno (ni PDF).

## Out of scope
- Telefonske številke iz `intro`/`intro8` (možen ločen uvoz v imenik — naloga 26, če želeno)
- Uvoz "Vrsta" enote (KKCL/knjižnica/NOE) kot strukturiran podatek (Document nima unit polja)
- E-mail obvestila ob uvozu (notify_staff naj bo false za uvožene)
