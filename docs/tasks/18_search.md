# Naloga 18: Globalni iskalnik (po dokumentih)

## Cilj
Iskalno polje v headerju, ki išče po dokumentih (naslov + opis). Rezultati na ločeni strani
ali v Turbo Frame. To je osnovni iskalnik; iskanje po OCR vsebini prek Meilisearch pride v
ločeni kasnejši nalogi.

## Predpogoji
- Naloga 14 (layout, header) končana
- `Document` model + `visible_to` scope obstajata
- `UnaccentSearchable` concern obstaja (iskanje brez šumnikov)

## Koraki

### 1. Route
`get "search", to: "search#index"` (preveri, da že obstaja v routes.rb — bil je dodan v
osnovnem routingu; če ne, dodaj).

### 2. `SearchController`
```ruby
class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @documents = if @query.present?
      scope = Document.visible_to(current_user).published.includes(:document_category)
      UnaccentSearchable.where_terms_match(scope, @query, ["documents.title", "documents.description"])
        .order(published_at: :desc)
    else
      Document.none
    end
    @pagy, @documents = pagy(@documents) if @query.present?
  end
end
```

### 3. Iskalno polje v headerju (`_header.html.erb`)
- `form_with url: search_path, method: :get` (GET, ne POST)
- Tekstovno polje `name="q"`, placeholder "Išči dokumente..."
- BREZ auto-submit (skladno z `.cursor/rules/03_hotwire_frontend.mdc` — globalni iskalnik
  potrjuje z Enter)
- Na mobilnem: iskalnik dostopen (lahko zložen v meni ali kot ikona, ki razširi polje)

### 4. Stran rezultatov `app/views/search/index.html.erb`
- Prikaži iskani niz in število zadetkov
- Seznam dokumentov (lahko ponovno uporabi `documents/_list.html.erb` iz naloge 17)
- Prazno stanje: "Ni zadetkov za '...'"
- Paginacija

### 5. Spoštuj varnost
Iskalnik MORA uporabljati `Document.visible_to(current_user)` — bralec ne sme najti
`internal_only` dokumentov prek iskanja.

## Reference
- `app/models/concerns/unaccent_searchable.rb` — `where_terms_match` metoda
- `app/policies/document_policy.rb` — varnostni scope
- `.cursor/rules/03_hotwire_frontend.mdc` — globalni iskalnik brez auto-submit

## Acceptance criteria
- [ ] Iskalno polje v headerju, deluje z Enter
- [ ] Iskanje po naslovu in opisu dokumentov
- [ ] Iskanje ignorira šumnike (Žiga = ziga)
- [ ] `internal_only` dokumenti se ne pojavijo v rezultatih za bralca
- [ ] Prazno stanje in paginacija delujeta
- [ ] Iskalnik dostopen na mobilnem

## Out of scope
- Iskanje po OCR vsebini (Meilisearch) — ločena kasnejša naloga
- Iskanje po imeniku/povezavah (zaenkrat samo dokumenti; lahko razširimo pozneje)
- Auto-complete / predlogi med tipkanjem
