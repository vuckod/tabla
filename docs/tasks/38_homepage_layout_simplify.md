# Naloga 38: Domača stran — povezave samo v 3. vrstici, brez scrolla

## Cilj
Poenostavi domačo stran: blok zunanjih povezav naj bo SAMO na enem mestu (v 3. vrstici ob
dokumentih, kjer je dovolj prostora). Imenik dobi več prostora (10 stolpcev). Scroll na
povezavah odpade — naj se vse povezave vidijo naenkrat.

## Struktura po vrsticah (lg breakpoint)

| Vrstica | Postavitev (lg:grid-cols-12)                  |
|---------|-----------------------------------------------|
| 1       | Nujna obvestila — polna širina (samo če obstajajo) |
| 2       | Imenik (10) + Aplikacije (2)                  |
| 3       | Dokumenti (10) + Povezave (2)                 |

Povezave se pojavijo SAMO V VRSTICI 3 — enkrat, na vseh ekranih.

## Stanje (po nalogi 37)
```erb
<%# Vrstica 2 %>
<div class="grid grid-cols-1 lg:grid-cols-12 gap-4">
  <div class="lg:col-span-8"><%= render "home/directory", ... %></div>
  <div class="lg:col-span-2"><%= render "home/internal_apps", ... %></div>
  <div class="lg:col-span-2"><%= render "home/external_links", ... %></div>
</div>

<%# Vrstica 3 %>
<div class="grid grid-cols-1 lg:grid-cols-12 gap-4">
  <div class="lg:col-span-10"><%= render "home/documents", ... %></div>
  <div class="hidden lg:block lg:col-span-2"><%= render "home/external_links", ... %></div>
</div>
```

## Koraki

### 1. `app/views/home/index.html.erb` — popravki

**Vrstica 2:** imenik na col-span-10, ODSTRANI blok povezav:
```erb
<%# Vrstica 2: imenik (10) + aplikacije (2) %>
<div class="grid grid-cols-1 lg:grid-cols-12 gap-4">
  <div class="lg:col-span-10">
    <%= render "home/directory", directory_rows: @directory_rows %>
  </div>
  <div class="lg:col-span-2">
    <%= render "home/internal_apps", internal_links: @internal_links %>
  </div>
</div>
```

**Vrstica 3:** ODSTRANI `hidden lg:block` (povezave naj bodo vidne tudi na mobilnem, ker
so zdaj samo na enem mestu):
```erb
<%# Vrstica 3: dokumenti (10) + povezave (2) %>
<div class="grid grid-cols-1 lg:grid-cols-12 gap-4">
  <div class="lg:col-span-10">
    <%= render "home/documents",
        document_categories: @document_categories,
        selected_category_id: @selected_category_id,
        documents: @documents,
        pagy: @pagy %>
  </div>
  <div class="lg:col-span-2">
    <%= render "home/external_links", external_link_categories: @external_link_categories %>
  </div>
</div>
```

### 2. `app/views/home/_external_links.html.erb` — odstrani max-h + scroll
Trenutno:
```erb
<div class="max-h-[44rem] overflow-y-auto space-y-3">
```
Zamenjaj z:
```erb
<div class="space-y-3">
```
Dovolj je prostora ob dokumentih (visok blok), povezave naj se prikažejo v polni višini brez
notranjega drsnika.

## Vrstni red na mobilnem (< lg)
Pri navpičnem zlaganju (na mobilnem) bo vrstni red:
1. Obvestila (če obstajajo)
2. Imenik
3. Aplikacije
4. Dokumenti
5. Povezave

To je smiselno — povezave na koncu, dokumenti pred njimi (glavna vsebina).

## Acceptance criteria
- [ ] Vrstica 2: imenik (10) + aplikacije (2); BREZ bloka povezav
- [ ] Vrstica 3: dokumenti (10) + povezave (2); BREZ `hidden lg:block`
- [ ] Povezave so SAMO v vrstici 3 — enkrat na vseh ekranih
- [ ] `_external_links.html.erb` BREZ `max-h-[44rem] overflow-y-auto` — samo `space-y-3`
- [ ] Imenik ima zdaj 10 stolpcev (širši, manj sproten scroll v tabeli)
- [ ] Mobilni vrstni red: obvestila → imenik → aplikacije → dokumenti → povezave
- [ ] `bin/rails tailwindcss:build` ni potreben (vsi razredi že obstajajo)

## Test
1. Desktop: vrstica 2 brez povezav (imenik širši); vrstica 3 z dokumenti + povezavami desno
2. Mobilni: imenik → aplikacije → dokumenti → povezave (zaporedoma navzdol)
3. Povezave: vse vidne brez notranjega drsnika

## Out of scope
- Sticky positioning povezav (možnost za kasneje)
- Spreminjanje vsebine blokov
