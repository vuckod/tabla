# Podatkovni model — Intranet KL-KL

## Pregled modelov

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│  Location    │────<│    Person     │────<│ PhoneNumber  │
│              │     │              │     │              │
│ name         │     │ first_name   │     │ number       │
│ kind         │     │ last_name    │     │ kind         │
│ short_code   │     │ email        │     │ label        │
│ position     │     │ position     │     │ location_id  │
│ schedule_info│     │ location_id  │     │ person_id    │
└─────────────┘     └──────────────┘     └──────────────┘

┌──────────────┐     ┌──────────────┐
│ LinkCategory │────<│    Link      │
│              │     │              │
│ name         │     │ title        │
│ position     │     │ url          │
│ icon         │     │ description  │
└──────────────┘     │ position     │
                     │ internal_app │
                     └──────────────┘

┌───────────────────┐     ┌──────────────┐     ┌──────────────┐
│ DocumentCategory  │────<│  Document    │────<│   OcrLog     │
│                   │     │              │     │              │
│ name              │     │ title        │     │ record (poly)│
│ slug              │     │ description  │     │ filename     │
│ position          │     │ published_at │     │ status       │
│ color             │     │ ocr_text     │     │ duration     │
└───────────────────┘     │ internal_only│     └──────────────┘
                          │ notify_staff │
                          │ file (AS)    │
                          └──────────────┘

┌──────────────┐     ┌──────────────┐
│    User      │<>──>│    Role      │
│ (mirror)     │     │              │
│ username     │     │ name         │
│ ime/priimek  │     └──────────────┘
│ email        │
│ remote_id    │
└──────────────┘
```

## Model: Location

Lokacije organizacije (SIKLND, NOE, krajevne knjižnice).

```ruby
# app/models/location.rb
class Location < ApplicationRecord
  has_many :persons, dependent: :nullify
  has_many :phone_numbers, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :kind, presence: true
  validates :position, numericality: { only_integer: true }, allow_nil: true

  enum :kind, {
    headquarters: 0,   # SIKLND (Knjižnica Lendava - sedež)
    branch: 1,         # NOE (Gledališka in koncertna dvorana)
    mobile_library: 2  # Krajevne knjižnice (Gaberje, Hotiza, ...)
  }

  scope :ordered, -> { order(:position, :name) }
end
```

### Migracija

```ruby
create_table :locations do |t|
  t.string  :name, null: false
  t.integer :kind, null: false, default: 0  # enum: headquarters, branch, mobile_library
  t.string  :short_code                      # "SIKLND", "NOE", "KK-Gaberje"
  t.integer :position, default: 0
  t.text    :schedule_info                   # Prostobesedilni urnik, npr. "PON 12-16, TOR 12-16"
  t.string  :address
  t.string  :phone                           # Glavna tel. številka lokacije (centrala)
  t.timestamps
end

add_index :locations, :name, unique: true
add_index :locations, :kind
```

### Seed podatki

```yaml
- name: "Knjižnica Lendava (sedež)"
  kind: headquarters
  short_code: "SIKLND"
  phone: "575-13-53"

- name: "Gledališka in koncertna dvorana"
  kind: branch
  short_code: "NOE"
  phone: "577-60-24"

- name: "Krajevna knjižnica Gaberje"
  kind: mobile_library
  short_code: "KK-Gaberje"
  schedule_info: "PON 12:00–16:00"

- name: "Krajevna knjižnica Hotiza"
  kind: mobile_library
  short_code: "KK-Hotiza"
  schedule_info: "TOR 12:00–16:00"
  # ... Petišovci (SRE), Dolina (ČET), Genterovci (PET)
```

---

## Model: Person

Zaposleni in kontaktne osebe v imeniku. **Ni enako kot User** — User je za login,
Person je za telefonski imenik (oseba je lahko v imeniku, a nima uporabniškega računa, ali obratno).

```ruby
# app/models/person.rb
class Person < ApplicationRecord
  include UserStampable

  belongs_to :location, optional: true
  has_many :phone_numbers, dependent: :destroy

  accepts_nested_attributes_for :phone_numbers, allow_destroy: true,
    reject_if: :all_blank

  audited except: %i[updated_at created_at]

  validates :last_name, presence: true

  scope :ordered, -> { order(:last_name, :first_name) }
  scope :by_location, ->(loc_id) { where(location_id: loc_id) if loc_id.present? }

  def full_name
    [first_name, last_name].compact_blank.join(" ")
  end
