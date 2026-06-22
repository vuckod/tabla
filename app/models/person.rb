# frozen_string_literal: true

# Osebe v telefonskem imeniku. Ni enako kot User — Person je za prikaz v imeniku,
# User je za prijavo. Ista oseba je lahko oboje (ali samo eno od tega).
class Person < ApplicationRecord
  self.table_name = "persons"

  include UserStampable

  belongs_to :location, optional: true
  has_many :phone_numbers, dependent: :destroy

  accepts_nested_attributes_for :phone_numbers, allow_destroy: true,
    reject_if: :all_blank

  audited except: %i[updated_at created_at]

  validates :last_name, presence: true

  scope :ordered, -> { order(:last_name, :first_name) }
  scope :by_location, ->(loc_id) { where(location_id: loc_id) if loc_id.present? }
  scope :active, -> { where(active: true) }

  def full_name
    [first_name, last_name].compact_blank.join(" ")
  end
end
