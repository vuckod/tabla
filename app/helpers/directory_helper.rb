# frozen_string_literal: true

module DirectoryHelper
  def directory_tel_link(number)
    return content_tag(:span, "—", class: "text-slate-400 dark:text-slate-500") if number.blank?

    link_to number, "tel:#{number.gsub(/[^\d+]/, '')}",
            class: "text-slate-900 dark:text-slate-100 hover:text-indigo-700 dark:hover:text-indigo-300 underline-offset-2 hover:underline"
  end

  def directory_unit_badge(enota, unit_kind)
    return if enota.blank?

    classes = if unit_kind == "branch"
                "bg-purple-100 dark:bg-purple-900/50 text-purple-900 dark:text-purple-100"
              else
                "bg-amber-200/80 dark:bg-amber-900/50 text-amber-950 dark:text-amber-100"
              end

    content_tag(:span, enota,
                class: "inline-flex items-center px-2 py-0.5 rounded text-xs font-semibold #{classes}")
  end

  def directory_unit_heading(unit_kind, fallback_short_code)
    key = unit_kind.presence || "other"
    t("views.directory.unit_headings.#{key}", default: fallback_short_code.presence || t("views.directory.other_unit"))
  end
end
