# frozen_string_literal: true

# Javni prikaz kategoriziranih povezav.
class LinksController < ApplicationController
  def index
    @link_categories = LinkCategory.ordered.includes(:links)
  end
end
