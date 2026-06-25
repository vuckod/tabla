# Naloga 39: Vizualna modernizacija — imenik v dva stolpca + header s grafiko

## Cilj
Tri dele modernizacije:
- **A) Imenik v dva stolpca** (SIKLND levo, NOE desno) — krajša vertikalna višina, logična ločitev enot
- **B) Header z grafiko** — ikona knjižnice, subtilen gradient, boljša tipografija, datum
- **C) Splošni dodatki** (opcijski, lahko v ločenem prehodu) — hover-lift na karticah, ikone na navigaciji

## Del A: Imenik v dva stolpca

### A1. Pripravi razdelitev v `DirectoryTableBuilder`
Trenutno `DirectoryTableBuilder.rows` vrne plosk seznam (sortiran po unit_position).
Dodaj metodo `rows_by_unit_kind`, ki vrne hash s skupinami:
```ruby
def self.rows_by_unit_kind
  new.rows_by_unit_kind
end

def rows_by_unit_kind
  rows.group_by(&:unit_kind)
  # Vrne: { "headquarters" => [...siklnd...], "branch" => [...noe...], nil => [...brez lokacije...] }
end
```
Ohrani `rows` metodo (uporablja jo lahko kdo drug — `persons#index`).

Posodobi `HomeController#index` (ali kjer se nastavlja `@directory_rows`):
```ruby
@directory_rows_by_unit = DirectoryTableBuilder.rows_by_unit_kind
```
Ohrani tudi `@directory_rows` (če se uporablja drugje).

### A2. Posodobi `home/_directory.html.erb` — dva stolpca
Postavitev:
- Naslov bloka "Telefonski imenik" (ostane)
- **Desktop (md+):** `grid grid-cols-2 gap-4` — SIKLND levo, NOE desno
- **Mobilni (<md):** ena pod drugim (samodejno, ker `grid-cols-2` deluje od md naprej)
- Vsaka enota ima svoj **podnaslov** (ime enote / short_code) in svojo tabelo
- Tabela ima **3 stolpce** (interna, zunanja, naziv) — stolpec "Enota" odpade (implicirano s skupino)

Predlog strukture:
```erb
<%= render layout: "shared/block",
    locals: { title: t("views.home.phone_directory"), color: :yellow } do %>
  <% if directory_rows_by_unit.empty? %>
    <p class="text-sm opacity-80"><%= t("views.directory.empty") %></p>
  <% else %>
    <div class="grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-4">
      <% directory_rows_by_unit.each do |unit_kind, rows| %>
        <% next if rows.blank? %>
        <section>
          <h4 class="font-semibold text-slate-800 dark:text-slate-200 mb-2 pb-1
                     border-b border-yellow-300/60 dark:border-yellow-700/60">
            <%= directory_unit_heading(unit_kind, rows.first.enota) %>
          </h4>

          <%# Desktop tabela %>
          <div class="hidden sm:block">
            <table class="w-full text-sm border-collapse">
              <thead>
                <tr class="border-b border-yellow-300/40 dark:border-yellow-700/40">
                  <th scope="col" class="py-2 pr-3 text-left font-semibold text-slate-700 dark:text-slate-300 w-[20%]">
                    <%= t("views.directory.internal") %>
                  </th>
                  <th scope="col" class="py-2 pr-3 text-left font-semibold text-slate-700 dark:text-slate-300 w-[30%]">
                    <%= t("views.directory.external") %>
                  </th>
                  <th scope="col" class="py-2 text-left font-semibold text-slate-700 dark:text-slate-300">
                    <%= t("views.directory.naziv") %>
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-yellow-200/40 dark:divide-yellow-800/30">
                <% rows.each do |row| %>
                  <tr class="hover:bg-yellow-200/30 dark:hover:bg-yellow-900/20">
                    <td class="py-1.5 pr-3 font-mono"><%= directory_tel_link(row.internal) %></td>
                    <td class="py-1.5 pr-3 font-mono"><%= directory_tel_link(row.external) %></td>
                    <td class="py-1.5 font-medium"><%= row.naziv %></td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

          <%# Mobilne kartice znotraj skupine %>
          <div class="sm:hidden space-y-2">
            <% rows.each do |row| %>
              <article class="rounded-lg border border-yellow-300/60 dark:border-yellow-700/60 bg-white/50 dark:bg-slate-900/30 p-3">
                <h3 class="font-semibold text-slate-900 dark:text-slate-100 mb-2"><%= row.naziv %></h3>
                <dl class="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 text-sm">
                  <dt class="text-slate-600 dark:text-slate-400"><%= t("views.directory.internal") %></dt>
                  <dd class="font-mono"><%= directory_tel_link(row.internal) %></dd>
                  <dt class="text-slate-600 dark:text-slate-400"><%= t("views.directory.external") %></dt>
                  <dd class="font-mono"><%= directory_tel_link(row.external) %></dd>
                </dl>
              </article>
            <% end %>
          </div>
        </section>
      <% end %>
    </div>
  <% end %>

  <p class="mt-4 pt-3 border-t border-yellow-300/50 dark:border-yellow-700/50">
    <%= link_to t("views.home.full_directory"), persons_path,
        class: "text-sm font-semibold text-slate-800 dark:text-slate-200 hover:text-indigo-700 dark:hover:text-indigo-300 underline-offset-2 hover:underline" %>
  </p>
<% end %>
```

