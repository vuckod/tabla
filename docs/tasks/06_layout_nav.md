# Naloga: Osnovni layout in navigacija

## Cilj
Zamenjaj privzeti Rails layout s pravim layoutom za Tablo: header z navigacijo, flash sporočili,
dark mode preklopom, in responsive ogrodjem za vsebino. To je temelj, na katerem stojijo vse
naslednje UI naloge (imenik, povezave, dokumenti).

## Predpogoji
- Aplikacija se zažene brez napak (`docker compose up`)
- Login flow deluje (`SessionsController`, `PrisotnostApiClient`)
- `current_user` helper je na voljo v `ApplicationController`

## Koraki

### 1. Tailwind dark mode konfiguracija
Preveri `app/assets/tailwind/application.css` (ali `config/tailwind.config.js`, odvisno od
verzije tailwindcss-rails) — omogoči `dark:` variant na podlagi `class` strategije (ne `media`),
da lahko uporabnik ročno preklaplja ne glede na sistemske nastavitve.

### 2. Stimulus kontroler za dark mode
Ustvari `app/javascript/controllers/dark_mode_controller.js`:
- Preklaplja `dark` razred na `<html>` elementu
- Shrani preferenco v `localStorage` (ali cookie, če želiš server-side persistenco)
- Ob `connect()` prebere shranjeno preferenco in jo takoj uveljavi (preprečuje "flash" napačne teme ob nalaganju)

### 3. Posodobi `app/views/layouts/application.html.erb`
Struktura:
```
<html data-controller="dark-mode" class="...">
  <head>...</head>
  <body class="bg-slate-50 dark:bg-slate-900 text-slate-900 dark:text-slate-100">
    <%= render "layouts/header" %>

    <% if flash.any? %>
      <%= render "layouts/flash" %>
    <% end %>

    <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
      <%= yield %>
    </main>
  </body>
</html>
```
Odstrani placeholder `container mx-auto mt-28 flex` razrede — niso primerni za to postavitev.

### 4. Ustvari `app/views/layouts/_header.html.erb`
Vsebuje:
- Logo/naziv "Tabla — Intranet KL-KL" (povezava na `root_path`)
- Navigacijske povezave: Domov, Imenik, Povezave, Dokumenti (vse `link_to` na ustrezne route-e
  — `root_path`, `persons_path`, `links_path`, `documents_path`)
- Če `current_user&.admin?` ali `urednik?` — dodaten link "Administracija" (na `admin_root_path`,
  ki ga dodaš v routes ali pusti kot TODO če admin namespace še nima root akcije)
- Dark mode toggle gumb (Stimulus action `data-action="click->dark-mode#toggle"`)
- Prikaz `current_user.polno_ime` z odjava linkom (`button_to logout_path, method: :delete` —
  preveri, da routes uporablja `delete "logout"` ali popravi na `get`, glede na obstoječi routes.rb)
- Mobilna verzija: hamburger meni (Stimulus `toggle` kontroler ali `details/summary` HTML pattern)
  ki se na `sm:` in večjih zaslonih skrije v favor horizontalne navigacije

### 5. Ustvari `app/views/layouts/_flash.html.erb`
- Render vsak `flash` tip (`notice`, `alert`) z ustrezno barvo (zeleno/rdeče)
- Dark mode varianta
- Stimulus kontroler `flash_controller.js` za samodejno izginotje po nekaj sekundah (opcijsko)

### 6. Posodobi `app/views/home/index.html.erb`
Odstrani placeholder kartice, pusti osnovno strukturo (3 stolpce: imenik / povezave / dokumenti)
pripravljeno za naslednje naloge, ki bodo vsako sekcijo napolnile z resničnimi podatki.

## Reference
- `delovodnik_rails/app/views/layouts/application.html.erb` — splošna struktura
- `delovodnik_rails/app/javascript/controllers/dark_mode_controller.js` — Stimulus vzorec
- `delovodnik_rails/app/views/layouts/_header.html.erb` (če obstaja) — navigacijski vzorec
- `docs/00_overview.md` — sekcija "UI/UX smer" za layout wireframe

## Acceptance criteria
- [ ] Aplikacija se naloži brez JS napak v konzoli
- [ ] Dark mode toggle deluje in preživi refresh strani (persistenca)
- [ ] Header je responsive — na mobilnem (< 640px) se navigacija zloži v hamburger meni
- [ ] Flash sporočila se prikažejo ob loginu/logoutu z ustrezno barvo
- [ ] Odjava deluje in preusmeri na login stran
- [ ] Vsi navigacijski linki vodijo na obstoječe route-e (ali na razumen placeholder, če route še ne obstaja)
- [ ] Print media (`print:hidden` na navigaciji in gumbih) — dokumenti naj bodo printable brez UI elementov

## Out of scope
- Dejanska vsebina imenika/povezav/dokumentov na domači strani — to so ločene naloge
- Admin panel notranja navigacija — ločena naloga
- Globalni iskalnik (Cmd+K) — faza 2
