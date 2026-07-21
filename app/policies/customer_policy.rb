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

  # Pausing rewards is an admin-only capability. Staff must not be able to
  # pause/resume rewards (Staff_FSM requirement S-PAUSE), so this is gated to
  # admins even though the routes live under the staff namespace.
  def pause_rewards?
    user&.admin?
  end

  def resume_rewards?
    user&.admin?
  end

  private

  def staff_access?
    user&.admin? || user&.staff?
  end
end
