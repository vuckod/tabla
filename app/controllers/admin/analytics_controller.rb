# frozen_string_literal: true

module Admin
  class AnalyticsController < BaseController
    before_action :authorize_analytics!

    def index
      visits = Ahoy::Visit.includes(:user).order(started_at: :desc)
      events = Ahoy::Event.eager_load(:user, :visit).order(time: :desc)

      start_time = parse_analytics_date_start(params[:start_date])
      end_time = parse_analytics_date_end(params[:end_date])

      if start_time && end_time && start_time > end_time
        flash.now[:alert] = t("views.admin.analytics.date_range_swapped")
        start_time, end_time = end_time, start_time
      end

      visits = visits.where("started_at >= ?", start_time) if start_time
      visits = visits.where("started_at <= ?", end_time) if end_time

      events = events.where("time >= ?", start_time) if start_time
      events = events.where("time <= ?", end_time) if end_time

      if params[:user_id].present?
        visits = visits.where(user_id: params[:user_id])
        events = events.where(user_id: params[:user_id])
      end

      if params[:ip].present?
        ip = "%#{ActiveRecord::Base.sanitize_sql_like(params[:ip].strip)}%"
        visits = visits.where("ip ILIKE ?", ip)
        events = events.where("ahoy_visits.ip ILIKE ?", ip)
      end

      if params[:q].present?
        term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].strip)}%"
        visits = visits.where(
          "ahoy_visits.ip ILIKE :t OR ahoy_visits.os ILIKE :t OR ahoy_visits.browser ILIKE :t OR ahoy_visits.user_agent ILIKE :t OR users.username ILIKE :t OR users.ime ILIKE :t OR users.priimek ILIKE :t",
          t: term
        ).references(:user)
        events = events.where(
          "ahoy_events.name ILIKE :t OR ahoy_events.properties::text ILIKE :t OR users.username ILIKE :t OR users.ime ILIKE :t OR users.priimek ILIKE :t OR ahoy_visits.ip ILIKE :t OR ahoy_visits.os ILIKE :t OR ahoy_visits.browser ILIKE :t",
          t: term
        )
      end

      @os_stats = visits.reorder(nil).group(:os).count
      @pagy_visits, @zadnji_obiski = pagy(visits, page_param: :page_obiski, limit: 50)
      @pagy_events, @zadnji_dogodki = pagy(events, page_param: :page_ogledi, limit: 50)
    end

    private

    def authorize_analytics!
      authorize :analytics
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
