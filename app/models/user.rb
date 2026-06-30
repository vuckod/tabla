# frozen_string_literal: true

# Lokalni mirror uporabnikov iz Prisotnosti (single source of truth).
# Credentials se NIKOLI ne shranjujejo lokalno — vsaka prijava gre prek
# PrisotnostApiClient, ki preveri username/geslo na Prisotnosti.
class User < ApplicationRecord
  has_and_belongs_to_many :roles
  has_many :visits, class_name: "Ahoy::Visit", dependent: :nullify
  has_many :ahoy_events, class_name: "Ahoy::Event", dependent: :nullify
  has_many :document_views, dependent: :destroy
  has_many :bookmarks, dependent: :destroy
  has_many :bookmarked_documents, through: :bookmarks, source: :document

  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :remote_id, presence: true, uniqueness: true

  scope :active, -> { where(onemogocen: false) }
  scope :ordered, -> { order(:priimek, :ime) }

  # Prejemniki e-pošte za ciljno enoto dokumenta (uprava prejme obvestila obeh enot).
  scope :for_document_unit, ->(unit) {
    base = active.where.not(email: [nil, ""])
    case unit.to_s
    when "library"
      base.where(enota: %w[knjiznica uprava])
    when "theatre"
      base.where(enota: %w[gledalisce uprava])
    else
      base
    end
  }

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

  def recent_documents(limit: 5)
    Document
      .joins(:document_views)
      .where(document_views: { user_id: id })
      .group("documents.id")
      .select("documents.*, MAX(document_views.viewed_at) AS last_viewed_at")
      .order(Arel.sql("MAX(document_views.viewed_at) DESC"))
      .limit(limit)
  end

  def bookmarked?(document)
    bookmarks.exists?(document_id: document.id)
  end

  def bookmarked_documents_ordered
    Document.joins(:bookmarks)
            .where(bookmarks: { user_id: id })
            .published
            .visible_to(self)
            .for_user_enota(self)
            .includes(:document_category)
            .order(Arel.sql("bookmarks.created_at DESC"))
  end

  def new_documents_count
    return 0 unless last_documents_seen_at

    Rails.cache.fetch(new_documents_count_cache_key, expires_in: 1.minute) do
      new_documents_scope.count
    end
  end

  def mark_documents_as_seen!
    update_column(:last_documents_seen_at, Time.current)
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
      enota: user_data["enota"],
      onemogocen: user_data["onemogocen"] || false,
      last_synced_at: Time.current
    )
    user.last_documents_seen_at ||= Time.current
    user.save!
    sync_roles(user, user_data["roles"] || [])
    user
  end

  def self.sync_roles(user, role_names)
    intranet_roles = role_names.select { |r| r.start_with?("intranet_") }
    target_roles = Role.where("LOWER(name) IN (?)", intranet_roles.map(&:downcase))
    user.roles = target_roles
  end

  private

  def new_documents_scope
    Document.published
            .visible_to(self)
            .for_user_enota(self)
            .where("documents.created_at > ?", last_documents_seen_at)
  end

  def new_documents_count_cache_key
    "user_new_docs_count_#{id}_#{last_documents_seen_at.to_i}"
  end
end
