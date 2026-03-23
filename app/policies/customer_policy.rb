class CustomerPolicy < ApplicationPolicy
  def index?
    user&.admin?
  end

  def show?
    user.present?
  end

  def points_ledger?
    show?
  end

  def transaction_history?
    show?
  end

  def new?
    staff_access?
  end

  def create?
    staff_access?
  end

  def update?
    staff_access?
  end

  def destroy?
    user&.admin?
  end

  def lookup?
    staff_access?
  end

  def activate?
    staff_access?
  end

  def deactivate?
    staff_access?
  end

  private

  def staff_access?
    user&.admin? || user&.staff?
  end
end
