# frozen_string_literal: true

class DocumentView < ApplicationRecord
  belongs_to :user
  belongs_to :document

  validates :viewed_at, presence: true

  scope :recent, -> { order(viewed_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
end
