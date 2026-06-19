# frozen_string_literal: true

# Polimorfni zapis OCR obdelave — enako kot v Delovodniku.
class OcrLog < ApplicationRecord
  belongs_to :record, polymorphic: true
  has_one_attached :searchable_pdf

  STATUSES = %w[processing success error].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :record_type, :record_id, :started_at, presence: true
end
