# Naloga 14: Prenova postavitve (layout) in ime aplikacije

## Cilj
Implementiraj novo mrežo blokov na domači strani, razširi vsebino na ~90% širine na velikih
zaslonih, posodobi ime aplikacije, in postavi ogrodje za živahno barvno shemo blokov.

## Predpogoji
- Naloga 13 (Announcement) končana
- Layout/header iz naloge 06 obstaja

## Koraki

### 1. Ime aplikacije
- `<title>` in header naziv: "Intranet (tabla) KKC Lendava" z manjšim madžarskim podnaslovom
  "Lendvai KKK"
- Posodobi `app/views/layouts/_header.html.erb` (naziv) in title v layoutu
- Preveri `config/locales/sl.yml` za morebitne nazive

### 2. Širina vsebine (~90%)
V `app/views/layouts/application.html.erb` zamenjaj ozki container z:
```erb
<main class="mx-auto w-[95%] xl:w-[90%] max-w-[1800px] px-2 sm:px-4 py-6">
  <%= yield %>
</main>
```
(95% na manjših, 90% na xl+, z zgornjo mejo 1800px da na ultra-wide ni predolgih vrstic.)

### 3. Mreža domače strani (`app/views/home/index.html.erb`)
12-stolpčna Tailwind mreža, razmerje 8:2:2 za zgornji del:
```erb
<div class="space-y-6">
  <%# Nujna obvestila — čez celo širino, samo če obstajajo %>
  <% if @announcements.any? %>
    <%= render "home/announcements", announcements: @announcements %>
  <% end %>

  <%# Zgornji del: imenik (8) | interne app (2) | zunanje povezave (2) %>
  <div class="grid grid-cols-1 lg:grid-cols-12 gap-4">
    <div class="lg:col-span-8">
      <%= render "home/directory" %>
    </div>
    <div class="lg:col-span-2">
      <%= render "home/internal_apps" %>
    </div>
    <div class="lg:col-span-2">
      <%= render "home/external_links" %>
    </div>
  </div>

  <%# Dokumenti — čez celo širino %>
  <div>
    <%= render "home/documents" %>
  </div>
</div>
```
Ustvari prazne/placeholder partiale za vsak blok (`_directory`, `_internal_apps`,
`_external_links`, `_documents`, `_announcements`) — vsebino napolnijo naloge 15-17.
Za zdaj naj vsak partial vsebuje samo barvno ogrodje bloka (glej korak 4) in naslov.

### 4. Komponenta barvnega bloka
Ustvari pomožni partial `app/views/shared/_block.html.erb`, ki ovije vsebino v živahno
obarvan blok z glavo:
```erb
<%# locals: title, color (yellow/green/blue/red/indigo), body content via yield/block %>
<section class="rounded-xl overflow-hidden shadow-md">
  <header class="px-4 py-2 font-bold text-lg <%= header_classes %>">
    <%= title %>
  </header>
  <div class="p-4 <%= body_classes %>">
    <%= yield %>
  </div>
</section>
```
Definiraj barvne mape (helper `BlocksHelper` ali inline), npr.:
- yellow: glava `bg-yellow-500 text-slate-900`, telo `bg-yellow-100 dark:bg-yellow-900/30 text-slate-900 dark:text-slate-100`
- green: glava `bg-green-600 text-white`, telo `bg-green-50 dark:bg-green-900/30`
- blue: glava `bg-blue-600 text-white`, telo `bg-blue-50 dark:bg-blue-900/30`
- red: glava `bg-red-600 text-white`, telo `bg-red-50 dark:bg-red-900/30`
- indigo: glava `bg-indigo-600 text-white`, telo `bg-indigo-50 dark:bg-indigo-900/30`

Pazi na WCAG kontrast: rumeno ozadje → temno besedilo, ostale (modra/zelena/rdeča) → belo
besedilo v glavi.

### 5. Nujna obvestila partial (`home/_announcements.html.erb`)
Uporabi `red` ali `amber` barvni blok. Vsako obvestilo: naslov, telo, značka enote
(knjižnica/gledališče/obe), datum objave. Če `pinned`, dodaj ikono pripetosti.

## Reference
- `docs/04_ui_design.md` — celotna specifikacija postavitve in barv
- Priložen PHP screenshot — referenca živahnih barvnih blokov
- `.cursor/rules/03_hotwire_frontend.mdc` — dark mode, responsive pravila

## Acceptance criteria
- [ ] Ime "Intranet (tabla) KKC Lendava — Lendvai KKK" v headerju in title
- [ ] Vsebina ~90% širine na velikih zaslonih, polna širina na mobilnem
- [ ] Mreža 8:2:2 na lg+ zaslonih, zložena v en stolpec na mobilnem
- [ ] Bloki imajo živahne barve z dobrim kontrastom v light in dark načinu
- [ ] Nujna obvestila se prikažejo samo če obstajajo, čez celo širino
- [ ] Placeholder bloki (imenik, app, povezave, dokumenti) so vidni z barvnim ogrodjem
- [ ] Brez horizontalnega scrolla na mobilnem

## Out of scope
- Dejanska vsebina imenika/povezav/dokumentov — naloge 15, 16, 17
- Iskalnik — naloga 18
