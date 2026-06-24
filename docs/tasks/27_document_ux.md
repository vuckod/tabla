# Naloga 27: Document UX — gumb "Prikaži" + modernizirana paginacija

## Cilj
Dve manjši, a opazni izboljšavi seznama dokumentov:
1. Poleg gumba "Prenesi" dodaj gumb "Prikaži" (predogled v brskalniku — naslov že vodi na
   predogled, a ekspliciten gumb je bolj očiten).
2. Modernizacija videza paginacije (trenutno privzeti Pagy stil — naredi Tailwind verzijo).

## Predpogoji
- Naloge 21/24 (predogled) — `document_path` prikaže searchable PDF
- Pagy 9.3 (v Gemfile)
- `documents/_document_row.html.erb` in `documents/_list.html.erb` obstajata

## Koraki

### 1. Gumb "Prikaži" v `_document_row`
V `documents/_document_row.html.erb`, v desnem bloku gumbov, dodaj poleg "Prenesi" še "Prikaži":
- "Prikaži" → `document_path(document)` (predogled), primarni/poudarjen videz
- "Prenesi" → `download_document_path(document)` (obstoječ, `data: { turbo: false }`)
- Na mobilnem naj bosta gumba polna širine ali v vrsti (presodi), na desktopu v vrsti

Predlog hierarhije: "Prikaži" naj bo primarni (indigo poln), "Prenesi" sekundarni (obrobljen),
ker je predogled pogostejša akcija. Ohrani `print:hidden` na obeh.

Naslov dokumenta naj OSTANE povezava na predogled (kot je) — gumb je dodatek, ne nadomestek.

### 2. Modernizirana Tailwind paginacija
Trenutno `_list.html.erb` uporablja `pagy_nav(pagy)` (privzeti HTML). Naredi Tailwind verzijo:
- Ustvari helper ali partial (npr. `shared/_pagination.html.erb` ali `pagy_nav_tailwind` helper)
- Stil: zaobljeni gumbi, indigo aktivna stran, hover stanja, dark mode, onemogočene
  prejšnja/naslednja na robovih
- Prikaži: « prejšnja, številke strani (z … za velike razpone), naslednja »
- Pagy 9 ima `pagy_get_vars` / seznam strani prek `pagy.series` — uporabi `@pagy.series` za
  generiranje številk z gap markerji ("gap")
- Responsive: na mobilnem morda samo prejšnja/naslednja + "stran X od Y", na desktopu polne številke

Pristop (Pagy 9 series):
```erb
<%# pagy.series vrne npr. [1, 2, "gap", 5, "6", 7, "gap", 20] kjer je String trenutna stran %>
<nav class="flex items-center gap-1" aria-label="Paginacija">
  <% if pagy.prev %>
    <%= link_to "«", url_for(page: pagy.prev), class: "...", data: { turbo_frame: "documents_list" } %>
  <% end %>
  <% pagy.series.each do |item| %>
    <% if item == "gap" %>
      <span class="px-2">…</span>
    <% elsif item.is_a?(String) %>
      <span class="... bg-indigo-600 text-white ...">#{item}</span>  <%# trenutna %>
    <% else %>
      <%= link_to item, url_for(page: item), class: "...", data: { turbo_frame: "documents_list" } %>
    <% end %>
  <% end %>
  <% if pagy.next %>
    <%= link_to "»", url_for(page: pagy.next), class: "...", data: { turbo_frame: "documents_list" } %>
  <% end %>
</nav>
```
POZOR: paginacija mora ohraniti `turbo_frame: "documents_list"` (da ostane znotraj Turbo Frame
filtriranja) IN trenutni `category_id` filter v URL-ju (da paginacija znotraj filtrirane
kategorije deluje). Preveri, da `url_for` ohrani obstoječe query parametre (category_id).

### 3. Uporabi povsod, kjer je paginacija
- `documents/_list.html.erb` (seznam + domača stran prek DocumentListing)
- `search/index.html.erb` (rezultati iskanja — naloga 23) — če uporablja pagy, isti stil
- Admin sezname, če uporabljajo pagy

## Reference
- `app/views/documents/_document_row.html.erb`
- `app/views/documents/_list.html.erb` — `pagy_nav`
- Pagy 9 docs: `pagy.series`, `pagy.prev`, `pagy.next`
- `config/initializers/pagy.rb` (če obstaja)

## Acceptance criteria
- [ ] Gumb "Prikaži" poleg "Prenesi" v vsaki vrstici dokumenta
- [ ] "Prikaži" → predogled, "Prenesi" → prenos; jasna vizualna hierarhija
- [ ] Naslov dokumenta še vedno vodi na predogled
- [ ] Modernizirana Tailwind paginacija (zaobljeni gumbi, indigo aktivna, dark mode)
- [ ] Paginacija ohrani category_id filter + turbo_frame
- [ ] Responsive (mobilni: poenostavljena paginacija)
- [ ] Gumba in paginacija `print:hidden`
- [ ] `bin/tailwind-build` pognan

## Out of scope
- Thumbnaili — naloga 28
- Spreminjanje števila dokumentov na stran (ostane privzeto)