end
```

### Migracija

```ruby
create_table :persons do |t|
  t.string     :first_name
  t.string     :last_name, null: false
  t.string     :email
  t.string     :position_title           # "direktorica", "knjižničarka", "računovodkinja"
  t.references :location, foreign_key: true
  t.integer    :created_by_id
  t.integer    :updated_by_id
  t.boolean    :active, null: false, default: true
  t.timestamps
end

add_index :persons, [:last_name, :first_name]
```

---

## Model: PhoneNumber

Telefonske številke, vezane na osebo in/ali lokacijo.
Ena oseba ima lahko več številk (zunanja, interna, GSM).

```ruby
# app/models/phone_number.rb
class PhoneNumber < ApplicationRecord
  belongs_to :person, optional: true
  belongs_to :location, optional: true

  validates :number, presence: true
  validates :kind, presence: true

  enum :kind, {
    external: 0,   # Zunanja tel. št. (574-25-80)
    internal: 1,   # Interna (580, 581, ...)
    mobile: 2,     # GSM (040-xxx-xxx)
    fax: 3
  }

  scope :ordered, -> { order(:kind, :number) }

  validate :person_or_location_present

  private

  def person_or_location_present
    return if person_id.present? || location_id.present?
    errors.add(:base, "Številka mora pripadati osebi ali lokaciji")
  end
end
```

### Migracija

```ruby
create_table :phone_numbers do |t|
  t.string     :number, null: false
  t.integer    :kind, null: false, default: 0   # enum: external, internal, mobile, fax
  t.string     :label                            # opcijski opis, npr. "pisarna zg.", "blagajna"
  t.references :person, foreign_key: true
  t.references :location, foreign_key: true
  t.integer    :position, default: 0
  t.timestamps
end

add_index :phone_numbers, :kind
```

---

## Model: LinkCategory

Skupine povezav (Aplikacije, COBISS, Pravni viri, Občine, Mediji…).

```ruby
# app/models/link_category.rb
class LinkCategory < ApplicationRecord
  has_many :links, dependent: :destroy

  validates :name, presence: true, uniqueness: true

  scope :ordered, -> { order(:position, :name) }
end
```

### Migracija

```ruby
create_table :link_categories do |t|
  t.string  :name, null: false
  t.integer :position, default: 0
  t.string  :icon                      # opcijsko: Heroicon ime za prikaz v UI
  t.timestamps
end

add_index :link_categories, :name, unique: true
```

### Seed podatki (iz obstoječe PHP table)

```yaml
- name: "Interne aplikacije"
  icon: "computer-desktop"
  links:
    - title: "Prisotnost"
      url: "https://p.kl-kl.si"
      internal_app: true
    - title: "Delovodnik"
      url: "https://d.kl-kl.si"
      internal_app: true
    # Statistika, Naslovi, Izobraževanje, Poštna knjiga, ...

- name: "COBISS"
  links:
    - title: "COBISS"
      url: "https://www.cobiss.si"
    - title: "COBISS KL"
    - title: "Moja knjižnica"

- name: "Geslovnik / UDK"
  links:
    - title: "Geslovnik"
    - title: "UDK tabele"
    - title: "Slovenska bibliografija"
    # ...

- name: "NUK / IZUM"
- name: "Slovenske knjižnice"
- name: "Pravni viri"
  # Uradni list RS, IUS-INFO, Tax-Fin-Lex, ...
- name: "Občine"
  # lendava.si, dobrovnik.si, ...
- name: "Drugo"
  # dlib.si, nagykar.hu, theeuropeanlibrary.org, Europeana
```

---

## Model: Link

Posamezna povezava znotraj kategorije.

```ruby
# app/models/link.rb
class Link < ApplicationRecord
  belongs_to :link_category

  validates :title, presence: true
  validates :url, presence: true

  scope :ordered, -> { order(:position, :title) }
