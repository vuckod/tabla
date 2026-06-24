# frozen_string_literal: true

module Admin
  class LinkCategoriesController < BaseController
    before_action :set_link_category, only: %i[edit update destroy]
    before_action :authorize_link_category!

    def index
      @link_categories = LinkCategory.ordered.includes(:links)
    end

    def new
      @link_category = LinkCategory.new
    end

    def create
      @link_category = LinkCategory.new(link_category_params)
      if @link_category.save
        redirect_to admin_link_categories_path, notice: t("views.admin.link_categories.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @link_category.update(link_category_params)
        redirect_to admin_link_categories_path, notice: t("views.admin.link_categories.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @link_category.destroy
      redirect_to admin_link_categories_path, notice: t("views.admin.link_categories.destroyed")
    end

    private

    def set_link_category
      @link_category = LinkCategory.find(params[:id])
    end

    def authorize_link_category!
      authorize(@link_category || LinkCategory)
    end

    def link_category_params
      params.require(:link_category).permit(:name, :position, :icon)
    end
  end
end
