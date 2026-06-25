# frozen_string_literal: true

class DocumentAuditPolicy < ApplicationPolicy
  def index?
    user&.admin?
  end
end
