# frozen_string_literal: true

module Admin
  class PersonsController < BaseController
    before_action :set_person, only: %i[edit update destroy]
    before_action :authorize_person!

    def index
      @persons = Person.includes(:location, :phone_numbers).ordered
    end

    def new
      @person = Person.new(active: true)
      @person.phone_numbers.build
    end

    def create
      @person = Person.new(person_params)
      if @person.save
        redirect_to admin_persons_path, notice: t("views.admin.persons.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @person.phone_numbers.build if @person.phone_numbers.empty?
    end

    def update
      if @person.update(person_params)
        redirect_to admin_persons_path, notice: t("views.admin.persons.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @person.destroy
      redirect_to admin_persons_path, notice: t("views.admin.persons.destroyed")
    end

    private

    def set_person
      @person = Person.find(params[:id])
    end

    def authorize_person!
      authorize(@person || Person)
    end

    def person_params
      params.require(:person).permit(
        :first_name, :last_name, :email, :position_title, :location_id, :active,
        phone_numbers_attributes: %i[id number kind label position _destroy]
      )
    end
  end
end
