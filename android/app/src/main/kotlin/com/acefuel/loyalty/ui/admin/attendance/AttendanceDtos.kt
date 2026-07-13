package com.acefuel.loyalty.ui.admin.attendance

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// ============================================================================
// Attendance admin DTOs.
// Backend: app/controllers/api/v1/admin/attendance_runs_controller.rb
//          app/serializers/api/v1/admin/attendance_run_serializer.rb
//          app/serializers/api/v1/admin/attendance_entry_serializer.rb
//          app/serializers/api/v1/admin/shift_template_serializer.rb
//          app/serializers/api/v1/user_serializer.rb
// Timestamps are ISO-8601 strings; there are no decimals in this payload
// (duration_hours can be fractional so it is modeled as Double).
// ============================================================================

// ---- Shared user payload (Api::V1::UserSerializer) ----
@Serializable
data class AttendanceUserDto(
    val id: Long,
    val name: String? = null,
    val username: String? = null,
    val role: String? = null,
    @SerialName("phone_number") val phoneNumber: String? = null,
    @SerialName("display_name") val displayName: String? = null,
    @SerialName("display_phone_number") val displayPhoneNumber: String? = null,
    val email: String? = null,
    @SerialName("employee_code") val employeeCode: String? = null,
    val subtitle: String? = null,
    @SerialName("avatar_initial") val avatarInitial: String? = null,
    val active: Boolean = true,
)

@Serializable
data class ShiftTemplateDto(
    val id: Long,
    val name: String,
    val active: Boolean = true,
    @SerialName("start_time") val startTime: String? = null,
    @SerialName("start_time_label") val startTimeLabel: String? = null,
    @SerialName("duration_minutes") val durationMinutes: Int = 0,
    @SerialName("duration_hours") val durationHours: Double? = null,
    @SerialName("duration_label") val durationLabel: String? = null,
    @SerialName("schedule_label") val scheduleLabel: String? = null,
)

/** GET /api/v1/admin/shift_templates -> { shift_templates: [...] } (planner source). */
@Serializable
data class ShiftTemplatesResponse(
    @SerialName("shift_templates") val shiftTemplates: List<ShiftTemplateDto> = emptyList(),
)

@Serializable
data class AttendanceEntryDto(
    val id: Long? = null, // null for unsaved planner-built rows
    val status: String = "present",
    @SerialName("worker_name") val workerName: String? = null,
    @SerialName("scheduled_user") val scheduledUser: AttendanceUserDto? = null,
    @SerialName("actual_user") val actualUser: AttendanceUserDto? = null,
    @SerialName("replacement_user") val replacementUser: AttendanceUserDto? = null,
    @SerialName("external_replacement_name") val externalReplacementName: String? = null,
    @SerialName("check_in_at") val checkInAt: String? = null,
    @SerialName("check_out_at") val checkOutAt: String? = null,
    val overridden: Boolean = false,
    val notes: String? = null,
)

@Serializable
data class AttendanceRunDto(
    val id: Long,
    @SerialName("shift_template_id") val shiftTemplateId: Long? = null,
    @SerialName("shift_name") val shiftName: String? = null,
    @SerialName("duration_snapshot_minutes") val durationSnapshotMinutes: Int? = null,
    @SerialName("starts_at") val startsAt: String? = null,
    @SerialName("ends_at") val endsAt: String? = null,
    val stale: Boolean = false,
    @SerialName("record_state_label") val recordStateLabel: String = "Valid",
    val notes: String? = null,
    @SerialName("shift_template") val shiftTemplate: ShiftTemplateDto? = null,
    @SerialName("recorded_by") val recordedBy: AttendanceUserDto? = null,
    @SerialName("status_counts") val statusCounts: Map<String, Int> = emptyMap(),
    @SerialName("entry_count") val entryCount: Int = 0,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
    val entries: List<AttendanceEntryDto> = emptyList(),
)

/** GET /api/v1/admin/attendance_runs (paged, 6/page). */
@Serializable
data class AttendanceRunsIndexResponse(
    @SerialName("attendance_runs") val attendanceRuns: List<AttendanceRunDto> = emptyList(),
    val filter: String = "all",
    @SerialName("start_date") val startDate: String? = null,
    @SerialName("end_date") val endDate: String? = null,
    val page: Int = 1,
    @SerialName("per_page") val perPage: Int = 6,
    val total: Int = 0,
    @SerialName("total_pages") val totalPages: Int = 1,
    @SerialName("showing_from") val showingFrom: Int = 0,
    @SerialName("showing_to") val showingTo: Int = 0,
)

/**
 * GET /api/v1/admin/attendance_runs/new -> planner preview. [entries] holds the
 * rostered staff rows for the chosen window; [errors] carries base errors
 * (duplicate window / cycle-misalignment) instead of rows.
 */
@Serializable
data class AttendancePlannerResponse(
    @SerialName("shift_template") val shiftTemplate: ShiftTemplateDto? = null,
    @SerialName("starts_at") val startsAt: String? = null,
    @SerialName("ends_at") val endsAt: String? = null,
    val entries: List<AttendanceEntryDto> = emptyList(),
    val errors: List<String> = emptyList(),
)

/** DELETE /api/v1/admin/attendance_runs/:id -> { message }. */
@Serializable
data class AttendanceMessageResponse(
    val message: String? = null,
)

// ---- Requests (canonical nested envelope) ----

@Serializable
data class AttendanceRunEnvelope(
    @SerialName("attendance_run") val attendanceRun: AttendanceRunRequest,
)

@Serializable
data class AttendanceRunRequest(
    @SerialName("shift_template_id") val shiftTemplateId: Long,
    @SerialName("starts_at") val startsAt: String,
    @SerialName("ends_at") val endsAt: String,
    val stale: Boolean = false,
    val notes: String? = null,
    @SerialName("attendance_entries_attributes") val attendanceEntriesAttributes: List<AttendanceEntryAttributes>,
)

/**
 * A single accepts_nested_attributes_for row. Null fields are dropped by the
 * shared Json (explicitNulls=false) so the Rails model's sync_actual_user /
 * worker_name logic behaves as it does on the web.
 */
@Serializable
data class AttendanceEntryAttributes(
    @SerialName("scheduled_user_id") val scheduledUserId: Long,
    @SerialName("actual_user_id") val actualUserId: Long? = null,
    @SerialName("replacement_user_id") val replacementUserId: Long? = null,
    @SerialName("external_replacement_name") val externalReplacementName: String? = null,
    val status: String,
    @SerialName("check_in_at") val checkInAt: String? = null,
    @SerialName("check_out_at") val checkOutAt: String? = null,
    val notes: String? = null,
)
