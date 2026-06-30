# frozen_string_literal: true

class Bookmark < ApplicationRecord
  belongs_to :user
  belongs_to :document

  validates :document_id, uniqueness: { scope: :user_id }
end
