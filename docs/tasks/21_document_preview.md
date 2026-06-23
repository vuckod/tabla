# Naloga 21: Predogled dokumenta (inline + nov zavihek)

## Cilj
Trenutno dokument ponuja samo prenos. Dodaj stran predogleda dokumenta (`documents#show`),
ki prikaže PDF inline v brskalniku (iframe), z gumboma za odpiranje v novem zavihku in prenos.
Vzorec po Delovodniku (`preview_switcher` / `file_preview` pristop).

## Predpogoji
- `DocumentsController#show` obstaja (naloga 09), trenutno verjetno minimalen
- `Document#file` (Active Storage) obstaja
- Pundit `DocumentPolicy#show?` obstaja (varnost za internal_only)

## Koraki

### 1. `DocumentsController#show` — pripravi podatke za predogled
- `@document` že naložen prek `set_document` (z `visible_to` scope — varnost)
- `authorize @document` (že je)
- Pripravi URL za inline prikaz: `rails_blob_path(@document.file, disposition: "inline")`
  (POZOR: "inline", ne "attachment" — da se PDF prikaže v iframe namesto prenese)
- Pripravi URL za prenos: `rails_blob_path(@document.file, disposition: "attachment")`

### 2. View `documents/show.html.erb`
Postavitev:
- Glava: naslov dokumenta, značka kategorije (`category_badge`), datum objave, internal_only oznaka
- Gumbi (vrstica, `print:hidden`):
  - "Odpri v novem zavihku" → inline URL, `target="_blank"`
  - "Prenesi" → attachment URL
  - "Nazaj" → `documents_path`
- Predogled: `<iframe>` z inline URL-jem, primerna višina (npr. `h-[80vh] w-full`), border
- Fallback: če brskalnik ne prikaže PDF v iframe, sporočilo + gumb za nov zavihek

### 3. Povezava do predogleda iz seznamov
V `documents/_list` (in `_document_row`) naredi naslov dokumenta povezavo na `document_path(document)`
(predogled), poleg obstoječega gumba za prenos. Tako uporabnik klikne naslov → predogled,
ali gumb → direktni prenos.

### 4. Varnost (kritично)
- Predogled MORA spoštovati `visible_to(current_user)` — `set_document` to že dela
- `internal_only` dokument: bralec dobi 404 (ker `set_document` filtrira), admin/urednik vidi
- inline disposition ne sme zaobiti Pundit avtorizacije

### 5. Mobilni predogled
Na ozkih zaslonih je iframe PDF predogled pogosto neuporaben (PDF se slabo prikaže). Na
mobilnem (`< md`) raje prikaži veliko "Odpri dokument" gumb namesto iframe, ali pa iframe z
opozorilom. Presodi po Delovodnikovem vzorcu.

## Reference
- `delovodnik_rails/app/javascript/controllers/preview_switcher_controller.js` — preklop predogleda
- `delovodnik_rails/app/javascript/controllers/file_preview_controller.js`
- Delovodnik `documents#show` ali ekvivalent — vzorec iframe predogleda PDF
- `app/controllers/documents_controller.rb` — obstoječi show/download
- `app/policies/document_policy.rb` — varnostni scope

## Acceptance criteria
- [ ] `documents#show` prikaže PDF inline v iframe
- [ ] Gumb "Odpri v novem zavihku" deluje (inline disposition)
- [ ] Gumb "Prenesi" deluje (attachment disposition)
- [ ] Naslov dokumenta v seznamu vodi na predogled
- [ ] `internal_only` dokument ni dostopen bralcu (404), je admin/uredniku
- [ ] Predogled uporaben na mobilnem (fallback gumb namesto neuporabnega iframe)
- [ ] Glava predogleda: naslov, značka, datum
- [ ] `bin/tailwind-build` pognan

## Out of scope
- OCR / iskanje po vsebini — naloga 22
- Predogled ne-PDF datotek (zaenkrat samo PDF, ker model validira PDF)
- Anotacije / komentarji na dokumentu
