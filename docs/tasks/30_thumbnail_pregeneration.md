# Naloga 30: Predgeneriranje thumbnailov (namenska priložena sličica)

## Cilj
Trenutni thumbnaili se generirajo lazy prek `document.file.preview(...)` ob prikazu seznama.
Problem: počasno (~10s/stran) IN nezanesljivo (včasih prazne sličice, ki so prej delovale —
variant pipeline pod hkratno obremenitvijo odpove). Rešitev: generiraj sličico VNAPREJ prek
joba (kot OCR), shrani kot namensko priloženo datoteko (`has_one_attached :thumbnail`), v
seznamu jo samo prikaži. Hitro in zanesljivo.

## Predpogoji
- `poppler-utils` (pdftoppm) v kontejnerju (✓ za OCR)
- Solid Queue deluje (✓)
- ~191 obstoječih dokumentov potrebuje backfill
- Naloga 28 (lazy thumbnaili) — to NADOMESTIMO

## Pristop
Namesto lazy Active Storage variant: namenska `has_one_attached :thumbnail`. Job uporabi
`pdftoppm` (isto preverjeno orodje kot OCR) za render prve strani v JPEG, priloži kot thumbnail.
Seznam prikaže `document.thumbnail` (priložena slika — hitro), fallback ikona če (še) ni.

## Koraki

### 1. Document model — has_one_attached :thumbnail
```ruby
has_one_attached :thumbnail
```
POZOR: priloga `thumbnail` NE sme sprožiti OCR (preveri `mark_ocr_file_change` — preverja
`attachment_changes.key?("file")`, torej "thumbnail" ga ne sproži ✓). Prav tako naj ne povzroči
Meilisearch reindex zanke (attach thumbnaila ne spreminja iskalnih atributov; če auto_index
sproži reindex ob attach, je neškodljivo — isti podatki).

Dodaj helper metodo:
```ruby
def thumbnail_ready? = thumbnail.attached?
```

### 2. ThumbnailGenerationService
`app/services/thumbnail_generation_service.rb` — generira JPEG prve strani:
- Materializiraj PDF blob v začasno datoteko (mirror `OcrExtractorService` pristopa za blob→temp)
- Zaženi: `pdftoppm -jpeg -f 1 -l 1 -scale-to 400 <input.pdf> <output_prefix>`
  (-f 1 -l 1 = samo prva stran; -scale-to 400 = največja dimenzija 400px; -jpeg = JPEG izhod)
- pdftoppm doda sufiks (npr. `output-1.jpg`) — najdi generirano datoteko
- Vrni pot do JPEG (ali io) + cleanup temp
- Robustno: rescue napake (poškodovan PDF), vrni nil ob neuspehu
- Samo za PDF (preveri content_type)

### 3. ThumbnailGenerationJob
`app/jobs/thumbnail_generation_job.rb`:
```ruby
class ThumbnailGenerationJob < ApplicationJob
  queue_as :thumbnails   # ali :default — queue.yml posluša "*"

  def perform(document)
    return unless document.file.attached?
    return if document.thumbnail.attached?   # idempotentno: ne regeneriraj

    result = ThumbnailGenerationService.call(document.file.blob)
    return unless result   # generiranje spodletelo — pusti fallback ikono

    document.thumbnail.attach(
      io: File.open(result[:path]),
      filename: "thumb_#{document.id}.jpg",
      content_type: "image/jpeg"
    )
  ensure
    ThumbnailGenerationService.cleanup(result) if result
  end
end
```
Idempotentno (`return if thumbnail.attached?`), robustno (neuspeh = brez thumbnaila, fallback
ikona v seznamu).

### 4. Sprožitev ob nalaganju (kot OCR)
V Document modelu, ob nalaganju nove datoteke sproži tudi thumbnail job (poleg OCR):
```ruby
after_commit :queue_thumbnail_generation, on: %i[create update]

def queue_thumbnail_generation
  return unless file.attached?
  return unless @ocr_file_changed   # ista zastavica kot OCR (datoteka se je spremenila)
  return unless defined?(ThumbnailGenerationJob)

  ThumbnailGenerationJob.perform_later(self)
end
```
POZOR: `@ocr_file_changed` se v `queue_ocr_extraction` resetira na false v `ensure`. Če oba
callbacka uporabljata isto zastavico, mora biti resetirana ŠELE po obeh. Reši: ali ločena
zastavica `@file_changed`, ali resetiraj v enem mestu po obeh klicih. PRIPOROČILO: preimenuj
`@ocr_file_changed` v `@file_changed` (splošnejše ime) in resetiraj v `mark_ocr_file_change`
naslednjič, NE v posameznem queue callbacku. Pazljivo, da ne pokvariš obstoječega OCR sprožanja.

