# Tabla — domača stran (dashboard)
class HomeController < ApplicationController
  skip_before_action :require_login

  def index
    @announcements = Announcement.active.recent
    @directory_rows = DirectoryTableBuilder.rows
  end
end
