# Samodejno beleži created_by_id in updated_by_id iz Current.user.
# Uporabi: `include UserStampable` v modelu.
# Enako kot v Delovodniku.
module UserStampable
  extend ActiveSupport::Concern

  included do
    belongs_to :creator, class_name: "User", foreign_key: "created_by_id", optional: true
    belongs_to :updater, class_name: "User", foreign_key: "updated_by_id", optional: true

    before_create :set_created_by
    before_save   :set_updated_by
  end

  private

  def set_created_by
    self.created_by_id ||= Current.user&.id
  end

  def set_updated_by
    self.updated_by_id = Current.user&.id
  end
end
