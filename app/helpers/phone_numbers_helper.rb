# frozen_string_literal: true

module PhoneNumbersHelper
  PHONE_KIND_ICONS = {
    "external" => "📞",
    "internal" => "☎️",
    "mobile" => "📱",
    "fax" => "📠"
  }.freeze

  def phone_kind_icon(kind)
    PHONE_KIND_ICONS.fetch(kind.to_s, "📞")
  end

  def phone_kind_label(kind)
    t("phone_number.kinds.#{kind}")
  end

  def render_phone_number(phone_number)
    label = phone_number.label.presence || phone_kind_label(phone_number.kind)
    content_tag(:span, class: "inline-flex items-center gap-1 text-sm") do
      safe_join([
        content_tag(:span, phone_kind_icon(phone_number.kind), class: "shrink-0", aria: { hidden: true }),
        content_tag(:span, "#{label}:", class: "text-slate-500 dark:text-slate-400"),
        link_to(phone_number.number, "tel:#{phone_number.number.gsub(/[^\d+]/, '')}",
                class: "text-indigo-600 dark:text-indigo-400 hover:underline")
      ])
    end
  end

  def render_phone_numbers_list(phone_numbers)
    numbers = phone_numbers.sort_by { |pn| [PhoneNumber.kinds[pn.kind], pn.position, pn.number] }
    return tag.p(t("views.persons.no_phone_numbers"), class: "text-sm text-slate-500 dark:text-slate-400") if numbers.empty?

    content_tag(:div, class: "flex flex-col gap-1") do
      safe_join(numbers.map { |pn| render_phone_number(pn) })
    end
  end

  def location_kind_label(kind)
    t("location.kinds.#{kind}")
  end
end
