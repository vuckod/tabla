# Tabla — avtentikacija (login/logout)
class SessionsController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]

  def new
  end

  def create
    # TODO: Faza 2 — preverjanje prek Prisotnost API-ja
    # Začasno: neposredna prijava z uporabniškim imenom (brez gesla)
    user = User.find_by(username: params[:username]) if defined?(User) && User.table_exists?

    if user
      session[:user_id] = user.id
      redirect_to root_path, notice: "Prijava uspešna."
    else
      flash.now[:alert] = "Napačno uporabniško ime ali geslo."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to login_path, notice: "Odjava uspešna."
  end
end
