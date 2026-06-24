# frozen_string_literal: true

module Admin
  class DocumentCategoriesController < BaseController
    before_action :set_document_category, only: %i[edit update destroy]
    before_action :authorize_document_category!

    def index
      @document_categories = DocumentCategory.ordered.includes(:documents)
    end

    def new
      @document_category = DocumentCategory.new(color: "slate", position: next_position)
    end

    def create
      @document_category = DocumentCategory.new(document_category_params)
      @document_category.position = next_position if @document_category.position.blank?

      if @document_category.save
        respond_to do |format|
          format.html { redirect_to admin_document_categories_path, notice: t("views.admin.document_categories.created") }
          format.turbo_stream
        end
      else
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.turbo_stream { render :inline_form, status: :unprocessable_entity }
        end
      end
    end

    def edit
    end

    def update
      if @document_category.update(document_category_params)
        redirect_to admin_document_categories_path, notice: t("views.admin.document_categories.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @document_category.destroy
        redirect_to admin_document_categories_path, notice: t("views.admin.document_categories.destroyed")
      else
        message = @document_category.errors.full_messages.first ||
                  t("views.admin.document_categories.destroy_blocked")
        redirect_to admin_document_categories_path, alert: message
      end
    end

    def inline_cancel
      render layout: false
    end

    private

    def set_document_category
      @document_category = DocumentCategory.find(params[:id])
    end

    def authorize_document_category!
      authorize(@document_category || DocumentCategory)
    end

    def document_category_params
      params.require(:document_category).permit(:name, :color, :position)
    end

    def next_position
      (DocumentCategory.maximum(:position) || 0) + 1
    end
  end
end
