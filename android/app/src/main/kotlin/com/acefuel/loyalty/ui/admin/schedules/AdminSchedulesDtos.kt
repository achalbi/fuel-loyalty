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
    // F2 — channel + audience targeting (mirrors the ad-hoc send).
    val channels: List<String> = listOf("push"),
    @SerialName("target_type") val targetType: String = "all",
    @SerialName("target_customer_type") val targetCustomerType: String? = null,
    @SerialName("campaign_id") val campaignId: Long? = null,
    @SerialName("schedule_summary") val scheduleSummary: String? = null,
)

/** GET /admin/schedules envelope. */
@Serializable
data class SchedulesListResponse(
    val schedules: List<ScheduleDto> = emptyList(),
)

/**
 * POST /admin/schedules/:id/send_now response. Send-now now routes through the
 * shared Broadcaster, so `delivery` is the per-channel { channel: { status: n } }
 * summary (same shape as the ad-hoc SendResponse), not the old FCM count hash.
 */
@Serializable
data class SendNowResponse(
    val schedule: ScheduleDto,
    val delivery: Map<String, Map<String, Int>> = emptyMap(),
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
    // F2 — channel + audience targeting (explicitNulls=false drops nulls).
    val channels: List<String>? = null,
    @SerialName("target_type") val targetType: String? = null,
    @SerialName("target_customer_type") val targetCustomerType: String? = null,
    @SerialName("campaign_id") val campaignId: Long? = null,
)

@Serializable
data class NotificationEnvelope(
    val notification: NotificationRequest,
)

// F2 — targeted, multi-channel ad-hoc send.
@Serializable
data class NotificationRequest(
    val title: String,
    val message: String,
    val category: String? = null,
    val channels: List<String> = listOf("push"),
    @SerialName("target_type") val targetType: String = "all",
    @SerialName("target_customer_type") val targetCustomerType: String? = null,
)

/** POST /admin/notifications/send response — { notification_message_id, delivery{channel{status:n}} }. */
@Serializable
data class SendResponse(
    @SerialName("notification_message_id") val notificationMessageId: Long? = null,
    val delivery: Map<String, Map<String, Int>> = emptyMap(),
)
