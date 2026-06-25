# Naloga 35: Admin strani — Ahoy analitika + audit zgodovina dokumentov

## Cilj
Dve admin strani (samo za adminе):
1. **Ahoy analitika** — pregled obiskov (sej) in dogodkov, s filtri (datum, uporabnik, IP, iskanje)
2. **Audit zgodovina dokumentov** — kdo je kdaj kaj spremenil; skupni pregled VSEH + per-dokument

Uporabi PREVERJENE vzorce iz Delovodnika. Vse temelje Tabla že ima:
- Ahoy beleži obiske/dogodke (initializer obstaja)
- Document ima `audited` + `has_associated_audits` (audit dnevnik že teče)
- UserStampable beleži creator/updater

## Dostop (POMEMBNO)
Obe strani SAMO za admine (`current_user&.admin?`), NE urednike — analitika in audit sta
občutljiva. Delovodnik uporablja `skrbnik?`, Tabla ima `admin?`.

## Del A: Ahoy analitika

### A1. Policy
`app/policies/analytics_policy.rb`:
```ruby
class AnalyticsPolicy < ApplicationPolicy
  def index?
    user&.admin?
  end
end
```

### A2. Controller (kopiraj iz Delovodnika, prilagodi)
`app/controllers/analytics_controller.rb` — kopiraj `delovodnik_rails/app/controllers/analytics_controller.rb`.
Prilagoditve:
- `authorize :analytics` (Pundit)
- Filtri: datum (start/end), user_id, ip, q (iskanje po IP/OS/brskalnik/user_agent/username/ime/priimek)
- `@os_stats` = group(:os).count
- Paginacija ločeno: `@pagy_visits` (obiski, page_param :page_obiski), `@pagy_events` (dogodki, :page_ogledi)
- POZOR: kontroler mora biti zaščiten z `require_login` (ker smo odstranili globalni require_login
  v nalogi 29). Ali naj deduje od Admin::BaseController, ALI dodaj `before_action :require_login`.
  PRIPOROČILO: naredi `Admin::AnalyticsController < Admin::BaseController` (že ima require_login +
  require_editor) IN dodaj dodaten admin check, ALI samostojen controller z require_login + authorize.
  Ker je samo za admine (ne urednike), je `authorize :analytics` (ki preveri admin?) ključen.

### A3. View (kopiraj iz Delovodnika)
`app/views/analytics/index.html.erb` — kopiraj iz Delovodnika. Vsebuje:
- Filter obrazec (auto-submit, turbo_frame "analytics_main")
- OS statistika (kartice)
- Tabela sej (uporabnik, IP, OS, brskalnik, začetek)
- Tabela dogodkov (čas, ime, uporabnik, lastnosti)
- Tailwind paginacija (uporablja `pagy_nav_tailwind` — Tabla ima `pagy_helper`, preveri združljivost)
POZOR: Delovodnik view uporablja `pagy_nav_tailwind(@pagy_visits, data: {...})`. Tablin
`pagy_helper` ima `pagy_nav_tailwind(pagy, turbo_frame:)` z drugačnim podpisom — PRILAGODI klic
ali helper (uskladi parametre). Preveri obstoječi `app/helpers/pagy_helper.rb`.

### A4. Route
```ruby
get "admin/analytics", to: "analytics#index", as: :admin_analytics
```
(ali znotraj namespace :admin, če narediš Admin::AnalyticsController)

### A5. auto-submit Stimulus controller
Delovodnik view uporablja `data-controller="auto-submit"` (debounced submit ob input). Tabla ima
`auto_submit_controller.js` (videl v assets) — preveri, da obstaja in ima `debouncedSubmit` +
`submitImmediate` akciji. Če ne, kopiraj iz Delovodnika.

## Del B: Audit zgodovina dokumentov

### B1. Helper (kopiraj iz Delovodnika)
`app/helpers/audit_history_helper.rb` — kopiraj `delovodnik_rails/app/helpers/audit_history_helper.rb`.
Vsebuje: `audit_revision_heading`, `audit_revision_change_lines` (create/update/destroy),
`audit_user_display`, `audit_action_label`, `audit_attr_label`, `audit_raw_value` (enum-aware),
`enum_label`. Vključi ga v ApplicationHelper ali pusti samostojnega (Rails auto-include).

### B2. Per-dokument: audit_history akcija
V `Admin::DocumentsController` dodaj member akcijo `audit_history`:
```ruby
def audit_history
  @document = Document.find(params[:id])
  authorize @document   # ali samostojen check
  @audits = @document.own_and_associated_audits.order(created_at: :desc)
  @audit_model_class = Document
  render "admin/documents/audit_history"
end
```
Route (member):
```ruby
namespace :admin do
  resources :documents do
    member { get :audit_history }
  end
end
```
View `app/views/admin/documents/audit_history.html.erb`:
```erb
<%= render "shared/audit_history_modal",
      audits: @audits, audit_model_class: @audit_model_class,
      heading: @document.title %>
```
Partial `app/views/shared/_audit_history_modal.html.erb` — kopiraj iz Delovodnika (turbo-frame
"modal", seznam revizij). POZOR: Delovodnik modal uporablja `data-controller="turbo"` z
`turbo#close` akcijo (turbo_controller.js). Preveri/kopiraj turbo_controller.js, ALI poenostavi
modal (link nazaj namesto JS close).

