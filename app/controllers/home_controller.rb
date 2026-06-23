# Tabla — domača stran (dashboard)
class HomeController < ApplicationController
  skip_before_action :require_login

  def index
    @announcements = Announcement.active.recent
    @directory_rows = DirectoryTableBuilder.rows
    @internal_links = Link.internal_apps.ordered
    @external_link_categories = external_link_categories_for_home
  end

  private

  def external_link_categories_for_home
    category_ids = Link.external_links.select(:link_category_id).distinct
    LinkCategory.ordered.where(id: category_ids).includes(:links)
  end
end
