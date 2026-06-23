# Audited — revizijska sled (enako kot v Delovodniku)
Audited.current_user_method = :current_user

# Audited privzeto serializira spremembe atributov (audited_changes) v YAML prek
# ActiveRecord::Coders::YAMLColumn, ki uporablja Psych.safe_load. Psych 4+ privzeto
# zavrne razrede, ki niso na "dovoljenem" seznamu — ActiveSupport::TimeWithZone
# (tip, ki ga npr. datetime_local_field vrača za published_at) ni privzeto dovoljen,
# kar povzroči Psych::DisallowedClass napako ob shranjevanju audit zapisa.
Rails.application.config.active_record.yaml_column_permitted_classes ||= []
Rails.application.config.active_record.yaml_column_permitted_classes |= [
  ActiveSupport::TimeWithZone,
  ActiveSupport::TimeZone,
  Time,
  Date,
  DateTime,
  Symbol,
  BigDecimal
]
