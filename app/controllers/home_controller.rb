# Tabla — domača stran (dashboard)
class HomeController < ApplicationController
  include DocumentListing

  def index
    @announcements = Announcement.active.recent
    @directory_rows = DirectoryTableBuilder.rows
    @directory_rows_by_unit = DirectoryTableBuilder.rows_by_unit_kind
    @internal_links = Link.internal_apps.ordered
    @external_link_categories = external_link_categories_for_home
    load_documents_list
  end

  private

  def external_link_categories_for_home
    category_ids = Link.external_links.select(:link_category_id).distinct
    LinkCategory.ordered.where(id: category_ids).includes(:links)
  end
end
