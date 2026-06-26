module ApplicationHelper
  include PagyHelper
  include BlocksHelper
  include DirectoryHelper
  include AdminFormHelper
  include SearchHelper
  include AuditHistoryHelper

  def turbo_frame_request?
    request.headers["Turbo-Frame"].present?
  end

  # Povezava na dinamični manifest (rails/pwa#manifest).
  def pwa_manifest
    tag.link(rel: "manifest", href: pwa_manifest_path(format: :json))
  end

  def nav_link_active?(path)
    case path
    when root_path
      current_page?(root_path)
    when admin_root_path
      controller_path.start_with?("admin/")
    else
      current_page?(path) || request.path.start_with?("#{path}/")
    end
  end

  def main_nav_link(path, mobile: false, **options, &block)
    active = nav_link_active?(path)
    base_class = if mobile
      "flex items-center gap-2 px-3 py-2 rounded-md text-base font-medium transition-colors"
    else
      "flex items-center gap-2 px-3 py-2 rounded-md text-sm font-medium transition-colors"
    end
    active_class = if active
      "bg-indigo-100 dark:bg-indigo-900/40 text-indigo-700 dark:text-indigo-200"
    else
      "text-slate-600 dark:text-slate-300 hover:text-indigo-600 dark:hover:text-indigo-400 hover:bg-slate-100 dark:hover:bg-slate-800"
    end

    link_to path,
            class: [base_class, active_class, options[:class]].compact.join(" "),
            aria: active ? { current: "page" } : {},
            &block
  end
end
