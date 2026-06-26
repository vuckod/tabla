# frozen_string_literal: true

module Admin
  class DocumentsController < BaseController
    before_action :set_document, only: %i[edit update destroy audit_history]
    before_action :authorize_document!

    def index
      @documents = policy_scope(Document).order(created_at: :desc).includes(:document_category, :ocr_logs)
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

    def audit_history
      authorize @document, :audit_history?
      @audits = @document.own_and_associated_audits.includes(:user).order(created_at: :desc)
      @audit_model_class = Document
      render layout: false
    end

    def bulk_destroy
      authorize Document, :destroy?

      documents = bulk_documents_scope
      count = documents.count
      documents.find_each(&:destroy!)

      redirect_to admin_documents_path, notice: t("views.admin.documents.bulk_destroyed", count: count)
    end

    def bulk_categorize
      authorize Document, :update?

      category_id = params[:document_category_id]
      if category_id.blank?
        redirect_to admin_documents_path, alert: t("views.admin.documents.bulk_category_required")
        return
      end

      documents = bulk_documents_scope
      count = 0
      documents.find_each do |document|
        document.update!(document_category_id: category_id)
        count += 1
      end

      redirect_to admin_documents_path, notice: t("views.admin.documents.bulk_categorized", count: count)
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
        :title, :description, :document_category_id, :unit,
        :published_at, :internal_only, :notify_staff, :file
      )
    end

    def bulk_documents_scope
      ids = Array(params[:document_ids]).filter_map { |id| Integer(id, exception: false) }.uniq
      policy_scope(Document).where(id: ids)
    end
  end
end
