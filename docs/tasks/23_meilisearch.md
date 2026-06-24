# Naloga 23: Meilisearch iskanje po dokumentih (vključno OCR vsebina)

## Cilj
Nadgradi globalni iskalnik (naloga 18) z Meilisearch: hitro, tipkarsko-tolerantno iskanje po
naslovu, opisu IN OCR vsebini dokumentov. Uporabi deljeno Meilisearch instanco z Delovodnikom
(ločen indeks `tabla_documents`). Ohrani varnost (`internal_only` dokumenti se ne smejo
pojaviti za bralca).

## Predpogoji
- Naloga 22 (OCR) končana — `Document#ocr_text` se polni
- Naloga 18 (osnovni iskalnik) obstaja — to nalogo nadgrajujemo
- `meilisearch-rails` gem v Gemfile (obstaja), `config/initializers/meilisearch.rb` (obstaja)
- Meilisearch instanca dostopna (deljena z Delovodnikom)

## POMEMBNE RAZLIKE OD DELOVODNIKA
- Delovodnikov `Document.filter_by_subject` je zelo kompleksen (fuzzy ranking, sequence boost,
  uradne številke). Tabla tega NE potrebuje — uporabi preprosto Meilisearch iskanje.
- Ločen indeks: `index_uid: "tabla_documents"` (NE delim indeksa z Delovodnikom).
- Varnost: `internal_only` filtriranje mora delovati v Meilisearch rezultatih.

## Koraki

### 1. Razširi `Document` model z Meilisearch
Dodaj v `app/models/document.rb`:
```ruby
include MeiliSearch::Rails

meilisearch index_uid: "tabla_documents",
            auto_index: !Rails.env.test?,
            auto_remove: !Rails.env.test? do
  attribute :id, :title, :description, :ocr_text, :document_category_id,
            :internal_only, :published_at, :created_at
  attribute :category_name do
    document_category&.name
  end
  attribute :published do
    published?
  end

  searchable_attributes [:title, :description, :ocr_text, :category_name]
  filterable_attributes [:document_category_id, :internal_only, :published]
  sortable_attributes [:published_at, :created_at]
end
```
POZOR: `include MeiliSearch::Rails` mora biti previdno dodan — preveri, da ne podre obstoječih
callback-ov (`after_commit :queue_ocr_extraction`). Meilisearch doda svoje after_commit hooke.

### 1b. KRITIČNO: OCR besedilo mora po ekstrakciji v indeks
OCR job (`OcrExtractionJob`) uporablja `record.update_column(:ocr_text, ...)`, ki NAMERNO
preskoči callbacke (da prepreči neskončno OCR zanko). Posledica: Meilisearch `after_commit`
hook se ob `update_column` NE sproži, zato novo OCR besedilo NE pride v indeks samodejno.

Rešitev: v `OcrExtractionJob`, takoj po `record.update_column(:ocr_text, extracted_text)`,
dodaj eksplicitni reindex:
```ruby
record.update_column(:ocr_text, extracted_text)
# Meilisearch: update_column preskoči callbacke, zato ročno osveži indeks z novim ocr_text.
if defined?(MeiliSearch::Rails) && record.class.respond_to?(:meilisearch_index)
  record.index!
end
```
(Preveri točno ime metode za verzijo meilisearch-rails v Gemfile — lahko je `index!`,
`ms_index!`, ali `reindex!`. Uporabi `defined?` guard, da OCR job ne pade, če Meilisearch
ni naložen ali dosegljiv.)

POZOR: ovij reindex v `rescue`, da nedosegljiv Meilisearch ne podre OCR joba — OCR besedilo
je že shranjeno v bazi (`update_column`), indeksiranje je sekundarno.

