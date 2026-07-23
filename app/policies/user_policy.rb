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

  # A7 — revealing the full Aadhaar / ID-card image is admin-only and audited.
  def view_aadhaar?
    user&.admin?
  end
  alias view_id_card? view_aadhaar?
  alias purge_kyc? view_aadhaar?

  # Staff may self-assign their pump for the selected day. Admins can use the
  # same screen for themselves as well as the separate staff-member assignment.
  def manage_pump?
    user&.admin? && record == user || user&.staff? && record == user
  end

  # Admin assigning a pump/nozzles to another user (A10).
  def assign_pump?
    user&.admin?
  end
end
