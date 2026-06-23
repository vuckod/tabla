# frozen_string_literal: true

module Admin
  class DocumentsController < ApplicationController
    before_action :set_document, only: %i[edit update destroy]
    before_action :authorize_document!

    def index
      @documents = policy_scope(Document).order(created_at: :desc).includes(:document_category)
    end

    def new
      @document = Document.new(published_at: Time.current)
    end

    def create
      @document = Document.new(document_params)
      if @document.save
        redirect_to admin_documents_path, notice: t("views.admin.documents.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @document.update(document_params)
        redirect_to admin_documents_path, notice: t("views.admin.documents.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @document.destroy
      redirect_to admin_documents_path, notice: t("views.admin.documents.destroyed")
    end

    private

    def set_document
      @document = Document.find(params[:id])
    end

    def authorize_document!
      authorize(@document || Document)
    end

    def document_params
      params.require(:document).permit(
        :title, :description, :document_category_id,
        :published_at, :internal_only, :notify_staff, :file
      )
    end
  end
end
