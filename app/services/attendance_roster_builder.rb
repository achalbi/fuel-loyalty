# A9 — who the attendance planner should pre-fill for one shift window: the
# active staff already rostered onto this template, plus anyone not yet rostered
# onto any template, so a new joiner is never silently left off the run.
class AttendanceRosterBuilder
  def self.call(...)
    new(...).call
  end

  def initialize(shift_template:, starts_at:)
    @shift_template = shift_template
    @starts_at = starts_at
  end

  def call
    rostered_staff.map { |staff_member| { staff_member: staff_member } }
  end

  private

  attr_reader :shift_template, :starts_at

  def rostered_staff
    active_staff.where(id: assigned_to_this_template)
      .or(active_staff.where.not(id: assigned_to_any_template))
      .order(:name, :username, :phone_number)
  end

  def active_staff
    User.active.where(role: :staff)
  end

  def assigned_to_this_template
    ShiftAssignment.active.effective_at(starts_at)
      .where(shift_template_id: shift_template.id)
      .select(:user_id)
  end

  def assigned_to_any_template
    ShiftAssignment.active.effective_at(starts_at).select(:user_id)
  end
end
