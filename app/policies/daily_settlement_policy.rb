class DailySettlementPolicy < ApplicationPolicy
  def index?
    staff_access?
  end

  def new?
    staff_access?
  end

  def show?
    staff_access?
  end

  def create?
    staff_access?
  end

  def update?
    staff_access?
  end

  # Only admins move a settlement to reconciled / edit a locked one.
  def reconcile?
    user&.admin?
  end

  def admin_manage?
    user&.admin?
  end

  private

  def staff_access?
    user&.admin? || user&.staff?
  end
end
