# frozen_string_literal: true

module NavigationHelper
  def nav_documents_badge_html
    return unless current_user

    count = current_user.new_documents_count
    return if count.zero?

    label = count > 99 ? "99+" : count.to_s

    content_tag(:span,
      label,
      class: "ml-1 inline-flex items-center justify-center " \
             "min-w-[1.25rem] h-5 px-1.5 rounded-full " \
             "text-xs font-semibold text-white bg-red-600 dark:bg-red-500",
      aria: { label: t("views.layouts.header.new_documents_badge", count: count) })
  end
end
