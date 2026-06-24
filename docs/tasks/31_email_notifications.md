# Naloga 31: E-mail obvestila ob objavi dokumenta (po enoti)

## Cilj
Ko admin/urednik objavi dokument z odkljukano opcijo "Obvesti zaposlene" (`notify_staff`),
pošlji HTML e-mail obvestilo zaposlenim **ciljne enote**. Uporabi PREVERJENO Outlook-kompatibilno
predlogo + SMTP konfiguracijo iz Delovodnika. Skupinski e-mail (vsi prejemniki v BCC). internal_only
dokumenti NE pošljejo obvestila.

## Odločitve (potrjene z uporabnikom)
- **Prejemniki:** vsi aktivni uporabniki ciljne enote (pravo filtriranje po enoti)
- **Način:** skupinsko (en e-mail, prejemniki v BCC) — manj jobov
- **internal_only:** NE pošlje obvestila (preveri pred pošiljanjem)

## Ključno odkritje — enota je IZVEDLJIVA
- Prisotnost API `GET /users` že vrača `enota` (in `delovnomesto`) za vsakega uporabnika.
  Vrednosti enote v Prisotnosti: **`knjiznica`, `gledalisce`, `uprava`** (radio v Prisotnosti).
- Tabla trenutno NE sinhronizira `enota` — to dodamo.
- `Announcement` ima `unit` enum (both/library/theatre). Document ga NIMA — dodamo.

## Mapiranje enot (POMEMBNO)
| Document.unit (Tabla) | Prejemniki (Prisotnost User.enota)        |
|-----------------------|-------------------------------------------|
| `both` (obe)          | vsi aktivni (knjiznica + gledalisce + uprava) |
| `library` (knjižnica) | `knjiznica` + `uprava`                     |
| `theatre` (gledališče)| `gledalisce` + `uprava`                    |

Uprava (administrativni) prejme obvestila OBEH enot (smiselno — vodstvo spremlja vse). To
vključi v `User` scope za prejemnike.

## Koraki

### 1. Migracija: enota na users + documents
```ruby
# users: shrani enoto iz Prisotnosti
add_column :users, :enota, :string
add_index :users, :enota
# documents: ciljna enota dokumenta (kot Announcement.unit)
add_column :documents, :unit, :integer, default: 0, null: false   # 0=both, 1=library, 2=theatre
add_index :documents, :unit
```
Po migraciji posodobi `db/schema.rb` (NE solid_*_schema.rb!).

### 2. User model + sinhronizacija enote
- V `User.sync_from_api_data` dodaj `enota: user_data["enota"]` v `assign_attributes`.
- Po deployu/naslednji sinhronizaciji (`UserSyncJob` + recurring) se enote napolnijo.
- Za TAKOJŠNJO napolnitev obstoječih: enkratni runner ali počakaj na recurring sync.
- Dodaj scope za prejemnike po enoti dokumenta:
```ruby
scope :active, -> { where(onemogocen: false) }   # že obstaja

# Prejemniki za ciljno enoto dokumenta (uprava prejme vse)
scope :for_document_unit, ->(unit) {
  base = active.where.not(email: [nil, ""])
  case unit.to_s
  when "library"  then base.where(enota: %w[knjiznica uprava])
  when "theatre"  then base.where(enota: %w[gledalisce uprava])
  else base   # both: vsi aktivni z emailom
  end
}
```

### 3. Document model + unit enum
```ruby
enum :unit, { both: 0, library: 1, theatre: 2 }, default: :both
```
Preveri, da se ne zaleti z obstoječim (Document nima enuma zdaj). Dodaj v admin permit
(`document_params`) `:unit`. Dodaj v admin formo izbiro enote (admin_select z enum opcijami).

POZOR `send_notification` (že obstaja v modelu):
```ruby
after_commit :send_notification, on: :create, if: :notify_staff?
def send_notification
  return unless notify_staff
  return unless published?
  return if internal_only?          # DODAJ: internal_only ne pošlje
  return unless defined?(DocumentNotificationJob)
  DocumentNotificationJob.perform_later(self)
end
```
Dodaj `return if internal_only?` (potrjena odločitev). Razmisli tudi o obvestilu ob UPDATE,
ko se notify_staff naknadno odkljuka — ZAENKRAT samo on: :create (preprosteje; uredi kasneje
če potrebno).

