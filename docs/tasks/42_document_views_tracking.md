# Naloga 42: Sledenje branjenosti dokumentov + "Nedavno ogledano"

## Cilj
Beleži, kdaj kateri uporabnik odpre kateri dokument. Iz tega izpelji:
1. **"Nedavno ogledano"** — widget na domači strani, 5 zadnjih dokumentov za prijavljenega
2. **Admin: "Najbolj brani dokumenti"** — kateri dokumenti so najpopularnejši, kdo jih bere

Ahoy že beleži obiske (visits/events), ampak za naš primer je preprostejši **lasten model
`DocumentView`**, ki omogoča direktne queryje brez prebiranja Ahoy event properties.

## Del A: Model DocumentView

### A1. Migracija
```bash
docker compose run --rm rails_app bin/rails g model DocumentView \
  user:references document:references viewed_at:datetime:index
```
Migracija prilagoditev (pred zagonom):
```ruby
class CreateDocumentViews < ActiveRecord::Migration[8.1]
  def change
    create_table :document_views do |t|
      t.references :user, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true
      t.datetime :viewed_at, null: false, default: -> { "CURRENT_TIMESTAMP" }, index: true
      t.timestamps
    end

    # Composite index za "zadnji ogled uporabnika tega dokumenta"
    add_index :document_views, [:user_id, :document_id, :viewed_at]
    # Index za skupinske statistike
    add_index :document_views, [:document_id, :viewed_at]
  end
end
```
Poženi: `bin/rails db:migrate`.

### A2. Model
`app/models/document_view.rb`:
```ruby
class DocumentView < ApplicationRecord
  belongs_to :user
  belongs_to :document

  validates :viewed_at, presence: true

  scope :recent, -> { order(viewed_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
end
```
Razširi `User` in `Document`:
```ruby
# User
has_many :document_views, dependent: :destroy

def recent_documents(limit: 5)
  Document
    .joins(:document_views)
    .where(document_views: { user_id: id })
    .where(document_views: { viewed_at: ..Time.current })
    .group("documents.id")
    .select("documents.*, MAX(document_views.viewed_at) AS last_viewed_at")
    .order("last_viewed_at DESC")
    .limit(limit)
end

# Document
has_many :document_views, dependent: :destroy

def views_count = document_views.count
def unique_viewers_count = document_views.select(:user_id).distinct.count
def last_viewed_at = document_views.maximum(:viewed_at)
```
POZOR: `recent_documents` query je nekoliko zapleten (group by + max) — testiraj v rails
console, da deluje pravilno (vrne unique dokumente, sortirane po zadnjem ogledu).

### A3. Beleženje ob ogledu
V `DocumentsController#show` (in `#preview`, če je ločen):
```ruby
def show
  @document = Document.visible_to(current_user).find(params[:id])
  record_document_view(@document) if current_user
  # ... ostalo
end

private

def record_document_view(document)
  DocumentView.create!(user: current_user, document: document, viewed_at: Time.current)
rescue ActiveRecord::RecordInvalid
  # tiho, ne smemo padti ob napaki beleženja
end
```
POZOR: če uporabnik večkrat klika F5, bo več zapisov v eno minuto. Lahko *throttle* (en zapis
na uporabnika+dokument na 5 minut):
```ruby
def record_document_view(document)
  last_view = current_user.document_views
                          .where(document: document)
                          .order(viewed_at: :desc).first
  return if last_view && last_view.viewed_at > 5.minutes.ago

  DocumentView.create!(user: current_user, document: document, viewed_at: Time.current)
rescue ActiveRecord::RecordInvalid
end
```
To prepreči "spam" zapisov za isti uporabnik+dokument, ohrani pa unique ogled na seji.

## Del B: "Nedavno ogledano" widget na domači strani

### B1. HomeController#index
```ruby
@recent_documents = current_user&.recent_documents(limit: 5) || []
```

### B2. Partial `home/_recent_documents.html.erb`
```erb
<%= render layout: "shared/block",
    locals: { title: t("views.home.recent_views"), color: :purple } do %>
  <% if recent_documents.any? %>
    <ul class="space-y-2">
      <% recent_documents.each do |doc| %>
        <li>
          <%= link_to document_path(doc),
              class: "block hover:bg-purple-100 dark:hover:bg-purple-900/30 rounded p-2" do %>
            <div class="text-sm font-medium truncate"><%= doc.title %></div>
            <div class="text-xs text-slate-500 dark:text-slate-400">
              <%= time_ago_in_words(doc.last_viewed_at) %> nazaj
            </div>
          <% end %>
        </li>
      <% end %>
    </ul>
  <% else %>
    <p class="text-sm opacity-80">Še niste pregledali nobenega dokumenta.</p>
  <% end %>
<% end %>
```

