# frozen_string_literal: true

module Admin
  class DocumentPopularityController < BaseController
    before_action :authorize_popularity!

    def index
      @range = parse_range(params[:range])
      base = DocumentView.where(viewed_at: @range)

      scope = Document
        .joins(:document_views)
        .where(document_views: { viewed_at: @range })
        .group("documents.id")
        .select("documents.*,
                 COUNT(document_views.id) AS views_count,
                 COUNT(DISTINCT document_views.user_id) AS unique_viewers_count,
                 MAX(document_views.viewed_at) AS last_viewed_at")
        .order(Arel.sql("COUNT(document_views.id) DESC"))

      document_count = Document.joins(:document_views)
                               .where(document_views: { viewed_at: @range })
                               .distinct
                               .count(:id)

      @pagy, @documents = pagy(scope, limit: 30, count: document_count)

      @total_views = base.count
      @total_unique_viewers = base.select(:user_id).distinct.count
      @range_param = params[:range].presence || "all"
    end

    private

    def authorize_popularity!
      authorize :document_popularity
    end

    def parse_range(input)
      case input
      when "week" then 1.week.ago..Time.current
      when "month" then 1.month.ago..Time.current
      else 100.years.ago..Time.current
      end
    end
  end
end
