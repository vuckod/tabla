# Naloga 15: Telefonski imenik — tabelaričen prikaz

## Cilj
Imenik na domači strani (levi široki blok, pod obvestili) kot kompakten tabelaričen prikaz:
interna številka | zunanja številka | naziv mesta | enota. Prikaže tako osebe (z imenom) kot
samostojna mesta (brez osebe). Rumeni barvni blok.

## Predpogoji
- Naloga 14 (layout, barvni bloki) končana
- Modeli `PhoneNumber`, `Person`, `Location` obstajajo (iz naloge 07)

## Kontekst podatkovnega modela
- `PhoneNumber` ima `kind` (external/internal/mobile/fax), `label`, `person_id` (opcijski),
  `location_id` (opcijski)
- Vrstica imenika lahko izhaja iz osebe (Person z njenimi številkami) ALI iz samostojne
  številke vezane samo na lokacijo z `label` (naziv mesta, npr. "izposoja ML")
- Primer ciljne vrstice: `587 | 02 574 25 87 | izposoja ML | knjižnica`

## Koraki

### 1. Pripravi podatke v `home#index` (ali ločen helper/query objekt)
Sestavi enoten seznam vrstic imenika. Vsaka vrstica ima:
- `internal` — interna številka (kind: internal)
- `external` — zunanja številka (kind: external)
- `naziv` — ime osebe (`person.full_name`) ALI `label` mesta
- `enota` — `location.short_code` ali `location.name`

Pristopi (izberi enostavnejšega):
- **A:** Grupiraj `PhoneNumber`-je po osebi/mestu in sestavi vrstice
- **B:** Dodaj v `Person` in `Location` modela metode, ki vrnejo svojo interno/zunanjo številko,
  in iteriraj po osebah + samostojnih lokacijskih številkah

Za zdaj naredi enostavno: prikaži osebe (z njihovimi internimi/zunanjimi številkami) in
samostojne lokacijske številke z `label`. Uredi po enoti, nato po nazivu.

### 2. Partial `home/_directory.html.erb` — rumeni blok
- Uporabi `shared/_block` z `color: yellow`, naslov "Telefonski imenik"
- Tabela (na desktopu) s stolpci: Interna | Zunanja | Naziv | Enota
- Na mobilnem: kompaktne kartice ali zložljiva tabela (ne horizontalni scroll)
- Telefonske številke kot `tel:` linki (klik kliče na mobilnih napravah)
- Enota kot majhna značka (knjižnica = ena barva, gledališče = druga)

### 3. Filter/iskanje znotraj imenika (neobvezno v tej fazi)
Lahko dodaš lokalni filter po nazivu (Stimulus auto-submit kot v nalogi 07), ampak primarni
globalni iskalnik pride v nalogi 18. Če dodaš, naj ne moti postavitve bloka.

### 4. Polna stran imenika ostane
`/persons` (iz naloge 07) ostane kot podrobnejši pogled. Domača stran je kompakten povzetek.
Dodaj link "Celoten imenik →" na `persons_path` v nogi bloka.

## Reference
- `docs/04_ui_design.md` — postavitev, rumena barva imenika
- `app/models/phone_number.rb`, `person.rb`, `location.rb`
- Priložen PHP screenshot — referenca tabelaričnega prikaza številk

## Acceptance criteria
- [ ] Imenik prikazan kot rumeni blok v levem širokem stolpcu
- [ ] Tabela: interna | zunanja | naziv mesta | enota
- [ ] Prikazane tako osebe (z imenom) kot samostojna mesta (label brez osebe)
- [ ] Enota vidna kot značka
- [ ] Telefonske številke so `tel:` linki
- [ ] Responsive — brez horizontalnega scrolla na mobilnem
- [ ] Link na celoten imenik (`/persons`)

## Out of scope
- Globalni iskalnik — naloga 18
- Urejanje imenika (admin CRUD že obstaja iz naloge 07)
