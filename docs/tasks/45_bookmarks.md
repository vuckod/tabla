# Naloga 45: Zaznamki dokumentov (osebni hitri dostop)

## Cilj
Vsak prijavljen uporabnik si lahko "pripne" (zaznamuje) dokumente. Zaznamovani dokumenti se
prikažejo v posebnem bloku na vrhu domače strani za hiter dostop. Knjižničar, ki vsak dan
odpre isti pravilnik, ga ima takoj pri roki.

Arhitektura je podobna `DocumentView` (naloga 42) — uporabi isti vzorec.

## Del A: Model Bookmark

### A1. Migracija
```bash
docker compose run --rm rails_app bin/rails g model Bookmark \
  user:references document:references
```
Migracija prilagoditev:
```ruby
class CreateBookmarks < ActiveRecord::Migration[8.1]
  def change
    create_table :bookmarks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true
      t.timestamps
    end

    # Unique: en uporabnik lahko zaznamuje dokument samo enkrat
    add_index :bookmarks, [:user_id, :document_id], unique: true
  end
end
```
Poženi `bin/rails db:migrate`.

### A2. Model
`app/models/bookmark.rb`:
```ruby
class Bookmark < ApplicationRecord
  belongs_to :user
  belongs_to :document

  validates :document_id, uniqueness: { scope: :user_id }
end
```

### A3. Razširi User in Document
```ruby
# User
has_many :bookmarks, dependent: :destroy
has_many :bookmarked_documents, through: :bookmarks, source: :document

def bookmarked?(document)
  bookmarks.exists?(document_id: document.id)
end

# Document
has_many :bookmarks, dependent: :destroy
```

## Del B: Controller + routes (toggle zaznamka)

### B1. BookmarksController
`app/controllers/bookmarks_controller.rb`:
```ruby
class BookmarksController < ApplicationController
  before_action :require_login

  def create
    document = Document.visible_to(current_user).published.find(params[:document_id])
    current_user.bookmarks.find_or_create_by!(document: document)
    respond_to_toggle(document)
  end

  def destroy
    document = Document.find(params[:document_id])
    current_user.bookmarks.where(document: document).destroy_all
    respond_to_toggle(document)
  end

  private

  def respond_to_toggle(document)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "bookmark_button_#{document.id}",
          partial: "bookmarks/button",
          locals: { document: document }
        )
      end
      format.html { redirect_back fallback_location: documents_path }
    end
  end
end
```

### B2. Routes
```ruby
resources :bookmarks, only: [:create, :destroy], param: :document_id
# Ali bolj RESTful kot member akcija na documents:
# resources :documents do
#   member { post :bookmark; delete :unbookmark }
# end
```
Predlog: `param: :document_id` varianta zgoraj (preprosto). Pot: `bookmarks_path` (POST),
`bookmark_path(document_id: id)` (DELETE).

## Del C: Gumb zaznamka (zvezdica)

### C1. Partial `bookmarks/_button.html.erb`
Turbo-frame ovit gumb, ki se zamenja ob toggle (brez reload strani):
```erb
<%= turbo_frame_tag "bookmark_button_#{document.id}" do %>
  <% if current_user&.bookmarked?(document) %>
    <%= button_to bookmark_path(document_id: document.id), method: :delete,
        class: "inline-flex items-center gap-1.5 px-3 py-2 text-sm font-medium rounded-md
                text-amber-600 dark:text-amber-400 hover:bg-amber-50 dark:hover:bg-amber-900/20",
        form: { data: { turbo_stream: true } },
        aria: { label: "Odstrani zaznamek" } do %>
      <%# Polna zvezda (solid) %>
      <svg class="h-5 w-5" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
        <path fill-rule="evenodd" d="M10.788 3.21c.448-1.077 1.976-1.077 2.424 0l2.082 5.007 5.404.433c1.164.093 1.636 1.545.749 2.305l-4.117 3.527 1.257 5.273c.271 1.136-.964 2.033-1.96 1.425L12 18.354 7.373 21.18c-.996.608-2.231-.29-1.96-1.425l1.257-5.273-4.117-3.527c-.887-.76-.415-2.212.749-2.305l5.404-.433 2.082-5.006Z" clip-rule="evenodd" />
      </svg>
      <span class="hidden sm:inline">Zaznamovano</span>
    <% end %>
  <% else %>
    <%= button_to bookmarks_path(document_id: document.id), method: :post,
        class: "inline-flex items-center gap-1.5 px-3 py-2 text-sm font-medium rounded-md
                text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700",
        form: { data: { turbo_stream: true } },
        aria: { label: "Dodaj zaznamek" } do %>
      <%# Prazna zvezda (outline) %>
      <svg class="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke-width="1.5" stroke="currentColor" aria-hidden="true">
        <path stroke-linecap="round" stroke-linejoin="round" d="M11.48 3.499a.562.562 0 0 1 1.04 0l2.125 5.111a.563.563 0 0 0 .475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 0 0-.182.557l1.285 5.385a.562.562 0 0 1-.84.61l-4.725-2.885a.562.562 0 0 0-.586 0L6.982 20.54a.562.562 0 0 1-.84-.61l1.285-5.386a.562.562 0 0 0-.182-.557l-4.204-3.602a.562.562 0 0 1 .321-.988l5.518-.442a.563.563 0 0 0 .475-.345L11.48 3.5Z" />
      </svg>
      <span class="hidden sm:inline">Zaznamuj</span>
    <% end %>
  <% end %>
<% end %>
```

