package com.acefuel.loyalty.ui.admin.cycles

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// ============================================================================
// Shift Cycles admin DTOs.
// Backend serializers:
//   app/serializers/api/v1/admin/shift_cycle_serializer.rb
//   app/serializers/api/v1/admin/shift_template_serializer.rb
// Timestamps + starts_on are ISO-8601 strings; duration_hours is a Double.
// NOTE: the shift_cycle payload does NOT expose an assigned-staff count; whether
// a cycle is in use is inferred from [ShiftCycleDto.deletable] (false == has
// staff assignment history).
// ============================================================================

// ---- Responses ----

/** GET /api/v1/admin/shift_cycles -> { shift_cycles: [...] } */
@Serializable
data class ShiftCyclesResponse(
    @SerialName("shift_cycles") val shiftCycles: List<ShiftCycleDto> = emptyList(),
)

@Serializable
data class ShiftCycleDto(
    val id: Long,
    val name: String = "",
    val active: Boolean = true,
    @SerialName("starts_on") val startsOn: String? = null,
    @SerialName("starts_at_label") val startsAtLabel: String? = null,
    @SerialName("sequence_label") val sequenceLabel: String? = null,
    @SerialName("schedule_label") val scheduleLabel: String? = null,
    @SerialName("cycle_duration_minutes") val cycleDurationMinutes: Int? = null,
    @SerialName("cycle_duration_label") val cycleDurationLabel: String? = null,
    val deletable: Boolean = true,
    val steps: List<ShiftCycleStepDto> = emptyList(),
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
)

@Serializable
data class ShiftCycleStepDto(
    val position: Int = 0,
    @SerialName("shift_template_id") val shiftTemplateId: Long,
    @SerialName("shift_template_name") val shiftTemplateName: String? = null,
)

/** GET /api/v1/admin/shift_templates -> { shift_templates: [...] } (step-picker source). */
@Serializable
data class ShiftTemplatesResponse(
    @SerialName("shift_templates") val shiftTemplates: List<ShiftTemplateDto> = emptyList(),
)

@Serializable
data class ShiftTemplateDto(
    val id: Long,
    val name: String = "",
    val active: Boolean = true,
    @SerialName("start_time") val startTime: String? = null,
    @SerialName("start_time_label") val startTimeLabel: String? = null,
    @SerialName("duration_minutes") val durationMinutes: Int? = null,
    @SerialName("duration_hours") val durationHours: Double? = null,
    @SerialName("duration_label") val durationLabel: String? = null,
    @SerialName("schedule_label") val scheduleLabel: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
) {
    /** Menu label, e.g. "Morning · 6:00 AM (8h)". */
    val menuLabel: String
        get() = buildString {
            append(name)
            val meta = listOfNotNull(startTimeLabel?.takeIf { it.isNotBlank() }, durationLabel?.takeIf { it.isNotBlank() })
            if (meta.isNotEmpty()) append(" · ").append(meta.joinToString(" · "))
        }
}

/** DELETE /api/v1/admin/shift_cycles/:id -> 204 (empty body, hence nullable). */
@Serializable
data class DeleteResponse(val message: String? = null)

// ---- Requests (canonical nested envelopes) ----

@Serializable
data class ShiftCycleEnvelope(
    @SerialName("shift_cycle") val shiftCycle: ShiftCycleRequest,
)

@Serializable
data class ShiftCycleRequest(
    val name: String,
    @SerialName("starts_on") val startsOn: String,
    val active: Boolean,
    @SerialName("step_shift_template_ids") val stepShiftTemplateIds: List<Long>,
)

/** Empty JSON object body for the bodyless activate/deactivate PATCH routes. */
@Serializable
class EmptyBody
