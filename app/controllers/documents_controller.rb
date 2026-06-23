# frozen_string_literal: true

# Javni prikaz in prenos dokumentov.
class DocumentsController < ApplicationController
  include DocumentListing

  before_action :set_document, only: %i[show download]

  def index
    load_documents_list
  end

  def show
    authorize @document

    unless @document.file.attached?
      redirect_to documents_path, alert: t("views.documents.file_missing")
      return
    end

    @inline_url = rails_blob_path(@document.file, disposition: "inline")
    @download_url = rails_blob_path(@document.file, disposition: "attachment")
  end

  def download
    authorize @document, :download?

    redirect_to rails_blob_path(@document.file, disposition: "attachment"), allow_other_host: true
  end

  private

  def set_document
    @document = Document.visible_to(current_user).published.includes(:document_category).find(params[:id])
  end
end
