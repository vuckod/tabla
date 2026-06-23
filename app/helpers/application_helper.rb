module ApplicationHelper
  include PagyHelper
  include BlocksHelper
  include DirectoryHelper
  include AdminFormHelper

  def turbo_frame_request?
    request.headers["Turbo-Frame"].present?
  end
end
