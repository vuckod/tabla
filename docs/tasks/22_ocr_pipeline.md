# Naloga 22: OCR pipeline (Tesseract slv+hun) + searchable PDF

## Cilj
Ob nalaganju PDF dokumenta v ozadju izvedi OCR (Tesseract, slovenščina + madžarščina),
shrani izvlečeno besedilo v `Document#ocr_text` (za iskanje), in generiraj "sandwich"
searchable PDF (besedilna plast čez sken), shranjen v `OcrLog#searchable_pdf`. Vzorec
neposredno iz Delovodnika, prilagojen za Tablo.

## Predpogoji
- `Document` model z `has_one_attached :file`, `has_many :ocr_logs`, `ocr_text` stolpec (obstaja)
- `OcrLog` model (polimorfni, `has_one_attached :searchable_pdf`) (obstaja)
- `Document` ima pripravljen `queue_ocr_extraction` callback z `defined?(OcrExtractionJob)` guard (obstaja)
- Docker slika ima `tesseract-ocr tesseract-ocr-slv tesseract-ocr-hun poppler-utils` (preveri Dockerfile.dev in Dockerfile)
- Solid Queue deluje

## POMEMBNE RAZLIKE OD DELOVODNIKA
- Tabla `Document` uporablja `has_one_attached :file` (NE `has_many_attached :attachments`).
  V `extractable_blobs` obravnavaj `record.file.blob` (eno datoteko), ne kolekcije.
- OCR jezik: `OCR_LANGUAGE = "slv+hun"` (NE samo "slv") — Tesseract z obema language packoma.
- Tabla nima `IncomingMail`/`OutgoingMail` — samo `Document`.

## Koraki

### 1. `OcrExtractorService` (kopiraj iz Delovodnika, ena sprememba)
Skopiraj `delovodnik_rails/app/services/ocr_extractor_service.rb` v
`tabla/app/services/ocr_extractor_service.rb`. Edina sprememba:
```ruby
OCR_LANGUAGE = "slv+hun".freeze
```
Vse ostalo (pdftoppm → tesseract → pdfunite, materializacija blob-a, cleanup) ostane enako.

### 2. `OcrExtractionJob` (kopiraj, prilagodi extractable_blobs)
Skopiraj `delovodnik_rails/app/jobs/ocr_extraction_job.rb`. Spremeni:
```ruby
def extractable_blobs(record)
  case record
  when Document
    return [] unless record.file.attached?
    [record.file.blob]
  else
    []
  end
end
```
Odstrani `IncomingMail`/`OutgoingMail` veje (ne obstajata v Tabli).
`queue_as :ocr` ostane — glej korak 4 za Solid Queue konfiguracijo te vrste.

### 3. Document model — aktiviraj OCR
Model že ima `queue_ocr_extraction` z `defined?(OcrExtractionJob)` guard. Ko `OcrExtractionJob`
zdaj obstaja, se bo callback samodejno sprožil ob create/update z novo datoteko. Preveri, da
`mark_ocr_file_change` pravilno zazna `has_one_attached :file` spremembo (`attachment_changes.key?("file")`).

### 4. Solid Queue — `ocr` vrsta
Job uporablja `queue_as :ocr`. Preveri `config/queue.yml` (Solid Queue), da delavec posluša
tudi vrsto `ocr` (ali doda `ocr` v seznam vrst). V developmentu Solid Queue lahko teče prek
`bin/jobs` ali znotraj Puma (`SOLID_QUEUE_IN_PUMA`). Preveri obstoječo konfiguracijo in po
potrebi dodaj `ocr` vrsto.

### 5. Prikaz OCR statusa v admin
V `admin/documents` (index ali show) prikaži OCR status zadnjega `OcrLog` za dokument
(processing / success / error), da admin vidi, ali je OCR uspel. Pri "error" prikaži
`error_message`.

### 6. Test ročno
Naloži skeniran PDF (slika besedila), počakaj na job, preveri:
- `Document.last.ocr_text` vsebuje izvlečeno besedilo
- `Document.last.ocr_logs.last.searchable_pdf` je priložen
- `OcrLog` status = "success"

## Reference
- `delovodnik_rails/app/services/ocr_extractor_service.rb` — KOPIRAJ (sprememba: slv+hun)
- `delovodnik_rails/app/jobs/ocr_extraction_job.rb` — KOPIRAJ (sprememba: extractable_blobs za has_one_attached)
- `tabla/app/models/document.rb` — `queue_ocr_extraction` že pripravljen
- `tabla/app/models/ocr_log.rb` — polimorfni log

## Acceptance criteria
- [ ] Nalaganje PDF sproži OcrExtractionJob v ozadju (ne blokira requesta)
- [ ] `Document#ocr_text` se napolni z izvlečenim besedilom (slv + hun)
- [ ] `OcrLog` zapis nastane s statusom success/error in trajanjem
- [ ] Searchable PDF (sandwich) priložen k OcrLog
- [ ] OCR napaka ne podre dokumenta (ujeta, logirana, status "error")
- [ ] Admin vidi OCR status dokumenta
- [ ] Tesseract slv+hun deluje (testiraj z madžarskim in slovenskim dokumentom)

## Out of scope
- Meilisearch indeksiranje ocr_text — naloga 23 (ampak ocr_text je pripravljen zanj)
- Prikaz searchable PDF namesto originala v predogledu (lahko kasneje — predogled iz naloge 21
  prikazuje original; sandwich PDF je za iskanje/kopiranje besedila)
- Ponovni OCR gumb v adminu (lahko kasneje)
