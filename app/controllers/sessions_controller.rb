# frozen_string_literal: true

# Tabla — avtentikacija (login/logout).
# Credentials se NIKOLI ne preverjajo lokalno — vedno prek Prisotnost API-ja.
class SessionsController < ApplicationController
  def new
    return redirect_to root_path if current_user

    # Sprejmi return_to iz URL parametra (npr. po prijavi iz blur snippeta v search).
    # Varovalka proti open-redirect: samo notranje poti ("/<karkoli>", a NE "//evil.com"
    # ali "/\evil.com", ki ju browser interpretira kot zunanja preusmeritev).
    target = params[:return_to].to_s
    if target.match?(%r{\A/[^/\\]})
      session[:return_to] = target
    end
  end

  def create
    api_user = PrisotnostApiClient.authenticate(params[:username], params[:password])

    if api_user
      user = User.sync_from_api_data(api_user)
      session[:user_id] = user.id
      destination = session.delete(:return_to) || root_path
      redirect_to destination, notice: t("views.sessions.login_success")
    else
      flash.now[:alert] = "Napačno uporabniško ime ali geslo."
      render :new, status: :unprocessable_entity
    end
  rescue PrisotnostApiClient::ConnectionError => e
    flash.now[:alert] = e.message
    render :new, status: :service_unavailable
  end

  def destroy
    session.delete(:user_id)
    redirect_to login_path, notice: "Odjava uspešna."
  end
end
