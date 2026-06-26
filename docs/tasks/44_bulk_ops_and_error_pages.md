# Naloga 44: Bulk operacije (admin) + brandirane napake (404/500/422)

## Cilj
Dva neodvisna dela:
- **A) Bulk operacije** — admin: množični izbris in množična kategorizacija dokumentov
- **B) Custom error pages** — 404/500/422 z Tabla brandom namesto privzetih Rails strani

## Del A: Bulk operacije (admin dokumenti)

### A1. Checkbox-i v admin documents index
V `app/views/admin/documents/index.html.erb`, dodaj checkbox stolpec v desktop tabelo IN
mobilne kartice:
```erb
<%# Glava tabele — dodaj na začetek %>
<th class="px-4 py-3 w-8">
  <input type="checkbox" id="select-all-documents"
         class="rounded border-slate-300 text-indigo-600 focus:ring-indigo-500"
         aria-label="<%= t('views.admin.documents.select_all') %>">
</th>

<%# Vsaka vrstica — dodaj na začetek %>
<td class="px-4 py-3">
  <%= check_box_tag "document_ids[]", document.id, false,
      class: "document-checkbox rounded border-slate-300 text-indigo-600 focus:ring-indigo-500",
      data: { document_id: document.id },
      form: "bulk-actions-form" %>
</td>
```
Checkboxi morajo biti povezani z **enim skupnim `<form>`** (`id="bulk-actions-form"`), ki obkroži
celotno tabelo (ali uporabi `form:` atribut na vsakem checkboxu, da se navežejo na oddaljen
obrazec brez gnezdenja znotraj tabele — Rails to podpira).

### A2. Bulk action bar (skrit, dokler ni izbire)
Nad tabelo dodaj bar, ki se prikaže prek Stimulus, ko je vsaj 1 checkbox izbran:
```erb
<div data-controller="bulk-select" class="mb-4">
  <div data-bulk-select-target="bar"
       class="hidden items-center gap-3 rounded-lg bg-indigo-50 dark:bg-indigo-950/40
              border border-indigo-200 dark:border-indigo-800 px-4 py-3">
    <span data-bulk-select-target="count" class="text-sm font-medium text-indigo-900 dark:text-indigo-200">
      0 <%= t("views.admin.documents.selected") %>
    </span>

    <%= form_with url: bulk_categorize_admin_documents_path, method: :patch,
        id: "bulk-categorize-form", data: { turbo_confirm: false } do |f| %>
      <%= f.select :document_category_id,
          DocumentCategory.ordered.pluck(:name, :id),
          { include_blank: t("views.admin.documents.bulk_choose_category") },
          class: "rounded border-slate-300 text-sm",
          onchange: "this.form.requestSubmit()" %>
    <% end %>

    <%= button_to t("views.admin.documents.bulk_delete"), bulk_destroy_admin_documents_path,
        method: :delete,
        form: { id: "bulk-destroy-form", data: { turbo_confirm: t("views.admin.documents.bulk_delete_confirm") } },
        class: "text-sm font-medium text-red-600 hover:text-red-700 dark:text-red-400" %>
  </div>

  <%# Tabela ide tukaj, znotraj istega data-controller scope, checkboxi z data-bulk-select-target="checkbox" %>
</div>
```

### A3. Stimulus controller `bulk_select_controller.js`
`app/javascript/controllers/bulk_select_controller.js`:
```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bar", "count", "checkbox", "selectAll"]

  connect() {
    this.updateBar()
  }

  toggle() {
    this.updateBar()
  }

  toggleAll(event) {
    this.checkboxTargets.forEach((cb) => { cb.checked = event.target.checked })
    this.updateBar()
  }

  updateBar() {
    const checked = this.checkboxTargets.filter((cb) => cb.checked)
    this.countTarget.textContent = `${checked.length} ${this.countTarget.dataset.label || "izbranih"}`
    this.barTarget.classList.toggle("hidden", checked.length === 0)
    this.barTarget.classList.toggle("flex", checked.length > 0)
  }

  selectedIds() {
    return this.checkboxTargets.filter((cb) => cb.checked).map((cb) => cb.value)
  }
}
```
POZOR: pred oddajo bulk obrazcev (kategorizacija/izbris) je treba izbrane `document_ids[]`
vrednosti vstaviti v `bulk-categorize-form` in `bulk-destroy-form` (ki sta ločena od glavne
tabele). Najpreprostejša rešitev: en skupni `<form id="bulk-actions-form">`, ki obkroži VSE
(tabelo + action bar), in select/delete gumbi so `type="submit"` znotraj istega obrazca z
dinamičnim `formaction`. ALI: JS pred-oddajo prepiše hidden inpute v ciljnem obrazcu s
trenutno izbranimi ID-ji (preberi `selectedIds()` in injektiraj kot hidden fields).
Predlagam preprostejšo varianto: en obrazec za celotno stran, `name="document_ids[]"` na vsakem
checkboxu, in dva submit gumba z različnim `formaction`/`formmethod` (HTML5 to podpira):
```erb
<%= form_with url: admin_documents_path, method: :patch, data: { controller: "bulk-select" } do |f| %>
  <%# ... tabela s checkboxi name="document_ids[]" ... %>

  <div data-bulk-select-target="bar" class="hidden ...">
    <select name="document_category_id" class="...">...</select>
    <button type="submit" formaction="<%= bulk_categorize_admin_documents_path %>" formmethod="patch">
      Kategoriziraj izbrane
    </button>
    <button type="submit" formaction="<%= bulk_destroy_admin_documents_path %>" formmethod="delete"
            data-turbo-confirm="Izbrišem izbrane dokumente?">
      Izbriši izbrane
    </button>
  </div>
<% end %>
```
Ta pristop je preprostejši — en obrazec, dva gumba z različnimi `formaction`. Uporabi to,
če deluje s Turbo (preveri — Turbo podpira `formaction` na submit gumbih).