### 4. ApplicationMailer (kopiraj iz Delovodnika, prilagodi)
`app/mailers/application_mailer.rb`:
```ruby
class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("DEFAULT_FROM_EMAIL", "intranet@kl-kl.si")
  layout "mailer"
end
```
(BCC na fiksni naslov je v Delovodniku za arhiv — za Tablo ga lahko izpustiš ali nastaviš na
intranet@kl-kl.si; presodi. Prejemniki obvestila so itak v BCC, glej korak 5.)

### 5. DocumentMailer
`app/mailers/document_mailer.rb`:
```ruby
class DocumentMailer < ApplicationMailer
  def new_document(document, recipient_emails)
    @document = document
    @category = document.document_category
    @url = document_url(document)   # predogled (zahteva prijavo — to je OK)
    @unit_label = unit_label(document.unit)

    mail(
      to: ENV.fetch("DEFAULT_FROM_EMAIL", "intranet@kl-kl.si"),   # to = pošiljatelj (placeholder)
      bcc: recipient_emails,                                       # pravi prejemniki v BCC
      subject: "Nov dokument: #{document.title}"
    )
  end
  # ...
end
```
Skupinski e-mail: `to` na intranet naslov (placeholder), vsi pravi prejemniki v `bcc` (zasebnost
— prejemniki ne vidijo drug drugega). `document_url` rabi `default_url_options` (korak 8).

### 6. Outlook-kompatibilna HTML predloga (KOPIRAJ iz Delovodnika)
Kopiraj `delovodnik_rails/app/views/assignment_mailer/new_assignment_email.html.erb` v
`tabla/app/views/document_mailer/new_document.html.erb` in PRILAGODI vsebino:
- Glava: "Intranet KKC Lendava" namesto "Delovodnik"
- Naslov dokumenta, kategorija (značka/ime), enota, datum objave
- Informacijska škatla: naslov dokumenta, kategorija, enota, datum
- Gumb "Odpri dokument" → `@url` (predogled; uporabnik se mora prijaviti — pričakovano)
- OHRANI vse Outlook hacke: VML roundrect za gumb, mso pogojne komentarje, inline stile,
  mso-line-height-rule, tabelarično postavitev. TO JE BISTVO — ne poenostavljaj.
Kopiraj tudi `.text.erb` verzijo (plain text fallback).

Prav tako kopiraj `delovodnik_rails/app/views/layouts/mailer.html.erb` + `mailer.text.erb` v
Tablo (če še ne obstajata).

### 7. DocumentNotificationJob
`app/jobs/document_notification_job.rb`:
```ruby
class DocumentNotificationJob < ApplicationJob
  queue_as :mailers

  def perform(document)
    return unless document.notify_staff?
    return unless document.published?
    return if document.internal_only?

    recipients = User.for_document_unit(document.unit).pluck(:email).compact_blank.uniq
    return if recipients.empty?

    DocumentMailer.new_document(document, recipients).deliver_now
  rescue StandardError => e
    Rails.logger.error("[DocumentNotificationJob] Document##{document&.id}: #{e.class} - #{e.message}")
  end
end
```
Skupinsko (en deliver_now z vsemi v BCC). `rescue` — če SMTP pade, ne podre joba (Solid Queue
retry mehanizem lahko poskusi znova). `deliver_now` znotraj joba (job JE async kontekst).

