package com.acefuel.loyalty.ui.admin.notifications

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// Mirror of Api::V1::Admin::NotificationMessageSerializer + the recipients JSON
// from NotificationsController#recipients. The `delivery` map is the persistent
// per-channel/per-status tally (delivery_summary) — the record the ephemeral FCM
// result never was.

/** GET /api/v1/admin/notifications -> { "notifications": [ ... ] } */
@Serializable
data class NotificationsListResponse(
    val notifications: List<NotificationMessageDto> = emptyList(),
)

@Serializable
data class NotificationMessageDto(
    val id: Long,
    val title: String = "",
    val body: String? = null,
    val category: String? = null,
    @SerialName("target_type") val targetType: String? = null,
    @SerialName("target_customer_type") val targetCustomerType: String? = null,
    val channels: List<String> = emptyList(),
    @SerialName("created_by") val createdBy: String? = null,
    /** { channel -> { status -> count } }, e.g. {"push":{"sent":12,"skipped":3}}. */
    val delivery: Map<String, Map<String, Int>> = emptyMap(),
    @SerialName("recipient_count") val recipientCount: Int = 0,
    @SerialName("created_at") val createdAt: String? = null,
)

/** GET /api/v1/admin/notifications/:id/recipients -> { "recipients": [ ... ] } */
@Serializable
data class RecipientsResponse(
    val recipients: List<NotificationRecipientDto> = emptyList(),
)

@Serializable
data class NotificationRecipientDto(
    @SerialName("customer_id") val customerId: Long? = null,
    @SerialName("customer_name") val customerName: String? = null,
    val channel: String = "",
    val status: String = "",
    val error: String? = null,
    @SerialName("provider_message_id") val providerMessageId: String? = null,
    @SerialName("sent_at") val sentAt: String? = null,
)
