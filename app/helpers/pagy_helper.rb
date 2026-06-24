# Pagy helper za poglede
module PagyHelper
  include Pagy::Frontend

  PAGY_PAGE_BASE = "inline-flex items-center justify-center min-w-9 h-9 px-3 text-sm font-medium rounded-lg border transition-colors"
  PAGY_LINK_CLASSES = "#{PAGY_PAGE_BASE} border-slate-200 dark:border-slate-600 text-slate-700 dark:text-slate-300 " \
                      "bg-white dark:bg-slate-800 hover:bg-indigo-50 dark:hover:bg-slate-700 " \
                      "hover:border-indigo-300 dark:hover:border-indigo-700".freeze
  PAGY_CURRENT_CLASSES = "#{PAGY_PAGE_BASE} border-indigo-600 bg-indigo-600 text-white " \
                         "dark:bg-indigo-500 dark:border-indigo-500 cursor-default".freeze
  PAGY_GAP_CLASSES = "inline-flex items-center justify-center min-w-9 h-9 px-1 text-sm " \
                     "text-slate-500 dark:text-slate-400 select-none".freeze
  PAGY_NAV_BTN_CLASSES = "#{PAGY_PAGE_BASE} border-slate-200 dark:border-slate-600 text-slate-700 dark:text-slate-300 " \
                         "bg-white dark:bg-slate-800 hover:bg-slate-50 dark:hover:bg-slate-700".freeze
  PAGY_NAV_BTN_DISABLED_CLASSES = "#{PAGY_PAGE_BASE} border-slate-200 dark:border-slate-700 text-slate-300 " \
                                  "dark:text-slate-600 bg-slate-50 dark:bg-slate-900 cursor-not-allowed".freeze

  def pagy_nav_tailwind(pagy, turbo_frame: nil)
    render partial: "shared/pagination", locals: { pagy: pagy, turbo_frame: turbo_frame }
  end

  def pagy_turbo_data(turbo_frame)
    turbo_frame.present? ? { turbo_frame: turbo_frame } : {}
  end

  # Razredi izpostavljeni kot metode, ker konstante modula niso dostopne v partialu
  # prek golega imena (view ne vidi modulnih konstant kot lokalnih).
  def pagy_link_classes = PAGY_LINK_CLASSES
  def pagy_current_classes = PAGY_CURRENT_CLASSES
  def pagy_gap_classes = PAGY_GAP_CLASSES
  def pagy_nav_btn_classes = PAGY_NAV_BTN_CLASSES
  def pagy_nav_btn_disabled_classes = PAGY_NAV_BTN_DISABLED_CLASSES
end
