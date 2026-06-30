# Naloga 46: QR koda dokumenta (samo admin/urednik)

## Cilj
Na strani dokumenta (in/ali admin pregledu) prikaži QR kodo, ki kaže na URL dokumenta.
Namen: admin/urednik gleda dokument na računalniku, skenira QR s telefonom → dokument se
odpre na telefonu (npr. za podpis, deljenje, branje na poti).

Vidno SAMO prijavljenim urednikom/administratorjem (ne navadnim uporabnikom, ne gostom).

## Pristop: server-side generiranje QR (gem rqrcode)

### Razlogi za server-side (ne JS):
- Deluje brez JS, tudi pri tisku
- En sam helper, čista koda
- QR kot inline SVG (oster na vseh velikostih, majhen)

### A1. Dodaj gem
V `Gemfile`:
```ruby
gem "rqrcode", "~> 2.2"
```
Zaženi:
```bash
docker compose run --rm rails_app bundle install
docker compose build rails_app   # POMEMBNO: Tabla nima bundle volumna, rebuild je obvezen
```
(Spomni se naloge o nokogiri — `docker-compose.yml` nima ločenega bundle volumna, zato
`bundle install` v efemernem kontejnerju ne zadošča; potreben je `docker compose build`.)

### A2. Helper za QR SVG
`app/helpers/qr_helper.rb`:
```ruby
# frozen_string_literal: true

require "rqrcode"

module QrHelper
  # Vrne inline SVG QR kode za podan URL. Privzeto 160px, prilagodljivo.
  def qr_code_svg(url, size: 160)
    qr = RQRCode::QRCode.new(url, level: :m)
    svg = qr.as_svg(
      module_size: 4,
      standalone: true,
      use_path: true,
      viewbox: true,
      svg_attributes: {
        class: "qr-code",
        width: size,
        height: size
      }
    )
    svg.html_safe
  end
end
```
POZOR: `as_svg` z `viewbox: true` naredi SVG, ki se skalira. Barve: privzeto črna na beli.
Za dark mode lahko zaviješ v bel `<div>` s paddingom (QR mora ostati črn na belem za
zanesljivo skeniranje — NE invertiraj v dark mode).

### A3. Prikaz na document show (samo urednik/admin)
V `documents/show.html.erb`, dodaj sekcijo (npr. pod gumbi ali ob strani):
```erb
<% if current_user&.urednik? || current_user&.admin? %>
  <div class="print:hidden mt-4">
    <details class="inline-block">
      <summary class="cursor-pointer text-sm font-medium text-slate-600 dark:text-slate-300
                      hover:text-indigo-600 dark:hover:text-indigo-400">
        <%= t("views.documents.show_qr") %>
      </summary>
      <div class="mt-3 inline-block rounded-lg border border-slate-200 dark:border-slate-700
                  bg-white p-3 shadow-sm">
        <%= qr_code_svg(document_url(@document), size: 160) %>
        <p class="mt-2 text-xs text-slate-500 text-center max-w-[160px]">
          <%= t("views.documents.qr_hint") %>
        </p>
      </div>
    </details>
  </div>
<% end %>
```
POZOR: uporabi `document_url` (polni URL z domeno https://i.kl-kl.si/documents/:id), NE
`document_path` (relativni) — QR mora vsebovati absolutni URL, da deluje s telefonom.

POZOR: preveri, ali `User` ima metodi `urednik?` in `admin?` (iz prejšnjih nalog obstajata).
Uporabi obstoječi mehanizem za preverjanje vloge.

### A4. (Opcijsko) QR v admin documents pregledu
Lahko dodaš QR tudi v admin edit/index, a document show zadošča za večino primerov.
Opcijsko, če je čas.

## Razmislek: kam QR pripelje
URL dokumenta (`/documents/:id`) zahteva prijavo (naloga 29). Torej skeniranje QR na telefonu
→ login stran → po prijavi → dokument. To je pravilno (dokumenti so za prijavljene). Admin,
ki skenira, se na telefonu prijavi enkrat (ali je že prijavljen v Safari), nato vidi dokument.

Če bi želel QR, ki ne zahteva prijave (npr. za res javni dokument), bi bil to drugačen
mehanizem (javni token URL) — NI del te naloge, omeni kot možnost za prihodnost.

## i18n (sl.yml, views.documents)
```yaml
show_qr: "Pokaži QR kodo"
qr_hint: "Skenirajte za odpiranje na telefonu"
```

## Reference
- `Gemfile` (dodaj rqrcode)
- `app/helpers/qr_helper.rb` (nov)
- `app/views/documents/show.html.erb` (prikaz, pogojen na vlogo)
- `app/models/user.rb` (preveri urednik?/admin? metodi)

## Acceptance criteria
- [ ] gem rqrcode dodan, `docker compose build` pognan
- [ ] QrHelper#qr_code_svg vrne inline SVG
- [ ] QR viden SAMO uredniku/adminu na document show
- [ ] QR vsebuje ABSOLUTNI URL (document_url, ne path)
- [ ] QR v belem okvirju (bere se v dark mode)
- [ ] Skrit pri tisku (print:hidden) — ali viden, če želiš tiskati z QR (presodi)
- [ ] details/summary toggle (QR ni vedno odprt, zavzema prostor le na klik)
- [ ] Navaden uporabnik / guest: NE vidi QR

## Test
1. Kot admin/urednik: odpri dokument → klikni "Pokaži QR kodo" → QR se prikaže
2. Skeniraj s telefonom → odpre se login → po prijavi dokument na telefonu
3. Kot navaden uporabnik: ni QR opcije
4. Dark mode: QR v belem okvirju, skenljiv

## Out of scope
- Javni QR brez prijave (token URL) — prihodnost
- QR za povezave/osebe
- Tisk QR na fizične nalepke (lahko ročno preko browser print)
