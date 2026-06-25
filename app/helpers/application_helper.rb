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
end
