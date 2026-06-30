# Naloga 47: Mobilni UX za nalaganje dokumentov (admin na telefonu)

## Kontekst
Admin (Dejan) pogosto dela na iPhone. Za nalaganje skeniranih dokumentov uporablja app
**TurboScan**, ki ustvari PDF. Cilj: gladko naložiti ta PDF v Tablo z iPhone.

POMEMBNO — preveri PRED implementacijo: obstoječi admin obrazec (`/admin/documents/new`) ima
`file_field` z `accept: application/pdf`. Na iPhone to ŽE deluje: klikneš polje → iOS ponudi
"Browse" → izbereš TurboScan PDF iz Files. Torej osnovna funkcija obstaja. Ta naloga je
**UX izboljšava**, ne nova funkcija — naredi nalaganje s telefona prijetnejše.

## Del A: Diagnoza (najprej preveri obstoječe stanje)
Preden karkoli spreminjaš, oceni obstoječi `/admin/documents/new` na ozkem ekranu (375px):
- Ali je file_field dovolj velik/očiten za dotik?
- Ali so polja smiselno razvrščena (najprej nujna: naslov, kategorija, datoteka)?
- Ali so neobvezna polja (internal_only, notify_staff, published_at) pod nujnimi?
Zapiši ugotovitve; popravi le, kar je dejansko nerodno.

## Del B: Mobilni file upload UX

### B1. Večje, bolj dotik-prijazno file polje
Trenutni `admin_file_field` ima `file:` Tailwind stile. Za mobilni dodaj večjo dotik tarčo —
dropzone slog (velik klikljiv blok namesto majhnega gumba):
```erb
<%# V admin_file_field helperju ali dedicated mobilni varianti %>
<label class="flex flex-col items-center justify-center w-full min-h-[8rem]
              border-2 border-dashed border-slate-300 dark:border-slate-600 rounded-lg
              cursor-pointer bg-slate-50 dark:bg-slate-800
              hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors p-6">
  <svg class="h-10 w-10 text-slate-400 mb-2" ...><%# document-arrow-up ikona %></svg>
  <span class="text-sm font-medium text-slate-700 dark:text-slate-300 text-center">
    <%= t("views.admin.documents.upload_tap") %>
  </span>
  <span class="text-xs text-slate-500 dark:text-slate-400 mt-1">
    <%= t("views.admin.documents.file_hint") %>
  </span>
  <%= form.file_field :file, accept: "application/pdf", class: "sr-only",
      data: { controller: "file-input", action: "change->file-input#showName" } %>
</label>
<p class="mt-2 text-sm text-slate-600 dark:text-slate-300 hidden"
   data-file-input-target="name"></p>
```
Stimulus `file_input_controller.js` pokaže izbrano ime datoteke (potrditev uporabniku):
```js
import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static targets = ["name"]
  showName(event) {
    const file = event.target.files[0]
    if (file && this.hasNameTarget) {
      this.nameTarget.textContent = `Izbrano: ${file.name}`
      this.nameTarget.classList.remove("hidden")
    }
  }
}
```

### B2. iOS kamera/skener namig
iOS pri `accept="application/pdf"` ponudi Files browser (kjer je TurboScan PDF). Če dodaš
`accept="application/pdf,image/*"`, iOS ponudi tudi "Take Photo" + "Scan Documents" (vgrajen
iOS skener!). RAZMISLEK: če dovoliš `image/*`, lahko uporabnik posname fotografijo, a potem
ni PDF (Tabla zahteva PDF za OCR/predogled). Zato:
- **Ostani pri `accept="application/pdf"`** — uporabnik uporabi TurboScan (ki dela PDF), to je
  najbolj zanesljivo.
- iOS vgrajen "Scan Documents" tudi shrani kot PDF v Files, torej uporabnik lahko skenira z iOS
  in nato izbere ta PDF.

Ne dodajaj `image/*` — PDF-only ohrani OCR/predogled konsistentnost.

### B3. Poenostavljen mobilni obrazec (opcijsko)
Razmisli o "hitrem nalaganju" — na mobilnem skrij napredna polja za zavihek/details:
- Vedno vidno: Naslov, Kategorija, Datoteka
- V `<details>` "Napredne nastavitve": internal_only, notify_staff, published_at, unit
To zmanjša drsenje na telefonu. Opcijsko — če je čas.

## Del C: PWA Share Target (NAPREDNO, opcijsko — lahko ločen prehod)

### C1. Kaj je
PWA Share Target omogoča, da se Tabla pojavi v iOS/Android **share sheet** — torej v TurboScan
klikneš "Share" → izbereš "Tabla" → PDF se pošlje direktno v Tablin obrazec za nalaganje.
To je najgladkejši UX, a tehnično najzahtevnejši.

### C2. Zakaj OPCIJSKO / morda preskoči
- **iOS podpora za Web Share Target je OMEJENA** — Android jo podpira dobro, iOS Safari pa
  share target za PWA NE podpira zanesljivo (stanje 2026 — preveri trenutno). Ker Dejan je na
  iPhone, je verjetno ROI nizek.
- Zahteva: manifest `share_target` polje, namenski endpoint, ki sprejme multipart POST z datoteko.

### C3. Če vseeno implementiraš (Android korist)
Manifest (`manifest.json.erb`) dodaj:
```json
"share_target": {
  "action": "/admin/documents/share",
  "method": "POST",
  "enctype": "multipart/form-data",
  "params": {
    "title": "title",
    "files": [{ "name": "file", "accept": ["application/pdf"] }]
  }
}
```
In endpoint `Admin::DocumentsController#share` (GET prikaže predizpolnjen obrazec z datoteko,
ali POST sprejme in ustvari osnutek). To je netrivialno — predlog: NAREDI ŠELE, če B ni dovolj.

PRIPOROČILO: implementiraj samo del A in B. Del C pusti za prihodnost (ali preskoči), ker je
iOS podpora slaba in Dejan je na iPhone. Omeni v acceptance, da je C odložen.

## Reference
- `app/helpers/admin_form_helper.rb` (admin_file_field — razširi za mobilni dropzone)
- `app/views/admin/documents/_form.html.erb` (obrazec)
- `app/javascript/controllers/` (nov file_input_controller.js)
- `app/views/pwa/manifest.json.erb` (samo če del C)

## i18n (sl.yml, views.admin.documents)
```yaml
upload_tap: "Dotaknite se za izbiro PDF datoteke"
# file_hint že obstaja: "Samo PDF, največ 50 MB"
```

## Acceptance criteria
### Del A + B (glavni)
- [ ] Diagnoza obstoječega obrazca na 375px zapisana
- [ ] File polje večje, dropzone slog (dotik-prijazno)
- [ ] Stimulus pokaže ime izbrane datoteke po izbiri
- [ ] accept ostane "application/pdf" (NE image/*)
- [ ] Obstoječa funkcionalnost (desktop upload) nespremenjena
- [ ] (Opcijsko) napredna polja v <details> na mobilnem
- [ ] `bin/rails tailwindcss:build`

### Del C (odloženo/opcijsko)
- [ ] Označeno kot odloženo (iOS Share Target slaba podpora)

## Test
1. iPhone Safari: /admin/documents/new → file polje je velik dropzone
2. Dotik → iOS Files → izberi TurboScan PDF → ime se pokaže
3. Izpolni naslov + kategorijo → shrani → dokument naložen, OCR teče
4. Desktop: obrazec deluje kot prej (regresija check)

## Out of scope
- Del C (Share Target) razen če B ni dovolj
- Fotografiranje → samodejni PDF v Tabli (uporabi TurboScan)
- Bulk upload več datotek hkrati
