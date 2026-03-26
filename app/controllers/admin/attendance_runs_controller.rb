module Admin
  class AttendanceRunsController < BaseController
    before_action :load_shift_templates, :load_active_staff_members, only: %i[new create]

    def index
      authorize AttendanceRun
      @record_filter = normalized_record_filter
      attendance_scope = AttendanceRun
        .includes(:shift_template, :recorded_by, attendance_entries: %i[scheduled_user actual_user replacement_user])
        .order(starts_at: :desc, created_at: :desc)
      @attendance_runs = filtered_attendance_scope(attendance_scope)
    end

    def new
      @attendance_run = AttendanceRun.new
      authorize @attendance_run

      apply_planning_state
    end

    def create
      @attendance_run = AttendanceRun.new(attendance_run_params)
      authorize @attendance_run
      @attendance_run.recorded_by = current_user
      attach_cycle_window_error(@attendance_run)

      if @attendance_run.errors.none? && @attendance_run.save
        redirect_to admin_attendance_run_path(@attendance_run), notice: "Attendance recorded successfully."
      else
        @selected_shift_template = @attendance_run.shift_template
        @planning_starts_at = @attendance_run.starts_at
        @planning_ends_at = @attendance_run.ends_at
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @attendance_run = AttendanceRun.includes(:shift_template, attendance_entries: %i[scheduled_user actual_user replacement_user]).find(params[:id])
      authorize @attendance_run
      @status_counts = AttendanceEntry.statuses.keys.index_with { |status| @attendance_run.status_counts.fetch(status, 0) }
    end

    def invalidate
      @attendance_run = AttendanceRun.find(params[:id])
      authorize @attendance_run

      if @attendance_run.stale?
        redirect_to admin_attendance_run_path(@attendance_run), alert: "Attendance record is already marked invalid."
      elsif @attendance_run.update(stale: true)
        redirect_to admin_attendance_run_path(@attendance_run), notice: "Attendance record marked invalid."
      else
        redirect_to admin_attendance_run_path(@attendance_run), alert: "Unable to mark this attendance record invalid."
      end
    end

    def mark_valid
      @attendance_run = AttendanceRun.find(params[:id])
      authorize @attendance_run

      unless @attendance_run.stale?
        redirect_to admin_attendance_run_path(@attendance_run), alert: "Attendance record is already marked valid."
        return
      end

      unless @attendance_run.can_mark_valid?
        redirect_to admin_attendance_run_path(@attendance_run), alert: "Another attendance record already exists for this shift and time window."
        return
      end

      if @attendance_run.update(stale: false)
        redirect_to admin_attendance_run_path(@attendance_run), notice: "Attendance record marked valid."
      else
        redirect_to admin_attendance_run_path(@attendance_run), alert: @attendance_run.errors.full_messages.to_sentence.presence || "Unable to mark this attendance record valid."
      end
    end

    def destroy
      @attendance_run = AttendanceRun.find(params[:id])
      authorize @attendance_run

      unless @attendance_run.stale?
        redirect_to admin_attendance_run_path(@attendance_run), alert: "Only invalid attendance records can be deleted."
        return
      end

      @attendance_run.destroy
      redirect_back fallback_location: admin_attendance_runs_path(filter: :invalid), notice: "Invalid attendance record deleted."
    end

    private

    def load_shift_templates
      @shift_templates = ShiftTemplate.active.order(:name, :duration_minutes)
    end

    def load_active_staff_members
      @active_staff_members = User.where(role: :staff, active: true).order(:username, :phone_number)
    end

    def apply_planning_state
      @selected_shift_template = selected_shift_template
      @planning_starts_at = parsed_starts_at
      @planning_ends_at = computed_ends_at

      return unless @selected_shift_template.present?
      return unless duplicate_window_valid?
      return unless cycle_window_valid?

      build_attendance_entries
    end

    def build_attendance_entries
      AttendanceRosterBuilder.call(shift_template: @selected_shift_template, starts_at: @planning_starts_at).each do |item|
        @attendance_run.attendance_entries.build(
          scheduled_user: item.fetch(:staff_member),
          actual_user: item.fetch(:staff_member),
          status: :present,
          check_in_at: @planning_starts_at,
          check_out_at: @planning_ends_at
        )
      end

      @attendance_run.shift_template = @selected_shift_template
      @attendance_run.starts_at = @planning_starts_at
      @attendance_run.ends_at = @planning_ends_at
    end

    def selected_shift_template
      shift_template_id = params[:shift_template_id].presence || params.dig(:attendance_run, :shift_template_id).presence
      return if shift_template_id.blank?

      ShiftTemplate.find_by(id: shift_template_id)
    end

    def parsed_starts_at
      raw_value = params[:starts_at].presence || params.dig(:attendance_run, :starts_at).presence
      return default_planning_starts_at if raw_value.blank?

      Time.zone.parse(raw_value)
    rescue ArgumentError, TypeError
      default_planning_starts_at
    end

    def computed_ends_at
      return unless @selected_shift_template.present?

      @planning_starts_at + @selected_shift_template.duration_minutes.minutes
    end

    def default_planning_starts_at
      return Time.zone.now.change(min: 0) unless @selected_shift_template.present?

      Time.zone.parse("#{Time.zone.today} #{@selected_shift_template.start_time_input_value}")
    rescue ArgumentError, TypeError
      Time.zone.now.change(min: 0)
    end

    def cycle_window_valid?
      return true unless @selected_shift_template.present? && @planning_starts_at.present? && @planning_ends_at.present?

      linked_cycles = @selected_shift_template.shift_cycles.active.includes(:shift_cycle_steps)
      return true if linked_cycles.empty?

      return true if linked_cycles.any? do |shift_cycle|
        shift_cycle.valid_window_for?(
          shift_template: @selected_shift_template,
          starts_at: @planning_starts_at,
          ends_at: @planning_ends_at
        )
      end

      @attendance_run.errors.add(:base, "Selected start and end date time do not match this shift's repeating cycle. Choose the next cycle-aligned window.")
      false
    end

    def duplicate_window_valid?
      return true unless @selected_shift_template.present? && @planning_starts_at.present? && @planning_ends_at.present?

      return true unless AttendanceRun.valid_records.exists?(
        shift_template_id: @selected_shift_template.id,
        starts_at: @planning_starts_at,
        ends_at: @planning_ends_at
      )

      @attendance_run.errors.add(:base, "Attendance has already been recorded for this shift and time window.")
      false
    end

    def attach_cycle_window_error(attendance_run)
      return unless attendance_run.shift_template.present? && attendance_run.starts_at.present? && attendance_run.ends_at.present?

      linked_cycles = attendance_run.shift_template.shift_cycles.active.includes(:shift_cycle_steps)
      return if linked_cycles.empty?
      return if linked_cycles.any? do |shift_cycle|
        shift_cycle.valid_window_for?(
          shift_template: attendance_run.shift_template,
          starts_at: attendance_run.starts_at,
          ends_at: attendance_run.ends_at
        )
      end

      attendance_run.errors.add(:base, "Selected start and end date time do not match this shift's repeating cycle. Choose the next cycle-aligned window.")
    end

    def attendance_run_params
      params.require(:attendance_run).permit(
        :shift_template_id,
        :starts_at,
        :ends_at,
        :stale,
        :notes,
        attendance_entries_attributes: [
          :scheduled_user_id,
          :actual_user_id,
          :replacement_user_id,
          :external_replacement_name,
          :status,
          :check_in_at,
          :check_out_at,
          :notes
        ]
      )
    end

    def normalized_record_filter
      legacy_filter = { "fresh" => "valid", "stale" => "invalid" }
      filter_value = legacy_filter.fetch(params[:filter], params[:filter])
      filter_value.presence_in(%w[all valid invalid]) || "all"
    end

    def filtered_attendance_scope(scope)
      case @record_filter
      when "invalid"
        scope.invalid_records
      when "valid"
        scope.valid_records
      else
        scope
      end
    end
  end
end
