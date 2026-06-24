# Naloga 28: Thumbnaili dokumentov (predogledna sličica prve strani PDF)

## Cilj
Vsak dokument v seznamu naj prikaže majhno predogledno sličico (prva stran PDF), da uporabnik
vizualno prepozna dokument. Uporabi vgrajeni Active Storage PDF preview (poppler + libvips sta
že v kontejnerju), brez lastnega thumbnail joba.

## Predpogoji
- `image_processing` gem (v Gemfile ✓)
- Dockerfile.dev ima `libvips`, `imagemagick`, `poppler-utils` (✓ preverjeno)
- `Document has_one_attached :file` (PDF)

## Pristop: Active Storage preview (lazy)
Rails ima vgrajen `ActiveStorage::Previewer::PopplerPDFPreviewer`, ki iz prve strani PDF
naredi sličico prek `pdftoppm`, nato `image_processing` (libvips) spremeni velikost. Sličica
se generira ob prvem prikazu (lazy) in se predpomni — NE rabimo lastnega joba ali stolpca.

## Koraki

### 1. Helper za thumbnail z varnim fallbackom
Ustvari helper `document_thumbnail(document, size:)`:
```ruby
def document_thumbnail(document, width: 96, height: 128)
  if document.file.attached? && document.file.previewable?
    image_tag document.file.preview(resize_to_limit: [width, height]),
              class: "rounded border border-slate-200 dark:border-slate-700 object-cover bg-white",
              loading: "lazy", alt: document.title
  else
    # Fallback: PDF ikona (inline SVG ali ikona)
    content_tag(:div, ...,  # PDF placeholder ikona
      class: "flex items-center justify-center w-[#{width}px] h-[#{height}px] rounded border ...")
  end
end
```
POZOR: `document.file.preview(...)` vrne lazy referenco; v image_tag Rails generira URL, ki
ob prvem dostopu sproži generiranje. Prvi prikaz strani bo malce počasnejši (generira ~20
sličic na stran), nato predpomnjeno.

POZOR robustnost: če preview generiranje spodleti (poškodovan PDF), naj helper ne podre strani.
Razmisli o `rescue` okoli `previewable?`/`preview` ali preveri samo `previewable?` (ki za PDF
vrne true, če je previewer registriran). Pokvarjen PDF se lahko pokaže kot fallback ikona.

### 2. Prikaži thumbnail v `_document_row`
V `documents/_document_row.html.erb` dodaj sličico na levo stran vrstice (pred naslovom/vsebino):
- Majhna (npr. 64×88 ali 96×128), zaobljena, z obrobo
- Na mobilnem morda skrita ali manjša (presodi — lahko `hidden sm:block`)
- Klik na sličico naj (opcijsko) vodi na predogled (`document_path`)

Postavitev: trenutna vrstica je `flex flex-col sm:flex-row`. Dodaj sličico kot prvi element
flex vrstice, vsebina ostane v sredini, gumbi desno.

### 3. internal_only varnost
Sličice se generirajo samo za dokumente, ki so v seznamu — seznam že filtrira `visible_to`,
torej bralec ne dobi internal_only dokumentov (in s tem ne njihovih sličic). Preveri, da
preview URL ne zaobide tega (Active Storage representation URL je signed; isti varnostni model
kot predogled — sprejemljivo za interni intranet).

### 4. Produkcijski Dockerfile (opomba)
Za delovanje sličic v PRODUKCIJI mora tudi `Dockerfile` (Kamal, ne Dockerfile.dev) vsebovati
`libvips` (ali imagemagick) + `poppler-utils`. Preveri produkcijski Dockerfile in dodaj, če
manjka — sicer bodo sličice v produkciji padle na fallback ikono. (To je za nalogo deploy, a
zabeleži zdaj.)

### 5. (Neobvezno) Predgeneriranje za gladkost
Lazy generiranje pomeni počasnejši prvi prikaz strani. ČE je to moteče, lahko KASNEJE dodamo
`ThumbnailJob`, ki predgenerira `document.file.preview(...).processed` po uploadu (podobno OCR).
Za zdaj NE implementiraj — lazy zadošča. Samo zabeleži kot možnost.

## Reference
- Rails Active Storage: `previewable?`, `preview(resize_to_limit:)`, PopplerPDFPreviewer
- `app/views/documents/_document_row.html.erb`
- `app/helpers/documents_helper.rb` — dodaj helper sem

## Acceptance criteria
- [ ] Helper `document_thumbnail` z varnim fallbackom (PDF ikona)
- [ ] Sličica prve strani PDF v vsaki vrstici dokumenta
- [ ] Pokvarjen/ne-previewable PDF → fallback ikona, ne napaka
- [ ] Sličica zaobljena, z obrobo, primerna velikost; `loading: lazy`
- [ ] Mobilni: sličica skrita ali pomanjšana (postavitev se ne podre)
- [ ] internal_only sličice se ne prikažejo bralcu (seznam že filtrira)
- [ ] Opomba o libvips/poppler v produkcijskem Dockerfile zabeležena
- [ ] `bin/tailwind-build` pognan

## Out of scope
- ThumbnailJob predgeneriranje (lazy zadošča za zdaj)
- Thumbnaili za ne-PDF (samo PDF)
- Galerijski/grid prikaz dokumentov (ostaja seznam z majhno sličico)
