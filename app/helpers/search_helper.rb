# frozen_string_literal: true

module SearchHelper
  HIGHLIGHT_OPEN = '<mark class="bg-yellow-200 dark:bg-yellow-800/60 rounded px-0.5">'
  HIGHLIGHT_CLOSE = "</mark>"

  def search_highlight_snippet(formatted_hit)
    return if formatted_hit.blank?

    formatted_hit["ocr_text"].presence ||
      formatted_hit["description"].presence ||
      formatted_hit["title"].presence
  end

  def extract_meilisearch_highlights(search_results)
    (search_results.raw_answer["hits"] || []).each_with_object({}) do |hit, memo|
      formatted = hit["_formatted"]
      next if formatted.blank?

      memo[hit["id"].to_i] = formatted
    end
  end

  def meilisearch_total_hits(search_results)
    raw = search_results.raw_answer
    raw["totalHits"] || raw["estimatedTotalHits"] || search_results.try(:count) || 0
  end
end
