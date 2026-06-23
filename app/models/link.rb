# frozen_string_literal: true

class Link < ApplicationRecord
  belongs_to :link_category

  validates :title, presence: true
  validates :url, presence: true

  scope :ordered, -> { order(:position, :title) }
  scope :internal_apps, -> { where(internal_app: true) }
  scope :external_links, -> { where(internal_app: false) }
end