### B3. Gumb "Zgodovina" na strani dokumenta
V admin document pregledu/seznamu dodaj gumb/povezavo "Zgodovina" → `audit_history_admin_document_path(document)`,
z `data: { turbo_frame: "modal" }` (odpre modal). Dodaj `<turbo-frame id="modal"></turbo-frame>`
v admin layout (ali document view), da se modal vanj naloži.

### B4. Skupni pregled: vse spremembe dokumentov
Nova admin stran, ki prikaže VSE audite dokumentov (ne per-dokument):
`Admin::DocumentAuditsController#index` (ali `analytics`-slog):
```ruby
def index
  authorize :document_audit   # admin only
  audits = Audited::Audit.where(auditable_type: "Document")
                         .includes(:user, :auditable)
                         .order(created_at: :desc)
  # filtri: datum, uporabnik, akcija (create/update/destroy), dokument
  @pagy, @audits = pagy(audits, limit: 50)
end
```
View: tabela (čas, dokument, uporabnik, akcija, povzetek sprememb). Vsaka vrstica lahko razširi
spremembe (ali link na per-dokument modal). Filtri kot pri analitiki (datum, uporabnik, akcija).
Route: `get "admin/document_audits", to: "admin/document_audits#index", as: :admin_document_audits`.

POZOR Audited model: gem "audited" shranjuje v `Audited::Audit`. Skupni pregled gre prek
`Audited::Audit.where(auditable_type: "Document")`. Za per-dokument je
`document.own_and_associated_audits` ali `document.audits`.

### B5. DocumentAuditPolicy (ali skupni AdminPolicy)
```ruby
class DocumentAuditPolicy < ApplicationPolicy
  def index? = user&.admin?
end
```

## Del C: Admin navigacija
Dodaj povezavi v admin meni (kjer so ostale admin povezave):
- "Analitika" → `admin_analytics_path` (samo admin)
- "Zgodovina dokumentov" → `admin_document_audits_path` (samo admin)
Preveri obstoječ admin meni/layout (verjetно v admin views ali `_nav_links` z admin pogojem).
Pogojno prikaži SAMO za `current_user&.admin?` (ne urednike).

## Reference (kopiraj iz Delovodnika)
- `delovodnik_rails/app/controllers/analytics_controller.rb`
- `delovodnik_rails/app/views/analytics/index.html.erb`
- `delovodnik_rails/app/policies/analytics_policy.rb`
- `delovodnik_rails/app/helpers/audit_history_helper.rb`
- `delovodnik_rails/app/views/shared/_audit_history_modal.html.erb`
- `delovodnik_rails/app/views/documents/audit_history.html.erb`
- `delovodnik_rails/app/javascript/controllers/turbo_controller.js` (modal close)
- `delovodnik_rails/app/javascript/controllers/auto_submit_controller.js` (če Tabla nima)
- Tabla: `app/helpers/pagy_helper.rb` (uskladi pagy_nav_tailwind podpis), `Admin::BaseController`

## Acceptance criteria
- [ ] Ahoy analitika: obiski + dogodki + OS statistika + filtri (datum/user/ip/q)
- [ ] Analitika dostopna SAMO adminu (ne urednik, ne bralec, ne guest)
- [ ] Audit zgodovina per-dokument (gumb "Zgodovina" → modal z revizijami)
- [ ] Audit skupni pregled (vse spremembe dokumentov, filtri, paginacija)
- [ ] Audit dostopen SAMO adminu
- [ ] Admin meni: povezavi "Analitika" + "Zgodovina dokumentov" (samo admin)
- [ ] Pagy paginacija deluje (uskladi podpis s Tablinim pagy_helper)
- [ ] Enum vrednosti v auditu prikazane berljivo (unit: both/library/theatre → slovensko)
- [ ] `bin/tailwind-build` pognan (novi razredi)

## Test
1. Kot ADMIN: odpri /admin/analytics → obiski/dogodki vidni, filtri delujejo
2. Kot ADMIN: odpri dokument → gumb "Zgodovina" → modal z revizijami (kdo/kdaj/kaj)
3. Kot ADMIN: /admin/document_audits → vse spremembe dokumentov
4. Kot UREDNIK: poskusi /admin/analytics → zavrnjen (Pundit)
5. Spremeni dokument (npr. naslov) → preveri, da se nova revizija pojavi v zgodovini

## Out of scope
- Audit za druge modele (samo dokumenti zaenkrat)
- Izvoz analitike (CSV)
- Grafi/vizualizacije (samo tabele + OS statistika)
