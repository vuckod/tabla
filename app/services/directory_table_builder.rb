# frozen_string_literal: true

# Sestavi enoten seznam vrstic za kompakten imenik na domači strani.
class DirectoryTableBuilder
  DirectoryRow = Data.define(:internal, :external, :naziv, :enota, :unit_kind, :unit_position)

  # Lokacije brez position (npr. samostojne številke brez lokacije) gredo na konec.
  NO_POSITION = 9_999

  def self.rows
    new.rows
  end

  def self.rows_by_unit_kind
    new.rows_by_unit_kind
  end

  def rows
    (person_rows + standalone_location_rows)
      .reject { |row| row.internal.blank? && row.external.blank? }
      .sort_by { |row| [row.unit_position, internal_sort_key(row.internal), row.naziv.to_s.downcase] }
  end

  def rows_by_unit_kind
    grouped = rows.group_by(&:unit_kind)
    ordered = {}
    %w[headquarters branch].each do |kind|
      ordered[kind] = grouped[kind] if grouped[kind].present?
    end
    ordered
  end

  private

  def person_rows
    Person.active.includes(:phone_numbers, :location).map do |person|
      numbers = person.phone_numbers
      DirectoryRow.new(
        internal: number_for(numbers, :internal),
        external: number_for(numbers, :external),
        naziv: person.full_name,
        enota: unit_label(person.location),
        unit_kind: person.location&.kind,
        unit_position: unit_position(person.location)
      )
    end
  end

  def standalone_location_rows
    PhoneNumber.where(person_id: nil)
               .includes(:location)
               .group_by { |pn| [pn.location_id, pn.label.presence] }
               .map do |_key, numbers|
      location = numbers.first.location
      DirectoryRow.new(
        internal: number_for(numbers, :internal),
        external: number_for(numbers, :external),
        naziv: numbers.first.label.presence || location.name,
        enota: unit_label(location),
        unit_kind: location.kind,
        unit_position: unit_position(location)
      )
    end
  end

  def number_for(numbers, kind)
    numbers.find { |n| n.public_send(:"#{kind}?") }&.number
  end

  def unit_label(location)
    return "" unless location

    location.short_code.presence || location.name
  end

  # Vrstni red enot po Location#position (SIKLND=1, NOE=2 iz seeda). Brez lokacije → na konec.
  def unit_position(location)
    location&.position.presence || NO_POSITION
  end

  # Numerični ključ za sortiranje po interni številki (da "80" pride pred "650").
  # Vrstice brez interne številke gredo na konec znotraj enote.
  def internal_sort_key(internal)
    digits = internal.to_s.gsub(/\D/, "")
    digits.present? ? digits.to_i : Float::INFINITY
  end
end
