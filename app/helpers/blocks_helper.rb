# frozen_string_literal: true

# Barvna ogrodja za živahne bloke na domači strani (docs/04_ui_design.md).
module BlocksHelper
  BLOCK_COLORS = {
    yellow: {
      header: "bg-yellow-500 dark:bg-yellow-600 text-slate-900",
      body: "bg-yellow-100 dark:bg-yellow-900/30 text-slate-900 dark:text-slate-100"
    },
    green: {
      header: "bg-green-600 dark:bg-green-700 text-white",
      body: "bg-green-50 dark:bg-green-900/30 text-slate-900 dark:text-slate-100"
    },
    blue: {
      header: "bg-blue-600 dark:bg-blue-700 text-white",
      body: "bg-blue-50 dark:bg-blue-900/30 text-slate-900 dark:text-slate-100"
    },
    teal: {
      header: "bg-teal-600 dark:bg-teal-700 text-white",
      body: "bg-teal-50 dark:bg-teal-900/30 text-slate-900 dark:text-slate-100"
    },
    red: {
      header: "bg-red-600 dark:bg-red-700 text-white",
      body: "bg-red-50 dark:bg-red-900/30 text-slate-900 dark:text-slate-100"
    },
    amber: {
      header: "bg-amber-500 dark:bg-amber-600 text-slate-900",
      body: "bg-amber-100 dark:bg-amber-900/30 text-slate-900 dark:text-slate-100"
    },
    indigo: {
      header: "bg-indigo-600 dark:bg-indigo-700 text-white",
      body: "bg-indigo-50 dark:bg-indigo-900/30 text-slate-900 dark:text-slate-100"
    }
  }.freeze

  def block_header_classes(color)
    BLOCK_COLORS.fetch(color.to_sym)[:header]
  end

  def block_body_classes(color)
    BLOCK_COLORS.fetch(color.to_sym)[:body]
  end

  def page_container_classes
    "mx-auto w-[95%] xl:w-[90%] max-w-[1800px] px-2 sm:px-4"
  end
end
