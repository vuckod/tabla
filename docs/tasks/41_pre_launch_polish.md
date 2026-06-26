# Naloga 41: Pre-launch polish (A11Y, empty states, dinamični title, print CSS)

## Cilj
Štiri vrste izboljšav pred uradno predajo — vse polish, brez nove logike, nizko tveganje
regresij. Naloga je razdeljena v 4 dele (A B C D), Cursor jih lahko commita ločeno.

- **A) A11Y** — dostopnost (skip link, focus stili, ARIA, aria-current)
- **B) Empty states** — lepo oblikovana sporočila, ko ni rezultatov
- **C) Dinamični browser title** — `Tabla — <stran>` (mehanizem že obstaja, samo uporaba)
- **D) Print CSS** — tisk seznamov in predogledov dokumentov brez navigacije

## Del A: Dostopnost (A11Y)

### A1. Skip-to-content link
V `app/views/layouts/application.html.erb` na začetek `<body>` pred renderjem header:
```erb
<a href="#main-content"
   class="sr-only focus:not-sr-only focus:absolute focus:top-2 focus:left-2 focus:z-50
          focus:rounded focus:bg-indigo-600 focus:px-4 focus:py-2 focus:text-white
          focus:shadow-lg focus:outline-none">
  Preskoči na vsebino
</a>
```
V `<main>` dodaj `id="main-content"` in `tabindex="-1"`:
```erb
<main id="main-content" tabindex="-1" class="<%= page_container_classes %> py-6 flex-1">
```

### A2. Focus stili (vidno na vseh povezavah/gumbih)
Tailwind privzeto skrije focus outline. V `app/assets/tailwind/application.css` (ali kjer je
global CSS) dodaj univerzalni focus-visible style:
```css
@layer base {
  :focus-visible {
    outline: 2px solid theme('colors.indigo.500');
    outline-offset: 2px;
    border-radius: theme('borderRadius.sm');
  }
}
```
Ali pa direktno na specifičnih razredih (`focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2`)
za interaktivne elemente (povezave, gumbi, inputi).

### A3. ARIA oznake — ključni elementi
- `<nav>` (v `_header.html.erb`): `aria-label="Glavna navigacija"`
- `<nav>` (`_nav_links.html.erb`): `aria-label="Strani"`
- Iskanje (`_search_form.html.erb`): input `aria-label="Iskanje"` ali povezava z label
- Mobilni meni button: `aria-expanded="..."`, `aria-controls="mobile-menu"`
- Modal (turbo-frame "modal"): `role="dialog"`, `aria-modal="true"`, `aria-labelledby="..."`
- Flash sporočila: `role="alert"` ali `aria-live="polite"`

### A4. aria-current="page" na trenutni nav povezavi
V `_nav_links.html.erb` razširi `nav_link_to` helper (ali kjer se renderirajo povezave):
```erb
<%= link_to documents_path,
    class: "...",
    aria: { current: current_page?(documents_path) ? "page" : nil } do %>
  ...
<% end %>
```
Brskalniki to izpostavljajo screen readerjem.

### A5. Vizualna oznaka trenutne strani
Hkrati z aria-current, dodaj vizualno (npr. `data-active` ali ločen razred):
```erb
<%= link_to documents_path,
    class: "#{current_page?(documents_path) ? 'bg-indigo-100 dark:bg-indigo-900/40' : ''} ..." %>
```
Že lahko obstaja — preveri.

### A6. Lighthouse preverba (po implementaciji)
```bash
# V Chrome DevTools: Lighthouse → Accessibility scan
```
Cilj: Accessibility ≥ 90. Popravi morebitne preostale opozorile (kontrast, alt teksti, ipd.).
Glavni izvori opozoril: barvni kontrasti na slabih kombinacijah (npr. `text-slate-400` na
`bg-slate-50` = premalo kontrasta). Popravi z `text-slate-600+`.

## Del B: Empty states

