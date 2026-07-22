class CampaignPolicy < ApplicationPolicy
  %i[index? show? create? update? destroy? preview? run? activate? pause?].each do |action|
    define_method(action) { user&.admin? }
  end
end
