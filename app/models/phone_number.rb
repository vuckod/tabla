# frozen_string_literal: true

# Telefonska številka — vezana na osebo in/ali lokacijo (vsaj eno od obeh).
class PhoneNumber < ApplicationRecord
  belongs_to :person, optional: true
  belongs_to :location, optional: true

  validates :number, presence: true
  validates :kind, presence: true
  validate :person_or_location_present

  enum :kind, {
    external: 0,
    internal: 1,
    mobile: 2,
    fax: 3
  }

  scope :ordered, -> { order(:kind, :number) }

  private

  def person_or_location_present
    return if person_id.present? || location_id.present?

    errors.add(:base, "Številka mora pripadati osebi ali lokaciji")
  end
end
