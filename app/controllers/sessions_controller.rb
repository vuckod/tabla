# frozen_string_literal: true

# Tabla — avtentikacija (login/logout).
# Credentials se NIKOLI ne preverjajo lokalno — vedno prek Prisotnost API-ja.
class SessionsController < ApplicationController
  skip_before_action :require_login, only: %i[new create]

  def new
    redirect_to root_path if current_user
  end

  def create
    api_user = PrisotnostApiClient.authenticate(params[:username], params[:password])

    if api_user
      user = User.sync_from_api_data(api_user)
      session[:user_id] = user.id
      redirect_to root_path, notice: "Prijava uspešna."
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
