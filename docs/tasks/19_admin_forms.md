# Naloga 19: Izboljšava admin obrazcev (UX)

## Cilj
Admin obrazci za vnos (osebe, lokacije, povezave, dokumenti, obvestila, kategorije) so
trenutno nepregledni. Poenoti jih v konsistenten, pregleden videz: skupna komponenta za polja,
jasne sekcije, boljši razmiki, opisi polj, in konsistentni gumbi. To je čisto UX/view naloga —
NE spreminjaj modelov, kontrolerjev ali validacij.

## Predpogoji
- Vsi admin CRUD-i obstajajo (naloge 07, 08, 09, 13)
- `bin/tailwind-build` po koncu (novi razredi)

## Kontekst
Trenutno vsak admin obrazec (`admin/persons/_form`, `admin/links/_form`, itd.) sam definira
svoje stiliranje polj, kar vodi v nekonsistenco. Cilj je skupna množica form helperjev/partialov.

## Koraki

### 1. Skupni form helperji (`FormHelper` ali `AdminFormHelper`)
Ustvari pomožne metode za pogosta polja, da imajo vsi obrazci isti videz:
- `admin_text_field(form, field, label:, hint: nil)` — label + input + opcijski opis + napake
- `admin_text_area(form, field, label:, rows: 4, hint: nil)`
- `admin_select(form, field, options, label:, hint: nil, include_blank: false)`
- `admin_checkbox(form, field, label:, hint: nil)`
- `admin_datetime_field(form, field, label:, hint: nil)`
- `admin_submit(form, label: nil)` — konsistenten primarni gumb

Vsak naj vključuje:
- Label (`text-sm font-medium text-slate-700 dark:text-slate-300`)
- Polje s konsistentnim stilom (`rounded-md border-slate-300 dark:border-slate-600 dark:bg-slate-700`, focus indigo)
- Opcijski hint (`text-xs text-slate-500` pod poljem)
- Prikaz field-specific napak (rdeče besedilo pod poljem)

### 2. Skupna ovojnica obrazca (`admin/shared/_form_wrapper` ali helper)
- Kartica z belim/temnim ozadjem, senco, zaobljenimi robovi
- Sekcije z naslovi (npr. "Osnovni podatki", "Telefonske številke", "Nastavitve objave")
- Vrstica z gumbi na dnu (primarni "Shrani" + sekundarni "Prekliči" → nazaj na index)
- Povzetek napak na vrhu (če `object.errors.any?`)

### 3. Preuredi vse admin obrazce z novimi helperji
Posodobi (samo view sloj, ne logika):
- `admin/persons/_form.html.erb` — osnovni podatki + nested telefonske številke v svoji sekciji
- `admin/locations/_form.html.erb`
- `admin/links/_form.html.erb` + `admin/link_categories/_form.html.erb`
- `admin/documents/_form.html.erb`
- `admin/announcements/_form.html.erb`

### 4. Konsistenten admin index videz (neobvezno, če čas dopušča)
Poenoti tudi sezname (tabele) v admin namespace: isti stil tabel, "Uredi"/"Izbriši" gumbi,
"Dodaj nov" gumb na vrhu, prazno stanje.

### 5. Mobilna uporabnost
Obrazci morajo biti uporabni na tablici/telefonu (admin morda ureja iz tablice). Polja polne
širine na mobilnem, razumni razmiki.

## Reference
- `delovodnik_rails` admin obrazci — vzorec konsistentnega stiliranja
- `delovodnik_rails/app/javascript/controllers/file_preview_controller.js` — prikaz izbrane datoteke
- `.cursor/rules/03_hotwire_frontend.mdc` — dark mode, responsive, I18n

## Acceptance criteria
- [ ] Vsi admin obrazci uporabljajo skupne form helperje (konsistenten videz)
- [ ] Vsako polje ima jasen label; kjer koristno, kratek hint
- [ ] Povzetek napak na vrhu + field-specific napake pod polji
- [ ] Sekcije z naslovi pri daljših obrazcih (npr. oseba + telefonske številke)
- [ ] Primarni in sekundarni (Prekliči) gumb na dnu
- [ ] Dark mode in responsive delujeta
- [ ] NOBENA sprememba v modelih/kontrolerjih/validacijah/routes
- [ ] `bin/tailwind-build` pognan na koncu

## Out of scope
- Dodajanje novih značk dokumentov — naloga 20
- Predogled dokumentov — naloga 21
- Karkoli, kar zahteva spremembo modela ali kontrolerja