### 2. Konfiguracija razvojnega okolja — Meilisearch dostop
V `docker-compose.yml` odkomentiraj/dodaj Meilisearch env (trenutno zakomentiran):
```yaml
MEILISEARCH_URL: ${MEILISEARCH_URL:-http://host.docker.internal:7700}
MEILISEARCH_MASTER_KEY: ${MEILISEARCH_MASTER_KEY:-}
```
Za razvoj na MacBooku: če Delovodnik teče lokalno z Meilisearch na portu 7700,
`host.docker.internal:7700` doseže to instanco. Dodaj `MEILISEARCH_MASTER_KEY` v `.env`
(isti kot Delovodnik). Glej docs/05_deployment.md za produkcijo (deljena instanca).

### 3. Indeksiraj obstoječe dokumente
Po nastavitvi poženi reindex:
```bash
docker compose run --rm rails_app bin/rails runner "Document.reindex!"
```
(ali `Document.reindex` — preveri meilisearch-rails API za verzijo v Gemfile)

### 4. Nadgradi `SearchController`
Zamenjaj `UnaccentSearchable` PostgreSQL iskanje z Meilisearch:
```ruby
def index
  @query = params[:q].to_s.strip
  if @query.present?
    filters = build_security_filters
    @results = Document.search(@query, filter: filters, sort: ["published_at:desc"])
    # paginacija prek pagy ali meilisearch-rails pagination
  else
    @results = []
  end
end

private

# KRITIČNO: varnostni filter. Bralec ne sme videti internal_only.
def build_security_filters
  base = ["published = true"]
  unless current_user&.admin? || current_user&.urednik?
    base << "internal_only = false"
  end
  base.join(" AND ")
end
```
POZOR — varnost: Meilisearch filter `internal_only = false` za bralce je EDINA zaščita v
Meilisearch poti (ni `visible_to` ActiveRecord scope-a). Mora biti pravilno sestavljen in
testiran. Razmisli o defense-in-depth: po Meilisearch rezultatih dodatno preveri prek
`Document.visible_to(current_user).where(id: result_ids)`, da je varnost dvojno zagotovljena.

### 5. Fallback, če Meilisearch ni dosegljiv
Če Meilisearch instanca pade, naj iskalnik ne podre strani. Ujemi izjemo in fallback na
PostgreSQL `UnaccentSearchable` iskanje (naloga 18 logika) ali vsaj prikaži sporočilo
"Iskanje trenutno ni na voljo".

### 6. Prikaz rezultatov
Ohrani obstoječo `search/index.html.erb` postavitev (naloga 18), samo vir podatkov je zdaj
Meilisearch. Prikaži zadetke v OCR vsebini (npr. highlight, če meilisearch-rails podpira).

## Reference
- `delovodnik_rails/app/models/document.rb` — `meilisearch do...end` blok (vzorec, a Tabla enostavnejša)
- `delovodnik_rails/config/initializers/meilisearch.rb` — konfiguracija
- `tabla/config/initializers/meilisearch.rb` — obstaja
- `tabla/app/controllers/search_controller.rb` — nadgradi
- `docs/00_overview.md` — deljena Meilisearch instanca

## Acceptance criteria
- [ ] Dokumenti se indeksirajo v `tabla_documents` indeks (ločen od Delovodnika)
- [ ] Iskanje najde dokumente po naslovu, opisu IN OCR vsebini
- [ ] Iskanje je tipkarsko-tolerantno (Meilisearch typo tolerance)
- [ ] `internal_only` dokumenti se NE pojavijo za bralca (varnostni filter + defense-in-depth)
- [ ] Admin/urednik najde tudi internal_only
- [ ] Samo objavljeni dokumenti v rezultatih (published filter)
- [ ] Meilisearch nedosegljiv → graceful fallback, ne podre strani
- [ ] Obstoječi OCR callback (queue_ocr_extraction) še vedno deluje po dodajanju Meilisearch

## Out of scope
- Iskanje po imeniku/povezavah prek Meilisearch (samo dokumenti)
- Faceted search UI (filtri po kategoriji v iskalniku) — lahko kasneje
- Search-as-you-type / instant search (zaenkrat submit z Enter)
