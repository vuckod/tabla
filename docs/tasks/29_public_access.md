# Naloga 29: Javni dostop (prijava samo za ogled/prenos dokumentov)

## Cilj
Obrni privzeto avtentikacijo: stran naj bo dostopna BREZ prijave (imenik, povezave, obvestila,
SEZNAM dokumentov z naslovi/značkami/datumi), prijava pa naj bo potrebna SAMO za:
- ogled vsebine dokumenta (predogled `documents#show` / `documents#preview`)
- prenos dokumenta (`documents#download`)
- admin del (kot doslej)

internal_only dokumenti ostanejo skriti pred neprijavljenimi IN prijavljenimi bralci (obstoječa
`visible_to` logika — NE spreminjaj).

## Trenutno stanje (analiza)
- `ApplicationController` ima globalni `before_action :require_login` → vse zaklenjeno
- `HomeController` že ima `skip_before_action :require_login`
- `SessionsController` že ima `skip_before_action :require_login, only: %i[new create]`
- `Document.visible_to(nil)` že pravilno vrne samo `internal_only: false` (varno za neprijavljene)
- `ApplicationPolicy` že varno obravnava `nil` uporabnika (`user.present?`, `user&.admin?`)
- `DocumentPolicy#show?`/`download?` že uporablja `user&.admin?` (varno za nil)

Torej je večina temeljev že pripravljena. Glavna sprememba je obrnitev privzete `require_login`
logike iz "vse zaklenjeno" v "vse odprto, razen izrecno zaščiteno".

## Koraki

### 1. ApplicationController — odstrani globalni require_login
Odstrani `before_action :require_login` iz `ApplicationController` (da privzeto NE zahteva
prijave). Metodo `require_login` OBDRŽI (uporabljena bo selektivno v kontrolerjih, ki jo rabijo).

POZOR: `set_current_user`, `track_ahoy_*` after_action ostanejo — delujejo tudi za nil uporabnika
(`Current.user = nil` je v redu). Preveri, da Ahoy tracking ne pade pri nil uporabniku.

Ker `HomeController` in `SessionsController` zdaj uporabljata `skip_before_action :require_login`
za nekaj, kar ne obstaja več, ODSTRANI te `skip_before_action :require_login` vrstice iz njiju
(sicer Rails vrže napako "before_action :require_login has not been defined"). Pusti pa
SessionsControllerjev `skip` samo, če je potrebno — ker globalnega filtra ni več, ga ne rabi.

### 2. Zakleni samo dokumentne akcije za ogled/prenos
V `DocumentsController` dodaj `before_action :require_login, only: %i[show preview download]`.
Tako:
- `index` (seznam dokumentov) → JAVEN (naslovi, značke, datumi vidni)
- `show` (predogled), `preview` (searchable PDF), `download` (prenos) → zahtevajo prijavo

POZOR: `set_document` v DocumentsController uporablja `Document.visible_to(current_user)`. Za
neprijavljenega (`current_user = nil`) to vrne samo javne dokumente — ampak ker `require_login`
preusmeri PRED `set_document` (oba before_action, vrstni red), neprijavljen do `show` sploh ne
pride. Preveri vrstni red: `require_login` MORA biti pred `set_document`.

### 3. Admin del ostane zaklenjen
Vsi `Admin::*` kontrolerji morajo ostati zaklenjeni. Ker odstranjujemo globalni `require_login`,
admin kontrolerji ga zdaj NIMAJO. Dodaj zaščito:
- **Pristop A (priporočen):** Ustvari `Admin::BaseController < ApplicationController` z
  `before_action :require_login` + `before_action :require_editor` (preveri admin/urednik), in
  vsi admin kontrolerji naj dedujejo od njega namesto od ApplicationController.
- **Pristop B:** Dodaj `before_action :require_login` v vsak admin kontroler posebej.

Izberi A (DRY, varneje). `require_editor` naj preusmeri ne-editorje (bralce in neprijavljene)
z razumljivim sporočilom. POZOR: admin kontrolerji že kličejo `authorize` (Pundit), ki preveri
vloge — ampak Pundit `authorize` brez prijave bi vrgel napako pri nil; eksplicitni `require_login`
najprej je čistejši.

