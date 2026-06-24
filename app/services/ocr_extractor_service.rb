# frozen_string_literal: true

require "fileutils"
require "open3"
require "securerandom"
require "tempfile"
require "tmpdir"

# Izvleče besedilo in searchable PDF iz PDF/slike prek Tesseract (slv+hun).
class OcrExtractorService
  OCR_LANGUAGE = "slv+hun".freeze

  def self.call(file_or_path)
    new(file_or_path).call
  end

  def initialize(file_or_path, logger: Rails.logger)
    @file_or_path = file_or_path
    @logger = logger
    @temporary_files = []
    @temporary_dirs = []
  end

  def call
    source = materialize_source(@file_or_path)
    return empty_result if source.nil?

    text, pdf_path =
      if pdf_file?(source[:path], source[:content_type], source[:filename])
        extract_from_pdf(source[:path])
      else
        extract_from_image(source[:path])
      end

    { text: normalize_text(text), pdf_path: pdf_path }
  rescue StandardError => e
    log_error("OCR extraction failed", e)
    empty_result
  ensure
    cleanup!
  end

  private

  def materialize_source(input)
    case input
    when String, Pathname
      path = input.to_s
      return nil unless File.exist?(path)

      { path: path, filename: File.basename(path), content_type: nil }
    else
      if defined?(ActiveStorage::Attached::One) && input.is_a?(ActiveStorage::Attached::One)
        return nil unless input.attached?

        return materialize_blob(input.blob)
      end

      if defined?(ActiveStorage::Blob) && input.is_a?(ActiveStorage::Blob)
        return materialize_blob(input)
      end

      if input.respond_to?(:path) && input.path.present? && File.exist?(input.path)
        filename = input.respond_to?(:original_filename) ? input.original_filename.to_s : File.basename(input.path)
        content_type = input.respond_to?(:content_type) ? input.content_type : nil
        return { path: input.path, filename: filename, content_type: content_type }
      end

      nil
    end
  end

  def materialize_blob(blob)
    ext = File.extname(blob.filename.to_s).presence || ".bin"
    file = Tempfile.new(["ocr-source-", ext])
    file.binmode
    file.write(blob.download)
    file.flush
    track_tempfile(file)

    { path: file.path, filename: blob.filename.to_s, content_type: blob.content_type }
  end

  def extract_from_pdf(path)
    image_paths = convert_pdf_to_images(path)
    return empty_result.values_at(:text, :pdf_path) if image_paths.empty?

    run_tesseract_for_pages(image_paths)
  end

  def convert_pdf_to_images(path)
    output_dir = Dir.mktmpdir("ocr-pdf-pages-")
    @temporary_dirs << output_dir
    output_prefix = File.join(output_dir, "page")

    stdout, stderr, status = Open3.capture3("pdftoppm", "-png", path.to_s, output_prefix)
    unless status.success?
      log_error("PDF to image conversion failed", StandardError.new(stderr.presence || stdout.presence || "pdftoppm failed"))
      return []
    end

    Dir.glob("#{output_prefix}-*.png").sort
  end

  def extract_from_image(path)
    run_tesseract_for_pages([path])
  end

  def run_tesseract_for_pages(page_paths)
    output_dir = Dir.mktmpdir("ocr-output-")
    @temporary_dirs << output_dir

    txt_paths = []
    pdf_paths = []

    page_paths.each_with_index do |page_path, idx|
      base_path = File.join(output_dir, format("page-%04d", idx + 1))
      stdout, stderr, status = Open3.capture3("tesseract", page_path.to_s, base_path, "-l", OCR_LANGUAGE, "txt", "pdf")
      unless status.success?
        message = stderr.presence || stdout.presence || "tesseract failed"
        raise StandardError, "Tesseract failed for #{File.basename(page_path)}: #{message}"
      end

      txt_paths << "#{base_path}.txt"
      pdf_paths << "#{base_path}.pdf"
    end

    combined_text = txt_paths.filter_map { |txt_path| File.exist?(txt_path) ? File.read(txt_path) : nil }.join("\n")
    final_pdf_path = merge_pdf_pages(pdf_paths)

    [combined_text, final_pdf_path]
  end

  def merge_pdf_pages(pdf_paths)
    existing_pdf_paths = pdf_paths.select { |path| File.exist?(path) }
    return nil if existing_pdf_paths.empty?

    final_pdf_path = persistent_tmp_path("ocr-searchable-", ".pdf")

    if existing_pdf_paths.one?
      FileUtils.cp(existing_pdf_paths.first, final_pdf_path)
      return final_pdf_path
    end

    stdout, stderr, status = Open3.capture3("pdfunite", *existing_pdf_paths, final_pdf_path)
    unless status.success?
      message = stderr.presence || stdout.presence || "pdfunite failed"
      raise StandardError, "PDF merge failed: #{message}"
    end

    final_pdf_path
  end

  def persistent_tmp_path(prefix, extension)
    File.join(Dir.tmpdir, "#{prefix}#{SecureRandom.hex(10)}#{extension}")
  end

  def pdf_file?(path, content_type, filename)
    return true if content_type.to_s == "application/pdf"
    return true if File.extname(filename.to_s).casecmp(".pdf").zero?

    begin
      Marcel::MimeType.for(Pathname.new(path)) == "application/pdf"
    rescue StandardError
      false
    end
  end

  def normalize_text(text)
    return "" if text.blank?

    lines = text.to_s.split("\n").map { |line| line.gsub(/[[:space:]]+/, " ").strip }
    lines.reject(&:blank?).join("\n")
  end

  def track_tempfile(file)
    @temporary_files << file
    file
  end

  def cleanup!
    @temporary_files.each(&:close!)
    @temporary_dirs.each { |dir| FileUtils.remove_entry(dir) if Dir.exist?(dir) }
  end

  def empty_result
    { text: "", pdf_path: nil }
  end

  def log_error(message, error)
    @logger.error("[OcrExtractorService] #{message}: #{error.class} - #{error.message}")
  end
end