Varnejša alternativa: en sam `after_commit :queue_file_processing`, ki sproži OBA joba (OCR +
thumbnail), in resetira zastavico enkrat na koncu.

### 5. Backfill obstoječih ~191 dokumentov
`lib/tasks/thumbnails.rake`:
```ruby
namespace :thumbnails do
  desc "Generiraj manjkajoče thumbnaile za obstoječe dokumente"
  task generate_missing: :environment do
    scope = Document.joins(:file_attachment)   # samo z datoteko
    total = scope.count
    queued = 0
    scope.find_each do |doc|
      next if doc.thumbnail.attached?
      ThumbnailGenerationJob.perform_later(doc)
      queued += 1
    end
    puts "V vrsto postavljeno #{queued} / #{total} thumbnail jobov."
  end

  desc "Regeneriraj VSE thumbnaile (najprej odstrani obstoječe)"
  task regenerate_all: :environment do
    Document.find_each do |doc|
      doc.thumbnail.purge if doc.thumbnail.attached?
      ThumbnailGenerationJob.perform_later(doc) if doc.file.attached?
    end
    puts "Regeneracija vseh thumbnailov sprožena."
  end
end
```
Opozori: backfill 191 jobov × nekaj s = nekaj minut prek Solid Queue (v ozadju).

### 6. Posodobi helper — prikaži priloženi thumbnail
V `documents_helper.rb` zamenjaj lazy `document.file.preview(...)` logiko:
```ruby
def document_thumbnail(document, width: THUMBNAIL_WIDTH, height: THUMBNAIL_HEIGHT)
  link_to document_path(document), class: "...", data: { turbo_frame: "_top" } do
    if document.thumbnail.attached?
      image_tag document.thumbnail, class: "#{thumbnail_size_classes} object-cover", loading: "lazy", alt: document.title
    else
      document_thumbnail_fallback(width: width, height: height)   # PDF ikona dokler thumb ni pripravljen
    end
  end
rescue StandardError => e
  Rails.logger.warn("[DocumentsHelper] Thumbnail error ##{document.id}: #{e.message}")
  # fallback ...
end
```
Odstrani lazy `.preview`, `previewable?`, `onerror` JS in povezano (ni več potrebno).
`image_tag document.thumbnail` servira priloženo sličico (hitro, zanesljivo, predpomnjeno).
Fallback ikona se prikaže samo, dokler thumbnail (še) ni generiran (med backfillom).

### 7. Produkcijski Dockerfile
Thumbnaili rabijo samo `poppler-utils` (pdftoppm) — že v produkcijskem Dockerfile (✓ za OCR).
libvips/imagemagick NISO več potrebni za thumbnaile (ne uporabljamo več Active Storage variant).
(Ostanejo lahko za druge namene, a niso kritični za thumbnaile.)

## Reference
- `app/services/ocr_extractor_service.rb` — vzorec blob→temp materializacije in pdftoppm klica
- `app/jobs/ocr_extraction_job.rb` — vzorec joba (queue, error handling)
- `app/helpers/documents_helper.rb` — `document_thumbnail` (zamenjaj)
- `app/models/document.rb` — callbacki, `@ocr_file_changed` zastavica

## Acceptance criteria
- [ ] `has_one_attached :thumbnail` na Document
- [ ] `ThumbnailGenerationService` (pdftoppm prva stran → JPEG, robustno)
- [ ] `ThumbnailGenerationJob` (idempotenten, neuspeh = fallback)
- [ ] Sprožitev ob nalaganju nove datoteke (NE pokvari obstoječega OCR sprožanja!)
- [ ] Backfill rake (`thumbnails:generate_missing` + `regenerate_all`)
- [ ] Helper prikaže priloženi thumbnail (hitro), fallback ikona dokler ni pripravljen
- [ ] Lazy `.preview` / `previewable?` / onerror JS odstranjeni
- [ ] Seznam dokumentov se naloži HITRO (brez sprotnega generiranja)
- [ ] Thumbnaili zanesljivi (ni več praznih)
- [ ] OCR sprožanje še vedno deluje (ni regresije)
- [ ] `bin/tailwind-build` pognan

## Test
1. Backfill: `docker compose run --rm rails_app bin/rails thumbnails:generate_missing`
2. Počakaj nekaj minut (Solid Queue obdela), osveži seznam → sličice naložene hitro
3. Naloži nov dokument → thumbnail se generira samodejno v ozadju
4. Preveri, da OCR še vedno teče za nov dokument (ni regresije)

## Out of scope
- Thumbnaili za ne-PDF
- Različne velikosti thumbnailov (ena velikost zadošča)
- Galerijski prikaz
