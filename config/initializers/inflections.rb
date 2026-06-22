# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format. Inflections
# are locale specific, and you may define rules for as many different
# locales as you wish. All of these examples are active by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.plural /^(ox)$/i, "\\1en"
#   inflect.singular /^(ox)en/i, "\\1"
#   inflect.irregular "person", "people"
#   inflect.uncountable %w( fish sheep )
# end

# These inflection rules are supported but not enabled by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.acronym "RESTful"
# end

# Tabla: model Person ima namensko tabelo "persons" (ne Rails-ovo privzeto
# nepravilno množino "people"), da se ujema z routes.rb (`resources :persons`)
# in vsemi route helperji (`persons_path`, `admin_persons_path`, ...).
# Brez tega pravila Rails generira `admin_people_path`, ki ne obstaja.
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.irregular "person", "persons"
end
