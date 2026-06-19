# frozen_string_literal: true

# Lokacije organizacije: sedež (SIKLND), enota (NOE), krajevne knjižnice.
class Location < ApplicationRecord
  has_many :persons, dependent: :nullify
  has_many :phone_numbers, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :kind, presence: true

  enum :kind, {
    headquarters: 0,
    branch: 1,
    mobile_library: 2
  }

  scope :ordered, -> { order(:position, :name) }
end
