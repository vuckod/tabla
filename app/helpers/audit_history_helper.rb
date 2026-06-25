# frozen_string_literal: true

module AuditHistoryHelper
  def audit_revision_heading(audit)
    when_s = audit.created_at.present? ? audit.created_at.in_time_zone.strftime("%d.%m.%Y %H:%M") : "—"
    who = audit_user_display(audit)
    action_label = audit_action_label(audit.action)
    [h(when_s), h(who), h(action_label)].join(" · ").html_safe
  end

  def audit_revision_change_lines(audit, model_class)
    changes = audit.audited_changes
    return [tag.em(t("views.admin.audit.no_changes"), class: "text-slate-400 dark:text-slate-500")] if changes.blank?

    case audit.action
    when "create"
      changes.map do |attr, value|
        tag.p(class: "text-sm text-slate-700 dark:text-slate-300") do
          safe_join(
            [
              tag.span("#{audit_attr_label(model_class, attr)}: ", class: "font-medium text-slate-600 dark:text-slate-400"),
              h(audit_raw_value(model_class, attr, value))
            ],
            ""
          )
        end
      end
    when "update"
      changes.map do |attr, pair|
        old_v, new_v = Array(pair)
        tag.p(class: "text-sm text-slate-700 dark:text-slate-300") do
          safe_join(
            [
              tag.span("#{audit_attr_label(model_class, attr)}: ", class: "font-medium text-slate-600 dark:text-slate-400"),
              h(audit_raw_value(model_class, attr, old_v)),
              " → ",
              h(audit_raw_value(model_class, attr, new_v))
            ],
            ""
          )
        end
      end
    when "destroy"
      [tag.p(t("views.admin.audit.record_destroyed"), class: "text-sm text-slate-700 dark:text-slate-300")]
    else
      [tag.p(audit.action.to_s, class: "text-sm text-slate-700 dark:text-slate-300")]
    end
  end

  def audit_change_summary(audit, model_class)
    lines = audit_revision_change_lines(audit, model_class)
    return t("views.admin.audit.no_changes") if lines.blank?

    lines.map { |line| strip_tags(line) }.join(" ").squish.truncate(120)
  end

  def audit_action_label(action)
    case action.to_s
    when "create" then t("views.admin.audit.actions.create")
    when "update" then t("views.admin.audit.actions.update")
    when "destroy" then t("views.admin.audit.actions.destroy")
    else action.to_s.humanize
    end
  end

  private

  def audit_user_display(audit)
    user = audit.user
    if user.respond_to?(:polno_ime) && user.polno_ime.present?
      user.polno_ime
    elsif audit.username.present?
      audit.username
    else
      "—"
    end
  end

  def audit_attr_label(model_class, attr)
    model_class.human_attribute_name(attr, default: attr.to_s.humanize)
  end

  def audit_raw_value(model_class, attr, value)
    return "—" if value.nil?

    attr_s = attr.to_s

    if model_class.respond_to?(:defined_enums) && model_class.defined_enums[attr_s]
      return enum_label(model_class, attr_s, value)
    end

    case value
    when true then t("views.admin.audit.boolean_yes")
    when false then t("views.admin.audit.boolean_no")
    when Time, DateTime, ActiveSupport::TimeWithZone
      value.in_time_zone.strftime("%d.%m.%Y %H:%M")
    when Date
      value.strftime("%d.%m.%Y")
    when Array
      value.map { |v| v.nil? ? "—" : v.to_s }.join(", ").presence || "—"
    when Hash
      value.to_json
    else
      value.to_s.presence || "—"
    end
  end

  def enum_label(model_class, attr_s, value)
    mapping = model_class.defined_enums[attr_s]
    key = resolve_enum_key(mapping, value)

    if key
      i18n_key = "activerecord.enums.#{model_class.model_name.i18n_key}.#{attr_s}.#{key}"
      return I18n.t(i18n_key) if I18n.exists?(i18n_key)

      return key.to_s.tr("_", " ").humanize
    end

    value.to_s
  end

  def resolve_enum_key(mapping, value)
    return nil if mapping.blank?

    case value
    when Integer
      mapping.key(value)
    when String
      return value if mapping.key?(value)

      mapping.key(value.to_i) if value.match?(/\A-?\d+\z/)
    end
  end
end
