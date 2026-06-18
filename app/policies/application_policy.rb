# frozen_string_literal: true

# Tabla — osnovna Pundit politika
# Vzorec iz Delovodnika, prilagojen za intranet vloge.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    user.present?
  end

  def show?
    user.present?
  end

  def create?
    editor?
  end

  def new?
    create?
  end

  def update?
    editor?
  end

  def edit?
    update?
  end

  def destroy?
    user&.admin?
  end

  protected

  # Admin ali urednik — lahko ureja vsebino.
  def editor?
    user.present? && (user.admin? || user.urednik?)
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end
end
