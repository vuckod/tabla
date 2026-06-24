# Naloga 24: Popravek predogleda — searchable PDF z označljivim besedilom

## Cilj
Dva problema s trenutnim predogledom dokumenta:
1. **Predogled nekonsistenten** — po osveževanju včasih sproži prenos namesto inline prikaza
   (Active Storage redirect + Turbo interakcija).
2. **Besedilo ni označljivo** — predogled kaže originalni (skenirani) PDF brez besedilne plasti,
   zato uporabnik ne more označiti/kopirati besedila.

Rešitev obojega hkrati: predogled naj prikaže **searchable sandwich PDF** (ki ga je OCR
generiral, ima OCR besedilno plast čez sken → besedilo je označljivo), serviran prek lastne
kontrolerske akcije z eksplicitnim `Content-Disposition: inline` (zanesljiv prikaz, brez Active
Storage redirect kapric).

## Predpogoji
- Naloga 22 (OCR) končana — `OcrLog#searchable_pdf` se generira
- Naloga 21 (predogled) obstaja — to nalogo nadgrajujemo
- `Document#latest_searchable_ocr_log` in `searchable_pdf_available?` metodi obstajata (dodani v model)

## Koraki

### 1. Nova kontrolerska akcija `DocumentsController#preview`
Doda member route in akcijo, ki servira searchable PDF inline:
```ruby
# routes.rb — v resources :documents member bloku, poleg :download
member do
  get :download
  get :preview   # servira searchable sandwich PDF inline
end
```

```ruby
# DocumentsController
def preview
  authorize @document, :show?

  ocr_log = @document.latest_searchable_ocr_log
  if ocr_log&.searchable_pdf&.attached?
    blob = ocr_log.searchable_pdf.blob
    send_data blob.download,
              filename: blob.filename.to_s,
              type: "application/pdf",
              disposition: "inline"
  elsif @document.file.attached?
    # Fallback: če searchable PDF (še) ni na voljo, servira original inline
    blob = @document.file.blob
    send_data blob.download,
              filename: blob.filename.to_s,
              type: "application/pdf",
              disposition: "inline"
  else
    redirect_to documents_path, alert: t("views.documents.file_missing")
  end
end
```
POZOR varnost: `authorize @document, :show?` + `set_document` že filtrira `visible_to`. Akcija
mora ostati zaščitena enako kot `show`/`download`.

POZOR zmogljivost: `send_data blob.download` naloži celoten PDF v pomnilnik. Za večino dokumentov
(< 50MB) je to v redu. Če bi bili dokumenti veliki, razmisli o `send_file` s potjo, ampak za
Active Storage `send_data` z `blob.download` je standardni pristop.

### 2. Posodobi `documents/show.html.erb` predogled
Zamenjaj iframe `src` z novo preview potjo:
```erb
<iframe src="<%= preview_document_path(@document) %>"
        title="<%= @document.title %>"
        class="w-full h-[80vh] ..."
        ...></iframe>
```
Tako iframe naloži PDF prek našega kontrolerja (zanesljiv inline), ne prek Active Storage
redirect URL-ja.

Posodobi tudi mobilni "Odpri dokument" gumb in "Odpri v novem zavihku" → naj kažeta na
`preview_document_path(@document)` (searchable PDF z označljivim besedilom).

"Prenesi" gumb ostane na `download_document_path` (originalni dokument za prenos).

### 3. Indikator "iskljivo besedilo"
Če `@document.searchable_pdf_available?`, prikaži v glavi predogleda majhno opombo/značko, da
predogled vsebuje prepoznano besedilo (OCR), ki ga je možno označiti in kopirati. Če searchable
PDF (še) ni na voljo (OCR v teku ali ni uspel), predogled prikaže original (fallback) — opomba
naj to nakaže ("Besedilo še ni prepoznano" ali podobno).

### 4. Admin predogled (neobvezno, če smiselno)
V admin/documents lahko dodaš isti preview link za adminov pregled. Ni nujno, če javni
predogled zadošča.

## Reference
- `app/controllers/documents_controller.rb` — obstoječi show/download/set_document
- `app/models/document.rb` — `latest_searchable_ocr_log`, `searchable_pdf_available?` (že dodani)
- `app/models/ocr_log.rb` — `has_one_attached :searchable_pdf`
- `app/policies/document_policy.rb` — varnostni scope

## Acceptance criteria
- [ ] Predogled konsistentno prikaže PDF inline (ne sproži prenosa po osveževanju)
- [ ] Predogled prikaže searchable sandwich PDF — besedilo je OZNAČLJIVO in kopirljivo
- [ ] Če searchable PDF ni na voljo (OCR v teku), fallback na original (inline)
- [ ] "Prenesi" prenese ORIGINALNI dokument (ne sandwich)
- [ ] Varnost: `internal_only` dokument ni dostopen bralcu prek preview poti (404/redirect)
- [ ] `preview_document_path` zahteva avtorizacijo (show?)
- [ ] Indikator, ali predogled vsebuje prepoznano besedilo
- [ ] `bin/tailwind-build` pognan

## Out of scope
- Meilisearch iskanje — naloga 23
- Highlight iskanega niza v predogledu
- Ponovni OCR gumb
