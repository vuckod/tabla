# frozen_string_literal: true

# Javni prikaz lokacij — preusmeritev na imenik z filtrom.
class LocationsController < ApplicationController
  def index
    redirect_to persons_path
  end

  def show
    redirect_to persons_path(location_id: params[:id])
  end
end