### A3. Helper za naslov skupine
V `app/helpers/directory_helper.rb` (ali kjer je `directory_tel_link`) dodaj:
```ruby
def directory_unit_heading(unit_kind, fallback_short_code)
  case unit_kind
  when "headquarters" then "SIKLND — Knjižnica"
  when "branch"       then "NOE — Gledališče"
  else fallback_short_code.presence || t("views.directory.other_unit")
  end
end
```
Ali bolje prek i18n: `t("views.directory.unit_headings.#{unit_kind}", default: fallback_short_code)`.
Dodaj prevode v `config/locales/sl.yml`.

### A4. Vrstni red enot
`group_by` v Ruby ohrani vrstni red ključev po prvem pojavu v iteraciji. Ker `rows` že sortira
po `unit_position` (SIKLND=1, NOE=2), bo `headquarters` skupina prva, `branch` druga. Brez
posebne logike za vrstni red.

POZOR: če pride vrstica brez lokacije (`unit_kind = nil`), gre na konec — preveri, da ne pokvari
postavitve (ali jo skrij, če ni smiselna na domači strani).

## Del B: Header z grafiko

### B1. Ikona knjižnice (Heroicons inline SVG)
Levo od naslova dodaj ikono iz Heroicons (BuildingLibraryIcon — outline 24px). Inline SVG:
```erb
<svg class="h-8 w-8 text-indigo-600 dark:text-indigo-400 shrink-0" fill="none"
     viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" aria-hidden="true">
  <path stroke-linecap="round" stroke-linejoin="round"
        d="M12 21v-8.25M15.75 21v-8.25M8.25 21v-8.25M3 9l9-6 9 6m-1.5 12V10.332A48.36 48.36 0 0 0 12 9.75c-2.551 0-5.056.2-7.5.582V21M3 21h18M12 6.75h.008v.008H12V6.75Z" />
</svg>
```
Ali pa BookOpenIcon, če bolj ustreza:
```erb
<svg class="h-8 w-8 text-indigo-600 dark:text-indigo-400 shrink-0" fill="none"
     viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" aria-hidden="true">
  <path stroke-linecap="round" stroke-linejoin="round"
        d="M12 6.042A8.967 8.967 0 0 0 6 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 0 1 6 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 0 1 6-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0 0 18 18a8.967 8.967 0 0 0-6 2.292m0-14.25v14.25" />
</svg>
```
Predlog: BuildingLibraryIcon (knjižnica, klasično). Cursor naj izbere ali pusti uporabniku.

Postavi v link_to skupaj z naslovom:
```erb
<%= link_to root_path, class: "flex items-center gap-3 ..." do %>
  <%# ikona SVG %>
  <span class="block leading-tight">
    <span class="text-base sm:text-lg font-semibold ...">Tabla</span>
    <span class="block text-xs ...">Intranet KKC Lendava — Lendvai KKK</span>
  </span>
<% end %>
```

### B2. Subtilen gradient ozadja
Trenutno `bg-white dark:bg-slate-800`. Spremeni v:
```erb
<header class="bg-gradient-to-r from-white via-indigo-50/50 to-white
               dark:from-slate-800 dark:via-slate-800 dark:to-slate-800
               border-b border-slate-200 dark:border-slate-700 print:hidden">
```
Svetel način: subtilen indigo nadih v sredini. Temni način: enotna slate-800 (gradient bi bil
preveč izrazit v temnem). Lahko Cursor poskusi različne kombinacije.

### B3. Datum (opcijsko, vredno premisliti)
V desni del headerja, pred uporabniškimi akcijami, lahko dodaš datum:
```erb
<span class="hidden lg:block text-sm text-slate-500 dark:text-slate-400 mr-2">
  <%= l(Date.current, format: "%A, %-d. %-m. %Y") %>
</span>
```
Slovenski format: "petek, 25. 6. 2026". Pomembno: `I18n` mora imeti slovenske dneve/mesece —
preveri `config/locales/sl.yml` ali Rails i18n-sl gem. Če ni nastavljen, izpust ali angleški format.

