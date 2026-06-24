# frozen_string_literal: true

module Admin
  class AnnouncementsController < BaseController
    before_action :set_announcement, only: %i[edit update destroy]
    before_action :authorize_announcement!

    def index
      @announcements = policy_scope(Announcement).recent
    end

    def new
      @announcement = Announcement.new(published_at: Time.current)
    end

    def create
      @announcement = Announcement.new(announcement_params)
      if @announcement.save
        redirect_to admin_announcements_path, notice: t("views.admin.announcements.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @announcement.update(announcement_params)
        redirect_to admin_announcements_path, notice: t("views.admin.announcements.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @announcement.destroy
      redirect_to admin_announcements_path, notice: t("views.admin.announcements.destroyed")
    end

    private

    def set_announcement
      @announcement = Announcement.find(params[:id])
    end

    def authorize_announcement!
      authorize(@announcement || Announcement)
    end

    def announcement_params
      params.require(:announcement).permit(
        :title, :body, :unit, :published_at, :expires_at, :pinned
      )
    end
  end
end
