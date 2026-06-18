# Meilisearch — deljena instanca z Delovodnikom, ločeni indeksi
MeiliSearch::Rails.configuration = {
  meilisearch_url: ENV.fetch("MEILISEARCH_URL", "http://localhost:7700"),
  meilisearch_api_key: ENV.fetch("MEILISEARCH_MASTER_KEY", ""),
  timeout: 10,
  max_retries: 2
}
