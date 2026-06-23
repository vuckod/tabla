# frozen_string_literal: true

# Skupna logika za seznam dokumentov (domača stran in /documents).
module DocumentListing
  extend ActiveSupport::Concern

  private

  def load_documents_list(frame_id: "documents_list")
    @document_categories = DocumentCategory.ordered
    @selected_category_id = params[:category_id].presence
    @documents = Document.visible_to(current_user).published.recent.includes(:document_category)
    @documents = @documents.where(document_category_id: @selected_category_id) if @selected_category_id
    @pagy, @documents = pagy(@documents, link_extra: %(data-turbo-frame="#{frame_id}"))
  end
end
