class RewardSettingPolicy < ApplicationPolicy
  def show?
    user&.admin?
  end

  def update?
    user&.admin?
  end
end
