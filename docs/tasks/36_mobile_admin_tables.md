# Naloga 36: Mobilna prilagoditev admin tabel (kartice na <md)

## Cilj
Vse admin tabele imajo trenutno `overflow-x-auto` (horizontalni scroll na ozkih ekranih), kar
je nerodno za uporabo na telefonu. Dodaj kartično varianto za `< md` (kot že imamo na /persons
in domačem imeniku), tabelo pa skrij na ozkih ekranih.

## Vzorec (že obstoječi v Tabli)
- `app/views/persons/index.html.erb` — `hidden md:block` tabela + `md:hidden space-y-4` kartice
- `app/views/home/_directory.html.erb` — `hidden sm:block` tabela + `sm:hidden space-y-2` kartice
Pristop: ohrani enako vsebino, samo drugačno postavitev (kartica namesto vrstice tabele).

## Strani za obravnavo
Vse admin index strani z `overflow-x-auto` + `<table>` (po enem vzorcu):
1. `app/views/admin/documents/index.html.erb`
2. `app/views/admin/persons/index.html.erb`
3. `app/views/admin/links/index.html.erb`
4. `app/views/admin/link_categories/index.html.erb`
5. `app/views/admin/document_categories/index.html.erb`
6. `app/views/admin/locations/index.html.erb`
7. `app/views/admin/announcements/index.html.erb`
8. `app/views/analytics/index.html.erb` (dve tabeli: obiski + dogodki)
9. `app/views/admin/document_audits/index.html.erb`

## Pristop za vsako stran
1. Ohrani obstoječo tabelo, zavij v `<div class="hidden md:block overflow-x-auto ...">` (skrij na mobilnem)
2. Dodaj `<div class="md:hidden space-y-3">` z **kartičnim prikazom** istih podatkov
3. V kartici: glavni naslov/title kot `<h3>` / poudarjeno, sekundarni atributi kot label+value pari
4. Akcije (uredi/izbriši/zgodovina) — gumbi na dnu kartice (full width ali horizontalna vrsta)

Vzorec kartice (po vzorcu /persons):
```erb
<div class="md:hidden space-y-3">
  <% @records.each do |record| %>
    <article class="bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 p-4 shadow-sm">
      <%# Glava: glavni naslov + status značke %>
      <div class="flex items-start justify-between gap-2 mb-2">
        <h3 class="font-semibold text-slate-900 dark:text-slate-100"><%= record.title %></h3>
        <%# status / kategorija badge %>
      </div>

      <%# Atributi: label + vrednost %>
      <dl class="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 text-sm">
        <dt class="text-slate-600 dark:text-slate-400">Kategorija</dt>
        <dd><%= record.category_name %></dd>
        <dt class="text-slate-600 dark:text-slate-400">Datum</dt>
        <dd><%= l(record.created_at, format: :short) %></dd>
      </dl>

      <%# Akcije na dnu %>
      <div class="mt-3 pt-3 border-t border-slate-100 dark:border-slate-700 flex flex-wrap gap-3 print:hidden">
        <%= link_to "Uredi", edit_admin_record_path(record), class: "text-indigo-600 ..." %>
        <% if policy(record).destroy? %>
          <%= button_to "Izbriši", ... %>
        <% end %>
      </div>
    </article>
  <% end %>
</div>
```

## Specifične točke
- **Admin Documents:** OCR status badge + zastavice (internal_only, notify_staff) v glavi kartice
- **Admin Persons:** ime + lokacija + telefoni (kot na /persons, samo z admin akcijami)
- **Admin Links:** title + URL + kategorija + internal_app značka
- **Analytics (obiski/dogledi):** najbolj zapleten — IP, OS, brskalnik, čas. Predlog: glavna vrstica
  čas + ime dogodka, ostalo v `<dl>`. Lahko poenostaviš (samo najpomembnejši atributi v kartici;
  za ostalo naj user obrne v landscape ali odpre detajl).
- **Document Audits:** dokument + uporabnik + akcija + povzetek sprememb. Akcijska značka v glavi.

## Acceptance criteria
- [ ] Vseh 9 admin index strani ima kartično varianto za `< md` (md breakpoint = 768px)
- [ ] Tabela skrita na ozkih ekranih (`hidden md:block`), kartice na njihovem mestu (`md:hidden`)
- [ ] Vsebina identična (vsi atributi, vse akcije)
- [ ] Akcije (uredi/izbriši/zgodovina) dostopne v kartici
- [ ] Dark mode deluje za kartice (slate-800 ozadje, slate-700 obroba)
- [ ] `print:hidden` na akcijah ohranjeno
- [ ] `bin/rails tailwindcss:build` pognan (verjetno ni potreben — vsi razredi že obstajajo iz /persons)

## Test
1. Odpri vsako admin stran v dev tools mobile view (npr. iPhone SE, 375px)
2. Tabela skrita, kartice vidne, vsebina pravilna
3. Akcije (uredi, izbriši) delujejo
4. Desktop (>= 768px): tabela vidna, kartice skrite

## Out of scope
- Spreminjanje vsebine ali atributov (samo postavitev)
- Filtri / iskanje (so že responsive)
- Domača stran in /persons (že imajo kartice — ne dotikaj)
