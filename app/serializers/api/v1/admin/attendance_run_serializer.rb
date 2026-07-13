module Api
  module V1
    module Admin
      # A recorded attendance session for one shift template + time window.
      # Reads the immutable snapshot columns (shift_name_snapshot /
      # duration_snapshot_minutes) rather than the live template.
      class AttendanceRunSerializer
        def self.call(run, include_entries: false)
          data = {
            id: run.id,
            shift_template_id: run.shift_template_id,
            shift_name: run.shift_name_snapshot,
            duration_snapshot_minutes: run.duration_snapshot_minutes,
            starts_at: run.starts_at&.iso8601,
            ends_at: run.ends_at&.iso8601,
            stale: run.stale,
            record_state_label: run.record_state_label, # "Valid" | "Invalid"
            notes: run.notes,
            shift_template: shift_template_json(run.shift_template),
            recorded_by: run.recorded_by ? Api::V1::UserSerializer.call(run.recorded_by) : nil,
            status_counts: status_counts_json(run),
            entry_count: run.attendance_entries.size,
            created_at: run.created_at&.iso8601,
            updated_at: run.updated_at&.iso8601,
          }
          if include_entries
            data[:entries] = run.attendance_entries.map { |entry| AttendanceEntrySerializer.call(entry) }
          end
          data
        end

        # Full status-key hash, zero-filled (mirrors the web show action).
        def self.status_counts_json(run)
          counts = run.status_counts
          AttendanceEntry.statuses.keys.index_with { |status| counts.fetch(status, 0) }
        end

        def self.shift_template_json(template)
          return nil if template.nil?

          {
            id: template.id,
            name: template.name,
            start_time: template.start_time,
            start_time_label: template.start_time_label,
            duration_minutes: template.duration_minutes,
            duration_label: template.duration_label,
            schedule_label: template.schedule_label,
          }
        end
      end
    end
  end
end
