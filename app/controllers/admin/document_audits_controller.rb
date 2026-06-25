# frozen_string_literal: true

module Admin
  class DocumentAuditsController < BaseController
    before_action :authorize_document_audits!

    def index
      audits = Audited::Audit.where(auditable_type: "Document")
                             .includes(:user, :auditable)
                             .order(created_at: :desc)

      start_time = parse_analytics_date_start(params[:start_date])
      end_time = parse_analytics_date_end(params[:end_date])

      if start_time && end_time && start_time > end_time
        flash.now[:alert] = t("views.admin.analytics.date_range_swapped")
        start_time, end_time = end_time, start_time
      end

      audits = audits.where("audits.created_at >= ?", start_time) if start_time
      audits = audits.where("audits.created_at <= ?", end_time) if end_time

      if params[:user_id].present?
        audits = audits.where(user_id: params[:user_id])
      end

      if params[:action_filter].present?
        audits = audits.where(action: params[:action_filter])
      end

      if params[:q].present?
        term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].strip)}%"
        document_ids = Document.where("title ILIKE ?", term).pluck(:id)
        audits = audits.where(auditable_id: document_ids)
      end

      @pagy, @audits = pagy(audits, limit: 50)
      @audit_model_class = Document
    end

    private

    def authorize_document_audits!
      authorize :document_audit
    end

    def parse_analytics_date_start(value)
      return nil if value.blank?

      Date.parse(value.to_s).in_time_zone.beginning_of_day
    rescue ArgumentError, TypeError
      nil
    end

    def parse_analytics_date_end(value)
      return nil if value.blank?

      Date.parse(value.to_s).in_time_zone.end_of_day
    rescue ArgumentError, TypeError
      nil
    end
  end
end
