# frozen_string_literal: true

module DocumentsHelper
  CATEGORY_COLORS = %i[red amber orange blue green purple slate indigo].freeze

  CATEGORY_COLOR_CLASSES = {
    red: "bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-200",
    amber: "bg-amber-100 text-amber-900 dark:bg-amber-900/40 dark:text-amber-200",
    orange: "bg-orange-100 text-orange-900 dark:bg-orange-900/40 dark:text-orange-200",
    blue: "bg-blue-100 text-blue-800 dark:bg-blue-900/40 dark:text-blue-200",
    green: "bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-200",
    purple: "bg-purple-100 text-purple-800 dark:bg-purple-900/40 dark:text-purple-200",
    slate: "bg-slate-100 text-slate-800 dark:bg-slate-700 dark:text-slate-200",
    indigo: "bg-indigo-100 text-indigo-800 dark:bg-indigo-900/40 dark:text-indigo-200"
  }.freeze

  CATEGORY_SWATCH_CLASSES = {
    red: "bg-red-500",
    amber: "bg-amber-500",
    orange: "bg-orange-500",
    blue: "bg-blue-500",
    green: "bg-green-500",
    purple: "bg-purple-500",
    slate: "bg-slate-500",
    indigo: "bg-indigo-500"
  }.freeze

  def category_badge(category)
    content_tag(:span, category.name,
                class: "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium #{category_color_classes(category.color)}")
  end
  alias document_category_badge category_badge

  def category_filter_chip(category, selected_category_id, url)
    active = selected_category_id.to_s == category.id.to_s
    classes = "#{category_color_classes(category.color)} inline-flex items-center px-3 py-1 rounded-full text-xs font-medium transition-opacity hover:opacity-90"
    classes += " ring-2 ring-offset-1 ring-slate-900/20 dark:ring-white/30 font-semibold" if active

    link_to category.name, url,
            class: classes,
            data: { turbo_frame: "documents_list" },
            aria: { current: active }
  end

  def category_filter_all_chip(selected_category_id, url)
    active = selected_category_id.blank?
    classes = "inline-flex items-center px-3 py-1 rounded-full text-xs font-medium " \
              "bg-slate-200 text-slate-800 dark:bg-slate-700 dark:text-slate-200 transition-opacity hover:opacity-90"
    classes += " ring-2 ring-offset-1 ring-indigo-500 font-semibold" if active

    link_to t("views.documents.all"), url,
            class: classes,
            data: { turbo_frame: "documents_list" },
            aria: { current: active }
  end

  def documents_filter_url(filter_base, category_id = nil)
    case filter_base.to_sym
    when :home
      category_id ? root_path(category_id: category_id) : root_path
    else
      category_id ? documents_path(category_id: category_id) : documents_path
    end
  end

  def format_published_at(document)
    return t("views.documents.unpublished") unless document.published_at

    l(document.published_at.to_date, format: :long)
  end

  def document_preview_text_badge(document)
    if document.searchable_pdf_available?
      ocr_status_badge(t("views.documents.preview_searchable_text"), :green)
    else
      ocr_status_badge(t("views.documents.preview_text_pending"), :amber)
    end
  end

  def document_ocr_status_badge(document)
    log = document.ocr_logs.max_by(&:started_at)
    return ocr_status_badge(t("views.admin.documents.ocr_none"), :slate) unless log

    case log.status
    when "processing"
      ocr_status_badge(t("views.admin.documents.ocr_processing"), :amber)
    when "success"
      ocr_status_badge(t("views.admin.documents.ocr_success"), :green)
    when "error"
      ocr_status_badge(t("views.admin.documents.ocr_error"), :red, title: log.error_message)
    else
      ocr_status_badge(log.status, :slate)
    end
  end

  def category_color_label(color)
    t("views.admin.document_categories.colors.#{color}", default: color.to_s.humanize)
  end

  def category_swatch_classes(color)
    CATEGORY_SWATCH_CLASSES.fetch(color.to_s.presence&.to_sym, CATEGORY_SWATCH_CLASSES[:slate])
  end

  private

  def ocr_status_badge(label, color, title: nil)
    classes = CATEGORY_COLOR_CLASSES.fetch(color, CATEGORY_COLOR_CLASSES[:slate])
    options = { class: "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium #{classes}" }
    options[:title] = title if title.present?

    content_tag(:span, label, **options)
  end

  def category_color_classes(color)
    CATEGORY_COLOR_CLASSES.fetch(color.to_s.presence&.to_sym, CATEGORY_COLOR_CLASSES[:slate])
  end
end
