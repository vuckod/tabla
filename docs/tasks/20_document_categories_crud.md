# Naloga 20: Upravljanje značk dokumentov (DocumentCategory CRUD + inline)

## Cilj
Admin lahko upravlja značke dokumentov (`DocumentCategory`): ločen CRUD vmesnik (seznam,
dodaj, uredi, izbriši, z izbiro barve) IN hitro inline dodajanje nove značke kar med
nalaganjem dokumenta (brez zapuščanja document forme).

## Predpogoji
- Naloga 19 (admin form helperji) končana — uporabi iste helperje
- `DocumentCategory` model + `category_badge` helper (naloga 17) obstajata
- `DocumentCategory` ima `color`, `name`, `slug`, `position` stolpce

## Koraki

### 1. Admin CRUD — `Admin::DocumentCategoriesController`
Standardni CRUD (kot `Admin::LinkCategoriesController`):
- `index` — seznam značk s predogledom barve (uporabi `category_badge`), vrstni red, število dokumentov
- `new`/`create`, `edit`/`update`, `destroy`
- Pundit `DocumentCategoryPolicy < ApplicationPolicy` (editor lahko ureja, admin briše)
- `destroy` — preveri, da značka NIMA dokumentov (model že ima `dependent: :restrict_with_error`),
  prikaži razumljivo napako če je značka v uporabi

### 2. Routes
V `namespace :admin` dodaj `resources :document_categories`.

### 3. Forma za značko (`admin/document_categories/_form`)
- Polje `name` (obvezno)
- Izbira barve `color` — vizualni izbirnik (radio gumbi ali dropdown z barvnimi vzorci);
  ponudi fiksni nabor barv, ki jih `category_badge` pozna: red, amber, orange, blue, green,
  purple, slate, indigo
- `slug` — naj se samodejno generira iz imena (model to že dela v `before_validation`), zato
  ga v formi NE prikazuj (ali samo read-only za info)
- `position` — vrstni red

### 4. Inline dodajanje v document formi
V `admin/documents/_form.html.erb` poleg obstoječega `document_category_id` selecta dodaj
gumb "+ Nova značka", ki odpre majhen inline obrazec (Turbo Frame ali Stimulus toggle), kjer
admin vnese ime + barvo nove značke, jo shrani prek AJAX/Turbo, in novo značka se takoj
pojavi izbrana v selectu.

Pristop (izberi enostavnejšega za Turbo):
- **A (Turbo Frame + Stream):** gumb naloži `new` document_category formo v Turbo Frame;
  ob submit `create` vrne Turbo Stream, ki doda novo opcijo v select in jo izbere
- **B (preprosto):** majhen ločen modal/inline form, ki POST-a na `admin_document_categories`
  z `format: :turbo_stream`; odgovor osveži select

Če je inline preveč kompleksno za zanesljivo izvedbo, naredi vsaj **A** robustno, sicer pa
fallback: link "Upravljaj značke" → odpre `/admin/document_categories` v novem zavihku.

### 5. Posodobi seed
Seed značk (naloga 17) ostane; preveri, da so barve nastavljene. Inline/CRUD samo dodaja
možnost upravljanja prek UI.

## Reference
- `app/controllers/admin/link_categories_controller.rb` — vzorec category CRUD
- `app/helpers/documents_helper.rb` — `category_badge`, barvni nabor
- `app/models/document_category.rb` — `dependent: :restrict_with_error`, auto slug

## Acceptance criteria
- [ ] `/admin/document_categories` — poln CRUD z izbiro barve
- [ ] Barva se izbere vizualno (vidi se vzorec barve)
- [ ] Brisanje značke z dokumenti prepreči razumljiva napaka
- [ ] V document formi gumb "+ Nova značka" omogoča dodajanje brez zapuščanja strani
- [ ] Nova značka se takoj pojavi izbrana v selectu
- [ ] Pundit: editor ureja, admin briše
- [ ] Dark mode + responsive
- [ ] `bin/tailwind-build` pognan

## Out of scope
- Več značk na dokument (ostajamo pri eni — `document_category_id`)
- Predogled dokumenta — naloga 21
