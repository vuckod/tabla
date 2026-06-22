# Naloga: Dokumenti — upload, prikaz, prenos (brez OCR/iskanja)

## Cilj
Implementiraj osnovno funkcionalnost dokumentov: admin nalaga PDF, izbere kategorijo in
(opcijsko) datum objave, zaposleni vidijo seznam in lahko prenesejo datoteko. OCR in
Meilisearch iskanje sta LOČENI naslednji nalogi (`10_ocr_pipeline.md`, `11_meilisearch_setup.md`)
— v tej nalogi pusti tista mesta v `Document` modelu kot so (defenzivno z `defined?`, glej kodo).

## Predpogoji
- `docs/tasks/06_layout_nav.md` končana
- `Document`, `DocumentCategory` modeli obstajajo z migracijami in seed kategorijami

## Koraki

### 1. `DocumentsController` (javni prikaz)
```ruby
class DocumentsController < ApplicationController
  def index
    @document_categories = DocumentCategory.ordered
    @documents = Document.visible_to(current_user).published.recent
    @documents = @documents.where(document_category_id: params[:category_id]) if params[:category_id].present?
  end

  def show
    @document = Document.visible_to(current_user).find(params[:id])
  end

  def download
    @document = Document.visible_to(current_user).find(params[:id])
    redirect_to @document.file.url
  end
end
```
Preveri Pundit `authorize @document` klice za `show`/`download` (uporabnik ne sme dostopati
do `internal_only` dokumentov, če ni admin/urednik — to že pokriva `visible_to` scope, ampak
dodaj tudi `DocumentPolicy#show?` za defense-in-depth, če bi kdo poskusil direkten URL).

### 2. View `app/views/documents/index.html.erb`
- Zavihki/tabs po `DocumentCategory` (glej PHP screenshot — "Info | Pravilniki | Zapisniki SSZ |
  Zapisniki NOE | ..." zavihki). Uporabi Turbo Frame za menjavo vsebine brez celotnega reloada.
- Vsak dokument: naslov, kategorija badge, datum objave, gumb "Prenesi", `internal_only` badge
  če relevantno
- Paginacija s `pagy` (gem je že v Gemfile)
- Prazno stanje: "Ni dokumentov v tej kategoriji" kadar seznam prazen

### 3. Admin — `Admin::DocumentsController`
```ruby
module Admin
  class DocumentsController < ApplicationController
    before_action :authorize_editor!

    def index
      @documents = policy_scope(Document).order(created_at: :desc)
    end

    def new
      @document = Document.new
    end

    def create
      @document = Document.new(document_params)
      if @document.save
        redirect_to admin_documents_path, notice: "Dokument objavljen."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @document = Document.find(params[:id])
    end

    def update
      @document = Document.find(params[:id])
      if @document.update(document_params)
        redirect_to admin_documents_path, notice: "Dokument posodobljen."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      Document.find(params[:id]).destroy
      redirect_to admin_documents_path, notice: "Dokument izbrisan."
    end

    private

    def document_params
      params.require(:document).permit(
        :title, :description, :document_category_id,
        :published_at, :internal_only, :notify_staff, :file
      )
    end

    def authorize_editor!
      authorize Document, policy_class: DocumentPolicy
    end
  end
end
```

### 4. Upload forma (`admin/documents/_form.html.erb`)
- `file_field :file, accept: "application/pdf"` — klientska validacija tipa datoteke
- Dropdown za `document_category`
- `datetime_field :published_at` (ali date_field + privzeto "zdaj" — admin lahko nastavi tudi
  prihodnji datum za zakasnjeno objavo, model že podpira `published?` logiko)
- Checkbox `internal_only`
- Checkbox `notify_staff` z opisom "Obvesti delavce po e-pošti ob objavi" — **OPOMBA: sama
  pošiljanje e-pošte je v fazi 2 (`DocumentNotificationJob` še ne obstaja), tukaj samo shrani
  zastavico, ne implementiraj pošiljanja**
- Prikaz napak validacije (naslov, kategorija, velikost datoteke, tip datoteke)

### 5. Politika `DocumentPolicy`
```ruby
class DocumentPolicy < ApplicationPolicy
  def show?
    return true if user&.admin? || user&.urednik?

    !record.internal_only
  end

  def download?
    show?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.visible_to(user)
    end
  end
end
```

### 6. Domača stran — "Zadnji dokumenti" sekcija
Na `home#index` prikaži zadnjih 5 objavljenih dokumentov (`Document.visible_to(current_user).recent.limit(5)`)
z linkom "Vsi dokumenti →" na `documents_path`.

## Reference
- `docs/01_data_model.md` — Document model (že implementiran, vključno z `visible_to` scope)
- `delovodnik_rails/app/controllers/documents_controller.rb` — vzorec upload kontrolerja
- `delovodnik_rails/app/views/documents/_form.html.erb` — vzorec forme z Active Storage
- Priloženi PHP screenshot — vizualna referenca zavihkov ("Dokumenti" sekcija)

## Acceptance criteria
- [ ] Admin lahko naloži PDF z naslovom, kategorijo, opisom
- [ ] Validacija: ne-PDF datoteka in datoteka > 50MB sta zavrnjeni z razumljivim sporočilom
- [ ] `/documents` prikaže samo objavljene dokumente (`published_at` v preteklosti)
- [ ] Zavihki po kategoriji delujejo (Turbo Frame, brez full page reload)
- [ ] `internal_only` dokumenti niso vidni bralcem, so vidni admin/uredniku
- [ ] Prenos datoteke deluje za avtoriziranega uporabnika
- [ ] Neavtoriziran dostop do `internal_only` dokumenta (direkten URL) vrne 403/redirect
- [ ] Admin lahko ureja in briše dokumente
- [ ] Domača stran prikazuje zadnjih 5 dokumentov

## Out of scope
- OCR ekstrakcija besedila — naslednja naloga (`10_ocr_pipeline.md`)
- Iskanje po vsebini (Meilisearch) — naslednja naloga (`11_meilisearch_setup.md`)
- Dejansko pošiljanje e-mail obvestil — `DocumentNotificationJob` še ne obstaja, samo shrani `notify_staff` zastavico
- Verzioniranje dokumentov (zamenjava PDF-ja z ohranjeno zgodovino) — `audited` že beleži spremembe metapodatkov, ampak menjava datoteke z zgodovino ni v tej nalogi