### B1. Prazne kategorije dokumentov
`documents/_list.html.erb` že ima `<p>Brez dokumentov...</p>` — zamenjaj z lepšim:
```erb
<% if documents.empty? %>
  <div class="text-center py-12 px-4">
    <svg class="mx-auto h-12 w-12 text-slate-400 dark:text-slate-600" fill="none"
         viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" aria-hidden="true">
      <path stroke-linecap="round" stroke-linejoin="round"
            d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
    </svg>
    <h3 class="mt-3 text-sm font-semibold text-slate-900 dark:text-slate-100">
      <%= t("views.documents.empty_category_title") %>
    </h3>
    <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
      <%= t("views.documents.empty_category_message") %>
    </p>
    <% if selected_category_id %>
      <div class="mt-4">
        <%= link_to t("views.documents.empty_show_all"), documents_filter_url(filter_base),
            class: "text-sm font-semibold text-indigo-600 dark:text-indigo-400 hover:underline" %>
      </div>
    <% end %>
  </div>
<% end %>
```
Dodaj prevode v `config/locales/sl.yml` (vse 3 ključe).

### B2. Iskanje brez rezultatov
`search/index.html.erb` (preveri natančen path) — ko ni zadetkov, pokaži:
- Ikona "iskanje"
- "Ni zadetkov za 'X'"
- Predlog: "Poskusi z drugačnim izrazom" + povezava "Počisti iskanje"

### B3. Imenik brez vrstic
`persons/index.html.erb` — ko ni oseb (npr. filtriranje brez ujemanj):
- Ikona uporabnikov
- "Ni oseb v tem imeniku"
- Reset filter povezava

