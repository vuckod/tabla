# frozen_string_literal: true

# Globalni iskalnik po dokumentih (Meilisearch + PostgreSQL fallback).
class SearchController < ApplicationController
  include SearchHelper

  SEARCH_RESULTS_PER_PAGE = Pagy::DEFAULT[:limit]

  def index
    @query = params[:q].to_s.strip
    @search_fallback = false
    @highlights_by_id = {}

    if @query.present?
      search_documents
    else
      @documents = Document.none
    end
  end

  private

  def search_documents
    search_with_meilisearch!
  rescue MeiliSearch::ApiError,
         Meilisearch::ApiError,
         Meilisearch::CommunicationError,
         Errno::ECONNREFUSED,
         SocketError,
         Timeout::Error => e
    Rails.logger.warn("[SearchController] Meilisearch unavailable, PostgreSQL fallback: #{e.class} - #{e.message}")
    @search_fallback = true
    search_with_postgresql!
  end

  def search_with_meilisearch!
    current_page = [params[:page].to_i, 1].max
    search_opts = {
      filter: build_meilisearch_security_filters,
      sort: ["published_at:desc"],
      page: current_page,
      hitsPerPage: SEARCH_RESULTS_PER_PAGE,
      attributesToHighlight: %w[title description ocr_text],
      highlightPreTag: SearchHelper::HIGHLIGHT_OPEN,
      highlightPostTag: SearchHelper::HIGHLIGHT_CLOSE
    }

    @search_results = Document.search(@query, search_opts)
    total_hits = meilisearch_total_hits(@search_results)
    @pagy = Pagy.new(
      count: total_hits,
      page: current_page,
      limit: SEARCH_RESULTS_PER_PAGE,
      request: request
    )

    result_ids = @search_results.map(&:id)
    @highlights_by_id = extract_meilisearch_highlights(@search_results)
    @documents = load_documents_defense_in_depth(result_ids)
  end

  def search_with_postgresql!
    scope = Document.visible_to(current_user).published.includes(:document_category)
    relation = UnaccentSearchable.where_terms_match(
      scope, @query, %w[documents.title documents.description documents.ocr_text]
    ).order(published_at: :desc)
    @pagy, @documents = pagy(relation)
  end

  # KRITIČNO: Meilisearch filter za bralce — internal_only dokumenti se ne smejo pojaviti.
  def build_meilisearch_security_filters
    filters = ["published = true"]
    unless current_user&.admin? || current_user&.urednik?
      filters << "internal_only = false"
    end
    filters.join(" AND ")
  end

  # Defense-in-depth: po Meilisearch zadetkih še enkrat preveri visible_to + published.
  def load_documents_defense_in_depth(result_ids)
    return Document.none if result_ids.empty?

    scope = Document.visible_to(current_user).published.includes(:document_category)
    loaded = scope.where(id: result_ids).index_by(&:id)
    result_ids.filter_map { |id| loaded[id] }
  end
end
