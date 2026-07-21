class UserPolicy < ApplicationPolicy
  def index?
    user&.admin?
  end

  def show?
    user&.admin?
  end

  def create?
    user&.admin?
  end

  def update?
    user&.admin?
  end

  def destroy?
    user&.admin? && record.is_a?(User) && record.staff?
  end

  # Self-service pump assignment ("My Pump"). Staff must NOT set their own pump
  # (Staff_FSM requirement S-MYPUMP) — an admin assigns it via the staff form
  # (A10). Kept as admin-only self so the route/page isn't reachable by staff.
  def manage_pump?
    user&.admin? && record == user
  end

  # Admin assigning a pump/nozzles to another user (A10).
  def assign_pump?
    user&.admin?
  end
end
