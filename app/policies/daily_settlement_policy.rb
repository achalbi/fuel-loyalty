class DailySettlementPolicy < ApplicationPolicy
  def index?
    staff_access?
  end

  # Capturing a fresh sheet is the FSM's job. `staff_access?` used to let an
  # admin reach the FSM form by URL and save a settlement stamped
  # `recorded_by = the admin` — misattributed, and with no audit row at all
  # (Settlement::Persister only audits the admin_edit path). Staff feedback
  # item 3: an admin reads and corrects through the admin console instead.
  # Recording *on behalf of* a named FSM is a separate, audited admin flow.
  def new?
    user&.staff?
  end

  def show?
    staff_access?
  end

  def create?
    user&.staff?
  end

  def update?
    staff_access?
  end

  # Staff feedback item 3, final part — an admin records a sheet ON BEHALF OF a
  # named FSM who could not do it themselves. Deliberately a separate capability
  # from #new?/#create? above rather than a loosening of them: those stay
  # staff-only so the misattributing, unaudited back door (an admin posting to
  # the FSM form and getting a sheet stamped as their own with no
  # settlement_changes row) stays shut. This route names the FSM explicitly,
  # keeps authorship with them, records the admin in `entered_by`, and demands a
  # change reason — so it is the audited flow, not the back door reopened.
  def create_on_behalf?
    user&.admin?
  end

  # Only admins move a settlement to reconciled / edit a locked one.
  def reconcile?
    user&.admin?
  end

  def admin_manage?
    user&.admin?
  end

  private

  def staff_access?
    user&.admin? || user&.staff?
  end
end
