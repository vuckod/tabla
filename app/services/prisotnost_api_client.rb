# frozen_string_literal: true

# HTTP klient za komunikacijo s Prisotnost API-jem (single source of truth za uporabnike).
# Glej: docs/02_authentication_api.md
class PrisotnostApiClient
  BASE_URL = ENV.fetch("PRISOTNOST_API_URL", "http://localhost:3000/api/v1")
  TOKEN = ENV.fetch("PRISOTNOST_API_TOKEN", "")

  class ConnectionError < StandardError; end

  class << self
    # Preveri credentials uporabnika prek Prisotnosti.
    # Vrne hash z uporabniškimi podatki (string keys) ali nil, če so credentials napačni.
    # Vrže ConnectionError, če Prisotnost ni dosegljiva.
    def authenticate(username, password)
      response = connection.post("authenticate") do |req|
        req.body = { username: username, password: password }
      end

      return nil unless response.status == 200

      response.body["user"]
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
      Rails.logger.error("[PrisotnostApiClient] Connection failed: #{e.message}")
      raise ConnectionError, "Prisotnost ni dosegljiva. Poskusite znova čez trenutek."
    end

    # Pridobi seznam vseh aktivnih uporabnikov (za periodično sinhronizacijo).
    # Vrne prazen array, če Prisotnost ni dosegljiva (ne vrže napake — sync job naj samo poskusi pozneje).
    def fetch_users
      response = connection.get("users")

      return [] unless response.status == 200

      response.body["users"] || []
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
      Rails.logger.error("[PrisotnostApiClient] Connection failed: #{e.message}")
      []
    end

    private

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.response :json, content_type: /\bjson$/
        f.headers["Authorization"] = "Bearer #{TOKEN}"
        f.options.timeout = 10
        f.options.open_timeout = 5
        f.adapter Faraday.default_adapter
      end
    end
  end
end
