# frozen_string_literal: true

# Javni prikaz in prenos dokumentov.
class DocumentsController < ApplicationController
  before_action :set_document, only: %i[show download]

  def index
    @document_categories = DocumentCategory.ordered
    @selected_category_id = params[:category_id].presence
    @documents = Document.visible_to(current_user).published.recent.includes(:document_category)
    @documents = @documents.where(document_category_id: @selected_category_id) if @selected_category_id
    @pagy, @documents = pagy(@documents, link_extra: 'data-turbo-frame="documents_list"')
  end

  def show
    authorize @document
  end

  def download
    authorize @document, :download?

    redirect_to rails_blob_path(@document.file, disposition: "attachment"), allow_other_host: true
  end

  private

  def set_document
    @document = Document.visible_to(current_user).published.find(params[:id])
  end
end