### B4. Admin index strani brez zapisov
Vseh 9 admin strani — ko ni vrstic v bazi, pokaži:
- Ikona (specifična za vsako, npr. dokumenti / povezave / osebe / kategorije)
- "Še ni X" 
- Gumb "Dodaj prvi/o X" (link na #new akcijo)

Lahko narediš shared partial `app/views/shared/_empty_state.html.erb`:
```erb
<%# locals: icon_path:, title:, message:, action: nil %>
<div class="text-center py-12 px-4">
  <svg class="mx-auto h-12 w-12 text-slate-400 dark:text-slate-600" ...>
    <path d="<%= icon_path %>" />
  </svg>
  <h3 class="mt-3 text-sm font-semibold..."><%= title %></h3>
  <p class="mt-1 text-sm..."><%= message %></p>
  <% if action %>
    <div class="mt-4"><%= action %></div>
  <% end %>
</div>
```
Uporabi povsod, kjer je smiselno.

## Del C: Dinamični browser title

### C1. Layout že ima mehanizem
V `application.html.erb`:
```erb
<title>
  <% if content_for?(:title) %>
    <%= content_for(:title) %> | <%= t("views.layouts.header.page_title") %>
  <% else %>
    <%= t("views.layouts.header.page_title") %>
  <% end %>
</title>
```
Format: `<podstran> | Tabla`. Treba je v vsake view dodati `content_for(:title)`.

### C2. Doda title v vse view
**Domača (home/index.html.erb)** — title odvisen od konteksta:
```erb
<% content_for :title, t("views.home.title") || "Domov" %>
```
Hmm, domača je najbolj generično — lahko brez (potem samo "Tabla"). Predlog: brez content_for
na domači, ostane samo "Tabla". Ali pa "Tabla — Domov".

**Dokumenti** (`documents/index.html.erb`):
```erb
<% category_part = @selected_category&.name %>
<% content_for :title, ["Dokumenti", category_part].compact.join(" — ") %>
```
Rezultat: `Tabla — Dokumenti — Pravilniki` ali `Tabla — Dokumenti`.

**Posamezen dokument** (`documents/show.html.erb`):
```erb
<% content_for :title, "Dokument — #{@document.title}" %>
```

**Imenik** (`persons/index.html.erb`): `Imenik`
**Iskanje** (`search/index.html.erb`):
```erb
<% content_for :title, %(Iskanje "#{params[:q]}") %>
```
**Prijava** (`sessions/new.html.erb`): `Prijava`
**Admin** vse: `Admin — <stran>`

Format konsistenten: `<sekcija> — <podrobnost>`. Layout doda " | Tabla" na koncu.

### C3. i18n ključe za title
Lahko vse ključe daš v `config/locales/sl.yml` pod `views.titles.*`:
```yaml
views:
  titles:
    home: ""  # ali "Domov"
    documents: "Dokumenti"
    persons: "Imenik"
    search: "Iskanje"
    login: "Prijava"
    admin:
      documents: "Admin — Dokumenti"
      # ...
```
In v view:
```erb
<% content_for :title, t("views.titles.documents") %>
```

## Del D: Print CSS

### D1. Globalno: skrij navigacijo, header, footer pri tisku
V `application.html.erb` ali global CSS:
```css
@media print {
  body { background: white !important; color: black !important; }
  header, footer, [data-turbo-frame="modal"], .print\:hidden { display: none !important; }
  main { padding: 0 !important; }
}
```
Header in footer že imata `print:hidden` (Tailwind utility). Preveri, da `_search_form.html.erb`,
gumbi, paginacija, filter chips tudi imajo `print:hidden`.

### D2. Predogled dokumenta (`/documents/:id`)
Ko uporabnik tiska to stran:
- Skrij gumb "Prenos", "Predogled", "Nazaj"
- Pokaži naslov + opis + kategorija + datum
- Pokaži source URL (`<a href>` z `print:after:content-['_(url)']` ali ročno izpisan URL)
- Predogled (iframe ali img) — naj se NE tiska samodejno (uporabnik tiska PDF posebej)

Strategija: dodaj `print:hidden` na vse interaktivne elemente, `print:block` na metadata blok.

### D3. Seznam dokumentov (`/documents`)
Pri tisku:
- Skrij filter chips, paginacija, gumbe
- Vsak dokument: samo naslov + kategorija + datum (brez thumbnaila, brez akcij)
- Lahko `print:` razredi:
  ```erb
  <div class="... print:border-b print:py-2">
    <h3 class="print:text-base"><%= document.title %></h3>
    <div class="print:hidden">...gumbi...</div>
  </div>
  ```

### D4. Imenik (`/persons`)
- Skrij iskanje, navigacijo
- Samo tabela (vse osebe/lokacije/telefoni)
- Lepo formatirano za list papirja

### D5. Obvestila
Lepo formatiraj vsebino brez interaktivnih elementov. Preveri obstoječi partial.

### D6. Print preverba
Chrome → DevTools → Cmd+Shift+P → "Show Rendering" → "Emulate CSS print media".
Ali: Cmd+P (predogled tiska). Preveri vseh 5 strani (home, documents, document show, persons,
search). Vsebina vidna, brez "fly-around" navigacijskih elementov.

## Reference
- `app/views/layouts/application.html.erb` (skip-link, main id)
- `app/views/layouts/_header.html.erb`, `_nav_links.html.erb`, `_search_form.html.erb` (ARIA)
- `app/views/documents/_list.html.erb` (empty state primer)
- `app/assets/tailwind/application.css` ali kjer je global CSS (focus + print)
- `config/locales/sl.yml` (i18n za titles + empty states)

## Acceptance criteria

### Del A (A11Y)
- [ ] Skip-to-content link viden ob Tab
- [ ] Focus-visible stili na vseh povezavah/gumbih (indigo outline)
- [ ] ARIA oznake na nav, search, modal, flash
- [ ] aria-current="page" na trenutni navigaciji
- [ ] Lighthouse Accessibility ≥ 90

### Del B (empty states)
- [ ] /documents brez rezultatov v kategoriji: lepa sporočilna stran z ikono in povezavo "Vsi"
- [ ] /search brez zadetkov: lepa sporočilna stran s predlogom
- [ ] /persons brez oseb: lepa sporočilna stran
- [ ] Admin strani brez vrstic: lepa sporočilna stran z "Dodaj prvi" gumbom
- [ ] Shared partial `_empty_state` (DRY)

### Del C (browser title)
- [ ] Vse pomembne strani imajo `content_for(:title)` ali ekvivalent
- [ ] Format: `<sekcija> — <podrobnost> | Tabla`
- [ ] i18n: prevodi v sl.yml pod `views.titles.*`
- [ ] Test: zavihek brskalnika ima smiseln naslov na vsaki strani

### Del D (print)
- [ ] Header, footer, navigacija, gumbi skriti pri tisku
- [ ] Predogled dokumenta: tisk pokaže samo naslov + metadata + source URL
- [ ] Seznam dokumentov: tisk pokaže samo naslove + datume
- [ ] Imenik: tisk pokaže samo tabelo
- [ ] Chrome print preview izgleda čisto, brez "ujetih" elementov

## Test
1. Vsako stran odpri, Tab po njej (skip link, focus vidno)
2. Lighthouse scan na home + documents + persons
3. Cmd+P predogled tiska na 4 ključnih straneh
4. /documents?category_id=<prazna> → empty state vidna
5. /search?q=neobstojezgrabljaba → empty state vidna
6. Brskalnik zavihek: naslov spreminja po straneh

## Out of scope
- Spremembe vsebine (samo predstavitev)
- Nove poti / kontrolerji
- WCAG AAA (target je AA, ki ga Lighthouse meri)
