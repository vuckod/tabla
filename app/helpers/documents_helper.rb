# frozen_string_literal: true

module DocumentsHelper
  def document_category_badge(category)
    content_tag(:span, category.name,
                class: "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium " \
                       "bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-200")
  end

  def document_tab_class(selected_id, category_id = nil)
    active = selected_id.to_s == category_id.to_s
    base = "px-4 py-2 text-sm font-medium rounded-t-lg border-b-2 transition-colors whitespace-nowrap"
    if active
      "#{base} border-indigo-600 text-indigo-600 dark:border-indigo-400 dark:text-indigo-400 bg-white dark:bg-slate-900"
    else
      "#{base} border-transparent text-slate-600 dark:text-slate-400 hover:text-indigo-600 dark:hover:text-indigo-400 hover:border-slate-300"
    end
  end

  def format_published_at(document)
    return t("views.documents.unpublished") unless document.published_at

    l(document.published_at.to_date, format: :long)
  end
end