### 4. Druge javne strani (preveri/potrdi)
Te naj bodo JAVNE (brez require_login) — ker odstranjujemo globalni filter, bodo samodejno javne:
- `HomeController#index` (domača stran) ✓
- `LinksController` (`/links`) — javen
- `PersonsController`, `LocationsController` (imenik) — javna
- `SearchController` (`/search`) — javen, AMPAK rezultati morajo spoštovati `visible_to(nil)`
  (neprijavljen ne sme najti internal_only). Preveri, da SearchController varnostni filter
  za nil uporabnika vrne samo javne (Meilisearch `internal_only = false` + defense-in-depth
  `visible_to(nil)`). To MORA delovati za nil uporabnika.

### 5. Navigacija / UI za neprijavljene
- Header: za neprijavljenega prikaži gumb "Prijava" namesto "Odjava"/uporabniškega imena
- Gumba "Prikaži"/"Prenesi" pri dokumentih: za neprijavljenega lahko (a) ostaneta vidna, klik
  preusmeri na login (require_login to naredi), ali (b) prikaži namig "Za ogled se prijavite".
  Izberi (a) — preprosteje; klik vodi na login z `flash` sporočilom. Po prijavi naj se uporabnik
  vrne na želeni dokument (glej korak 6).
- Admin povezave v navigaciji: prikaži samo prijavljenim editorjem (verjetno že tako)

### 6. Po prijavi: vrnitev na želeno stran (return_to)
Ko neprijavljen klikne na predogled/prenos, ga `require_login` preusmeri na login. Po uspešni
prijavi naj se vrne na prvotno želeni URL (ne na root):
- V `require_login`: shrani `session[:return_to] = request.fullpath` (samo za GET requeste)
- V `SessionsController#create`: po prijavi `redirect_to(session.delete(:return_to) || root_path)`
Tako klik na dokument → login → po prijavi nazaj na dokument. Lepši UX.

### 7. Varnostni pregled (kritično)
Po spremembah PREVERI, da neprijavljen NE more:
- odpreti predogleda dokumenta (`/documents/:id` → redirect na login)
- prenesti dokumenta (`/documents/:id/download` → redirect na login)
- dostopati do `/documents/:id/preview` (searchable PDF → redirect na login)
- videti internal_only dokumentov nikjer (seznam, iskanje)
- dostopati do admin dela (`/admin/*` → redirect na login)
- najti internal_only prek iskanja

In da neprijavljen LAHKO:
- vidi domačo stran, imenik, povezave, obvestila
- vidi seznam dokumentov (naslovi, značke, datumi)
- išče (a najde samo javne dokumente)

## Reference
- `app/controllers/application_controller.rb` — `require_login`, before_action
- `app/controllers/documents_controller.rb` — show/preview/download/index, set_document
- `app/controllers/admin/*` — vsi morajo ostati zaklenjeni
- `app/controllers/search_controller.rb` — varnostni filter za nil uporabnika
- `app/models/document.rb` — `visible_to` (NE spreminjaj)
- `app/policies/document_policy.rb`, `application_policy.rb` — že nil-safe

## Acceptance criteria
- [ ] Globalni `require_login` odstranjen iz ApplicationController
- [ ] `DocumentsController` show/preview/download zahtevajo prijavo; index javen
- [ ] `Admin::BaseController` z require_login + require_editor; vsi admin kontrolerji dedujejo
- [ ] Domača stran, imenik, povezave, obvestila, seznam dokumentov JAVNI
- [ ] Iskanje javno, a za nil uporabnika vrne SAMO javne dokumente (brez internal_only)
- [ ] internal_only nikjer viden neprijavljenemu (in bralcu)
- [ ] Header prikaže "Prijava" za neprijavljenega, "Odjava" za prijavljenega
- [ ] Po prijavi vrnitev na prvotno želeni dokument (return_to)
- [ ] Ahoy tracking ne pade pri nil uporabniku
- [ ] Varnostni pregled (korak 7) v celoti opravljen

## Out of scope
- E-mail obvestila — ločena naloga
- Produkcijski deploy — ločena naloga
- Sprememba internal_only logike (ostane nespremenjena)
