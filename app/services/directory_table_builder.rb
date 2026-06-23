# frozen_string_literal: true

# Sestavi enoten seznam vrstic za kompakten imenik na domači strani.
class DirectoryTableBuilder
  DirectoryRow = Data.define(:internal, :external, :naziv, :enota, :unit_kind)

  def self.rows
    new.rows
  end

  def rows
    (person_rows + standalone_location_rows)
      .reject { |row| row.internal.blank? && row.external.blank? }
      .sort_by { |row| [row.enota.to_s.downcase, row.naziv.to_s.downcase] }
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
        unit_kind: person.location&.kind
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
        unit_kind: location.kind
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
end
