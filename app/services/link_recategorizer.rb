# frozen_string_literal: true

# Premakne obstoječe povezave v kategorije glede na LinkCategorizer mapiranje.
class LinkRecategorizer
  SCOPES = {
    imported: LinkCategorizer::IMPORTED_LINKS_CATEGORY,
    all: nil
  }.freeze

  def self.call(scope: :imported, logger: Rails.logger)
    new(scope: scope, logger: logger).call
  end

  def initialize(scope: :imported, logger: Rails.logger)
    @scope = scope.to_sym
    @logger = logger
    @stats = {
      moved: Hash.new(0),
      unchanged: 0,
      failed: 0,
      failures: []
    }
  end

  def call
    links = links_scope
    @logger.info("[LinkRecategorizer] Obdelujem #{links.size} povezav (obseg: #{@scope})")

    links.find_each do |link|
      recategorize_link(link)
    end

    cleanup_imported_category!
    print_summary
    @stats
  end

  private

  def links_scope
    scope = Link.includes(:link_category).external_links
    category_name = SCOPES.fetch(@scope)

    if category_name
      imported = LinkCategory.find_by(name: category_name)
      return Link.none unless imported

      scope.where(link_category_id: imported.id)
    else
      scope
    end
  end

  def recategorize_link(link)
    target_name = LinkCategorizer.category_name_for(link.url)
    return record_unchanged(link) if link.link_category.name == target_name

    target_category = LinkCategorizer.ensure_category!(target_name)
    link.update!(link_category: target_category)
    @stats[:moved][target_name] += 1
    @logger.info("[LinkRecategorizer] #{link.title} → #{target_name}")
  rescue StandardError => e
    @stats[:failed] += 1
    @stats[:failures] << { title: link.title, url: link.url, reason: e.message }
    @logger.error("[LinkRecategorizer] Napaka pri #{link.title}: #{e.message}")
  end

  def record_unchanged(link)
    @stats[:unchanged] += 1
    @logger.debug("[LinkRecategorizer] Brez spremembe: #{link.title} (#{link.link_category.name})")
  end

  def cleanup_imported_category!
    imported = LinkCategory.find_by(name: LinkCategorizer::IMPORTED_LINKS_CATEGORY)
    return unless imported
    return if imported.links.exists?

    imported.destroy!
    @logger.info("[LinkRecategorizer] Odstranjena prazna kategorija \"#{LinkCategorizer::IMPORTED_LINKS_CATEGORY}\"")
    @stats[:imported_category_removed] = true
  end

  def print_summary
    moved_total = @stats[:moved].values.sum

    summary = <<~SUMMARY

      ========== LinkRecategorizer — povzetek ==========
      Obseg: #{@scope}
      Premaknjene:  #{moved_total}
      Nespremenjene: #{@stats[:unchanged]}
      Neuspešne:     #{@stats[:failed]}
    SUMMARY

    if @stats[:moved].any?
      summary << "\nPo kategorijah:\n"
      @stats[:moved].sort_by { |name, _| name }.each do |name, count|
        summary << "  #{name}: #{count}\n"
      end
    end

    if @stats[:failures].any?
      summary << "\nNapake:\n"
      @stats[:failures].each do |failure|
        summary << "  - #{failure[:title]}: #{failure[:reason]}\n"
      end
    end

    if @stats[:imported_category_removed]
      summary << "\nKategorija \"#{LinkCategorizer::IMPORTED_LINKS_CATEGORY}\" odstranjena (prazna).\n"
    end

    @logger.info(summary)
    puts summary
  end
end
