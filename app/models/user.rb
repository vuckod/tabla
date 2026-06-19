# frozen_string_literal: true

# Lokalni mirror uporabnikov iz Prisotnosti (single source of truth).
# Credentials se NIKOLI ne shranjujejo lokalno — vsaka prijava gre prek
# PrisotnostApiClient, ki preveri username/geslo na Prisotnosti.
class User < ApplicationRecord
  has_and_belongs_to_many :roles
  has_many :visits, class_name: "Ahoy::Visit", dependent: :nullify
  has_many :ahoy_events, class_name: "Ahoy::Event", dependent: :nullify

  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :remote_id, presence: true, uniqueness: true

  scope :active, -> { where(onemogocen: false) }
  scope :ordered, -> { order(:priimek, :ime) }

  def polno_ime
    "#{ime} #{priimek}".strip
  end

  def role_symbols
    (roles || []).map { |r| r.name.underscore.to_sym }
  end

  def has_role?(role_sym)
    role_symbols.include?(role_sym.to_sym)
  end

  def admin?
    has_role?(:intranet_admin)
  end

  def urednik?
    has_role?(:intranet_urednik)
  end

  def bralec?
    !admin? && !urednik?
  end

  # Ustvari ali posodobi lokalni zapis na podlagi podatkov iz Prisotnost API-ja.
  # user_data: { "id", "username", "ime", "priimek", "email", "onemogocen", "roles" => [...] }
  def self.sync_from_api_data(user_data)
    user = find_or_initialize_by(remote_id: user_data["id"])
    user.assign_attributes(
      username: user_data["username"],
      ime: user_data["ime"],
      priimek: user_data["priimek"],
      email: user_data["email"],
      onemogocen: user_data["onemogocen"] || false,
      last_synced_at: Time.current
    )
    user.save!
    sync_roles(user, user_data["roles"] || [])
    user
  end

  def self.sync_roles(user, role_names)
    intranet_roles = role_names.select { |r| r.start_with?("intranet_") }
    target_roles = Role.where("LOWER(name) IN (?)", intranet_roles.map(&:downcase))
    user.roles = target_roles
  end
end
