# Naloga 43: In-app notifikacije za nove dokumente

## Cilj
Vidno indicirati uporabniku, ko obstajajo **novi dokumenti** od njegovega zadnjega obiska.
Badge (numeri/pika) v navigaciji ob "Dokumenti" — kot v e-mail klientih.

## Pristop
Per-user timestamp `last_documents_seen_at` na `users` tabeli. Vsakič ko obišče `/documents`,
posodobi se. Badge prikaže razliko (število novih dokumentov od zadnjega obiska).

## Del A: User model + migracija

### A1. Migracija
```bash
docker compose run --rm rails_app bin/rails g migration AddLastDocumentsSeenAtToUsers \
  last_documents_seen_at:datetime
```
Migracija:
```ruby
class AddLastDocumentsSeenAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :last_documents_seen_at, :datetime
    # Default za obstoječe uporabnike: NOW() (da ne vidijo vseh 195 kot "novih")
    reversible do |dir|
      dir.up do
        execute "UPDATE users SET last_documents_seen_at = NOW() WHERE last_documents_seen_at IS NULL"
      end
    end
  end
end
```
Poženi: `bin/rails db:migrate`.

### A2. User model
```ruby
class User < ApplicationRecord
  # ...

  def new_documents_count
    return 0 unless last_documents_seen_at

    Document.published
            .visible_to(self)
            .for_document_unit(unit)
            .where("created_at > ?", last_documents_seen_at)
            .count
  end

  def mark_documents_as_seen!
    update_column(:last_documents_seen_at, Time.current)
  end
end
```
POZOR: `for_document_unit` scope že obstaja (iz naloge 31). Uporabi obstoječi. Preveri točen
podpis (lahko zahteva `User#unit` ali pa direktno scope na Document).

POZOR: `new_documents_count` lahko klikne bazo na vsakem prikazu navigacije — uporabi
**caching** (npr. `Rails.cache.fetch("user_#{id}_new_docs", expires_in: 1.minute)`) za
preprečevanje N+1 ob renderu vsakega query.

## Del B: Posodobitev timestamp ob obisku

### B1. DocumentsController#index
```ruby
class DocumentsController < ApplicationController
  before_action :mark_documents_seen, only: :index, if: -> { current_user }

  private

  def mark_documents_seen
    current_user.mark_documents_as_seen!
  end
end
```
POZOR vrstni red: shrani timestamp PO renderju (ali z `after_action`), sicer bo badge
takoj 0 ko uporabnik obišče. Razmisli:
- **Opcija 1**: `before_action` (badge 0 takoj ko obišče) — uporabniško razumljivo
- **Opcija 2**: `after_action` (badge ostaja, dokler ne osveži) — tehnično boljše
Predlog: **opcija 1** (`before_action`) — ko uporabnik pride na /documents, "videl je novosti",
badge gre na 0. Ko nazaj pride, je 0 dokler ne pridejo novi.

### B2. Razmislek o predogledu vs. seznam
Naj se timestamp posodobi tudi pri:
- `/documents` (seznam) — DA, glavni vir
- `/documents/:id` (predogled posameznega) — NE (preveč pogosto, samo če pride na index)
- Iskanje — NE
Samo ko uporabnik pride na index, posodobi.

## Del C: Badge v navigaciji

### C1. Helper
`app/helpers/navigation_helper.rb`:
```ruby
def nav_documents_badge_html
  return unless current_user

  count = current_user.new_documents_count
  return if count.zero?

  content_tag(:span,
    count > 99 ? "99+" : count,
    class: "ml-1 inline-flex items-center justify-center
            min-w-[1.25rem] h-5 px-1.5 rounded-full
            text-xs font-semibold text-white bg-red-600
            dark:bg-red-500",
    aria: { label: "#{count} novih dokumentov" })
end
```

### C2. Posodobi `_nav_links.html.erb`
Ob povezavi "Dokumenti" dodaj badge:
```erb
<%= link_to documents_path, class: "..." do %>
  Dokumenti
  <%= nav_documents_badge_html %>
<% end %>
```

