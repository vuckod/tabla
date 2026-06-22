# frozen_string_literal: true

# Periodična sinhronizacija uporabnikov iz Prisotnosti (single source of truth).
# Poganja se prek Solid Queue recurring scheduler-ja — glej config/recurring.yml.
class UserSyncJob < ApplicationJob
  queue_as :default

  def perform
    api_users = PrisotnostApiClient.fetch_users
    if api_users.blank?
      Rails.logger.warn("[UserSyncJob] Prisotnost ni vrnila uporabnikov (morda ni dosegljiva).")
      return
    end

    Rails.logger.info("[UserSyncJob] Sinhronizacija #{api_users.size} uporabnikov...")

    api_users.each do |user_data|
      User.sync_from_api_data(user_data)
    rescue StandardError => e
      Rails.logger.error("[UserSyncJob] Napaka pri #{user_data['username']}: #{e.message}")
    end

    deactivate_missing_users(api_users)

    Rails.logger.info("[UserSyncJob] Sinhronizacija končana.")
  end

  private

  # Uporabnike, ki jih Prisotnost ne vrne več (odpuščeni, izbrisani), lokalno onemogoči.
  def deactivate_missing_users(api_users)
    active_remote_ids = api_users.map { |u| u["id"] }

    User.where.not(remote_id: active_remote_ids)
        .where(onemogocen: false)
        .update_all(onemogocen: true, updated_at: Time.current)
  end
end
