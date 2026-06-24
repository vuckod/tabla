# frozen_string_literal: true

module Admin
  class LocationsController < BaseController
    before_action :set_location, only: %i[edit update destroy]
    before_action :authorize_location!

    def index
      @locations = Location.ordered.includes(:phone_numbers)
    end

    def new
      @location = Location.new
      @location.phone_numbers.build
    end

    def create
      @location = Location.new(location_params)
      if @location.save
        redirect_to admin_locations_path, notice: t("views.admin.locations.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @location.phone_numbers.build if @location.phone_numbers.empty?
    end

    def update
      if @location.update(location_params)
        redirect_to admin_locations_path, notice: t("views.admin.locations.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @location.destroy
      redirect_to admin_locations_path, notice: t("views.admin.locations.destroyed")
    end

    private

    def set_location
      @location = Location.find(params[:id])
    end

    def authorize_location!
      authorize(@location || Location)
    end

    def location_params
      params.require(:location).permit(
        :name, :kind, :short_code, :position, :schedule_info, :address, :phone,
        phone_numbers_attributes: %i[id number kind label position _destroy]
      )
    end
  end
end
