require "test_helper"

module Admin
  class AttendanceRunsControllerTest < ActionDispatch::IntegrationTest
    test "admin can view saved attendance runs" do
      sign_in users(:one)

      get admin_attendance_runs_path

      assert_response :success
      assert_select "h1", text: "Attendance"
      assert_select ".nav-section-label", text: "Attendance"
      assert_select "a.nav-link.active[href='#{admin_attendance_runs_path}']", text: /Attendance/
      assert_select ".admin-attendance-run-list", 1
      assert_select ".admin-attendance-run-card", minimum: 1
      assert_select ".admin-attendance-item__name", text: /Day Shift/
      assert_select ".admin-attendance-run__summary", text: "Present 1"
      assert_select ".admin-attendance-run__summary", text: /Absent 0/, count: 0
      assert_select "a.admin-attendance-run__open[href='#{admin_attendance_run_path(attendance_runs(:day_run))}']"
      assert_select "a[href='#{admin_attendance_runs_path(filter: :invalid)}']", text: "Invalid"
    end

    test "admin can filter recorded attendance by invalid flag" do
      sign_in users(:one)

      stale_run = create_attendance_run_for(
        shift_template: shift_templates(:day_shift),
        starts_at: Time.zone.parse("2026-03-31 06:00"),
        ends_at: Time.zone.parse("2026-03-31 18:00"),
        stale: true
      )

      get admin_attendance_runs_path, params: { filter: :invalid }

      assert_response :success
      assert_select ".admin-attendance-item__name", text: stale_run.shift_name_snapshot, minimum: 1
      assert_select ".admin-attendance-run__state-badge", text: "Invalid"
      assert_select "form[action='#{admin_attendance_run_path(stale_run)}']"
      assert_select ".admin-shift-item__detail-value", text: "Invalid"
      assert_select ".admin-shift-item__detail-value", text: "Valid", count: 0
    end

    test "admin can view attendance planner with assigned staff" do
      sign_in users(:one)

      travel_to Time.zone.parse("2026-03-26 06:15") do
        get new_admin_attendance_run_path, params: {
          shift_template_id: shift_templates(:day_shift).id,
          starts_at: "2026-03-27T18:00"
        }
      end

      assert_response :success
      assert_select "h1", text: "Attendance"
      assert_select ".nav-section-label", text: "Attendance"
      assert_select "a.nav-link.active[href='#{admin_attendance_runs_path}']", text: /Attendance/
      assert_select ".admin-attendance-entry-list", 1
      assert_select ".admin-attendance-entry", 1
      assert_select ".admin-attendance-entry h3", text: /Staff/
      assert_select "input[name='attendance_run[attendance_entries_attributes][0][check_in_at]'][value='2026-03-27T18:00']", 1
      assert_select "input[name='attendance_run[attendance_entries_attributes][0][check_out_at]'][value='2026-03-28T06:00']", 1
      assert_select ".admin-attendance-card__summary-label", text: "Loaded Staff"
      assert_select ".admin-attendance-card__summary-value", text: "1"
      assert_select "p.small-muted", text: "Planned Window", count: 0
      assert_select "button[data-attendance-mark-all-present]", text: "Mark All Present"
    end

    test "attendance planner uses the shift start time when the start is blank" do
      sign_in users(:one)

      travel_to Time.zone.parse("2026-03-26 11:45") do
        get new_admin_attendance_run_path, params: {
          shift_template_id: shift_templates(:night_shift).id
        }
      end

      assert_response :success
      assert_includes @response.body, 'data-start-time="18:00"'
      assert_select "input[data-attendance-start-input][value='2026-03-26T18:00']", 1
      assert_select "input[data-attendance-end-input][value='2026-03-27T18:00']", 1
    end

    test "attendance planner rejects a window that does not match the repeating cycle" do
      sign_in users(:one)

      get new_admin_attendance_run_path, params: {
        shift_template_id: shift_templates(:day_shift).id,
        starts_at: "2026-03-26T08:00"
      }

      assert_response :success
      assert_select ".alert.alert-danger", text: /do not match this shift's repeating cycle/
      assert_select ".admin-attendance-entry", 0
      assert_select "h2", text: "Adjust the planned window"
      assert_select "p.small-muted", text: /Choose the next cycle-aligned window/
    end

    test "attendance planner rejects a shift window already recorded" do
      sign_in users(:one)

      existing_run = create_attendance_run_for(
        shift_template: shift_templates(:day_shift),
        starts_at: Time.zone.parse("2026-03-29 06:00"),
        ends_at: Time.zone.parse("2026-03-29 18:00")
      )

      get new_admin_attendance_run_path, params: {
        shift_template_id: shift_templates(:day_shift).id,
        starts_at: existing_run.starts_at.strftime("%Y-%m-%dT%H:%M")
      }

      assert_response :success
      assert_select ".alert.alert-danger", text: /already been recorded for this shift and time window/
      assert_select ".admin-attendance-entry", 0
      assert_select "h2", text: "Adjust the planned window"
    end

    test "attendance planner loads staff when the existing record for the window is invalid" do
      sign_in users(:one)

      invalid_run = create_attendance_run_for(
        shift_template: shift_templates(:day_shift),
        starts_at: Time.zone.parse("2026-04-04 06:00"),
        ends_at: Time.zone.parse("2026-04-04 18:00"),
        stale: true
      )

      get new_admin_attendance_run_path, params: {
        shift_template_id: shift_templates(:day_shift).id,
        starts_at: invalid_run.starts_at.strftime("%Y-%m-%dT%H:%M")
      }

      assert_response :success
      assert_select ".alert.alert-danger", count: 0
      assert_select ".admin-attendance-entry-list", 1
      assert_select ".admin-attendance-entry", 1
    end

    test "admin can create an attendance run" do
      sign_in users(:one)

      assert_difference(["AttendanceRun.count", "AttendanceEntry.count"], 1) do
        post admin_attendance_runs_path, params: {
          attendance_run: {
            shift_template_id: shift_templates(:day_shift).id,
            starts_at: "2026-03-27T18:00",
            ends_at: "2026-03-28T06:00",
            notes: "Morning attendance",
            attendance_entries_attributes: {
              "0" => {
                scheduled_user_id: users(:two).id,
                actual_user_id: users(:two).id,
                status: "present",
                notes: "Ready on shift"
              }
            }
          }
        }
      end

      attendance_run = AttendanceRun.order(:created_at).last
      assert_redirected_to admin_attendance_run_path(attendance_run)
      assert_equal users(:one), attendance_run.recorded_by
      assert_equal "Day Shift", attendance_run.shift_name_snapshot
      assert_equal 720, attendance_run.duration_snapshot_minutes
      assert_equal "present", attendance_run.attendance_entries.first.status
    end

    test "admin can create an invalid attendance run" do
      sign_in users(:one)

      assert_difference(["AttendanceRun.count", "AttendanceEntry.count"], 1) do
        post admin_attendance_runs_path, params: {
          attendance_run: {
            shift_template_id: shift_templates(:day_shift).id,
            starts_at: "2026-03-29T06:00",
            ends_at: "2026-03-29T18:00",
            stale: "1",
            notes: "Backfilled entry",
            attendance_entries_attributes: {
              "0" => {
                scheduled_user_id: users(:two).id,
                actual_user_id: users(:two).id,
                status: "present",
                notes: "Entered later"
              }
            }
          }
        }
      end

      attendance_run = AttendanceRun.order(:created_at).last
      assert attendance_run.stale?
      follow_redirect!
      assert_select "h2", text: "Invalid"
      assert_select "form[action='#{mark_valid_admin_attendance_run_path(attendance_run)}']"
    end

    test "admin can create a valid attendance run when the existing window is invalid" do
      sign_in users(:one)

      create_attendance_run_for(
        shift_template: shift_templates(:day_shift),
        starts_at: Time.zone.parse("2026-04-04 06:00"),
        ends_at: Time.zone.parse("2026-04-04 18:00"),
        stale: true
      )

      assert_difference(["AttendanceRun.count", "AttendanceEntry.count"], 1) do
        post admin_attendance_runs_path, params: {
          attendance_run: {
            shift_template_id: shift_templates(:day_shift).id,
            starts_at: "2026-04-04T06:00",
            ends_at: "2026-04-04T18:00",
            notes: "Replacement valid entry",
            attendance_entries_attributes: {
              "0" => {
                scheduled_user_id: users(:two).id,
                actual_user_id: users(:two).id,
                status: "present",
                notes: "Replacement attendance"
              }
            }
          }
        }
      end

      attendance_run = AttendanceRun.order(:created_at).last
      assert_not attendance_run.stale?
      assert_redirected_to admin_attendance_run_path(attendance_run)
    end

    test "admin cannot create an attendance run outside the repeating cycle window" do
      sign_in users(:one)

      assert_no_difference("AttendanceRun.count") do
        post admin_attendance_runs_path, params: {
          attendance_run: {
            shift_template_id: shift_templates(:day_shift).id,
            starts_at: "2026-03-26T08:00",
            ends_at: "2026-03-26T20:00",
            attendance_entries_attributes: {
              "0" => {
                scheduled_user_id: users(:two).id,
                actual_user_id: users(:two).id,
                status: "present",
                notes: "Cycle mismatch"
              }
            }
          }
        }
      end

      assert_response :unprocessable_entity
      assert_select ".alert.alert-danger", text: /do not match this shift's repeating cycle/
    end

    test "admin cannot create a duplicate attendance run for the same shift window" do
      sign_in users(:one)

      existing_run = create_attendance_run_for(
        shift_template: shift_templates(:day_shift),
        starts_at: Time.zone.parse("2026-03-29 06:00"),
        ends_at: Time.zone.parse("2026-03-29 18:00")
      )

      assert_no_difference("AttendanceRun.count") do
        post admin_attendance_runs_path, params: {
          attendance_run: {
            shift_template_id: shift_templates(:day_shift).id,
            starts_at: existing_run.starts_at.strftime("%Y-%m-%dT%H:%M"),
            ends_at: existing_run.ends_at.strftime("%Y-%m-%dT%H:%M"),
            attendance_entries_attributes: {
              "0" => {
                scheduled_user_id: users(:two).id,
                actual_user_id: users(:two).id,
                status: "present",
                notes: "Duplicate window"
              }
            }
          }
        }
      end

      assert_response :unprocessable_entity
      assert_select ".alert.alert-danger", text: /already been recorded for this shift and time window/
    end

    test "admin can view a saved attendance run" do
      sign_in users(:one)

      get admin_attendance_run_path(attendance_runs(:day_run))

      assert_response :success
      assert_select "h1", text: "Attendance Details"
      assert_select ".admin-attendance-status-list", 1
      assert_select ".admin-attendance-status-card", 6
      assert_select ".admin-attendance-list", 1
      assert_select ".admin-attendance-item__name", text: /Staff/
      assert_select ".badge", text: /Present/
      assert_select "p.small-muted", text: "Status"
      assert_select "h2", text: "Valid"
      assert_select "form[action='#{invalidate_admin_attendance_run_path(attendance_runs(:day_run))}']"
      assert_select "form[action='#{admin_attendance_run_path(attendance_runs(:day_run))}']", count: 0
    end

    test "admin can invalidate a recorded attendance run" do
      sign_in users(:one)

      patch invalidate_admin_attendance_run_path(attendance_runs(:day_run))

      assert_redirected_to admin_attendance_run_path(attendance_runs(:day_run))
      assert attendance_runs(:day_run).reload.stale?

      follow_redirect!
      assert_select "p.small-muted", text: "Status"
      assert_select "h2", text: "Invalid"
      assert_select "form[action='#{invalidate_admin_attendance_run_path(attendance_runs(:day_run))}']", count: 0
      assert_select "form[action='#{mark_valid_admin_attendance_run_path(attendance_runs(:day_run))}']"
      assert_select "form[action='#{admin_attendance_run_path(attendance_runs(:day_run))}']"
    end

    test "admin can mark an invalid attendance run valid when no conflicting window exists" do
      sign_in users(:one)

      invalid_run = create_attendance_run_for(
        shift_template: shift_templates(:day_shift),
        starts_at: Time.zone.parse("2026-04-03 06:00"),
        ends_at: Time.zone.parse("2026-04-03 18:00"),
        stale: true
      )

      patch mark_valid_admin_attendance_run_path(invalid_run)

      assert_redirected_to admin_attendance_run_path(invalid_run)
      assert_not invalid_run.reload.stale?

      follow_redirect!
      assert_select "p.small-muted", text: "Status"
      assert_select "h2", text: "Valid"
      assert_select "form[action='#{mark_valid_admin_attendance_run_path(invalid_run)}']", count: 0
      assert_select "form[action='#{invalidate_admin_attendance_run_path(invalid_run)}']"
    end

    test "admin cannot mark an invalid attendance run valid when another record exists for the same window" do
      sign_in users(:one)

      invalid_run = create_attendance_run_for(
        shift_template: shift_templates(:day_shift),
        starts_at: Time.zone.parse("2026-04-04 06:00"),
        ends_at: Time.zone.parse("2026-04-04 18:00"),
        stale: true
      )
      force_create_attendance_run_for(
        shift_template: shift_templates(:day_shift),
        starts_at: invalid_run.starts_at,
        ends_at: invalid_run.ends_at
      )

      get admin_attendance_run_path(invalid_run)

      assert_response :success
      assert_select "button[disabled]", text: "Mark Valid"

      patch mark_valid_admin_attendance_run_path(invalid_run)

      assert_redirected_to admin_attendance_run_path(invalid_run)
      assert invalid_run.reload.stale?
    end

    test "admin can delete an invalid attendance run" do
      sign_in users(:one)

      invalid_run = create_attendance_run_for(
        shift_template: shift_templates(:day_shift),
        starts_at: Time.zone.parse("2026-04-02 06:00"),
        ends_at: Time.zone.parse("2026-04-02 18:00"),
        stale: true
      )

      assert_difference(["AttendanceRun.count", "AttendanceEntry.count"], -1) do
        delete admin_attendance_run_path(invalid_run)
      end

      assert_redirected_to admin_attendance_runs_path(filter: :invalid)
    end

    test "admin cannot delete a valid attendance run" do
      sign_in users(:one)

      assert_no_difference("AttendanceRun.count") do
        delete admin_attendance_run_path(attendance_runs(:day_run))
      end

      assert_redirected_to admin_attendance_run_path(attendance_runs(:day_run))
    end

    private

    def create_attendance_run_for(shift_template:, starts_at:, ends_at:, stale: false)
      AttendanceRun.create!(
        shift_template: shift_template,
        starts_at: starts_at,
        ends_at: ends_at,
        stale: stale,
        recorded_by: users(:one),
        attendance_entries_attributes: {
          "0" => {
            scheduled_user_id: users(:two).id,
            actual_user_id: users(:two).id,
            status: "present",
            notes: "Existing attendance"
          }
        }
      )
    end

    def force_create_attendance_run_for(shift_template:, starts_at:, ends_at:, stale: false)
      attendance_run = AttendanceRun.new(
        shift_template: shift_template,
        starts_at: starts_at,
        ends_at: ends_at,
        stale: stale,
        recorded_by: users(:one),
        shift_name_snapshot: shift_template.name,
        duration_snapshot_minutes: shift_template.duration_minutes
      )
      attendance_run.save!(validate: false)
      AttendanceEntry.create!(
        attendance_run: attendance_run,
        scheduled_user: users(:two),
        actual_user: users(:two),
        status: :present,
        notes: "Forced duplicate"
      )
      attendance_run
    end
  end
end
