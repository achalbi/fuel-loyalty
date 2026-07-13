package com.acefuel.loyalty.ui.admin.staff

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// ============================================================================
// Admin Staff DTOs.
// Backend:
//   app/controllers/api/v1/admin/staff_members_controller.rb
//   app/controllers/api/v1/admin/shift_assignments_controller.rb
//   app/controllers/api/v1/admin/shift_templates_controller.rb
//   app/serializers/api/v1/admin/staff_member_serializer.rb  (User base + shift)
//   app/serializers/api/v1/admin/shift_template_serializer.rb
//   app/serializers/api/v1/admin/shift_assignment_serializer.rb
// Request bodies use the canonical nested envelope ({"user":{...}} /
// {"shift_assignment":{...}}). Timestamps are ISO-8601 strings; unknown keys are
// ignored by the shared Json.
// ============================================================================

// ---- Responses ----

/** GET /api/v1/admin/staff_members -> { staff_members: [...], stats: {...} } */
@Serializable
data class StaffMembersResponse(
    @SerialName("staff_members") val staffMembers: List<StaffMemberDto> = emptyList(),
    val stats: StaffStatsDto = StaffStatsDto(),
)

@Serializable
data class StaffStatsDto(
    val active: Int = 0,
    val inactive: Int = 0,
    val unassigned: Int = 0,
    val total: Int = 0,
)

/**
 * A staff-role user: the shared UserSerializer fields plus the currently
 * assigned shift template + cycle (either may be null when unassigned).
 */
@Serializable
data class StaffMemberDto(
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
    @SerialName("current_shift_template") val currentShiftTemplate: ShiftTemplateDto? = null,
    @SerialName("current_shift_cycle") val currentShiftCycle: ShiftCycleRefDto? = null,
)

/**
 * Shift template (from ShiftTemplateSerializer). `duration_hours` is
 * intentionally not modelled: the serializer emits it as a formatted string
 * ("8", "7.5"), so display uses [durationLabel] / [scheduleLabel] instead.
 */
@Serializable
data class ShiftTemplateDto(
    val id: Long,
    val name: String = "",
    val active: Boolean = true,
    @SerialName("start_time") val startTime: String? = null,
    @SerialName("start_time_label") val startTimeLabel: String? = null,
    @SerialName("duration_minutes") val durationMinutes: Int = 0,
    @SerialName("duration_label") val durationLabel: String? = null,
    @SerialName("schedule_label") val scheduleLabel: String? = null,
)

/** Lightweight shift-cycle reference embedded in the staff/assignment payload. */
@Serializable
data class ShiftCycleRefDto(
    val id: Long,
    val name: String? = null,
    @SerialName("sequence_label") val sequenceLabel: String? = null,
)

/** GET /api/v1/admin/shift_templates -> { shift_templates: [...] } */
@Serializable
data class ShiftTemplatesResponse(
    @SerialName("shift_templates") val shiftTemplates: List<ShiftTemplateDto> = emptyList(),
)

/** POST .../shift_assignments returns this object directly (unwrapped). */
@Serializable
data class ShiftAssignmentDto(
    val id: Long,
    @SerialName("user_id") val userId: Long? = null,
    val active: Boolean = true,
    val notes: String? = null,
    @SerialName("effective_from") val effectiveFrom: String? = null,
    @SerialName("effective_to") val effectiveTo: String? = null,
    @SerialName("shift_template") val shiftTemplate: ShiftTemplateDto? = null,
    @SerialName("shift_cycle") val shiftCycle: ShiftCycleRefDto? = null,
)

// ---- Requests (canonical nested envelope) ----

/** PATCH /api/v1/admin/staff_members/:id  { "user": { ... } } */
@Serializable
data class StaffUpdateEnvelope(val user: StaffUpdateRequest)

@Serializable
data class StaffUpdateRequest(
    val name: String,
    @SerialName("employee_code") val employeeCode: String,
    val subtitle: String,
    val active: Boolean,
)

/** POST .../:id/shift_assignments  { "shift_assignment": { ... } } */
@Serializable
data class ShiftAssignmentEnvelope(
    @SerialName("shift_assignment") val shiftAssignment: ShiftAssignmentRequest,
)

@Serializable
data class ShiftAssignmentRequest(
    @SerialName("shift_template_id") val shiftTemplateId: Long,
    val notes: String? = null,
)