### A4. Controller akcije
V `Admin::DocumentsController`:
```ruby
def bulk_destroy
  authorize Document
  ids = params[:document_ids] || []
  documents = Document.where(id: ids)
  count = documents.count
  documents.destroy_all
  redirect_to admin_documents_path, notice: "Izbrisanih #{count} dokumentov."
end

def bulk_categorize
  authorize Document
  ids = params[:document_ids] || []
  category_id = params[:document_category_id]
  return redirect_to admin_documents_path, alert: "Izberi kategorijo." if category_id.blank?

  count = Document.where(id: ids).update_all(document_category_id: category_id)
  redirect_to admin_documents_path, notice: "Posodobljenih #{count} dokumentov."
end
```
POZOR: `update_all` ne sproži `audited` callbackov (audit zgodovina NE bo zabeležila bulk
kategorizacije). Če je to pomembno, uporabi `documents.find_each(&:update!)` namesto `update_all`
(počasneje, a audit-friendly). Priporočilo: za majhno število dokumentov (intranet, ne na
tisoče) uporabi `find_each` + `update!`, da ostane audit trail celovit.

### A5. Routes
```ruby
namespace :admin do
  resources :documents do
    collection do
      delete :bulk_destroy
      patch :bulk_categorize
    end
    member { get :audit_history }
  end
end
```

### A6. Policy preverba
`authorize Document` v bulk akcijah preveri `DocumentPolicy#destroy?`/`update?` (razredna
avtorizacija — Pundit `authorize Document` brez instance preveri `class`-level metode, ali
uporabi `authorize Document.new` če policy pričakuje instanco). Preveri obstoječi
`DocumentPolicy`, uskladi.

## Del B: Custom error pages (404, 500, 422)

### B1. Arhitekturna odločitev — STATIČNE strani, NE Rails views
`public/404.html`, `public/422.html`, `public/500.html` so **statične HTML datoteke**, ki jih
Rack/nginx postreže NEPOSREDNO, brez prehoda skozi Rails aplikacijo. To je namensko — če je
podatkovna baza nedosegljiva ali je aplikacija sama padla, te strani VSEENO delujejo (ne
zahtevajo Rails runtime, ne ActiveRecord, ne views/layout).

NE spreminjaj `config.exceptions_app` v dinamični Rails handler — to bi pomenilo, da če
podatkovna baza pade, error page SAMA pade (ker bi rabila Rails boot + DB povezavo za render).
Ostani pri statičnih HTML datotekah, samo jih prebrendiraj z RAW HTML/CSS (brez ERB, brez
Rails helperjev).

### B2. Prepiši `public/404.html`
Inline CSS (ne sklicuj na Tailwind/asset pipeline — statična stran nima dostopa do njih).
Predlog vsebine (Tabla barve: indigo-600, slate):
```html
<!doctype html>
<html lang="sl">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="robots" content="noindex,nofollow">
  <title>Stran ni najdena — Tabla</title>
  <style>
    * { box-sizing: border-box; margin: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: #f8fafc; color: #0f172a;
      min-height: 100vh; display: flex; align-items: center; justify-content: center;
      padding: 2rem;
    }
    @media (prefers-color-scheme: dark) {
      body { background: #0f172a; color: #f1f5f9; }
      .card { background: #1e293b !important; border-color: #334155 !important; }
      .muted { color: #94a3b8 !important; }
    }
    .card {
      max-width: 28rem; text-align: center; background: white;
      border: 1px solid #e2e8f0; border-radius: 0.75rem; padding: 2.5rem 2rem;
      box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1);
    }
    .icon { width: 3rem; height: 3rem; color: #4f46e5; margin: 0 auto 1rem; }
    h1 { font-size: 1.5rem; font-weight: 700; margin-bottom: 0.5rem; }
    p.muted { color: #64748b; margin-bottom: 1.5rem; font-size: 0.9375rem; }
    a.btn {
      display: inline-block; background: #4f46e5; color: white; text-decoration: none;
      padding: 0.625rem 1.25rem; border-radius: 0.5rem; font-weight: 600; font-size: 0.9375rem;
    }
    a.btn:hover { background: #4338ca; }
  </style>
</head>
<body>
  <div class="card">
    <svg class="icon" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" d="M12 21v-8.25M15.75 21v-8.25M8.25 21v-8.25M3 9l9-6 9 6m-1.5 12V10.332A48.36 48.36 0 0 0 12 9.75c-2.551 0-5.056.2-7.5.582V21M3 21h18M12 6.75h.008v.008H12V6.75Z" />
    </svg>
    <h1>Stran ni najdena</h1>
    <p class="muted">Stran, ki jo iščete, ne obstaja ali je bila premaknjena.</p>
    <a class="btn" href="/">Nazaj na domov</a>
  </div>
</body>
</html>
```
(Ikona: BuildingLibraryIcon, kot v headerju — konsistentnost.)

