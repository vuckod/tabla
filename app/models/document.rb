# frozen_string_literal: true

# Glavni model — interni dokumenti (PDF), z OCR besedilom in (kasneje) iskanjem prek Meilisearch.
class Document < ApplicationRecord
  include UserStampable
  include MeiliSearch::Rails

  belongs_to :document_category
  belongs_to :creator, class_name: "User", foreign_key: "created_by_id", optional: true
  belongs_to :updater, class_name: "User", foreign_key: "updated_by_id", optional: true

  has_many :ocr_logs, as: :record, dependent: :destroy
  has_one_attached :file
  has_one_attached :thumbnail

  audited except: %i[updated_at created_at ocr_text source_url]
  has_associated_audits

  MAX_FILE_SIZE = 50.megabytes

  validates :title, presence: true
  validates :document_category, presence: true
  validate :file_must_be_attached, on: :create
  validate :file_size_within_limit
  validate :file_is_pdf

  before_save :mark_file_change
  before_save :purge_thumbnail_on_file_change
  after_commit :queue_file_processing, on: %i[create update]
  after_commit :send_notification, on: :create, if: :notify_staff?

  scope :published, -> { where.not(published_at: nil).where("published_at <= ?", Time.current) }
  scope :recent, -> { published.order(published_at: :desc) }
  scope :visible_to, ->(user) {
    return all if user&.admin? || user&.urednik?

    where(internal_only: false)
  }

  def published?
    published_at.present? && published_at <= Time.current
  end

  # Zadnji uspešni OCR log s priloženim searchable (sandwich) PDF-jem.
  def latest_searchable_ocr_log
    ocr_logs
      .where(status: "success")
      .order(completed_at: :desc, created_at: :desc)
      .detect { |log| log.searchable_pdf.attached? }
  end

  # Ali obstaja searchable PDF (z OZnačljivim OCR besedilom)?
  def searchable_pdf_available?
    latest_searchable_ocr_log.present?
  end

  def thumbnail_ready?
    thumbnail.attached?
  end

  meilisearch index_uid: "tabla_documents",
              auto_index: !Rails.env.test?,
              auto_remove: !Rails.env.test? do
    attribute :id, :title, :description, :ocr_text, :document_category_id,
              :internal_only, :published_at, :created_at
    attribute :category_name do
      document_category&.name
    end
    attribute :published do
      published?
    end

    searchable_attributes [:title, :description, :ocr_text, :category_name]
    filterable_attributes [:document_category_id, :internal_only, :published]
    sortable_attributes [:published_at, :created_at]
  end

  private

  def mark_file_change
    @file_changed = attachment_changes.key?("file")
  end

  def purge_thumbnail_on_file_change
    return unless @file_changed

    thumbnail.purge if thumbnail.attached?
  end

  def queue_file_processing
    return unless file.attached?
    return unless @file_changed

    queue_ocr_extraction
    queue_thumbnail_generation
  ensure
    @file_changed = false
  end

  def queue_ocr_extraction
    return unless defined?(OcrExtractionJob)

    OcrExtractionJob.perform_later(self)
  end

  def queue_thumbnail_generation
    return unless defined?(ThumbnailGenerationJob)

    ThumbnailGenerationJob.perform_later(self)
  end

  def send_notification
    return unless notify_staff
    return unless published?
    return unless defined?(DocumentNotificationJob)

    DocumentNotificationJob.perform_later(self)
  end

  def file_size_within_limit
    return unless file.attached?
    return unless file.blob.byte_size > MAX_FILE_SIZE

    errors.add(:file, "je prevelika (največ #{MAX_FILE_SIZE / 1.megabyte} MB)")
  end

  def file_is_pdf
    return unless file.attached?
    return if file.content_type == "application/pdf"

    errors.add(:file, "mora biti v PDF obliki")
  end

  def file_must_be_attached
    return if file.attached?

    errors.add(:file, "mora biti priložena")
  end
end
