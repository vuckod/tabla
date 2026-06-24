# frozen_string_literal: true

namespace :thumbnails do
  desc "Generiraj manjkajoče thumbnaile za obstoječe dokumente"
  task generate_missing: :environment do
    scope = Document.joins(:file_attachment)
    total = scope.count
    queued = 0

    scope.find_each do |doc|
      next if doc.thumbnail.attached?

      ThumbnailGenerationJob.perform_later(doc)
      queued += 1
    end

    puts "V vrsto postavljeno #{queued} / #{total} thumbnail jobov."
  end

  desc "Regeneriraj VSE thumbnaile (najprej odstrani obstoječe)"
  task regenerate_all: :environment do
    queued = 0

    Document.find_each do |doc|
      doc.thumbnail.purge if doc.thumbnail.attached?
      next unless doc.file.attached?

      ThumbnailGenerationJob.perform_later(doc)
      queued += 1
    end

    puts "Regeneracija vseh thumbnailov sprožena (#{queued} jobov)."
  end
end
