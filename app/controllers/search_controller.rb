# frozen_string_literal: true

# Globalni iskalnik po dokumentih (naslov + opis).
class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip

    if @query.present?
      scope = Document.visible_to(current_user).published.includes(:document_category)
      @documents = UnaccentSearchable.where_terms_match(
        scope, @query, %w[documents.title documents.description]
      ).order(published_at: :desc)
      @pagy, @documents = pagy(@documents)
    else
      @documents = Document.none
    end
  end
end
