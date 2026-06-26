# Tabla — Application Controller
class ApplicationController < ActionController::Base
  include Pagy::Backend
  include Pundit::Authorization

  # OPOMBA: `allow_browser versions: :modern` je odstranjen, ker je Tabla interni intranet,
  # ki ga zaposleni uporabljajo tudi s starejšimi brskalniki na službenih računalnikih.
  # Privzeti Rails 8 check je vračal HTTP 406 ("Your browser is not supported").

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

    @current_user ||= User.find_by(id: session[:user_id])
  end

  def require_login
    return if current_user

    # request.get? vrne false za HEAD zahteve, čeprav Rails HEAD usmerja enako kot GET
    # (Brakeman VerbConfusion) — zato preverimo oboje, da HEAD ne shrani napačne poti.
    session[:return_to] = request.fullpath if request.get? || request.head?
    flash[:alert] = t("views.sessions.login_required")
    redirect_to login_path
  end

  def track_ahoy_visit
    return if request.headers["Turbo-Frame"].present?
    return unless request.get? && request.format.html?

    ahoy.track_visit
  rescue ActiveRecord::RecordNotUnique
    # Dirkalni pogoj: dva hitra zaporedna requesta (npr. redirect takoj za njim) sta
    # poskusila ustvariti isti visit_token preden je bil cookie potrjen. Neškodljivo —
    # visit je bil že ustvarjen pri prvem requestu, samo ne logiramo kot napako.
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
