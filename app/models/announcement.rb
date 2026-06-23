# frozen_string_literal: true

# Nujna obvestila za domačo stran — ciljajo enoto (knjižnica / gledališče / obe).
class Announcement < ApplicationRecord
  include UserStampable

  audited except: %i[updated_at created_at]

  DEFAULT_DURATION = 7.days

  enum :unit, { both: 0, library: 1, theatre: 2 }

  validates :title, presence: true
  validates :unit, presence: true
  validates :published_at, presence: true

  before_validation :set_defaults, on: :create

  scope :active, -> {
    where("published_at <= ?", Time.current)
      .where("pinned = ? OR expires_at IS NULL OR expires_at >= ?", true, Time.current)
  }
  scope :recent, -> { order(pinned: :desc, published_at: :desc) }

  scope :for_unit, ->(unit_key) {
    return all if unit_key.blank?

    where(unit: [units[:both], units[unit_key.to_s]].compact)
  }

  private

  def set_defaults
    self.published_at ||= Time.current
    self.expires_at ||= (published_at || Time.current) + DEFAULT_DURATION
  end
end