end
```

### Migracija

```ruby
create_table :links do |t|
  t.string     :title, null: false
  t.string     :url, null: false
  t.text       :description              # kratka opomba, opcijsko
  t.references :link_category, null: false, foreign_key: true
  t.integer    :position, default: 0
  t.boolean    :internal_app, null: false, default: false   # ali je to interna app (Prisotnost, Delovodnik...)
  t.boolean    :new_tab, null: false, default: true         # odpri v novem zavihku
  t.timestamps
end
```

---

## Model: DocumentCategory

Kategorije dokumentov (Interni akti, Obvestila, Zapisniki SSZ, Zapisniki NOE…).

```ruby
# app/models/document_category.rb
class DocumentCategory < ApplicationRecord
  has_many :documents, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  scope :ordered, -> { order(:position, :name) }

  private

  def generate_slug
    self.slug = name.parameterize(separator: "_")
  end
end
```

### Migracija

```ruby
create_table :document_categories do |t|
  t.string  :name, null: false           # "Interni akti", "Obvestila za zaposlene", ...
  t.string  :slug, null: false           # "interni_akti", "obvestila", "zapisniki_ssz"
  t.integer :position, default: 0
  t.string  :color                       # opcijsko: barva za tab/badge v UI
  t.text    :description
  t.timestamps
end

add_index :document_categories, :name, unique: true
add_index :document_categories, :slug, unique: true
```

### Seed podatki

```yaml
- name: "Interni akti"
  slug: "interni_akti"
  position: 1

- name: "Obvestila za zaposlene"
  slug: "obvestila"
  position: 2

- name: "Zapisniki sej sveta zavoda"
  slug: "zapisniki_ssz"
  position: 3

- name: "Zapisniki sestankov delavcev - knjižnica"
  slug: "zapisniki_knjiznica"
  position: 4

- name: "Zapisniki sestankov delavcev - NOE"
  slug: "zapisniki_noe"
  position: 5

- name: "Pravilniki, navodila, ukrepi"
  slug: "pravilniki"
  position: 6
```

---

## Model: Document

Glavni model — interni dokumenti (PDF-ji), z OCR in iskanjem.

```ruby
# app/models/document.rb
class Document < ApplicationRecord
  include MeiliSearch::Rails
  include UserStampable

  belongs_to :document_category
  belongs_to :creator, class_name: "User", foreign_key: "created_by_id", optional: true
  belongs_to :updater, class_name: "User", foreign_key: "updated_by_id", optional: true

  has_many :ocr_logs, as: :record, dependent: :destroy
  has_one_attached :file

  audited except: %i[updated_at created_at ocr_text]
  has_associated_audits

  MAX_FILE_SIZE = 50.megabytes

  validates :title, presence: true
  validates :document_category, presence: true
  validate :file_size_within_limit
  validate :file_is_pdf

  before_save :mark_ocr_file_change
  after_commit :queue_ocr_extraction, on: %i[create update]
  after_commit :send_notification, on: :create, if: :notify_staff?

  scope :published, -> { where.not(published_at: nil).where("published_at <= ?", Time.current) }
  scope :recent, -> { published.order(published_at: :desc) }
  scope :visible_to, ->(user) {
    return all if user.admin? || user.has_role?(:intranet_urednik)
    where(internal_only: false)
  }

  meilisearch index_uid: "intranet_documents",
              auto_index: !Rails.env.test?,
              auto_remove: !Rails.env.test? do
    attribute :id, :title, :description, :ocr_text, :document_category_id,
              :internal_only, :published_at, :created_at
    attribute :category_name do
      document_category&.name
    end

    searchable_attributes [:title, :description, :ocr_text]
    filterable_attributes [:document_category_id, :internal_only]
    sortable_attributes [:published_at, :created_at]
  end

  def published?
    published_at.present? && published_at <= Time.current
  end

  private

  def mark_ocr_file_change
    @ocr_file_changed = attachment_changes.key?("file")
  end

  def queue_ocr_extraction
    return unless file.attached?
    return unless @ocr_file_changed

    OcrExtractionJob.perform_later(self)
  ensure
    @ocr_file_changed = false
  end

  def send_notification
    return unless notify_staff
    return unless published?

    DocumentNotificationJob.perform_later(self)
  end

  def file_size_within_limit
    return unless file.attached?
    return unless file.blob.byte_size > MAX_FILE_SIZE

    errors.add(:file, "je prevelika (največ #{MAX_FILE_SIZE / 1.megabyte} MB)")
  end

  def file_is_pdf
    return unless file.attached?
    return if file.content_type == "application/pdf"

    errors.add(:file, "mora biti v PDF obliki")
  end
