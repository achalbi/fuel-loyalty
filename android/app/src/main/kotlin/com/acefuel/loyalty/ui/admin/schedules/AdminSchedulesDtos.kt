package com.acefuel.loyalty.ui.admin.schedules

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// ============================================================================
// Notification-schedule + push DTOs — mirror of
//   Api::V1::Admin::NotificationScheduleSerializer,
//   NotificationScheduleRunner::Result, FirebasePushService::Result.
//
// Responses use snake_case keys (@SerialName). Requests use the canonical
// nested envelope keyed by the resource ("notification_schedule" / "notification").
// The shared Json omits nulls (explicitNulls = false) so frequency-irrelevant
// conditional fields are dropped from the request body; the server also nulls
// them per-frequency on save.
// ============================================================================

// ---- Responses ----

/** One saved schedule. `scheduledDate` is an ISO date (yyyy-MM-dd); `scheduledTime` a raw "HH:MM". */
@Serializable
data class ScheduleDto(
    val id: Long,
    val title: String = "",
    val message: String = "",
    val frequency: String = "daily",
    @SerialName("scheduled_time") val scheduledTime: String? = null,
    @SerialName("scheduled_date") val scheduledDate: String? = null,
    @SerialName("day_of_week") val dayOfWeek: Int? = null,
    @SerialName("day_of_month") val dayOfMonth: Int? = null,
    @SerialName("last_sent_at") val lastSentAt: String? = null,
    val active: Boolean = true,
    @SerialName("schedule_summary") val scheduleSummary: String? = null,
)

/** GET /admin/schedules envelope. */
@Serializable
data class SchedulesListResponse(
    val schedules: List<ScheduleDto> = emptyList(),
)

/** FirebasePushService result hash. `errors[]` is intentionally omitted (only counts are surfaced). */
@Serializable
data class DeliveryResultDto(
    val requested: Int = 0,
    val sent: Int = 0,
    val failed: Int = 0,
    val invalidated: Int = 0,
    val batches: Int = 0,
)

/** POST /admin/schedules/:id/send_now response. */
@Serializable
data class SendNowResponse(
    val schedule: ScheduleDto,
    val delivery: DeliveryResultDto = DeliveryResultDto(),
)

/** POST /admin/schedules/run — NotificationScheduleRunner::Result (details[] omitted). */
@Serializable
data class RunResultDto(
    val checked: Int = 0,
    val due: Int = 0,
    val sent: Int = 0,
    val failed: Int = 0,
    val acquired: Boolean = false,
    val skipped: Boolean = false,
    val message: String? = null,
)

// ---- Requests (nested envelopes) ----

@Serializable
data class ScheduleEnvelope(
    @SerialName("notification_schedule") val notificationSchedule: ScheduleRequest,
)

@Serializable
data class ScheduleRequest(
    val title: String,
    val message: String,
    val frequency: String,
    @SerialName("scheduled_time") val scheduledTime: String,
    @SerialName("scheduled_date") val scheduledDate: String? = null,
    @SerialName("day_of_week") val dayOfWeek: Int? = null,
    @SerialName("day_of_month") val dayOfMonth: Int? = null,
    val active: Boolean,
)

@Serializable
data class NotificationEnvelope(
    val notification: NotificationRequest,
)

@Serializable
data class NotificationRequest(
    val title: String,
    val message: String,
)
