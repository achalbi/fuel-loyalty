module Api
  module V1
    module Admin
      # JSON mirror of Admin::AttendanceRunsController. Records and reviews
      # attendance sessions for a shift template + time window. All planning
      # math (auto end time, roster build, duplicate/cycle-window guards) is
      # replicated verbatim from the web controller so the API and the web
      # produce identical records and user-facing messages.
      class AttendanceRunsController < Api::V1::Admin::BaseController
        ATTENDANCE_RUNS_PER_PAGE = 6

        # GET /api/v1/admin/attendance_runs
        # filters: filter=(all|valid|invalid), start_date, end_date, page (6/page)
        def index
          authorize AttendanceRun, :index?
          @record_filter = normalized_record_filter
          @current_start_date, @current_end_date = normalized_date_range

          scope = filtered_attendance_scope(AttendanceRun.all)
          scope = filtered_by_date_range(scope)
          scope = scope.order(starts_at: :desc, created_at: :desc)

          total = scope.count
          total_pages = total.zero? ? 1 : (total.to_f / ATTENDANCE_RUNS_PER_PAGE).ceil
          page = normalized_page(total_pages)

          runs = scope
                 .includes(:shift_template, :recorded_by, attendance_entries: %i[scheduled_user actual_user replacement_user])
                 .offset((page - 1) * ATTENDANCE_RUNS_PER_PAGE)
                 .limit(ATTENDANCE_RUNS_PER_PAGE)

          showing_from = total.zero? ? 0 : ((page - 1) * ATTENDANCE_RUNS_PER_PAGE) + 1
          showing_to = total.zero? ? 0 : showing_from + runs.size - 1

          render json: {
            attendance_runs: runs.map { |run| AttendanceRunSerializer.call(run) },
            filter: @record_filter,
            start_date: @current_start_date&.iso8601,
            end_date: @current_end_date&.iso8601,
            page: page,
            per_page: ATTENDANCE_RUNS_PER_PAGE,
            total: total,
            total_pages: total_pages,
            showing_from: showing_from,
            showing_to: showing_to,
          }, status: :ok
        end

        # GET /api/v1/admin/attendance_runs/new?shift_template_id=&starts_at=
        # Planner: returns the auto-computed end time + the rostered staff rows
        # (via AttendanceRosterBuilder) for the chosen template/start window.
        # Returns base errors instead of rows when the window is a duplicate or
        # does not align with the template's repeating cycle.
        def new
          @attendance_run = AttendanceRun.new
          authorize @attendance_run, :new?
          apply_planning_state

          render json: {
            shift_template: AttendanceRunSerializer.shift_template_json(@selected_shift_template),
            starts_at: @planning_starts_at&.iso8601,
            ends_at: @planning_ends_at&.iso8601,
            entries: @attendance_run.attendance_entries.map { |entry| AttendanceEntrySerializer.call(entry) },
            errors: @attendance_run.errors[:base],
          }, status: :ok
        end

        # POST /api/v1/admin/attendance_runs
        # attendance_run[shift_template_id, starts_at, ends_at, stale, notes,
        #   attendance_entries_attributes[]]
        def create
          @attendance_run = AttendanceRun.new(attendance_run_params)
          authorize @attendance_run, :create?
          @attendance_run.recorded_by = current_user
          attach_cycle_window_error(@attendance_run)

          if @attendance_run.errors.none? && @attendance_run.save
            render json: AttendanceRunSerializer.call(@attendance_run.reload, include_entries: true), status: :created
          else
            render_validation_error(@attendance_run)
          end
        end

        # GET /api/v1/admin/attendance_runs/:id
        def show
          @attendance_run = AttendanceRun
                            .includes(:shift_template, :recorded_by, attendance_entries: %i[scheduled_user actual_user replacement_user])
                            .find(params[:id])
          authorize @attendance_run, :show?
          render json: AttendanceRunSerializer.call(@attendance_run, include_entries: true), status: :ok
        end

        # PATCH /api/v1/admin/attendance_runs/:id/invalidate
        def invalidate
          @attendance_run = AttendanceRun.find(params[:id])
          authorize @attendance_run, :invalidate?

          if @attendance_run.stale?
            render_error(status: 422, code: "already_invalid",
                         message: "Attendance record is already marked invalid.")
          elsif @attendance_run.update(stale: true)
            render json: AttendanceRunSerializer.call(@attendance_run.reload, include_entries: true), status: :ok
          else
            render_error(status: 422, code: "invalidate_failed",
                         message: "Unable to mark this attendance record invalid.")
          end
        end

        # PATCH /api/v1/admin/attendance_runs/:id/mark_valid
        def mark_valid
          @attendance_run = AttendanceRun.find(params[:id])
          authorize @attendance_run, :mark_valid?

          unless @attendance_run.stale?
            return render_error(status: 422, code: "already_valid",
                                message: "Attendance record is already marked valid.")
          end

          unless @attendance_run.can_mark_valid?
            return render_error(status: 422, code: "shift_window_conflict",
                                message: "Another attendance record already exists for this shift and time window.")
          end

          if @attendance_run.update(stale: false)
            render json: AttendanceRunSerializer.call(@attendance_run.reload, include_entries: true), status: :ok
          else
            render_error(status: 422, code: "mark_valid_failed",
                         message: @attendance_run.errors.full_messages.to_sentence.presence || "Unable to mark this attendance record valid.")
          end
        end

        # DELETE /api/v1/admin/attendance_runs/:id  (invalid records only)
        def destroy
          @attendance_run = AttendanceRun.find(params[:id])
          authorize @attendance_run, :destroy?

          unless @attendance_run.stale?
            return render_error(status: 422, code: "not_invalid",
                                message: "Only invalid attendance records can be deleted.")
          end

          if @attendance_run.destroy
            render json: { message: "Invalid attendance record deleted." }, status: :ok
          else
            render_error(status: 422, code: "delete_failed",
                         message: @attendance_run.errors.full_messages.to_sentence.presence || "Unable to delete this attendance record.")
          end
        end

        private

        def render_validation_error(record)
          render_error(status: 422, code: "validation_failed",
                       message: record.errors.full_messages.to_sentence.presence || "Validation failed.",
                       details: record.errors.messages)
        end

        # --- planner (new) helpers, mirrored from the web controller ----------

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
              check_out_at: @planning_ends_at,
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
              ends_at: @planning_ends_at,
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
            ends_at: @planning_ends_at,
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
              ends_at: attendance_run.ends_at,
            )
          end

          attendance_run.errors.add(:base, "Selected start and end date time do not match this shift's repeating cycle. Choose the next cycle-aligned window.")
        end

        def attendance_run_params
          resource_params(:attendance_run).permit(
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
              :notes,
            ],
          )
        end

        # --- index filter/pagination helpers, mirrored from the web -----------

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

        def filtered_by_date_range(scope)
          scope = scope.where("starts_at >= ?", @current_start_date.beginning_of_day) if @current_start_date.present?
          scope = scope.where("starts_at <= ?", @current_end_date.end_of_day) if @current_end_date.present?
          scope
        end

        def normalized_date_range
          start_date = clamp_to_today(parse_date(params[:start_date]))
          end_date = clamp_to_today(parse_date(params[:end_date]))

          if start_date.present? && end_date.present? && start_date > end_date
            [end_date, start_date]
          else
            [start_date, end_date]
          end
        end

        def clamp_to_today(date)
          return if date.blank?

          [date, Time.zone.today].min
        end

        def normalized_page(total_pages)
          page = params[:page].to_i
          page = 1 if page < 1
          page = total_pages if page > total_pages
          page
        end

        def parse_date(value)
          return if value.blank?

          Date.iso8601(value.to_s)
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
