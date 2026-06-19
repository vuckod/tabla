# frozen_string_literal: true

class LinkCategory < ApplicationRecord
  has_many :links, dependent: :destroy

  validates :name, presence: true, uniqueness: true

  scope :ordered, -> { order(:position, :name) }
end
