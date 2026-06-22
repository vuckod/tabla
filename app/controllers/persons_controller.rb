# frozen_string_literal: true

# Javni prikaz telefonskega imenika.
class PersonsController < ApplicationController
  def index
    @locations = Location.ordered.includes(:phone_numbers)
    @persons = Person.active.ordered.includes(:phone_numbers, :location)
    @persons = @persons.by_location(params[:location_id]) if params[:location_id].present?

    if params[:q].present?
      @persons = UnaccentSearchable.where_single_term_or_match(
        @persons, params[:q], %w[persons.first_name persons.last_name]
      )
    end
  end

  def show
    @person = Person.active.includes(:phone_numbers, :location).find(params[:id])
  end
end
