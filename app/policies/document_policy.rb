# frozen_string_literal: true

class DocumentPolicy < ApplicationPolicy
  def show?
    return true if user&.admin? || user&.urednik?

    !record.internal_only?
  end

  def download?
    show?
  end

  def audit_history?
    user&.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.visible_to(user)
    end
  end
end
