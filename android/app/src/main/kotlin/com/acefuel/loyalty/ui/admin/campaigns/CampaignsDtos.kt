package com.acefuel.loyalty.ui.admin.campaigns

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// F1 campaign DTOs. Backend:
//   app/controllers/api/v1/admin/campaigns_controller.rb
//   app/serializers/api/v1/admin/campaign_serializer.rb
@Serializable
data class CampaignDto(
    val id: Long,
    val name: String,
    val description: String? = null,
    @SerialName("reward_kind") val rewardKind: String,
    @SerialName("discount_amount") val discountAmount: Double? = null,
    @SerialName("discount_percent") val discountPercent: Double? = null,
    @SerialName("gift_description") val giftDescription: String? = null,
    @SerialName("bonus_points") val bonusPoints: Int? = null,
    @SerialName("min_purchase_amount") val minPurchaseAmount: Double? = null,
    @SerialName("min_purchase_litres") val minPurchaseLitres: Double? = null,
    val period: String,
    @SerialName("period_days") val periodDays: Int? = null,
    @SerialName("target_type") val targetType: String,
    @SerialName("target_customer_type") val targetCustomerType: String? = null,
    val channels: List<String> = emptyList(),
    val status: String,
    @SerialName("offer_headline") val offerHeadline: String? = null,
    @SerialName("qualification_count") val qualificationCount: Int = 0,
)

@Serializable
data class CampaignListResponse(val campaigns: List<CampaignDto> = emptyList())

@Serializable
data class CampaignPreviewResponse(
    @SerialName("qualifying_count") val qualifyingCount: Int = 0,
    val sample: List<CampaignSampleDto> = emptyList(),
    val reachable: Map<String, Int> = emptyMap(),
)

@Serializable
data class CampaignSampleDto(
    @SerialName("customer_id") val customerId: Long,
    val name: String? = null,
    @SerialName("aggregated_amount") val aggregatedAmount: Double = 0.0,
    @SerialName("aggregated_litres") val aggregatedLitres: Double = 0.0,
)

@Serializable
data class CampaignRunResponse(
    val qualified: Int = 0,
    val rewarded: Int = 0,
    @SerialName("notification_message_id") val notificationMessageId: Long? = null,
    val delivery: Map<String, Map<String, Int>> = emptyMap(),
)
