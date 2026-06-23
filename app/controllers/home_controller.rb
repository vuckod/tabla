# Tabla — domača stran (dashboard)
class HomeController < ApplicationController
  skip_before_action :require_login

  def index
    @announcements = Announcement.active.recent
    @internal_links = Link.internal_apps.ordered
    @recent_documents = Document.visible_to(current_user).recent.limit(5).includes(:document_category)
  end
end
