# frozen_string_literal: true

# Javni prikaz in prenos dokumentov.
class DocumentsController < ApplicationController
  include DocumentListing

  before_action :set_document, only: %i[show preview download]

  def index
    load_documents_list
  end

  def show
    authorize @document

    unless @document.file.attached?
      redirect_to documents_path, alert: t("views.documents.file_missing")
      return
    end
  end

  def preview
    authorize @document, :show?

    ocr_log = @document.latest_searchable_ocr_log
    if ocr_log&.searchable_pdf&.attached?
      blob = ocr_log.searchable_pdf.blob
      send_data blob.download,
                filename: blob.filename.to_s,
                type: "application/pdf",
                disposition: "inline"
    elsif @document.file.attached?
      blob = @document.file.blob
      send_data blob.download,
                filename: blob.filename.to_s,
                type: "application/pdf",
                disposition: "inline"
    else
      redirect_to documents_path, alert: t("views.documents.file_missing")
    end
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