### C2. Dodaj gumb na document show stran
V `documents/show.html.erb`, v vrstico z gumbi (`flex flex-wrap gap-3 print:hidden`), dodaj:
```erb
<% if current_user %>
  <%= render "bookmarks/button", document: @document %>
<% end %>
```

### C3. (Opcijsko) Gumb tudi v seznamu dokumentov
V `documents/_document_row.html.erb` lahko dodaš manjšo zvezdico ob vsakem dokumentu, da
uporabnik zaznamuje brez odpiranja. Opcijsko — lahko v ločenem prehodu.

## Del D: Blok "Moji zaznamki" na domači strani

### D1. HomeController
```ruby
@bookmarked_documents = current_user&.bookmarked_documents
                                     &.published
                                     &.includes(:document_category)
                                     &.order(created_at: :desc) || []
```
POZOR: `bookmarked_documents` prek `through:` ne ohrani vrstnega reda zaznamovanja samodejno;
če želiš sortirati po času zaznamovanja, sortiraj prek `bookmarks.created_at`:
```ruby
@bookmarked_documents = Document.joins(:bookmarks)
                                .where(bookmarks: { user_id: current_user.id })
                                .published.includes(:document_category)
                                .order("bookmarks.created_at DESC")
  if current_user
```

### D2. Partial `home/_bookmarks.html.erb`
```erb
<%= render layout: "shared/block",
    locals: { title: t("views.home.bookmarks"), color: :amber } do %>
  <% if bookmarked_documents.any? %>
    <ul class="space-y-2">
      <% bookmarked_documents.each do |doc| %>
        <li>
          <%= link_to document_path(doc),
              class: "flex items-center gap-2 hover:bg-amber-100 dark:hover:bg-amber-900/30 rounded p-2" do %>
            <svg class="h-4 w-4 text-amber-500 shrink-0" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
              <path fill-rule="evenodd" d="M10.788 3.21c.448-1.077 1.976-1.077 2.424 0l2.082 5.007 5.404.433c1.164.093 1.636 1.545.749 2.305l-4.117 3.527 1.257 5.273c.271 1.136-.964 2.033-1.96 1.425L12 18.354 7.373 21.18c-.996.608-2.231-.29-1.96-1.425l1.257-5.273-4.117-3.527c-.887-.76-.415-2.212.749-2.305l5.404-.433 2.082-5.006Z" clip-rule="evenodd" />
            </svg>
            <span class="text-sm font-medium truncate"><%= doc.title %></span>
          <% end %>
        </li>
      <% end %>
    </ul>
  <% else %>
    <p class="text-sm opacity-80"><%= t("views.home.bookmarks_empty") %></p>
  <% end %>
<% end %>
```

### D3. Postavitev na domači strani
Dodaj blok zaznamkov. Predlog: v desni stolpec 3. vrstice, NAD "Nedavno ogledano" (oba sta
osebna, oba ozka). Struktura desnega stolpca postane:
1. Moji zaznamki (amber) — če obstajajo
2. Nedavno ogledano (purple) — če obstaja
3. Povezave (teal)

V `home/index.html.erb`, v `lg:col-span-2 space-y-4` stolpcu, pred recent_documents:
```erb
<% if current_user && @bookmarked_documents.any? %>
  <%= render "home/bookmarks", bookmarked_documents: @bookmarked_documents %>
<% end %>
```

POZOR: če je preveč blokov v ozkem stolpcu (zaznamki + nedavno + povezave), razmisli, ali
"Nedavno ogledano" premakniti drugam, ali zaznamke prikazati le, če obstajajo (kar zgornji
`if` že naredi). Vizualno preveri na koncu.

## Reference
- `app/models/document_view.rb` (vzorec model)
- `app/controllers/home_controller.rb` (dodaj @bookmarked_documents)
- `app/views/home/_recent_documents.html.erb` (vzorec bloka)
- `app/views/documents/show.html.erb` (dodaj gumb)
- `app/helpers/blocks_helper.rb` (preveri :amber barvo — verjetno obstaja)

## i18n (sl.yml, views.home)
```yaml
bookmarks: "Moji zaznamki"
bookmarks_empty: "Nimate zaznamovanih dokumentov. Kliknite zvezdico ob dokumentu."
```

## Acceptance criteria
- [ ] Bookmark model + migracija (unique user+document)
- [ ] BookmarksController create/destroy z Turbo Stream odzivom
- [ ] Gumb zvezdica na document show (toggle brez reload strani)
- [ ] Blok "Moji zaznamki" na domači (samo prijavljeni, samo če obstajajo)
- [ ] Zaznamki sortirani po času zaznamovanja (najnovejši zgoraj)
- [ ] Dostop: samo prijavljeni; zaznamuje lahko samo vidne dokumente
- [ ] Turbo: toggle ne reloada cele strani
- [ ] `bin/rails tailwindcss:build` (če novi razredi)

## Test
1. Prijavi se, odpri dokument → klikni zvezdico → postane "Zaznamovano" (rumena)
2. Domača stran → dokument v "Moji zaznamki"
3. Klik zvezdice znova → odstrani zaznamek → izgine z domače
4. Guest: ni gumba zvezdice, ni bloka zaznamkov

## Out of scope
- Zaznamki za povezave/osebe (samo dokumenti)
- Mape/organizacija zaznamkov
- Deljenje zaznamkov med uporabniki
