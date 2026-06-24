# frozen_string_literal: true

require "cgi"
require "net/http"
require "set"
require "uri"

# Enkratni/idempotenten uvoz dokumentov in povezav iz stare PHP table (HTML izvoz).
class LegacyTableImporter
  DEFAULT_HTML_PATH = Rails.root.join("docs", "KKC Lendava - Lendvai KKK  Vstopna stran za zaposlene.htm").freeze
  IMPORTED_LINKS_CATEGORY = "Uvožene povezave"
  CATEGORY_COLORS = DocumentsHelper::CATEGORY_COLORS.freeze

  DOCUMENT_TABLES = [
    {
      selector: "table#dokumenti",
      label: "Pravilniki, navodila, ukrepi",
      layout: :full
    },
    {
      selector: "#tabs-3 table#zapisniki",
      label: "Zapisniki sestankov delavcev - knjižnica",
      layout: :simple,
      default_category: "Zapisniki sestankov delavcev - knjižnica"
    },
    {
      selector: "table#svet",
      label: "Zapisniki sej sveta zavoda",
      layout: :simple,
      default_category: "Zapisniki sej sveta zavoda"
    },
    {
      selector: "table#obvestila",
      label: "Obvestila za zaposlene",
      layout: :full
    }
  ].freeze

  TIP_NAME_MAP = {
    "akt" => "Akt",
    "pravilnik" => "Pravilnik",
    "navodilo" => "Navodilo",
    "sklep" => "Sklep",
    "načrt" => "Načrt",
    "nacrt" => "Načrt",
    "obrazec" => "Obrazec",
    "kodeks" => "Kodeks",
    "ukrep" => "Ukrep",
    "ukrepi" => "Ukrepi",
    "smernice" => "Smernice",
    "protokol" => "Protokol",
    "pravila" => "Pravila",
    "priloga" => "Priloga",
    "interni akt" => "Interni akt",
    "osebni podatki" => "Osebni podatki",
    "razpis" => "Razpis",
    "delovna uspešnost" => "Delovna uspešnost",
    "delovna uspesnost" => "Delovna uspešnost",
    "obvestilo" => "Obvestilo",
    "poslovnik" => "Poslovnik",
    "politika" => "Politika",
    "informacije" => "Informacije",
    "strateski načrt" => "Strateški načrt",
    "strateski nacrt" => "Strateški načrt",
    "zapisnik" => "Zapisnik",
    "seznam" => "Seznam"
  }.freeze

  ParsedDocument = Data.define(
    :table_label, :title, :url, :category_name, :unit, :published_at, :pdf
  )

  ParsedLink = Data.define(:title, :url)

  def self.call(html_path = DEFAULT_HTML_PATH, download: true)
    new(html_path, download: download).call
  end

  def initialize(html_path, download: true, logger: Rails.logger)
    @html_path = html_path.to_s
    @download = download
    @logger = logger
    @seen_document_urls = Set.new
    @color_index = DocumentCategory.count
    reset_stats!
  end

  def call
    doc = Nokogiri::HTML(File.read(@html_path, encoding: "UTF-8"))

    DOCUMENT_TABLES.each do |config|
      import_document_table(doc, config)
    end

    import_side_links(doc)
    print_summary
    @stats
  end

  private

  def reset_stats!
    @stats = {
      documents: { created: 0, skipped: 0, failed: 0, dry_run: 0, non_pdf: 0 },
      links: { created: 0, skipped: 0, failed: 0, dry_run: 0 },
      failures: []
    }
  end

  def import_document_table(doc, config)
    table = doc.at_css(config[:selector])
    unless table
      @logger.info("[LegacyTableImporter] Tabela ni najdena: #{config[:selector]} (#{config[:label]})")
      return
    end

    rows = table.css("tbody tr")
    if rows.empty?
      @logger.info("[LegacyTableImporter] Prazna tabela: #{config[:label]}")
      return
    end

    @logger.info("[LegacyTableImporter] === #{config[:label]} (#{rows.size} vrstic) ===")

    rows.each do |row|
      begin
        parsed = parse_document_row(row, config)
        next unless parsed

        process_document_row(parsed)
      rescue StandardError => e
        record_failure("dokument", config[:label], e.message, row.text.squish.presence)
      end
    end
  end

  def parse_document_row(row, config)
    link = row.at_css("a[href]")
    return nil unless link

    url = normalize_url(link["href"])
    title = link.text.squish
    return nil if url.blank? || title.blank?
    return nil if @seen_document_urls.include?(url)

    @seen_document_urls << url

    cells = row.css("td").map { |td| td.inner_html }
    date_text = cells.last&.then { |html| Nokogiri::HTML.fragment(html).text.squish }
    published_at = parse_date(date_text)

    category_name, unit = resolve_category_name(config, cells)

    ParsedDocument.new(
      table_label: config[:label],
      title: title,
      url: url,
      category_name: category_name,
      unit: unit,
      published_at: published_at,
      pdf: pdf_url?(url)
    )
  end

  def resolve_category_name(config, cells)
    if config[:layout] == :simple
      return [config.fetch(:default_category), nil]
    end

    vrsta_index = cells.size >= 4 ? 2 : 1
    vrsta_html = cells[vrsta_index]
    tip, unit = parse_vrsta(vrsta_html)
    [capitalize_tip(tip), unit]
  end

  def process_document_row(parsed)
    if Document.exists?(source_url: parsed.url)
      @stats[:documents][:skipped] += 1
      log_document_row(parsed, status: "PRESKOČENO (že v bazi)")
      return
    end

    unless parsed.pdf
      @stats[:documents][:non_pdf] += 1
      @stats[:failures] << { kind: "dokument", title: parsed.title, reason: "Ni PDF (#{File.extname(URI.parse(parsed.url).path)})" }
      log_document_row(parsed, status: "PRESKOČENO (ni PDF)")
      return
    end

    unless @download
      @stats[:documents][:dry_run] += 1
      log_document_row(parsed, status: "BI UVOZIL")
      return
    end

    import_document_record(parsed)
  end

  def import_document_record(parsed)
    category = find_or_create_category(parsed.category_name)
    downloaded = download_file(parsed.url)
    unless downloaded
      @stats[:documents][:failed] += 1
      return
    end

    document = Document.new(
      title: parsed.title,
      description: parsed.unit.present? ? "Enota: #{parsed.unit}" : nil,
      document_category: category,
      published_at: parsed.published_at&.in_time_zone || Time.current,
      source_url: parsed.url,
      internal_only: false,
      notify_staff: false
    )

    document.file.attach(
      io: downloaded[:io],
      filename: downloaded[:filename],
      content_type: downloaded[:content_type]
    )

    if document.save
      @stats[:documents][:created] += 1
      log_document_row(parsed, status: "USTVARJENO")
    else
      @stats[:documents][:failed] += 1
      @stats[:failures] << { kind: "dokument", title: parsed.title, reason: document.errors.full_messages.join(", ") }
    end
  rescue StandardError => e
    @stats[:documents][:failed] += 1
    @stats[:failures] << { kind: "dokument", title: parsed.title, reason: e.message }
    @logger.error("[LegacyTableImporter] Napaka pri uvozu #{parsed.title}: #{e.class} - #{e.message}")
  end

  def import_side_links(doc)
    side = doc.at_css("#side")
    return unless side

    @logger.info("[LegacyTableImporter] === Povezave (bočni stolpec) ===")

    side.css("a[href]").each do |link|
      begin
        process_side_link(link)
      rescue StandardError => e
        record_failure("povezava", link.text.squish, e.message, link["href"])
      end
    end
  end

  def process_side_link(link)
    url = normalize_url(link["href"])
    title = link.text.squish
    return if url.blank? || title.blank?
    return if url.start_with?("#")

    parsed = ParsedLink.new(title: title, url: url)

    if Link.exists?(url: url)
      @stats[:links][:skipped] += 1
      log_link_row(parsed, status: "PRESKOČENO (že v bazi)")
      return
    end

    unless @download
      @stats[:links][:dry_run] += 1
      log_link_row(parsed, status: "BI UVOZIL")
      return
    end

    category = LinkCategory.find_or_create_by!(name: IMPORTED_LINKS_CATEGORY) do |cat|
      cat.position = (LinkCategory.maximum(:position) || 0) + 1
    end

    record = Link.find_or_create_by!(url: url) do |lnk|
      lnk.title = title
      lnk.link_category = category
      lnk.new_tab = true
      lnk.internal_app = false
      lnk.position = (Link.maximum(:position) || 0) + 1
    end

    if record.previously_new_record?
      @stats[:links][:created] += 1
      log_link_row(parsed, status: "USTVARJENO")
    else
      @stats[:links][:skipped] += 1
      log_link_row(parsed, status: "PRESKOČENO (že v bazi)")
    end
  end

  def find_or_create_category(name)
    category = DocumentCategory.find_or_initialize_by(name: name)
    return category if category.persisted?

    category.color = CATEGORY_COLORS[@color_index % CATEGORY_COLORS.size].to_s
    category.position = (DocumentCategory.maximum(:position) || 0) + 1
    category.save!
    @color_index += 1
    category
  end

  def download_file(url)
    uri = URI.parse(url)
    response = nil

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 15, read_timeout: 60) do |http|
      response = http.get(uri.request_uri)
    end

    unless response.is_a?(Net::HTTPSuccess)
      @stats[:failures] << { kind: "prenos", title: url, reason: "HTTP #{response.code}" }
      return nil
    end

    body = response.body
    content_type = response.content_type.presence || Marcel::MimeType.for(StringIO.new(body))
    filename = filename_from_url(url)

    { io: StringIO.new(body), filename: filename, content_type: content_type }
  rescue StandardError => e
    @stats[:failures] << { kind: "prenos", title: url, reason: e.message }
    nil
  end

  def parse_vrsta(vrsta_html)
    return [nil, nil] if vrsta_html.blank?

    plain = vrsta_html.to_s.gsub(/<br\s*\/?>/i, "\n")
    text = Nokogiri::HTML.fragment(plain).text
    parts = text.split("\n").map(&:strip).reject(&:blank?)
    tip = parts[0]
    unit = parts[1]
    [tip, unit]
  end

  def capitalize_tip(tip)
    return "Neznano" if tip.blank?

    normalized = tip.strip.downcase.gsub(/\s+/, " ")
    return TIP_NAME_MAP[normalized] if TIP_NAME_MAP.key?(normalized)

    normalized.split.map { |word| word.capitalize }.join(" ")
  end

  def parse_date(text)
    return nil if text.blank?

    Date.parse(text.strip)
  rescue Date::Error
    nil
  end

  def normalize_url(url)
    url.to_s.strip
  end

  def pdf_url?(url)
    path = URI.parse(url).path
    File.extname(path).casecmp(".pdf").zero?
  rescue URI::InvalidURIError
    false
  end

  def filename_from_url(url)
    path = URI.parse(url).path
    name = File.basename(path)
    CGI.unescape(name).presence || "document.pdf"
  rescue URI::InvalidURIError
    "document.pdf"
  end

  def log_document_row(parsed, status:)
    date = parsed.published_at&.iso8601 || "—"
    unit = parsed.unit.present? ? " | enota: #{parsed.unit}" : ""
    @logger.info(
      "[#{status}] #{parsed.table_label} | #{parsed.category_name} | #{date} | #{parsed.title}#{unit}\n  #{parsed.url}"
    )
  end

  def log_link_row(parsed, status:)
    @logger.info("[#{status}] povezava | #{parsed.title}\n  #{parsed.url}")
  end

  def record_failure(kind, label, message, detail = nil)
    @stats[:documents][:failed] += 1 if kind == "dokument"
    @stats[:links][:failed] += 1 if kind == "povezava"
    @stats[:failures] << { kind: kind, title: label, reason: message, detail: detail }
    @logger.error("[LegacyTableImporter] #{kind} napaka (#{label}): #{message}")
  end

  def print_summary
    mode = @download ? "DEJANSKI UVOZ" : "SUHI TEK (brez prenosa)"
    docs = @stats[:documents]
    links = @stats[:links]

    summary = <<~SUMMARY

      ========== LegacyTableImporter — #{mode} ==========
      Dokumenti:
        bi ustvaril / ustvarjeni: #{docs[:dry_run] + docs[:created]}
        preskočeni (že obstajajo): #{docs[:skipped]}
        ne-PDF preskočeni:         #{docs[:non_pdf]}
        neuspešni:                 #{docs[:failed]}
      Povezave:
        bi ustvaril / ustvarjeni: #{links[:dry_run] + links[:created]}
        preskočene:                #{links[:skipped]}
        neuspešne:                 #{links[:failed]}
    SUMMARY

    if @stats[:failures].any?
      summary << "\nNapake (#{@stats[:failures].size}):\n"
      @stats[:failures].first(20).each do |failure|
        summary << "  - [#{failure[:kind]}] #{failure[:title]}: #{failure[:reason]}\n"
      end
      summary << "  ... in še #{@stats[:failures].size - 20}\n" if @stats[:failures].size > 20
    end

    unless @download
      summary << "\nZa dejanski uvoz zaženi: bin/rails import:legacy\n"
      summary << "Opozorilo: OCR bo obdelal ~#{docs[:dry_run]} PDF-jev asinhrono (~20-30 min).\n"
    end

    @logger.info(summary)
    puts summary
  end
end