### 8. SMTP + mailer host konfiguracija (kopiraj vzorec iz Delovodnika)
`config/environments/production.rb`:
```ruby
config.action_mailer.default_url_options = {
  host: ENV.fetch("MAILER_URL_HOST", "i.kl-kl.si"),
  protocol: ENV.fetch("MAILER_URL_PROTOCOL", "https")
}
config.action_mailer.delivery_method = :smtp
config.action_mailer.perform_deliveries = true
config.action_mailer.smtp_settings = {
  address: ENV.fetch("SMTP_HOST", "localhost"),
  port: ENV.fetch("SMTP_PORT", 587).to_i,
  user_name: ENV["SMTP_USERNAME"].presence,
  password: ENV["SMTP_PASSWORD"].presence,
  authentication: ENV["SMTP_USERNAME"].present? ? :plain : nil,
  enable_starttls_auto: true
}
```
`config/environments/development.rb`: POPRAVI obstoječi mailer port — trenutno
`default_url_options = { host: "localhost", port: 3000 }`, mora biti **port: 3002** (Tabla dev
port), sicer bodo linki v e-mailih kazali na napačen port. Za dev delivery uporabi `:letter_opener`
(če gem obstaja) ali `perform_deliveries = false` + log, da ne pošilja pravih e-mailov v razvoju.

### 9. Dev testiranje (brez pravega SMTP)
V razvoju NE pošiljaj pravih e-mailov. Možnosti:
- `config.action_mailer.delivery_method = :test` + preveri `ActionMailer::Base.deliveries`
- ali `letter_opener` gem (odpre e-mail v brskalniku) — če dodaš gem
- ali samo `perform_deliveries = false` in preveri v logu, da se mail sestavi brez napake
Priporočilo: za test sestavi mail v konzoli in preveri HTML (glej spodaj).

### 10. Queue za mailers
`DocumentNotificationJob` `queue_as :mailers`. `queue.yml` ima `queues: "*"` (posluša vse) —
brez sprememb.

## Reference (KOPIRAJ iz Delovodnika)
- `delovodnik_rails/app/mailers/application_mailer.rb`
- `delovodnik_rails/app/views/assignment_mailer/new_assignment_email.html.erb` ← Outlook predloga
- `delovodnik_rails/app/views/assignment_mailer/new_assignment_email.text.erb`
- `delovodnik_rails/app/views/layouts/mailer.html.erb` + `mailer.text.erb`
- `delovodnik_rails/config/environments/production.rb` ← SMTP + default_url_options vzorec
- `prisotnost_028/app/controllers/api/v1/users_controller.rb` ← `enota` v API (potrjeno)
- `tabla/app/models/document.rb` ← `send_notification` (že obstaja, dodaj internal_only guard + unit)
- `tabla/app/models/user.rb` ← `sync_from_api_data` (dodaj enota), scope for_document_unit

## Acceptance criteria
- [ ] Migracija: `users.enota`, `documents.unit` + schema.rb
- [ ] `User.sync_from_api_data` sinhronizira `enota` iz Prisotnosti
- [ ] `User.for_document_unit(unit)` scope (uprava prejme vse, pravo filtriranje)
- [ ] `Document` `unit` enum + admin forma izbira enote + permit
- [ ] `send_notification` doda `return if internal_only?`
- [ ] `DocumentMailer#new_document` (skupinsko, prejemniki v BCC)
- [ ] Outlook-kompatibilna HTML predloga (KOPIRANA, prilagojena vsebina, VML/mso ohranjeni)
- [ ] Text fallback predloga
- [ ] `DocumentNotificationJob` (robusten, internal_only guard, prazni prejemniki → skip)
- [ ] SMTP konfiguracija (production) + dev port popravljen na 3002
- [ ] Dev ne pošilja pravih e-mailov (test/letter_opener/disabled)
- [ ] internal_only dokument NE sproži obvestila (preverjeno)

## Test (dev, brez pravega SMTP)
```ruby
# konzola: sestavi mail in preveri HTML
d = Document.published.where(notify_staff: true).first || Document.first
mail = DocumentMailer.new_document(d, ["test@example.com"])
puts mail.subject
puts mail.html_part.body.to_s[0..500]   # preveri HTML
# preveri prejemnike po enoti
puts User.for_document_unit(d.unit).pluck(:email, :enota).inspect
```

## Out of scope
- Obvestila ob UPDATE (samo create zaenkrat)
- Posamični e-maili (ostajamo pri skupinskem BCC)
- Naročanje/odjava od obvestil (vsi v enoti prejmejo)
- Discord/druge kanale
