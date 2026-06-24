# frozen_string_literal: true

class DocumentMailer < ApplicationMailer
  include AnnouncementsHelper

  def new_document(document, recipient_emails)
    @document = document
    @category = document.document_category
    @url = document_url(document)
    @unit_label = announcement_unit_label(document.unit)
    @published_at_label = format_published_at(document)

    mail(
      to: ENV.fetch("DEFAULT_FROM_EMAIL", "intranet@kl-kl.si"),
      bcc: recipient_emails,
      subject: t("mailers.document_mailer.new_document.subject", title: document.title)
    )
  end

  private

  def format_published_at(document)
    return "—" unless document.published_at

    I18n.l(document.published_at.to_date, format: :long)
  end
end
