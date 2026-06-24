# frozen_string_literal: true

# Pošlje e-mail obvestilo zaposlenim ciljne enote ob objavi dokumenta.
class DocumentNotificationJob < ApplicationJob
  queue_as :mailers

  def perform(document)
    return unless document.notify_staff?
    return unless document.published?
    return if document.internal_only?

    recipients = User.for_document_unit(document.unit).pluck(:email).compact_blank.uniq
    return if recipients.empty?

    DocumentMailer.new_document(document, recipients).deliver_now
  rescue StandardError => e
    Rails.logger.error(
      "[DocumentNotificationJob] Document##{document&.id}: #{e.class} - #{e.message}"
    )
  end
end