end
```

### Migracija

```ruby
create_table :documents do |t|
  t.string     :title, null: false
  t.text       :description
  t.references :document_category, null: false, foreign_key: true
  t.datetime   :published_at                       # nil = osnutek (draft)
  t.boolean    :internal_only, null: false, default: false
  t.boolean    :notify_staff, null: false, default: false  # ali pošlji e-mail ob objavi
  t.text       :ocr_text                           # izvlečeno besedilo iz PDF-ja
  t.integer    :created_by_id
  t.integer    :updated_by_id
  t.timestamps
end

add_index :documents, :published_at
add_index :documents, :document_category_id
add_index :documents, :internal_only

# Trigram indeks za fallback iskanje brez Meilisearch
execute "CREATE INDEX index_documents_on_title_trgm ON documents USING gin (title gin_trgm_ops)"
execute "CREATE INDEX index_documents_on_ocr_text_trgm ON documents USING gin (ocr_text gin_trgm_ops)"
```

---

## Model: OcrLog

Popolnoma enak kot v Delovodniku — polimorfni zapis OCR obdelave.

```ruby
# app/models/ocr_log.rb
class OcrLog < ApplicationRecord
  belongs_to :record, polymorphic: true
  has_one_attached :searchable_pdf, dependent: :purge_later

  STATUSES = %w[processing success error].freeze
  validates :status, inclusion: { in: STATUSES }
  validates :record_type, :record_id, :started_at, presence: true
end
```

### Migracija

```ruby
create_table :ocr_logs do |t|
  t.references :record, polymorphic: true, null: false
  t.string     :filename
  t.string     :status, null: false, default: "processing"
  t.datetime   :started_at, null: false
  t.datetime   :completed_at
  t.float      :duration
  t.text       :error_message
  t.timestamps
end

add_index :ocr_logs, [:record_type, :record_id]
```

---

## Model: User (mirror iz Prisotnosti)

Lokalna kopija uporabnikov iz Prisotnosti. **Brez has_secure_password** — gesla se preverjajo
prek API-ja na Prisotnosti, lokalno se hrani le session.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_and_belongs_to_many :roles
  has_many :visits, class_name: "Ahoy::Visit", dependent: :nullify
  has_many :ahoy_events, class_name: "Ahoy::Event", dependent: :nullify

  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :remote_id, presence: true, uniqueness: true

  scope :active, -> { where(onemogocen: false) }
  scope :ordered, -> { order(:priimek, :ime) }

  def polno_ime
    "#{ime} #{priimek}"
  end

  def role_symbols
    (roles || []).map { |r| r.name.underscore.to_sym }
  end

  def has_role?(role_sym)
    role_symbols.include?(role_sym.to_sym)
  end

  def admin?
    has_role?(:intranet_admin)
  end

  def urednik?
    has_role?(:intranet_urednik)
  end

  def bralec?
    !admin? && !urednik?
  end

  # Sinhronizacija iz Prisotnost API-ja
  def self.sync_from_api_data(user_data)
    user = find_or_initialize_by(remote_id: user_data["id"])
    user.assign_attributes(
      username: user_data["username"],
      ime: user_data["ime"],
      priimek: user_data["priimek"],
      email: user_data["email"],
      onemogocen: user_data["onemogocen"] || false
    )
    user.save!
    sync_roles(user, user_data["roles"] || [])
    user
  end

  def self.sync_roles(user, role_names)
    intranet_roles = role_names.select { |r| r.start_with?("intranet_") }
    target_roles = Role.where("LOWER(name) IN (?)", intranet_roles.map(&:downcase))
    user.roles = target_roles
  end
end
```

### Migracija

