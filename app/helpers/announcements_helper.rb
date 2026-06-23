# frozen_string_literal: true

module AnnouncementsHelper
  def announcement_unit_label(unit)
    t("announcement.units.#{unit}")
  end

  def announcement_unit_badge(unit)
    content_tag(:span, announcement_unit_label(unit),
                class: "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium " \
                       "bg-amber-100 dark:bg-amber-900/40 text-amber-800 dark:text-amber-200")
  end

  def announcement_status_badge(announcement)
    if announcement.pinned?
      content_tag(:span, t("views.admin.announcements.pinned"),
                  class: "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium " \
                         "bg-indigo-100 dark:bg-indigo-900/40 text-indigo-800 dark:text-indigo-200")
    elsif announcement.expires_at.present? && announcement.expires_at < Time.current
      content_tag(:span, t("views.admin.announcements.expired"),
                  class: "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium " \
                         "bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300")
    elsif announcement.published_at > Time.current
      content_tag(:span, t("views.admin.announcements.scheduled"),
                  class: "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium " \
                         "bg-amber-100 dark:bg-amber-900/40 text-amber-800 dark:text-amber-200")
    else
      content_tag(:span, t("views.admin.announcements.active"),
                  class: "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium " \
                         "bg-green-100 dark:bg-green-900/40 text-green-800 dark:text-green-200")
    end
  end
end
