# frozen_string_literal: true

module Admin
  class LinksController < ApplicationController
    before_action :set_link, only: %i[edit update destroy]
    before_action :authorize_link!

    def index
      @links = Link.includes(:link_category).ordered
    end

    def new
      @link = Link.new(new_tab: true)
    end

    def create
      @link = Link.new(link_params)
      if @link.save
        redirect_to admin_links_path, notice: t("views.admin.links.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @link.update(link_params)
        redirect_to admin_links_path, notice: t("views.admin.links.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @link.destroy
      redirect_to admin_links_path, notice: t("views.admin.links.destroyed")
    end

    private

    def set_link
      @link = Link.find(params[:id])
    end

    def authorize_link!
      authorize(@link || Link)
    end

    def link_params
      params.require(:link).permit(
        :title, :url, :description, :link_category_id, :position, :internal_app, :new_tab
      )
    end
  end
end