### B3. Prepiši `public/422.html` (Unprocessable Content)
Enak vzorec, naslov "Zahteve ni mogoče obdelati", sporočilo "Prišlo je do napake pri obdelavi
vaše zahteve. Morda je vaša seja potekla — poskusite znova.", isti gumb "Nazaj na domov".

### B4. Prepiši `public/500.html` (Internal Server Error)
Enak vzorec, naslov "Prišlo je do napake", sporočilo "Žal je prišlo do nepričakovane napake na
strežniku. Poskusite kasneje ali se obrnite na skrbnika.", isti gumb "Nazaj na domov".
POZOR: 500 stran naj bo NAJBOLJ minimalna in samostojna (brez SVG ikone, če je možno) — to je
stran, ki se prikaže, ko je nekaj ŽE narobe; čim manj kompleksnosti, manj možnosti, da tudi
sama ne deluje. Lahko emoji namesto SVG (📚 ali ⚠️) za enostavnost.

### B5. `public/400.html` in `public/406-unsupported-browser.html`
Obstajata tudi ti dve (manj pomembni, redko se prikažeta). Lahko enak vzorec, manjša prioriteta
— naredi, če je čas, sicer pusti privzete.

### B6. Test
```bash
# Lokalno simuliraj napake (Rails dev način privzeto NE prikaže teh strani — samo produkcija
# ali RAILS_ENV=production lokalno).
docker compose run --rm -e RAILS_ENV=production rails_app bin/rails runner "puts 'test'"
```
Najlažji test je obiskati neobstoječ URL v produkciji po deployu: `https://i.kl-kl.si/ne-obstaja`
→ mora pokazati nov 404 design.

## Reference
- `app/views/persons/index.html.erb` (vzorec mobilnih kartic, za bulk checkbox UI usklajenost)
- `public/404.html`, `422.html`, `500.html`, `400.html` (obstoječi privzeti — prepiši)
- `app/controllers/admin/documents_controller.rb` (dodaj bulk akcije)
- `app/policies/document_policy.rb` (preveri razredna avtorizacija)
- `config/routes.rb` (dodaj bulk_destroy, bulk_categorize)

## Acceptance criteria

### Del A (bulk operacije)
- [ ] Checkbox stolpec v admin documents (desktop tabela)
- [ ] "Izberi vse" checkbox v glavi
- [ ] Bulk action bar prikazan samo ob izbiri ≥1
- [ ] Bulk izbris deluje (z potrditvenim dialogom)
- [ ] Bulk kategorizacija deluje (select + submit)
- [ ] Audit trail ohranjen (find_each + update!, NE update_all, če audit pomemben)
- [ ] Policy avtorizacija (samo admin/urednik z destroy?/update? pravicami)
- [ ] Mobilne kartice — bulk operacije lahko izpuščene na mobilnem (manj prostora), ali
  dodane kot checkbox v vsaki kartici (Cursor presodi glede na čas)

### Del B (error pages)
- [ ] 404.html — Tabla brand, ikona, "Nazaj na domov"
- [ ] 422.html — Tabla brand, ustrezno sporočilo
- [ ] 500.html — minimalen, samostojen, brez kompleksnih odvisnosti
- [ ] Vse strani delujejo BREZ Rails runtime (čist HTML/CSS, ne ERB)
- [ ] Dark mode (prefers-color-scheme) podprt
- [ ] Test v produkciji: neobstoječ URL pokaže nov 404 design

## Test
1. Admin dokumenti: izberi 3, kategoriziraj → vsi premaknjeni v novo kategorijo
2. Admin dokumenti: izberi 2, izbriši → potrditveni dialog → izbrisana
3. Po deployu: `https://i.kl-kl.si/ne-obstaja-stran` → nov 404 design
4. Dark mode brskalnika + obisk 404 strani → temna varianta

## Out of scope
- Bulk operacije za druge modele (persons, links) — samo dokumenti za zdaj
- Bulk export/import (CSV)
- Razveljavitev bulk operacij (undo)
