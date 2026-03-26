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
    ShiftAssignment
      .includes(:user, :shift_template)
      .active
      .effective_at(starts_at)
      .where(shift_template_id: shift_template.id)
      .joins(:user)
      .merge(User.where(role: :staff, active: true).order(:username, :phone_number))
  end
end
