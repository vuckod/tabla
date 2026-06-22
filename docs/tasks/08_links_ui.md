# Naloga: Povezave — prikaz in admin CRUD

## Cilj
Implementiraj prikaz kategoriziranih povezav (interne aplikacije, COBISS, pravni viri, občine...)
in admin vmesnik za urejanje. Model in seed podatki že obstajajo.

## Predpogoji
- `docs/tasks/06_layout_nav.md` končana

## Koraki

### 1. `LinksController` (javni prikaz)
```ruby
class LinksController < ApplicationController
  def index
    @link_categories = LinkCategory.ordered.includes(:links)
  end
end
```

### 2. View `app/views/links/index.html.erb`
- Skupine po kategoriji (vsaka kategorija = sekcija/kartica)
- Znotraj kategorije: seznam povezav, `target="_blank"` če `link.new_tab?`
- Posebej izpostavi `internal_app: true` povezave (Prisotnost, Delovodnik) — drugačen stil
  ali ikona, ker so to "naše" aplikacije
- Grid layout: na desktopu več stolpcev kategorij, na mobilnem ena pod drugo (glej PHP
  screenshot — rumeni stolpec na desni strani z več sekcijami)

### 3. Domača stran — "Hitre povezave" sekcija
Na `home#index` prikaži samo `internal_app: true` povezave kot bližnjice (manjša kartica),
s linkom "Vse povezave →" na `links_path`.

### 4. Admin CRUD — `Admin::LinkCategoriesController` in `Admin::LinksController`
Standardna CRUD struktura. Pri `Link` formi: dropdown za izbiro `link_category`,
checkbox za `internal_app` in `new_tab`, number field ali drag-drop za `position`.

### 5. Politike
`LinkPolicy`, `LinkCategoryPolicy < ApplicationPolicy` — dedujejo `editor?` iz base.

## Reference
- `docs/01_data_model.md` — modeli LinkCategory, Link
- Priloženi screenshot stare PHP table — rumeni "POVEZAVE" stolpec je vizualna referenca

## Acceptance criteria
- [ ] `/links` prikaže vse kategorije z njihovimi povezavami
- [ ] Interne aplikacije so vizualno izpostavljene
- [ ] Domača stran prikazuje hitre povezave (samo internal_app)
- [ ] Admin lahko CRUD kategorije in povezave, vključno z urejanjem vrstnega reda (`position`)
- [ ] Bralec ne vidi admin povezav/akcij
- [ ] Responsive grid

## Out of scope
- Avtomatsko preverjanje, ali povezava še deluje (health check) — morebitna faza 2
- Štetje klikov na povezave (Ahoy event tracking) — lahko dodano kasneje brez večjih sprememb
