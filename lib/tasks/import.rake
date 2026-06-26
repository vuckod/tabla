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

  desc "Uvoz telefonskih številk iz stare table (HTML)"
  task :phones, [:path] => :environment do |_t, args|
    path = args[:path] || LegacyPhoneImporter::DEFAULT_HTML_PATH.to_s
    LegacyPhoneImporter.call(path, dry_run: false)
  end

  desc "Suhi tek telefonskih — parsiraj in izpiši ujemanja, brez shranjevanja"
  task :phones_dry, [:path] => :environment do |_t, args|
    path = args[:path] || LegacyPhoneImporter::DEFAULT_HTML_PATH.to_s
    LegacyPhoneImporter.call(path, dry_run: true)
  end

  desc "Posodobi unit obstoječih uvoženih dokumentov glede na kategorijo"
  task update_units: :environment do
    updated = 0
    Document.find_each do |doc|
      next unless doc.document_category

      new_unit = case doc.document_category.name
                 when /knjižnica/i then :library
                 when /noe/i then :theatre
                 else :both
                 end
      next if doc.unit.to_s == new_unit.to_s

      doc.update_column(:unit, Document.units[new_unit])
      updated += 1
      puts "  Posodobil: #{doc.title} → #{new_unit}"
    end
    puts "Posodobljeno #{updated} dokumentov."
  end
end
