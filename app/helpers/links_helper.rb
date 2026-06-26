# frozen_string_literal: true

module LinksHelper
  def link_item_classes(link, variant: :default)
    base = "block rounded-lg transition-colors print:break-inside-avoid"

    if link.internal_app?
      internal = "bg-indigo-50 dark:bg-indigo-900/30 text-indigo-900 dark:text-indigo-100 " \
                 "border border-indigo-200 dark:border-indigo-700 font-medium " \
                 "hover:bg-indigo-100 dark:hover:bg-indigo-900/50"
      variant == :compact ? "#{base} #{internal} px-4 py-3" : "#{base} #{internal} px-3 py-2.5"
    else
      standard = "text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700/50 " \
                 "hover:text-indigo-600 dark:hover:text-indigo-400"
      variant == :compact ? "#{base} #{standard} px-3 py-2" : "#{base} #{standard} px-3 py-2"
    end
  end

  def link_to_entry(link, variant: :default)
    options = { class: link_item_classes(link, variant: variant) }
    if link.new_tab?
      options[:target] = "_blank"
      options[:rel] = "noopener noreferrer"
    end

    link_to link.url, options do
      if link.internal_app?
        content_tag(:span, class: "inline-flex items-center gap-2") do
          safe_join([
            content_tag(:span, "🏠", class: "shrink-0", aria: { hidden: true }),
            content_tag(:span, link.title)
          ])
        end
      elsif link.description.present?
        safe_join([
          content_tag(:span, link.title),
          content_tag(:span, link.description,
                      class: "block text-xs text-slate-500 dark:text-slate-400 mt-0.5 font-normal")
        ])
      else
        link.title
      end
    end
  end

  def link_to_internal_block(link)
    options = {
      class: "block rounded-lg px-3 py-2.5 text-sm font-semibold " \
             "bg-white/85 dark:bg-slate-900/50 text-slate-900 dark:text-slate-100 " \
             "border border-green-700/20 dark:border-green-500/30 shadow-sm " \
             "hover:bg-white dark:hover:bg-slate-900/70 transition-colors"
    }
    if link.new_tab?
      options[:target] = "_blank"
      options[:rel] = "noopener noreferrer"
    end

    link_to link.url, options do
      content_tag(:span, class: "inline-flex items-center gap-2") do
        safe_join([
          content_tag(:span, "🏠", class: "shrink-0", aria: { hidden: true }),
          content_tag(:span, link.title, class: "leading-snug")
        ])
      end
    end
  end

  def link_to_external_block(link)
    link_to link.title, link.url,
            class: "block text-xs leading-tight truncate text-slate-900 dark:text-slate-100 " \
                   "hover:text-teal-800 dark:hover:text-teal-300 hover:underline",
            title: link.title,
            target: "_blank",
            rel: "noopener noreferrer"
  end
end
