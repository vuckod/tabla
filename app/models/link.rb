# frozen_string_literal: true

class Link < ApplicationRecord
  belongs_to :link_category

  validates :title, presence: true
  validates :url, presence: true

  scope :ordered, -> { order(:position, :title) }
end