### B4. Boljša tipografija subtitle
Trenutno subtitle "Intranet KKC Lendava — Lendvai KKK" v `text-xs`. Razmisli:
- Razdeli na dve vrstici? "KKC Lendava" / "Lendvai KKK" (madžarska različica)?
- Ali pusti v eni vrstici (zdajšnje)? Ostane berljivo.
Pusti kot je v tem prehodu — sprememba ni nujna.

## Del C: Splošni dodatki (OPCIJSKI — lahko v ločenem prehodu)

### C1. Hover-lift na karticah dokumentov
V `documents/_document_row.html.erb`, na zunanjem `<div>` kartice:
```erb
<div class="... transition-all duration-200 hover:shadow-lg hover:-translate-y-0.5">
```
Subtilen "lift" učinek na hover. Že ima sence — samo dodaj transition + hover stanja.

### C2. Heroicons na navigaciji
V `layouts/_nav_links.html.erb`, predobej ikono pred tekstom za vsako povezavo:
- Domov → HomeIcon
- Imenik → UserGroupIcon (ali PhoneIcon)
- Povezave → LinkIcon (ali GlobeAltIcon)
- Dokumenti → DocumentTextIcon (ali FolderIcon)
- Admin → Cog6ToothIcon (ali ShieldCheckIcon)
Vsaka povezava: `<flex items-center gap-2>` z SVG (h-4 w-4) + tekst. Ohrani aria oznake.

### C3. Lepše ločilne črte
Namesto navadne `border-t border-slate-200`, lahko poskusiš subtle gradient line:
```erb
<div class="h-px bg-gradient-to-r from-transparent via-slate-300 dark:via-slate-600 to-transparent"></div>
```
Ne na vseh mestih — samo kjer izstopa (npr. footer ali sekcije domače strani).

Del C je za kasneje — najprej A in B (vsebinske spremembe), C je polish.

## Reference
- `app/views/home/_directory.html.erb` (del A)
- `app/services/directory_table_builder.rb` (del A)
- `app/helpers/directory_helper.rb` ali `application_helper.rb` (helperji)
- `app/controllers/home_controller.rb` (priprava `@directory_rows_by_unit`)
- `config/locales/sl.yml` (prevodi za naslove skupin)
- `app/views/layouts/_header.html.erb` (del B)
- Heroicons: https://heroicons.com — inline SVG, "outline" različica

## Acceptance criteria

### Del A (imenik)
- [ ] `DirectoryTableBuilder.rows_by_unit_kind` vrne hash skupin
- [ ] Domača stran prikaže imenik v dva stolpca (md+): SIKLND levo, NOE desno
- [ ] Vsaka enota ima podnaslov ("SIKLND — Knjižnica", "NOE — Gledališče")
- [ ] Tabela: 3 stolpci (interna, zunanja, naziv) — stolpec "Enota" odpade
- [ ] Mobilni (<md): skupini eno pod drugim, kartice znotraj
- [ ] Vrstni red skupin: SIKLND prva, NOE druga (po `unit_position`)
- [ ] Brez vrstic brez lokacije, ki bi pokvarile vizualno (skrij ali pustimo "Ostalo")

### Del B (header)
- [ ] Ikona knjižnice (Heroicons SVG) levo od naslova
- [ ] Subtilen gradient ozadja (svetel način — indigo-50/50 v sredini)
- [ ] Tipografija: ikona + naslov + subtitle čisto poravnani
- [ ] Datum desno (opcijsko) v lg+ velikosti
- [ ] Funkcionalnost: navigacija, iskanje, dark mode, prijava, mobilni meni — vse deluje
- [ ] Print: header skrit (`print:hidden` ostane)

### Del C (opcijsko)
- [ ] Hover-lift na karticah dokumentov (transition + translate)
- [ ] Ikone v navigaciji (Heroicons SVG, h-4 w-4)
- [ ] Gradient ločilne črte (kjer smiselno)

## Test
1. Desktop (≥md): imenik v dveh stolpcih, vsaka enota ima svoj podnaslov in tabelo
2. Mobilni (<md): imenik kot ena navpična kolona, skupini ena pod drugim
3. Header: ikona + naslov + subtitle vidni, gradient subtilen, navigacija deluje
4. Dark mode: vse barve in gradient pravilno
5. Print preview: header skrit, vsebina vidna

## Out of scope
- Sprememba `Person`/`Location` modelov
- Razdelitev imenika tudi na `/persons` strani (samo domača za zdaj)
- Animacije/transitions povsod (samo kjer omenjeno)
- Logo grafika kot rasterska slika (uporabljamo SVG ikone)
