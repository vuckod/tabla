# Naloga 26: Kategorizacija uvoženih povezav

## Cilj
Uvoz (naloga 25) je dal vseh ~54 povezav v eno samo kategorijo "Uvožene povezave", zaradi
česar je blok povezav na domači strani zelo visok (in povzroča praznino ob krajšem imeniku).
Razdeli povezave v smiselne `LinkCategory` skupine, posodobi importer za prihodnje uvoze, in
omeji višino bloka na domači strani.

## Predpogoji
- Naloga 25 (uvoz) končana — povezave so v bazi v kategoriji "Uvožene povezave"
- `LinkCategory`, `Link` modela obstajata; blok `home/_external_links` že prikazuje po kategorijah

## Koraki

### 1. Definiraj ciljne kategorije in mapiranje
Ustvari mapiranje URL-domena/ključna beseda → kategorija. Predlagane kategorije (6):

| Kategorija            | Povezave (po domeni/imenu)                                                        |
|-----------------------|----------------------------------------------------------------------------------|
| **Interni sistemi**   | kl-kl.si, knjiznica-lendava.si (owa, webmail, tabla, galerija, digitalna, admin), 194.249.80.* (UserLock, SysLocator, PaperCut) |
| **COBISS**            | cobiss.si, cobiss*.izum.si (COBISS, COBISS KL, Moja knjižnica)                    |
| **Strokovni viri**    | nuk.uni-lj.si, sssg.nuk, udcmrf, islovar, nektar, dfmk, izum.si, zbds, biblioblog, revija-knjiznica, knjiznicarske novice, ebsco, najbolj brane |
| **Digitalne knjižnice** | dlib.si, nagykar.hu, theeuropeanlibrary, europeana                              |
| **Pravni in splošni viri** | uradni-list, iusinfo, tax-fin-lex, stat.si, itis, odpiralnicasi, podjetnik, zps |
| **Občine in lokalno** | lendava.si, dobrovnik, crensovci, turnisce, kobilje, velika-polana, odranci, lendava.net, zkp-lendava, mnmi-zkmn, nepujsag, gml |

Mapiranje naj bo v konstanti (npr. v `LegacyTableImporter` ali ločenem `LinkCategorizer`
service-u), da je pregledno in vzdržljivo. Pristop: za vsak URL preveri, ali vsebuje katero
od domen/ključnih besed za posamezno kategorijo; prva ujemajoča zmaga; če nič, fallback
"Ostale povezave".

### 2. Rake task za re-kategorizacijo OBSTOJEČIH povezav
`lib/tasks/import.rake` — nov task `import:recategorize_links`:
- Za vsako povezavo v kategoriji "Uvožene povezave" (ali vse povezave) določi pravo kategorijo
  prek mapiranja
- `LinkCategory.find_or_create_by(name:)` za ciljne kategorije (z `position`)
- Premakni povezavo v pravo kategorijo (`link.update(link_category: target)`)
- Idempotentno: ponovni zagon ne škodi
- Na koncu izbriši prazno "Uvožene povezave" kategorijo, če je ostala brez povezav
- Izpiši povzetek (koliko premaknjenih v katero kategorijo)

POZOR: ne podvajaj s SEED povezavami (naloga 11). Če seed povezava in uvožena povezava kažeta
na isti URL, sta že deduplicirani (importer je uporabil `find_or_create_by(url:)`). Re-kategorizacija
naj premakne samo uvožene, seed povezave pusti pri miru (ali jih tudi pravilno kategorizira —
presodi; varneje je premakniti vse v dosledne kategorije).

### 3. Posodobi importer za prihodnje uvoze
V `LegacyTableImporter#process_side_link` zamenjaj fiksno `IMPORTED_LINKS_CATEGORY` z
mapiranjem iz koraka 1 (uporabi isti `LinkCategorizer` / mapiranje). Tako bo prihodnji uvoz
takoj kategoriziral pravilno.

### 4. Omeji višino bloka povezav na domači strani (praznina)
Tudi po kategorizaciji je 54 povezav veliko za ozek blok (2/12). Reši praznino:
- **Pristop A (priporočen):** Na domačem bloku (`home/_external_links`) prikaži kategorije, a
  z omejeno višino + notranji drsnik: dodaj `max-h-[28rem] overflow-y-auto` na seznam, da blok
  ne raste neomejeno. Spodaj ostane "Vse povezave →" na `/links`.
- **Pristop B:** Na domačem bloku prikaži samo prvih N povezav na kategorijo (npr. 4) z
  "+N več" → `/links`. Polna kategorizirana lista na `/links`.

Izberi A (preprostejši, ohrani vse vidno z drsnikom). Polna stran `/links` naj prikaže vse
kategorije razprte (brez drsnika).

### 5. Stran /links — kategoriziran prikaz
Preveri, da `links#index` (`/links`) prikaže vse povezave grupirane po kategorijah (verjetno
že dela prek obstoječega view-a). Po re-kategorizaciji bo samodejno organizirano.

## Reference
- `app/services/legacy_table_importer.rb` — `process_side_link`, `IMPORTED_LINKS_CATEGORY`
- `app/views/home/_external_links.html.erb` — blok (že po kategorijah)
- `app/models/link.rb`, `link_category.rb`
- `app/controllers/links_controller.rb` + view

## Acceptance criteria
- [ ] Mapiranje domena/ključ → kategorija v pregledni konstanti
- [ ] `import:recategorize_links` premakne obstoječe povezave v prave kategorije (idempotentno)
- [ ] Prazna "Uvožene povezave" kategorija odstranjena, če ostane prazna
- [ ] Importer za prihodnje uvoze uporablja isto mapiranje
- [ ] Domači blok povezav ne raste neomejeno (max-h + drsnik), praznina zmanjšana
- [ ] `/links` prikaže vse povezave kategorizirano
- [ ] Brez podvajanja s seed povezavami
- [ ] `bin/tailwind-build` pognan

## Out of scope
- "Featured" zastavica na povezavah (model sprememba) — ne potrebujemo
- Admin UI za vlečenje povezav med kategorijami (obstoječi CRUD zadošča)
