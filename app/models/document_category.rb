# frozen_string_literal: true

class DocumentCategory < ApplicationRecord
  has_many :documents, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  scope :ordered, -> { order(:position, :name) }

  private

  def generate_slug
    self.slug = name.parameterize(separator: "_")
  end
end
