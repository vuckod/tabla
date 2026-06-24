# frozen_string_literal: true

require "fileutils"
require "open3"
require "securerandom"
require "tempfile"
require "tmpdir"

# Generira JPEG sličico prve strani PDF prek pdftoppm.
class ThumbnailGenerationService
  SCALE_TO = 400

  def self.call(blob)
    new(blob).call
  end

  def self.cleanup(result)
    return unless result.is_a?(Hash)

    path = result[:path].to_s
    File.delete(path) if path.present? && File.exist?(path)
  rescue StandardError => e
    Rails.logger.warn("[ThumbnailGenerationService] Cleanup failed for #{path}: #{e.class} - #{e.message}")
  end

  def initialize(blob, logger: Rails.logger)
    @blob = blob
    @logger = logger
    @temp_source = nil
    @temp_dir = nil
  end

  def call
    return nil unless pdf_blob?

    source_path = materialize_blob
    return nil unless source_path

    @temp_dir = Dir.mktmpdir("thumbnail-gen-")
    output_prefix = File.join(@temp_dir, "thumb")

    stdout, stderr, status = Open3.capture3(
      "pdftoppm", "-jpeg", "-f", "1", "-l", "1", "-scale-to", SCALE_TO.to_s,
      source_path, output_prefix
    )
    unless status.success?
      log_error("pdftoppm failed", StandardError.new(stderr.presence || stdout.presence || "pdftoppm failed"))
      return nil
    end

    jpeg_path = Dir.glob(File.join(@temp_dir, "thumb-*.{jpg,jpeg}")).first
    return nil if jpeg_path.blank? || !File.exist?(jpeg_path)

    persistent_path = File.join(Dir.tmpdir, "thumb-#{SecureRandom.hex(10)}.jpg")
    FileUtils.cp(jpeg_path, persistent_path)
    { path: persistent_path }
  rescue StandardError => e
    log_error("thumbnail generation failed", e)
    nil
  ensure
    cleanup_temp_source!
    cleanup_temp_dir!
  end

  private

  def pdf_blob?
    return false unless @blob.present?

    return true if @blob.content_type.to_s == "application/pdf"
    return true if File.extname(@blob.filename.to_s).casecmp(".pdf").zero?

    false
  end

  def materialize_blob
    ext = File.extname(@blob.filename.to_s).presence || ".pdf"
    @temp_source = Tempfile.new(["thumbnail-source-", ext])
    @temp_source.binmode
    @temp_source.write(@blob.download)
    @temp_source.flush
    @temp_source.path
  end

  def cleanup_temp_source!
    @temp_source&.close!
    @temp_source = nil
  end

  def cleanup_temp_dir!
    FileUtils.remove_entry(@temp_dir) if @temp_dir.present? && Dir.exist?(@temp_dir)
    @temp_dir = nil
  end

  def log_error(message, error)
    @logger.error("[ThumbnailGenerationService] #{message}: #{error.class} - #{error.message}")
  end
end
