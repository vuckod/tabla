# Tabla — Application Controller
class ApplicationController < ActionController::Base
  include Pagy::Backend
  include Pundit::Authorization

  allow_browser versions: :modern

  before_action :require_login
  before_action :set_current_user
  after_action :track_ahoy_visit, :track_ahoy_page_view

  helper_method :current_user

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def set_current_user
    Current.user = current_user
  end

  def user_not_authorized
    flash[:alert] = "Za to dejanje nimate dovoljenja."
    redirect_back fallback_location: (current_user ? root_path : login_path)
  end

  def pundit_user
    current_user
  end

  def current_user
    return nil unless session[:user_id]
    return nil unless defined?(User) && User.table_exists?

    @current_user ||= User.find_by(id: session[:user_id])
  rescue ActiveRecord::StatementInvalid
    nil
  end

  def require_login
    return if current_user

    flash[:alert] = "Za dostop se morate prijaviti."
    redirect_to login_path
  end

  def track_ahoy_visit
    return if request.headers["Turbo-Frame"].present?
    return unless request.get? && request.format.html?

    ahoy.track_visit
  rescue StandardError => e
    Rails.logger.error "Ahoy track_visit: #{e.message}"
  end

  def track_ahoy_page_view
    return unless request.get? && request.format.html?
    return if request.headers["Turbo-Frame"].present?

    ahoy.track "Ogled strani", url: request.original_fullpath
  rescue StandardError => e
    Rails.logger.error "Ahoy track: #{e.message}"
  end
end
