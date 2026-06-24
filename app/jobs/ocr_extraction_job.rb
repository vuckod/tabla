# frozen_string_literal: true

# Ozadje OCR obdelava dokumentov — izvleče besedilo in searchable PDF.
class OcrExtractionJob < ApplicationJob
  queue_as :ocr

  def perform(record)
    return unless record.present?

    blobs = extractable_blobs(record)
    return if blobs.empty?

    extracted_text = blobs.filter_map { |blob| extract_text_with_logging(record, blob) }.join("\n").strip
    record.update_column(:ocr_text, extracted_text)
    reindex_document_for_meilisearch(record)
  rescue StandardError => e
    Rails.logger.error("[OcrExtractionJob] OCR job failed for #{record.class.name}##{record.id}: #{e.class} - #{e.message}")
  ensure
    # Majhen premor zmanjša CPU "burst" med zaporednimi OCR opravili.
    sleep 2 if blobs.present?
  end

  private

  def extract_text_with_logging(record, blob)
    started_at = Time.current
    result = nil
    ocr_log = OcrLog.create!(
      record: record,
      filename: blob.filename.to_s,
      status: "processing",
      started_at: started_at
    )

    result = OcrExtractorService.call(blob)
    extracted_text = result[:text].to_s.strip
    attach_searchable_pdf(ocr_log, blob, result[:pdf_path])

    mark_log_success!(ocr_log, started_at)
    extracted_text.presence
  rescue StandardError => e
    mark_log_error!(ocr_log, started_at, e)
    Rails.logger.error("[OcrExtractionJob] OCR extraction failed for #{record.class.name}##{record.id} (#{blob.filename}): #{e.class} - #{e.message}")
    nil
  ensure
    cleanup_generated_pdf(result)
  end

  def mark_log_success!(ocr_log, started_at)
    completed_at = Time.current
    ocr_log.update!(
      status: "success",
      completed_at: completed_at,
      duration: completed_at - started_at,
      error_message: nil
    )
  end

  def mark_log_error!(ocr_log, started_at, error)
    return unless ocr_log.present?

    completed_at = Time.current
    ocr_log.update!(
      status: "error",
      completed_at: completed_at,
      duration: completed_at - started_at,
      error_message: "#{error.class}: #{error.message}"
    )
  end

  def extractable_blobs(record)
    case record
    when Document
      return [] unless record.file.attached?

      [record.file.blob]
    else
      []
    end
  end

  def attach_searchable_pdf(ocr_log, blob, pdf_path)
    return if pdf_path.blank? || !File.exist?(pdf_path)

    ocr_log.searchable_pdf.purge if ocr_log.searchable_pdf.attached?

    filename_base = File.basename(blob.filename.to_s, ".*").presence || "file"
    safe_filename = "ocr_#{filename_base}.pdf"

    File.open(pdf_path, "rb") do |file|
      ocr_log.searchable_pdf.attach(
        io: file,
        filename: safe_filename,
        content_type: "application/pdf"
      )
    end
  end

  def cleanup_generated_pdf(result)
    return unless result.is_a?(Hash)

    pdf_path = result[:pdf_path].to_s
    return if pdf_path.blank?
    return unless File.exist?(pdf_path)

    File.delete(pdf_path)
  rescue StandardError => e
    Rails.logger.warn("[OcrExtractionJob] Failed to cleanup OCR pdf #{pdf_path}: #{e.class} - #{e.message}")
  end

  def reindex_document_for_meilisearch(record)
    return unless defined?(MeiliSearch::Rails)
    return unless record.is_a?(Document) && record.respond_to?(:index!)

    record.reload
    record.index!
  rescue StandardError => e
    Rails.logger.warn(
      "[OcrExtractionJob] Meilisearch reindex failed for Document##{record.id}: #{e.class} - #{e.message}"
    )
  end
end
