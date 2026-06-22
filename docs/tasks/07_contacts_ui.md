# Naloga: Telefonski imenik — prikaz in admin CRUD

## Cilj
Implementiraj javni prikaz telefonskega imenika (osebe + lokacije s številkami) in admin
vmesnik za urejanje. Podatkovni model (`Location`, `Person`, `PhoneNumber`) in seed podatki
za lokacije že obstajajo — ta naloga je samo UI plast.

## Predpogoji
- `docs/tasks/06_layout_nav.md` končana (potreben je header/layout)
- Modeli `Location`, `Person`, `PhoneNumber` obstajajo z migracijami in seed podatki

## Koraki

### 1. `PersonsController` (javni prikaz)
```ruby
class PersonsController < ApplicationController
  def index
    @locations = Location.ordered.includes(persons: :phone_numbers)
    @persons = Person.active.ordered.includes(:phone_numbers, :location)
    @persons = @persons.by_location(params[:location_id]) if params[:location_id].present?
  end

  def show
    @person = Person.find(params[:id])
  end
end
```

### 2. View `app/views/persons/index.html.erb`
- Filter po lokaciji (dropdown ali tabs — glej `Location.ordered`)
- Lokalni iskalnik po imenu/priimku (uporabi `UnaccentSearchable.where_single_term_or_match`,
  Stimulus `auto-submit` kontroler za sprotno filtriranje brez page reload)
- Tabela ali kartice z: ime priimek, delovno mesto, lokacija, telefonske številke
  (ločeno po `kind`: zunanja/interna/GSM/faks z ikonami ali labeli)
- Responsive: na mobilnem kartice namesto tabele

### 3. Lokacije z lastnimi številkami (centrala, krajevne knjižnice)
Poleg oseb, prikaži tudi `Location` zapise z lastnimi `phone_numbers` (centrala, blagajna)
in `schedule_info` za krajevne knjižnice (urnik PON-PET). Glej obstoječi PHP screenshot za
referenco strukture (priložen na začetku projekta — SIKLND/NOE skupine, krajevne knjižnice
spodaj s urniki).

### 4. Admin CRUD — `Admin::PersonsController`
```ruby
module Admin
  class PersonsController < ApplicationController
    before_action :authorize_editor!

    def index; end
    def new; end
    def create; end
    def edit; end
    def update; end
    def destroy; end

    private

    def authorize_editor!
      authorize Person, policy_class: PersonPolicy
    end
  end
end
```
Uporabi Pundit `PersonPolicy < ApplicationPolicy` (deduje `editor?` logiko iz base policy).

### 5. Nested form za telefonske številke
V `admin/persons/_form.html.erb` uporabi `accepts_nested_attributes_for :phone_numbers`
(že definirano v modelu) — dinamično dodajanje/odstranjevanje številk s Stimulus kontrolerjem
(`nested_form_controller.js` ali podoben "add fields" pattern).

### 6. Admin CRUD — `Admin::LocationsController`
Enako za lokacije — admin lahko ureja urnike krajevnih knjižnic, telefonske številke lokacij.

### 7. Politike
```ruby
# app/policies/person_policy.rb
class PersonPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
```
Enako za `LocationPolicy`, `PhoneNumberPolicy`.

## Reference
- `docs/01_data_model.md` — modeli Location, Person, PhoneNumber
- Priloženi screenshot stare PHP table (na začetku projekta) — vizualna referenca strukture
- `app/models/concerns/unaccent_searchable.rb` — za iskalnik
- `delovodnik_rails` admin CRUD kontrolerji — splošen vzorec

## Acceptance criteria
- [ ] `/persons` prikaže vse aktivne osebe z njihovimi telefonskimi številkami
- [ ] Filter po lokaciji deluje
- [ ] Iskanje po imenu/priimku ignorira šumnike (Žiga = ziga)
- [ ] Lokacije s skupnimi številkami (centrala, blagajna) so vidne ločeno od oseb
- [ ] Krajevne knjižnice prikazujejo urnik
- [ ] Admin lahko CRUD osebe, lokacije in njihove telefonske številke
- [ ] Samo admin/urednik vidi admin povezave in lahko dostopa do `/admin/persons`
- [ ] Bralec (navadna vloga) dobi 403/redirect, če poskusi dostopati do admin poti
- [ ] Responsive na mobilnem zaslonu

## Out of scope
- Sinhronizacija oseb iz Prisotnost API-ja (osebe v imeniku so ločene od User modela — ročno
  vnašanje/urejanje v tej fazi)
- Fotografije oseb (morebitna faza 2)
