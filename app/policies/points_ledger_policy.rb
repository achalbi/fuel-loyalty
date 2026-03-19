class PointsLedgerPolicy < ApplicationPolicy
  def new?
    user&.admin?
  end

  def create?
    user&.admin?
  end

  def redeem?
    user&.admin? || user&.staff?
  end
end
