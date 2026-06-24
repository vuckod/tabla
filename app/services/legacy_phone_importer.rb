# frozen_string_literal: true

# Uvoz telefonskih številk iz stare table (HTML) v imenik.
class LegacyPhoneImporter
  DEFAULT_HTML_PATH = LegacyTableImporter::DEFAULT_HTML_PATH

  DEPARTMENTS = [
    "odrasli izp.",
    "mladinski izp.",
    "sm oddelek",
    "pisarna zg.",
    "blagajna",
    "kavarna",
    "centrala"
  ].freeze

  DEPARTMENT_DISPLAY_NAMES = {
    "odrasli izp." => "Odrasli izposoja",
    "mladinski izp." => "Mladinski izposoja",
    "sm oddelek" => "SM oddelek",
    "pisarna zg." => "Pisarna zg.",
    "blagajna" => "Blagajna",
    "kavarna" => "Kavarna",
    "centrala" => "Centrala"
  }.freeze

  LOCATION_MOBILE_NUMBERS = {
    "031-333-401" => "Službeni"
  }.freeze

  LOCATION_BLOCKS = [
    {
      label: "SIKLND",
      short_code: "SIKLND",
      external_selector: "#intro #mission",
      internal_selector: "#intro #services",
      other_selector: "#intro #services6"
    },
    {
      label: "NOE",
      short_code: "NOE",
      external_selector: "#intro8 #mission8",
      internal_selector: "#intro8 #services8",
      other_selector: "#intro8 #services81"
    }
  ].freeze

  ParsedEntry = Data.define(:number, :description, :source)

  def self.call(html_path = DEFAULT_HTML_PATH, dry_run: false)
    new(html_path, dry_run: dry_run).call
  end

  def initialize(html_path, dry_run: false, logger: Rails.logger)
    @html_path = html_path.to_s
    @dry_run = dry_run
    @logger = logger
    reset_stats!
  end

  def call
    doc = Nokogiri::HTML(File.read(@html_path, encoding: "UTF-8"))

    LOCATION_BLOCKS.each do |config|
      import_location_block(doc, config)
    end

    print_summary
    @stats
  end

  private

  def reset_stats!
    @stats = {
      persons: { created: 0, updated: 0, dry_run: 0, skipped: 0 },
      phones: { created: 0, skipped: 0, dry_run: 0 },
      location_phones: { created: 0, skipped: 0, dry_run: 0 },
      matched_users: [],
      manual_review: [],
      failures: []
    }
  end

  def import_location_block(doc, config)
    location = Location.find_by!(short_code: config[:short_code])
    @logger.info("[LegacyPhoneImporter] === #{config[:label]} (#{location.name}) ===")

    external = parse_phone_section(doc, config[:external_selector], "zunanja")
    internal = parse_phone_section(doc, config[:internal_selector], "interna")
    other = parse_other_section(doc, config[:other_selector])

    merge_external_internal_pairs(external, internal, location, config[:label])
    import_other_entries(other, location, config[:label])
  end

  def parse_phone_section(doc, selector, source_label)
    node = doc.at_css(selector)
    return [] unless node

    parse_paragraph_entries(node.at_css("p"), source_label)
  end

  def parse_other_section(doc, selector)
    node = doc.at_css(selector)
    return [] unless node

    paragraph = node.at_css("p")
    return [] unless paragraph

    parse_paragraph_entries(paragraph, "ostale")
  end

  def parse_paragraph_entries(paragraph, source_label)
    return [] unless paragraph

    html = paragraph.inner_html
    html.split(/<br\s*\/?>/i).filter_map do |fragment|
      fragment = fragment.gsub(/\r?\n+/, " ")
      text = Nokogiri::HTML.fragment(fragment).text.squish
      next if text.blank?
      next if text.match?(/\AGSM:?\z/i)

      match = fragment.match(/<b>([^<]+)<\/b>\s*-\s*(.+)/im) ||
              text.match(/\A(.+?)\s*-\s*(.+)\z/)
      next unless match

      number = Nokogiri::HTML.fragment("<b>#{match[1]}</b>").text.squish
      description = Nokogiri::HTML.fragment(match[2]).text.squish
      next if number.blank? || description.blank?
      next if description.match?(/a1\.si|uc\.a1|imenik\.a1/i)
      next if number.match?(/https?:/i)

      ParsedEntry.new(number: number, description: description, source: source_label)
    end
  end

  def merge_external_internal_pairs(external, internal, location, block_label)
    if external.size != internal.size
      record_failure(
        block_label,
        "Različno število zunanjih (#{external.size}) in internih (#{internal.size}) vnosov"
      )
    end

    external.zip(internal).each do |ext_entry, int_entry|
      next unless ext_entry

      description = preferred_description(ext_entry.description, int_entry&.description)

      begin
        import_person_entry(
          location: location,
          block_label: block_label,
          description: description,
          external_number: ext_entry.number,
          internal_number: int_entry&.number
        )
      rescue StandardError => e
        record_failure(block_label, e.message, ext_entry.description)
      end
    end
  end

  def import_other_entries(entries, location, block_label)
    entries.each do |entry|
      begin
        if location_mobile_number?(entry.number)
          import_location_phone(
            location: location,
            number: entry.number,
            kind: :mobile,
            label: LOCATION_MOBILE_NUMBERS[entry.number],
            block_label: block_label
          )
          next
        end

        if department?(entry.description)
          if entry.description.downcase == "centrala"
            import_location_phone(
              location: location,
              number: entry.number,
              kind: :external,
              label: "Centrala",
              block_label: block_label
            )
          else
            import_person_entry(
              location: location,
              block_label: block_label,
              description: entry.description,
              external_number: entry.number,
              internal_number: nil
            )
          end
          next
        end

        if mobile_number?(entry.number)
          import_person_entry(
            location: location,
            block_label: block_label,
            description: entry.description,
            external_number: nil,
            internal_number: nil,
            mobile_number: entry.number
          )
          next
        end

        import_person_entry(
          location: location,
          block_label: block_label,
          description: entry.description,
          external_number: entry.number,
          internal_number: nil
        )
      rescue StandardError => e
        record_failure(block_label, e.message, entry.description)
      end
    end
  end

  def import_person_entry(location:, block_label:, description:, external_number:, internal_number:, mobile_number: nil)
    name_data = resolve_name_data(description)
    person_name = display_person_name(name_data)

    if @dry_run
      @stats[:persons][:dry_run] += 1
      count_dry_run_phones(external_number, internal_number, mobile_number)
      log_person_dry_run(block_label, person_name, name_data, external_number, internal_number, mobile_number)
      return
    end

    person = find_or_create_person!(name_data, location)
    track_person_stats(person)

    phones = [
      { number: external_number, kind: :external, label: nil },
      { number: internal_number, kind: :internal, label: nil },
      { number: mobile_number, kind: :mobile, label: nil }
    ].select { |phone| phone[:number].present? }

    phones.each do |phone|
      import_person_phone(person, phone[:number], phone[:kind], phone[:label], block_label, person_name)
    end
  end

  def import_person_phone(person, number, kind, label, block_label, person_name)
    if phone_exists?(number)
      @stats[:phones][:skipped] += 1
      @logger.info("[PRESKOČENO] #{block_label} | #{person_name} | #{kind} #{number} (že obstaja)")
      return
    end

    person.phone_numbers.create!(number: number, kind: kind, label: label)
    @stats[:phones][:created] += 1
    @logger.info("[USTVARJENO] #{block_label} | #{person_name} | #{kind} #{number}")
  end

  def import_location_phone(location:, number:, kind:, label:, block_label:)
    if phone_exists?(number)
      @stats[:location_phones][:skipped] += 1
      @logger.info("[PRESKOČENO] #{block_label} | lokacija | #{label} #{number} (že obstaja)")
      return
    end

    if @dry_run
      @stats[:location_phones][:dry_run] += 1
      @logger.info("[BI UVOZIL] #{block_label} | lokacija #{location.short_code} | #{label} | #{kind} #{number}")
      return
    end

    location.phone_numbers.create!(number: number, kind: kind, label: label)
    @stats[:location_phones][:created] += 1
    @logger.info("[USTVARJENO] #{block_label} | lokacija #{location.short_code} | #{label} | #{kind} #{number}")
  end

  def find_or_create_person!(name_data, location)
    if name_data[:is_department]
      person = Person.find_or_initialize_by(last_name: name_data[:last_name], location_id: location.id) do |record|
        record.first_name = ""
        record.position_title = "Oddelek"
        record.active = true
      end
    else
      person = Person.find_or_initialize_by(
        first_name: name_data[:first_name],
        last_name: name_data[:last_name],
        location_id: location.id
      ) do |record|
        record.active = true
      end
    end

    person.position_title = "Oddelek" if name_data[:is_department]
    person.active = true
    person.save!
    person
  end

  def track_person_stats(person)
    if person.previously_new_record?
      @stats[:persons][:created] += 1
    else
      @stats[:persons][:updated] += 1
    end
  end

  def resolve_name_data(description)
    if department?(description)
      key = normalize_description(description)
      return {
        is_department: true,
        first_name: "",
        last_name: DEPARTMENT_DISPLAY_NAMES.fetch(key, description.squish.titleize),
        matched_user: nil,
        source_description: description.squish
      }
    end

    parsed = parse_person_description(description)
    users = find_matching_users(parsed[:first_name], parsed[:surname_initial])

    if users.size == 1
      user = users.first
      @stats[:matched_users] << { source: description.squish, user: user.polno_ime }
      {
        is_department: false,
        first_name: user.ime,
        last_name: user.priimek,
        matched_user: user,
        source_description: description.squish
      }
    else
      reason = users.empty? ? "ni zadetka" : "več zadetkov (#{users.map(&:polno_ime).join(', ')})"
      @stats[:manual_review] << { source: description.squish, reason: reason }
      {
        is_department: false,
        first_name: parsed[:display_first_name],
        last_name: parsed[:display_last_name],
        matched_user: nil,
        source_description: description.squish
      }
    end
  end

  def parse_person_description(description)
    text = description.squish
    text = text.sub(/\A((?:dr|mag|prof)\.)\s+/i, "").strip
    parts = text.split(/\s+/)

    display_first_name = parts.first.to_s
    surname_initial = extract_surname_initial(parts[1..] || [])
    display_last_name = (parts[1..] || []).join(" ").presence || display_first_name

    {
      first_name: display_first_name,
      surname_initial: surname_initial,
      display_first_name: display_first_name,
      display_last_name: display_last_name
    }
  end

  def extract_surname_initial(parts)
    parts.each do |part|
      letters = part.gsub(/[^A-Za-zÀ-ÖØ-öø-ÿŠČĆŽĐščćžđ]/, "")
      return letters[0] if letters.present?
    end
    nil
  end

  def find_matching_users(first_name, surname_initial)
    scope = User.active.where("LOWER(ime) = ?", first_name.to_s.downcase)
    if surname_initial.present?
      scope = scope.where("priimek ILIKE ?", "#{surname_initial}%")
    end
    scope.to_a
  end

  def preferred_description(external_description, internal_description)
    return external_description if internal_description.blank?
    return internal_description if department?(internal_description) && !department?(external_description)

    ext = external_description.to_s.squish
    int = internal_description.to_s.squish
    return int if int.length > ext.length && int.downcase.start_with?(ext.downcase)

    external_description
  end

  def department?(description)
    DEPARTMENTS.include?(normalize_description(description))
  end

  def normalize_description(description)
    description.to_s.squish.downcase
  end

  def location_mobile_number?(number)
    LOCATION_MOBILE_NUMBERS.key?(number)
  end

  def mobile_number?(number)
    number.to_s.match?(/\A0\d{2}-/)
  end

  def phone_exists?(number)
    PhoneNumber.exists?(number: number)
  end

  def display_person_name(name_data)
    if name_data[:is_department]
      name_data[:last_name]
    else
      [name_data[:first_name], name_data[:last_name]].compact_blank.join(" ")
    end
  end

  def count_dry_run_phones(*numbers)
    numbers.compact_blank.each do |number|
      if phone_exists?(number)
        @stats[:phones][:skipped] += 1
      else
        @stats[:phones][:dry_run] += 1
      end
    end
  end

  def log_person_dry_run(block_label, person_name, name_data, external_number, internal_number, mobile_number)
    match = if name_data[:matched_user]
              "ujeto → #{name_data[:matched_user].polno_ime}"
            else
              "ROČNI PREGLED (#{name_data[:source_description]})"
            end
    type = name_data[:is_department] ? "oddelek" : "oseba"
    phones = [
      external_number.present? ? "zunanja #{external_number}" : nil,
      internal_number.present? ? "interna #{internal_number}" : nil,
      mobile_number.present? ? "gsm #{mobile_number}" : nil
    ].compact.join(", ")

    @logger.info("[BI UVOZIL] #{block_label} | #{type} | #{person_name} | #{phones} | #{match}")
  end

  def record_failure(block_label, message, detail = nil)
    @stats[:failures] << { block: block_label, message: message, detail: detail }
    @logger.error("[LegacyPhoneImporter] #{block_label}: #{message}#{detail ? " (#{detail})" : ""}")
  end

  def print_summary
    mode = @dry_run ? "SUHI TEK (brez shranjevanja)" : "DEJANSKI UVOZ"
    persons = @stats[:persons]
    phones = @stats[:phones]
    location_phones = @stats[:location_phones]

    summary = <<~SUMMARY

      ========== LegacyPhoneImporter — #{mode} ==========
      Osebe/oddelki:
        bi ustvaril / ustvarjeni: #{persons[:dry_run] + persons[:created]}
        posodobljeni:              #{persons[:updated]}
      Telefonske (osebe):
        bi ustvaril / ustvarjene:  #{phones[:dry_run] + phones[:created]}
        preskočene (že obstajajo): #{phones[:skipped]}
      Telefonske (lokacije):
        bi ustvaril / ustvarjene:  #{location_phones[:dry_run] + location_phones[:created]}
        preskočene:                #{location_phones[:skipped]}
    SUMMARY

    if @stats[:matched_users].any?
      summary << "\nUjemanja z uporabniki (#{@stats[:matched_users].size}):\n"
      @stats[:matched_users].each do |row|
        summary << "  - \"#{row[:source]}\" → #{row[:user]}\n"
      end
    end

    if @stats[:manual_review].any?
      summary << "\nRočni pregled (#{@stats[:manual_review].size}):\n"
      @stats[:manual_review].each do |row|
        summary << "  - \"#{row[:source]}\" (#{row[:reason]})\n"
      end
    end

    if @stats[:failures].any?
      summary << "\nNapake (#{@stats[:failures].size}):\n"
      @stats[:failures].each do |failure|
        summary << "  - [#{failure[:block]}] #{failure[:message]}"
        summary << " (#{failure[:detail]})" if failure[:detail]
        summary << "\n"
      end
    end

    unless @dry_run
      summary << "\nZa dejanski uvoz zaženi: bin/rails import:phones\n"
    end

    @logger.info(summary)
    puts summary
  end
end
