# frozen_string_literal: true

class DocumentPopularityPolicy < ApplicationPolicy
  def index?
    user&.admin?
  end
end
