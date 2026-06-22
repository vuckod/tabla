# Tabla — domača stran (dashboard)
class HomeController < ApplicationController
  skip_before_action :require_login

  def index
    @internal_links = Link.internal_apps.ordered
  end
end