```ruby
create_table :users do |t|
  t.integer  :remote_id, null: false             # ID iz Prisotnosti
  t.string   :username, null: false
  t.string   :ime
  t.string   :priimek
  t.string   :email
  t.boolean  :onemogocen, null: false, default: false
  t.datetime :last_synced_at
  t.datetime :last_request_at
  t.timestamps
end

add_index :users, :remote_id, unique: true
add_index :users, :username, unique: true

# HABTM join tabela
create_table :roles do |t|
  t.string :name, null: false
  t.timestamps
end

add_index :roles, :name, unique: true

create_join_table :roles, :users do |t|
  t.index [:user_id, :role_id], unique: true
  t.index [:role_id, :user_id]
end
```

---

## Model: Role

Identično kot v Delovodniku/Prisotnosti.

```ruby
# app/models/role.rb
class Role < ApplicationRecord
  has_and_belongs_to_many :users

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
```

### Seed vloge

```ruby
Role.find_or_create_by!(name: "intranet_admin")
Role.find_or_create_by!(name: "intranet_urednik")
# bralec je implicitna vloga (vsak prijavljen uporabnik brez zgornjih dveh)
```

---

## Ahoy (analitika)

Identičen setup kot v Delovodniku.

### Migracija

```ruby
# Ahoy visits & events — standardna migracija iz ahoy_matey gema
create_table :ahoy_visits do |t|
  t.string   :visit_token
  t.string   :visitor_token
  t.references :user
  t.string   :ip
  t.text     :user_agent
  t.text     :referrer
  t.string   :referring_domain
  t.text     :landing_page
  t.string   :browser
  t.string   :os
  t.string   :device_type
  t.string   :country
  t.string   :region
  t.string   :city
  t.float    :latitude
  t.float    :longitude
  t.datetime :started_at
end

add_index :ahoy_visits, :visit_token, unique: true
add_index :ahoy_visits, :user_id

create_table :ahoy_events do |t|
  t.references :visit
  t.references :user
  t.string     :name
  t.jsonb      :properties
  t.datetime   :time
end

add_index :ahoy_events, [:name, :time]
add_index :ahoy_events, :properties, using: :gin, opclass: :jsonb_path_ops
```

---

## Audited (revizijska sled)

Standardna `install_audited` migracija.

```ruby
# Generira se z: rails generate audited:install
# Ustvari tabelo audits z vsemi polji za revizijsko sledenje
```

---

## PostgreSQL razširitve

Omogočiti je treba v prvi migraciji:

```ruby
class EnableExtensions < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pg_trgm"     # trigram iskanje
    enable_extension "unaccent"    # iskanje brez šumnikov
  end
end
```

---

## Active Storage

Standardna Active Storage migracija (`rails active_storage:install`).
Uporablja se za:
- `Document#file` — priloženi PDF
- `OcrLog#searchable_pdf` — OCR-procesiran iskljiv PDF

Storage backend: lokalni disk (`storage/`) ali MinIO (faza 2).

---

## Diagram relacij (povzetek)

```
Location 1──* PhoneNumber
Location 1──* Person
Person   1──* PhoneNumber

LinkCategory 1──* Link

DocumentCategory 1──* Document
Document   1──* OcrLog
Document   1──1 ActiveStorage::Attachment (file)

User  *──* Role (HABTM)
User  1──* Ahoy::Visit
User  1──* Ahoy::Event
```

---

## Meilisearch indeksi

| Indeks               | Model    | Iskalna polja                    | Filtri                              |
| -------------------- | -------- | -------------------------------- | ----------------------------------- |
| `intranet_documents` | Document | title, description, ocr_text    | document_category_id, internal_only |

Isti Meilisearch strežnik kot Delovodnik (`delovodnik-app-meilisearch:7700`),
ločen `index_uid` prepreči konflikte.

---

## Vrstni red migracij

```
001_enable_extensions.rb
002_create_active_storage_tables.rb
003_create_locations.rb
004_create_persons.rb
005_create_phone_numbers.rb
006_create_link_categories.rb
007_create_links.rb
008_create_roles.rb
009_create_users.rb
010_create_roles_users_join.rb
011_create_document_categories.rb
012_create_documents.rb
013_create_ocr_logs.rb
014_create_ahoy_visits_and_events.rb
015_install_audited.rb
016_add_trgm_indexes.rb
```
