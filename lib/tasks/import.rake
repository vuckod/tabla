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

  desc "Re-kategorizira uvožene povezave (privzeto samo iz 'Uvožene povezave'; scope=all za vse zunanje)"
  task :recategorize_links, [:scope] => :environment do |_t, args|
    scope = args[:scope].presence&.to_sym || :imported
    unless LinkRecategorizer::SCOPES.key?(scope)
      abort "Neveljaven obseg: #{scope}. Dovoljeno: #{LinkRecategorizer::SCOPES.keys.join(', ')}"
    end

    LinkRecategorizer.call(scope: scope)
  end
end
