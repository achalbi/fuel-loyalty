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

  # Gates the FSM flow only, and says nothing about *which* settlement: the staff
  # controllers scope that to the caller's own sheet. An admin passes this check
  # but has no editable sheet there — an admin edit of a recorded settlement runs
  # through `admin_manage?` in the audited D9 console, which writes the diff.
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
