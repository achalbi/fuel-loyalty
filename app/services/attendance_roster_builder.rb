class AttendanceRosterBuilder
  def self.call(...)
    new(...).call
  end

  def initialize(shift_template:, starts_at:)
    @shift_template = shift_template
    @starts_at = starts_at
  end

  def call
    assignments.map do |assignment|
      {
        staff_member: assignment.user,
        assignment:
      }
    end
  end

  private

  attr_reader :shift_template, :starts_at

  def assignments
    matching_assignments = ShiftAssignment
      .includes(:user, :shift_template)
      .active
      .effective_at(starts_at)
      .where(shift_template_id: shift_template.id)
      .joins(:user)
    assigned_user_ids = ShiftAssignment.active.effective_at(starts_at).pluck(:user_id)
    matching_user_ids = matching_assignments.pluck(:user_id)

    User.active.where(role: :staff)
      .where(id: matching_user_ids)
      .or(User.active.where(role: :staff).where.not(id: assigned_user_ids))
      .order(:name, :username, :phone_number)
      .includes(:shift_assignments)
  end
end
