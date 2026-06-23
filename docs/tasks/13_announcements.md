# Naloga 13: Nujna obvestila (Announcement)

## Cilj
Nov model `Announcement` za nujna obvestila, ki se prikažejo v vrhnjem bloku domače strani.
Obvestilo cilja enoto (knjižnica / gledališče / obe), in se privzeto prikazuje 7 dni od objave,
nato samodejno izgine (brez ročnega brisanja). Admin in urednik lahko CRUD.

## Predpogoji
- Modeli `User`, `Location` obstajajo
- Pundit `ApplicationPolicy` z `editor?` logiko obstaja

## Koraki

### 1. Migracija
```ruby
class CreateAnnouncements < ActiveRecord::Migration[8.1]
  def change
    create_table :announcements do |t|
      t.string   :title, null: false
      t.text     :body
      t.integer  :unit, null: false, default: 0   # enum: both, library, theatre
      t.datetime :published_at, null: false
      t.datetime :expires_at                       # privzeto published_at + 7 dni
      t.boolean  :pinned, null: false, default: false  # ostane prikazano tudi po poteku
      t.integer  :created_by_id
      t.integer  :updated_by_id
      t.timestamps
    end

    add_index :announcements, :published_at
    add_index :announcements, :expires_at
    add_index :announcements, :unit
  end
end
```
Migracijo poimenuj z naslednjo zaporedno timestamp številko (po obstoječih v `db/migrate/`).
Poženi: `docker compose run --rm rails_app bin/rails db:migrate`

### 2. Model `app/models/announcement.rb`
```ruby
class Announcement < ApplicationRecord
  include UserStampable

  audited except: %i[updated_at created_at]

  DEFAULT_DURATION = 7.days

  enum :unit, { both: 0, library: 1, theatre: 2 }

  validates :title, presence: true
  validates :unit, presence: true
  validates :published_at, presence: true

  before_validation :set_defaults, on: :create

  # Trenutno aktivna obvestila (objavljena, ne potekla ali pripeta).
  scope :active, -> {
    where("published_at <= ?", Time.current)
      .where("pinned = ? OR expires_at IS NULL OR expires_at >= ?", true, Time.current)
  }
  scope :recent, -> { order(pinned: :desc, published_at: :desc) }

  # Obvestila za določeno enoto (vključi tudi "both").
  scope :for_unit, ->(unit_key) {
    return all if unit_key.blank?
    where(unit: [units[:both], units[unit_key.to_s]].compact)
  }

  private

  def set_defaults
    self.published_at ||= Time.current
    self.expires_at ||= (published_at || Time.current) + DEFAULT_DURATION
  end
end
```

### 3. Pundit politika `app/policies/announcement_policy.rb`
```ruby
class AnnouncementPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
```
(Deduje `create?`/`update?` → `editor?`, `destroy?` → `admin?` iz base.)

### 4. Admin CRUD — `Admin::AnnouncementsController`
Sledi natanko vzorcu `Admin::DocumentsController` (ki že obstaja):
- `before_action :authorize_announcement!` z `authorize(@announcement || Announcement)`
- Polja v `permit`: `:title, :body, :unit, :published_at, :expires_at, :pinned`
- `index` z `policy_scope(Announcement).recent`
- Forma: naslov, telo (textarea), izbira enote (radio/select: obe/knjižnica/gledališče),
  `published_at` (datetime, privzeto zdaj), `expires_at` (datetime, neobvezno — če prazno,
  model nastavi +7 dni), checkbox `pinned` ("ostane prikazano tudi po preteku")

### 5. Routes
V `namespace :admin` dodaj `resources :announcements`. NE dodajaj javnega resource-a
(obvestila se prikažejo samo na domači strani, ne na svoji strani).

### 6. Prikaz na domači strani (zaenkrat začasno — dokončni layout v nalogi 14)
V `home#index` kontrolerju naloži:
```ruby
@announcements = Announcement.active.recent
```
V `home/index.html.erb` prikaži blok z obvestili SAMO če `@announcements.any?`.
Vsako obvestilo: naslov, telo, značka enote, datum. (Natančno barvno/postavitveno oblikovanje
pride v nalogi 14 — tukaj samo funkcionalen prikaz.)

### 7. Seed (neobvezno)
Dodaj 1 vzorčno aktivno obvestilo v `db/seeds.rb` za testiranje prikaza.

## Reference
- `app/controllers/admin/documents_controller.rb` — vzorec admin CRUD
- `app/policies/document_policy.rb` — vzorec politike
- `app/models/concerns/user_stampable.rb` — že vključen pri ostalih modelih
- `config/initializers/audited.rb` — `yaml_column_permitted_classes` že vključuje TimeWithZone

## Acceptance criteria
- [ ] Migracija gre skozi brez napak
- [ ] Admin/urednik lahko ustvari, uredi, izbriše obvestilo (`/admin/announcements`)
- [ ] Obvestilo brez `expires_at` samodejno dobi published_at + 7 dni
- [ ] `Announcement.active` vrne samo objavljena, nepotekla (ali pripeta) obvestila
- [ ] `for_unit("library")` vrne obvestila za knjižnico IN "both"
- [ ] Domača stran prikaže blok obvestil samo če obstaja aktivno obvestilo
- [ ] Bralec ne more dostopati do `/admin/announcements`
- [ ] Audited beleži spremembe brez Psych napake

## Out of scope
- Dokončno barvno oblikovanje bloka (naloga 14)
- Filtriranje prikaza po enoti glede na uporabnika (zaenkrat prikaži vsa aktivna; per-unit
  filter pride lahko pozneje, ko bo jasno, ali uporabnik pripada enoti)
- E-mail obvestila ob objavi
