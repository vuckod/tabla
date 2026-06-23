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
