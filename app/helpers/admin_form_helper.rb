# frozen_string_literal: true

# Skupni helperji za konsistenten videz admin obrazcev.
module AdminFormHelper
  FIELD_CLASSES = "w-full rounded-md border-slate-300 dark:border-slate-600 dark:bg-slate-700 " \
                  "dark:text-slate-100 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
  LABEL_CLASSES = "block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
  HINT_CLASSES = "mt-1 text-xs text-slate-500 dark:text-slate-400"
  ERROR_CLASSES = "mt-1 text-xs text-red-600 dark:text-red-400"
  CHECKBOX_CLASSES = "mt-1 rounded border-slate-300 dark:border-slate-600 text-indigo-600 focus:ring-indigo-500"
  SUBMIT_CLASSES = "px-4 py-2 bg-indigo-600 dark:bg-indigo-500 text-white text-sm font-medium rounded-md " \
                   "hover:bg-indigo-700 dark:hover:bg-indigo-600 shadow-sm cursor-pointer"
  CANCEL_CLASSES = "inline-flex items-center justify-center px-4 py-2 text-sm font-medium rounded-md " \
                   "border border-slate-300 dark:border-slate-600 text-slate-700 dark:text-slate-300 " \
                   "bg-white dark:bg-slate-800 hover:bg-slate-50 dark:hover:bg-slate-700"

  def admin_text_field(form, field, label:, hint: nil, input: :text_field, **options)
    admin_field(form, field, label: label, hint: hint) do
      form.public_send(input, field, { class: FIELD_CLASSES }.merge(options))
    end
  end

  def admin_text_area(form, field, label:, rows: 4, hint: nil, **options)
    admin_field(form, field, label: label, hint: hint) do
      form.text_area(field, { rows: rows, class: FIELD_CLASSES }.merge(options))
    end
  end

  def admin_select(form, field, choices = nil, label:, hint: nil, include_blank: false,
                   collection: nil, value_method: :id, text_method: :name, **options)
    admin_field(form, field, label: label, hint: hint) do
      html_options = { class: FIELD_CLASSES }.merge(options)
      select_options = { include_blank: include_blank }

      if collection
        form.collection_select(field, collection, value_method, text_method, select_options, html_options)
      else
        form.select(field, choices, select_options, html_options)
      end
    end
  end

  def admin_checkbox(form, field, label:, hint: nil, **options)
    content_tag(:div, class: "space-y-1") do
      safe_join([
        content_tag(:div, class: "flex items-start gap-3") do
          safe_join([
            form.check_box(field, { class: CHECKBOX_CLASSES }.merge(options)),
            form.label(field, label, class: "text-sm font-medium text-slate-700 dark:text-slate-300")
          ])
        end,
        (hint.present? ? content_tag(:p, hint, class: HINT_CLASSES) : nil),
        admin_field_errors(form, field)
      ].compact)
    end
  end

  def admin_datetime_field(form, field, label:, hint: nil, **options)
    admin_field(form, field, label: label, hint: hint) do
      form.datetime_local_field(field, { class: FIELD_CLASSES }.merge(options))
    end
  end

  def admin_file_field(form, field, label:, hint: nil, accept: nil, **options)
    file_classes = "block w-full text-sm text-slate-600 dark:text-slate-300 " \
                   "file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 " \
                   "file:text-sm file:font-medium file:bg-indigo-50 file:text-indigo-700 " \
                   "dark:file:bg-indigo-900/30 dark:file:text-indigo-300 " \
                   "hover:file:bg-indigo-100 dark:hover:file:bg-indigo-900/50"

    admin_field(form, field, label: label, hint: hint) do
      form.file_field(field, { accept: accept, class: file_classes }.merge(options))
    end
  end

  def admin_submit(form, label: nil)
    form.submit(label, class: SUBMIT_CLASSES)
  end

  def admin_cancel_link(path)
    link_to t("views.admin.shared.cancel"), path, class: CANCEL_CLASSES
  end

  def admin_color_picker(form, field, label:, hint: nil)
    selected = form.object.public_send(field).to_s.presence || "slate"

    content_tag(:div, class: "space-y-1") do
      safe_join([
        form.label(field, label, class: LABEL_CLASSES),
        content_tag(:div, class: "flex flex-wrap gap-3", role: "radiogroup", aria: { label: label }) do
          safe_join(DocumentsHelper::CATEGORY_COLORS.map do |color|
            admin_color_option(form, field, color, selected)
          end)
        end,
        (hint.present? ? content_tag(:p, hint, class: HINT_CLASSES) : nil),
        admin_field_errors(form, field)
      ].compact)
    end
  end

  def admin_icon_picker(form, field, label:, hint: nil)
    selected = form.object.public_send(field).to_s

    content_tag(:div, class: "space-y-1") do
      safe_join([
        form.label(field, label, class: LABEL_CLASSES),
        content_tag(:div, class: "flex flex-wrap gap-2", role: "radiogroup", aria: { label: label }) do
          safe_join(
            [admin_icon_option(form, field, nil, selected)] +
            IconHelper::ICONS.keys.map { |name| admin_icon_option(form, field, name, selected) }
          )
        end,
        (hint.present? ? content_tag(:p, hint, class: HINT_CLASSES) : nil),
        admin_field_errors(form, field)
      ].compact)
    end
  end

  private

  def admin_color_option(form, field, color, selected)
    checked = selected == color.to_s
    ring_classes = if checked
                     "ring-2 ring-offset-2 ring-indigo-500 dark:ring-offset-slate-800"
                   else
                     "hover:ring-2 hover:ring-offset-2 hover:ring-slate-300 dark:hover:ring-slate-600 dark:hover:ring-offset-slate-800"
                   end

    content_tag(:label, class: "cursor-pointer") do
      safe_join([
        form.radio_button(field, color, class: "sr-only", checked: checked),
        content_tag(:span, "",
                    class: "block w-9 h-9 rounded-full #{category_swatch_classes(color)} #{ring_classes}",
                    title: category_color_label(color),
                    aria: { hidden: true })
      ])
    end
  end

  def admin_icon_option(form, field, name, selected)
    checked = selected == name.to_s
    label_text = name.nil? ? "Brez ikone" : name.tr("-", " ").capitalize
    box_classes = "flex items-center justify-center w-10 h-10 rounded-md border " \
                  "text-slate-600 dark:text-slate-300"
    box_classes += if checked
                     " border-indigo-500 ring-2 ring-indigo-500 bg-indigo-50 dark:bg-indigo-900/30"
                   else
                     " border-slate-300 dark:border-slate-600 hover:border-indigo-300 dark:hover:border-indigo-600"
                   end

    content_tag(:label, class: "cursor-pointer", title: label_text) do
      safe_join([
        form.radio_button(field, name.to_s, class: "sr-only", checked: checked),
        content_tag(:span, class: box_classes, aria: { hidden: true }) do
          name.nil? ? content_tag(:span, "—", class: "text-xs") : icon_svg(name, css_class: "h-5 w-5")
        end
      ])
    end
  end

  def admin_field(form, field, label:, hint: nil, &block)
    content_tag(:div, class: "space-y-1") do
      safe_join([
        form.label(field, label, class: LABEL_CLASSES),
        capture(&block),
        (hint.present? ? content_tag(:p, hint, class: HINT_CLASSES) : nil),
        admin_field_errors(form, field)
      ].compact)
    end
  end

  def admin_field_errors(form, field)
    return unless form.object.errors[field].any?

    content_tag(:p, form.object.errors[field].first, class: ERROR_CLASSES)
  end
end
