# Tabla — Seed podatki
# Idempotentno: varno za ponovni zagon kadarkoli.

puts "=== Seed: Vloge ==="
Role.find_or_create_by!(name: "intranet_admin")
Role.find_or_create_by!(name: "intranet_urednik")
puts "  Vloge: #{Role.pluck(:name).join(', ')}"

puts "=== Seed: Lokacije ==="
lokacije = [
  { name: "Knjižnica Lendava (sedež)", kind: :headquarters, short_code: "SIKLND", phone: "575-13-53", position: 1 },
  { name: "Gledališka in koncertna dvorana", kind: :branch, short_code: "NOE", phone: "577-60-24", position: 2 },
  { name: "Krajevna knjižnica Gaberje", kind: :mobile_library, short_code: "KK-Gaberje", schedule_info: "PON 12:00–16:00", position: 3 },
  { name: "Krajevna knjižnica Hotiza", kind: :mobile_library, short_code: "KK-Hotiza", schedule_info: "TOR 12:00–16:00", position: 4 },
  { name: "Krajevna knjižnica Petišovci", kind: :mobile_library, short_code: "KK-Petisovci", schedule_info: "SRE 12:00–16:00", position: 5 },
  { name: "Krajevna knjižnica Dolina", kind: :mobile_library, short_code: "KK-Dolina", schedule_info: "ČET 12:00–16:00", position: 6 },
  { name: "Krajevna knjižnica Genterovci", kind: :mobile_library, short_code: "KK-Genterovci", schedule_info: "PET 12:00–16:00", position: 7 }
]

lokacije.each do |attrs|
  loc = Location.find_or_initialize_by(name: attrs[:name])
  loc.assign_attributes(attrs)
  loc.save!
end
puts "  Lokacije: #{Location.count}"

puts "=== Seed: Telefonske številke lokacij ==="
siklnd = Location.find_by!(short_code: "SIKLND")
[
  { number: "575-13-53", kind: :external, label: "Centrala" },
  { number: "575-13-54", kind: :external, label: "Blagajna" },
  { number: "580", kind: :internal, label: "Interna" }
].each do |attrs|
  siklnd.phone_numbers.find_or_create_by!(label: attrs[:label]) do |pn|
    pn.number = attrs[:number]
    pn.kind = attrs[:kind]
  end
end
puts "  Telefonske številke: #{PhoneNumber.count}"

puts "=== Seed: Osebe v imeniku (vzorčni podatki) ==="
if Person.none?
  hq = Location.find_by!(short_code: "SIKLND")
  person = Person.create!(
    first_name: "Maja",
    last_name: "Novak",
    email: "maja.novak@kl-kl.si",
    position_title: "Direktorica",
    location: hq,
    active: true
  )
  person.phone_numbers.create!(number: "574-25-80", kind: :external)
  person.phone_numbers.create!(number: "581", kind: :internal)
  person.phone_numbers.create!(number: "040-123-456", kind: :mobile)
end
puts "  Osebe: #{Person.count}"

puts "=== Seed: Kategorije povezav ==="
kategorije_povezav = [
  { name: "Interne aplikacije", icon: "computer-desktop", position: 1 },
  { name: "COBISS", position: 2 },
  { name: "Geslovnik / UDK", position: 3 },
  { name: "NUK / IZUM", position: 4 },
  { name: "Slovenske knjižnice", position: 5 },
  { name: "Pravni viri", position: 6 },
  { name: "Občine", position: 7 },
  { name: "Drugo", position: 8 }
]

kategorije_povezav.each do |attrs|
  LinkCategory.find_or_create_by!(name: attrs[:name]) do |lc|
    lc.position = attrs[:position]
    lc.icon = attrs[:icon]
  end
end
puts "  Kategorije povezav: #{LinkCategory.count}"

puts "=== Seed: Povezave ==="
interne_apps = LinkCategory.find_by!(name: "Interne aplikacije")
povezave = [
  { title: "Prisotnost", url: "https://p.kl-kl.si", internal_app: true, category: interne_apps },
  { title: "Delovodnik", url: "https://d.kl-kl.si", internal_app: true, category: interne_apps },
  { title: "COBISS", url: "https://www.cobiss.si", category: LinkCategory.find_by!(name: "COBISS") },
  { title: "Uradni list RS", url: "https://www.uradni-list.si", category: LinkCategory.find_by!(name: "Pravni viri") },
  { title: "dlib.si", url: "https://www.dlib.si", category: LinkCategory.find_by!(name: "Drugo") }
]

povezave.each do |attrs|
  Link.find_or_create_by!(title: attrs[:title], link_category: attrs[:category]) do |l|
    l.url = attrs[:url]
    l.internal_app = attrs[:internal_app] || false
  end
end
puts "  Povezave: #{Link.count}"

puts "=== Seed: Kategorije dokumentov ==="
kategorije_dokumentov = [
  { name: "Interni akti", slug: "interni_akti", position: 1 },
  { name: "Obvestila za zaposlene", slug: "obvestila", position: 2 },
  { name: "Zapisniki sej sveta zavoda", slug: "zapisniki_ssz", position: 3 },
  { name: "Zapisniki sestankov delavcev - knjižnica", slug: "zapisniki_knjiznica", position: 4 },
  { name: "Zapisniki sestankov delavcev - NOE", slug: "zapisniki_noe", position: 5 },
  { name: "Pravilniki, navodila, ukrepi", slug: "pravilniki", position: 6 }
]

kategorije_dokumentov.each do |attrs|
  DocumentCategory.find_or_create_by!(slug: attrs[:slug]) do |dc|
    dc.name = attrs[:name]
    dc.position = attrs[:position]
  end
end
puts "  Kategorije dokumentov: #{DocumentCategory.count}"

puts "=== Seed končan ==="