### B3. Postavitev na home/index.html.erb
Razmisli, kam dodati. Trenutna postavitev:
- Vrstica 1: obvestila
- Vrstica 2: imenik (10) + aplikacije (2)
- Vrstica 3: dokumenti (10) + povezave (2)

Predlog: **dodati v vrstico 2** kot dodatni blok, ali **v vrstico 3** kot del povezav blok.
ALI: nova **vrstica 1b** "Nedavno ogledano" — širši (lg:col-span-12) ali zoženo (lg:col-span-6).

Predlog: ŠIROKA vrstica nad dokumenti (vrstica 2b), polna širina, vidno samo prijavljenim.
Tako je v pasici ko prijavljen uporabnik pride, vidi takoj nedavne.

```erb
<% if current_user && @recent_documents.any? %>
  <div>
    <%= render "home/recent_documents", recent_documents: @recent_documents %>
  </div>
<% end %>
```

### B4. Barva bloka
`:purple` (ali `:rose`, `:amber`) — drugačna od ostalih, da izstopa kot "tvoje".
Preveri, ali barva že obstaja v `blocks_helper.rb`, dodaj če ni.

## Del C: Admin "Najbolj brani dokumenti"

### C1. Controller
`app/controllers/admin/document_popularity_controller.rb`:
```ruby
class Admin::DocumentPopularityController < Admin::BaseController
  def index
    authorize :document_popularity, :index?

    @range = parse_range(params[:range])
    base = DocumentView.where(viewed_at: @range)

    @pagy, @documents = pagy(
      Document
        .joins(:document_views)
        .where(document_views: { viewed_at: @range })
        .group("documents.id")
        .select("documents.*,
                 COUNT(document_views.id) AS views_count,
                 COUNT(DISTINCT document_views.user_id) AS unique_viewers_count,
                 MAX(document_views.viewed_at) AS last_viewed_at")
        .order("views_count DESC"),
      limit: 30
    )

    @total_views = base.count
    @total_unique_viewers = base.select(:user_id).distinct.count
  end

  private

  def parse_range(input)
    case input
    when "week"  then 1.week.ago..Time.current
    when "month" then 1.month.ago..Time.current
    else              100.years.ago..Time.current
    end
  end
end
```

### C2. Policy
```ruby
# app/policies/document_popularity_policy.rb
class DocumentPopularityPolicy < ApplicationPolicy
  def index? = user&.admin?
end
```

### C3. View
`app/views/admin/document_popularity/index.html.erb`:
- Filter: zadnji teden / mesec / od začetka (radio ali select)
- Statistika: skupaj ogledov, unique uporabnikov
- Tabela: dokument | ogledov | unique uporabnikov | zadnji ogled
- Paginacija (pagy)

### C4. Route
```ruby
namespace :admin do
  get "document_popularity", to: "document_popularity#index", as: :document_popularity
end
```

### C5. Admin meni
Dodaj povezavo "Branjenost dokumentov" v admin meni (samo admin).

## Reference
- `app/controllers/documents_controller.rb` (#show — dodaj record_document_view)
- `app/models/user.rb` (has_many :document_views, recent_documents)
- `app/models/document.rb` (has_many :document_views, statistike)
- `app/views/home/index.html.erb` (vključitev partiala)
- `app/helpers/blocks_helper.rb` (preveri/dodaj :purple barvo)

## Acceptance criteria
- [ ] DocumentView model + migracija (z indeksi)
- [ ] DocumentsController#show beleži ogled (z throttle 5 min)
- [ ] Domača stran: "Nedavno ogledano" blok za prijavljene
- [ ] Blok skrit, če uporabnik ni prijavljen ali ni ničesar pogledal
- [ ] Admin: /admin/document_popularity z filtrom in statistiko
- [ ] Časovni filtri (teden/mesec/vse) delujejo
- [ ] Policy: dostop samo adminu
- [ ] `bin/rails tailwindcss:build` pognan (purple razredi, če novi)

## Test
1. Kot prijavljen uporabnik: odpri 3 dokumente → na domačo → vidiš jih v "Nedavno ogledano"
2. Klik F5 na istem dokumentu večkrat → samo en zapis (throttle 5 min)
3. Kot admin: /admin/document_popularity → tabela z najbolj branimi dokumenti
4. Filter "teden" → samo zadnji teden
5. Guest: domača stran nima bloka "Nedavno ogledano"

## Out of scope
- Beleženje za guest (anonimno) — samo prijavljeni
- Beleženje predogleda PDF-ja (`/preview` route) — če to želiš, dodaj kasneje
- Heatmap / grafi (zaenkrat samo tabela in števci)
- Sledenje *katero stran* PDF-ja uporabnik gleda
