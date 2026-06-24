# frozen_string_literal: true

module Admin
  # Osnovni admin kontroler — zahteva prijavo in vlogo urednika/administratorja.
  class BaseController < ApplicationController
    before_action :require_login
    before_action :require_editor

    private

    def require_editor
      return if current_user&.admin? || current_user&.urednik?

      flash[:alert] = t("views.admin.access_denied")
      redirect_to root_path
    end
  end
end
