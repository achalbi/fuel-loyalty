class ProductPolicy < ApplicationPolicy
  def index?
    user&.admin?
  end

  def create?
    user&.admin?
  end

  def show?
    user&.admin?
  end

  def edit?
    user&.admin?
  end

  def update?
    user&.admin?
  end

  def destroy?
    user&.admin?
  end

  # Read-only catalog is available to any staff (settlement/visit pickers).
  def catalog?
    user&.admin? || user&.staff?
  end
end
