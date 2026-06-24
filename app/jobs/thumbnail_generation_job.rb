# frozen_string_literal: true

# Predgenerira JPEG sličico prve strani PDF in jo shrani kot priloženo datoteko.
class ThumbnailGenerationJob < ApplicationJob
  queue_as :thumbnails

  def perform(document)
    return unless document.is_a?(Document)
    return unless document.file.attached?
    return if document.thumbnail.attached?

    result = nil
    result = ThumbnailGenerationService.call(document.file.blob)
    return unless result

    File.open(result[:path], "rb") do |io|
      document.thumbnail.attach(
        io: io,
        filename: "thumb_#{document.id}.jpg",
        content_type: "image/jpeg"
      )
    end
  rescue StandardError => e
    Rails.logger.error(
      "[ThumbnailGenerationJob] Failed for Document##{document&.id}: #{e.class} - #{e.message}"
    )
  ensure
    ThumbnailGenerationService.cleanup(result) if result
  end
end
