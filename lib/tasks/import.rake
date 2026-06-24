# frozen_string_literal: true

namespace :import do
  desc "Uvoz dokumentov in povezav iz stare table (HTML)"
  task :legacy, [:path] => :environment do |_t, args|
    path = args[:path] || LegacyTableImporter::DEFAULT_HTML_PATH.to_s
    LegacyTableImporter.call(path, download: true)
  end

  desc "Suhi tek — samo parsiraj in izpiši, brez prenosa in shranjevanja"
  task :legacy_dry, [:path] => :environment do |_t, args|
    path = args[:path] || LegacyTableImporter::DEFAULT_HTML_PATH.to_s
    LegacyTableImporter.call(path, download: false)
  end
end
