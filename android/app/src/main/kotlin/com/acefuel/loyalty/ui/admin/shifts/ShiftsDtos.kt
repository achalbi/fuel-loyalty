package com.acefuel.loyalty.ui.admin.shifts

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// ============================================================================
// Admin Shift Templates DTOs.
// Backend: app/controllers/api/v1/admin/shift_templates_controller.rb
//          app/serializers/api/v1/admin/shift_template_serializer.rb
//          app/models/shift_template.rb
// Request bodies use the canonical nested envelope ({"shift_template":{...}}).
// `duration_hours` is a virtual write attribute the model rounds into
// `duration_minutes`; timestamps are ISO-8601 strings.
// ============================================================================

// ---- Responses ----

/** GET /api/v1/admin/shift_templates -> { shift_templates: [...] } */
@Serializable
data class ShiftTemplatesIndexResponse(
    @SerialName("shift_templates") val shiftTemplates: List<ShiftTemplateDto> = emptyList(),
)

/**
 * Create/update return this object directly (unwrapped).
 *
 * `duration_hours` is intentionally not modelled: the serializer emits it as a
 * formatted string (e.g. "8", "7.5"), so the edit-form hours are derived from
 * [durationMinutes] instead. Unknown keys are ignored by the shared Json.
 */
@Serializable
data class ShiftTemplateDto(
    val id: Long,
    val name: String,
    val active: Boolean = true,
    @SerialName("start_time") val startTime: String? = null,
    @SerialName("start_time_label") val startTimeLabel: String? = null,
    @SerialName("duration_minutes") val durationMinutes: Int = 0,
    @SerialName("duration_label") val durationLabel: String? = null,
    @SerialName("schedule_label") val scheduleLabel: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
)

// ---- Requests (canonical nested envelope) ----

@Serializable
data class ShiftTemplateEnvelope(
    @SerialName("shift_template") val shiftTemplate: ShiftTemplateRequest,
)

@Serializable
data class ShiftTemplateRequest(
    val name: String,
    @SerialName("start_time") val startTime: String,
    // Decimal hours; the model converts this to duration_minutes on save.
    @SerialName("duration_hours") val durationHours: Double,
    val active: Boolean,
)