### C3. Mobilni meni
Preveri tudi mobilni meni (`_mobile_menu.html.erb` ali kjerkoli je). Badge mora biti viden
tudi tam.

### C4. Caching (priporočeno)
```ruby
def new_documents_count
  return 0 unless last_documents_seen_at

  Rails.cache.fetch("user_new_docs_count_#{id}_#{last_documents_seen_at.to_i}", expires_in: 1.minute) do
    Document.published
            .visible_to(self)
            .where("created_at > ?", last_documents_seen_at)
            .count
  end
end
```
Cache key vključuje `last_documents_seen_at.to_i` — ko se posodobi (uporabnik obišče /documents),
cache key se spremeni, query se ponovi. Cache vmes je 1 minuta — preprečuje query ob vsakem
renderju navigacije.

## Del D: Razmisleki

### D1. Začetno stanje za obstoječe uporabnike
Migracija postavi `last_documents_seen_at = NOW()` za obstoječe (da ne vidijo vseh 195 kot
"novih"). To je smiselno — ob deployu je zdaj "videli vse".

### D2. Začetno stanje za nove uporabnike (UserSync)
Ko se ustvari nov uporabnik (iz Prisotnost sinhronizacije), nastavi `last_documents_seen_at`
na `Time.current` (ne na nil), da takoj ne vidi vseh kot novih:
```ruby
# UserSyncJob ali kjer se ustvarjajo
user = User.find_or_initialize_by(prisotnost_id: data["id"])
user.last_documents_seen_at ||= Time.current  # samo če nil
# ...
user.save!
```

### D3. Email obvestila (iz naloge 31) ostanejo
Email obvestila po enoti (admin pošlje obvestilo ob objavi dokumenta) so ločen mehanizem.
Ta naloga doda samo **vizualni indikator** v navigaciji — komplementarno, ne nadomestilo.

### D4. Badge naj NE prikaže lastnih dokumentov
Če uporabnik je admin/urednik in sam naloži dokument, badge ne bi smel za njega "blesteti".
Preverim, ali query izloča lastne dokumente:
```ruby
.where.not(created_by: self)  # če ima Document#created_by
```
Ali je to vredno truda — odvisno. Lahko zaenkrat NE filtriraj (preprostejše), in dodaj kasneje
če bo motilo.

## Reference
- `app/models/user.rb` (last_documents_seen_at, new_documents_count, mark_documents_as_seen!)
- `app/controllers/documents_controller.rb#index` (mark_documents_seen)
- `app/helpers/navigation_helper.rb` ali application_helper (badge)
- `app/views/layouts/_nav_links.html.erb` (badge v Dokumenti povezavi)
- `app/jobs/user_sync_job.rb` (init last_documents_seen_at za nove)

## Acceptance criteria
- [ ] User.last_documents_seen_at kolumna (datetime, default NOW za obstoječe)
- [ ] User#new_documents_count metoda (z cache)
- [ ] DocumentsController#index posodobi timestamp pred renderjem
- [ ] Badge v navigaciji (rdeč, kolikor je novih, max "99+")
- [ ] Badge skrit, če 0
- [ ] Badge na mobilnem meniju tudi
- [ ] aria-label za screen readerje
- [ ] Cache 1 min (ne queryja na vsakem renderju)
- [ ] UserSyncJob: novi uporabniki dobijo Time.current
- [ ] Test: prijavi se, dodaj dokument prek admin, odjavi se, prijavi → badge "1"; klikni
  Dokumenti → badge "0"

## Test
1. Trenutno stanje: badge 0 za vse (ali nima badge)
2. Kot admin naloži nov dokument
3. Drug uporabnik (urednik/bralec) se prijavi → vidi badge "1" ob "Dokumenti"
4. Klik na "Dokumenti" → badge izgine
5. Vrni se na home → badge še vedno 0
6. Naloži še 2 dokumenta → ostali uporabniki vidijo badge "2"

## Out of scope
- Notification center / dropdown z naslovi novih dokumentov
- Push notifikacije (browser API)
- Drugi tipi notifikacij (povezave, obvestila) — samo dokumenti
- Email digest (že obstaja iz naloge 31 — ločeno)
