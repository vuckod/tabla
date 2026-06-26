# frozen_string_literal: true

# Javni prikaz in prenos dokumentov.
class DocumentsController < ApplicationController
  include DocumentListing

  before_action :require_login, only: %i[show preview download]
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

    record_document_view(@document)
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

  def record_document_view(document)
    last_view = current_user.document_views
                            .where(document: document)
                            .order(viewed_at: :desc)
                            .first
    return if last_view && last_view.viewed_at > 5.minutes.ago

    DocumentView.create!(user: current_user, document: document, viewed_at: Time.current)
  rescue ActiveRecord::RecordInvalid
    # Ne prekinemo prikaza dokumenta ob napaki beleženja.
  end
end
