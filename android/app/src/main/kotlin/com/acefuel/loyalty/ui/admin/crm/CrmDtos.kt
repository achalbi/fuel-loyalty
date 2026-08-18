package com.acefuel.loyalty.ui.admin.crm

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// ============================================================================
// Phase 4 — CRM intelligence payloads. Backend:
//   app/controllers/api/v1/admin/customers_controller.rb   (insight, contact_logs)
//   app/controllers/api/v1/admin/dashboard_controller.rb   (churn)
//   app/controllers/api/v1/staff/feedbacks_controller.rb   (feedbacks)
// json is configured ignoreUnknownKeys=true, so only the fields we read need
// declaring; snake_case wire names carry @SerialName.
// ============================================================================

// ---- Insight (admin) -------------------------------------------------------

@Serializable
data class InsightDto(
    @SerialName("customer_id") val customerId: Long,
    @SerialName("first_visited_on") val firstVisitedOn: String? = null,
    @SerialName("last_visited_on") val lastVisitedOn: String? = null,
    @SerialName("days_since_last_visit") val daysSinceLastVisit: Int? = null,
    @SerialName("visit_count") val visitCount: Int = 0,
    @SerialName("cadence_class") val cadenceClass: String,
    @SerialName("cadence_label") val cadenceLabel: String,
    @SerialName("median_gap_days") val medianGapDays: Int? = null,
    @SerialName("expected_next_visit_on") val expectedNextVisitOn: String? = null,
    @SerialName("is_lost") val isLost: Boolean = false,
    @SerialName("conversion_probability") val conversionProbability: Int = 0,
    val metrics: CustomerMetricsDto = CustomerMetricsDto(),
    // Present only when the insight was requested for a period.
    @SerialName("lifetime_metrics") val lifetimeMetrics: CustomerMetricsDto? = null,
    val contacts: ContactsSummaryDto = ContactsSummaryDto(),
    val feedback: FeedbackSummaryDto = FeedbackSummaryDto(),
)

// What the customer has taken and cost us: litres filled, discount given, and the
// rupee value of the gifts (reward redemptions) they redeemed.
@Serializable
data class CustomerMetricsDto(
    val visits: Int = 0,
    val litres: Double = 0.0,
    val discount: Double = 0.0,
    val gifts: Double = 0.0,
    val contacts: Int = 0,
    val points: Int = 0,
)

@Serializable
data class ContactsSummaryDto(
    val count: Int = 0,
    @SerialName("last_contacted_at") val lastContactedAt: String? = null,
    @SerialName("last_outcome") val lastOutcome: String? = null,
    @SerialName("last_outcome_label") val lastOutcomeLabel: String? = null,
)

@Serializable
data class FeedbackSummaryDto(
    val count: Int = 0,
    @SerialName("avg_rating") val avgRating: Double? = null,
    @SerialName("latest_rating") val latestRating: Int? = null,
    @SerialName("latest_comment") val latestComment: String? = null,
)

// ---- Contact logs (admin) --------------------------------------------------

@Serializable
data class ContactLogDto(
    val id: Long,
    @SerialName("customer_id") val customerId: Long,
    val channel: String,
    @SerialName("channel_label") val channelLabel: String,
    val outcome: String,
    @SerialName("outcome_label") val outcomeLabel: String,
    @SerialName("contacted_role") val contactedRole: String? = null,
    @SerialName("customer_contact_id") val customerContactId: Long? = null,
    val notes: String? = null,
    @SerialName("logged_by") val loggedBy: String? = null,
    @SerialName("contacted_at") val contactedAt: String,
)

@Serializable
data class ContactLogListResponse(
    @SerialName("contact_logs") val contactLogs: List<ContactLogDto> = emptyList(),
)

@Serializable
data class ContactLogBody(
    val channel: String,
    val outcome: String,
    @SerialName("contacted_role") val contactedRole: String? = null,
    @SerialName("customer_contact_id") val customerContactId: Long? = null,
    val notes: String? = null,
)

@Serializable
data class ContactLogRequest(
    @SerialName("contact_log") val contactLog: ContactLogBody,
)

// ---- Churn / reach-out list (admin) ---------------------------------------

@Serializable
data class ChurnResponse(
    val period: ChurnPeriodDto = ChurnPeriodDto(),
    @SerialName("previous_period") val previousPeriod: ChurnPeriodDto = ChurnPeriodDto(),
    val page: Int = 1,
    @SerialName("per_page") val perPage: Int = 0,
    val total: Int = 0,
    @SerialName("has_more") val hasMore: Boolean = false,
    val customers: List<ChurnCustomerDto> = emptyList(),
)

@Serializable
data class ChurnPeriodDto(
    @SerialName("start_date") val startDate: String? = null,
    @SerialName("end_date") val endDate: String? = null,
)

@Serializable
data class ChurnCustomerDto(
    val id: Long,
    val name: String,
    @SerialName("phone_number") val phoneNumber: String,
    @SerialName("customer_type") val customerType: String,
    @SerialName("customer_type_label") val customerTypeLabel: String,
    @SerialName("visit_count") val visitCount: Int = 0,
    @SerialName("last_visited_on") val lastVisitedOn: String? = null,
    @SerialName("cadence_class") val cadenceClass: String,
    @SerialName("cadence_label") val cadenceLabel: String,
    @SerialName("expected_next_visit_on") val expectedNextVisitOn: String? = null,
    @SerialName("days_overdue") val daysOverdue: Int? = null,
    @SerialName("conversion_probability") val conversionProbability: Int = 0,
    val contacts: ContactsSummaryDto = ContactsSummaryDto(),
)

// ---- Feedback (staff endpoint; works for staff + admin tokens) -------------

@Serializable
data class FeedbackDto(
    val id: Long,
    @SerialName("customer_id") val customerId: Long,
    val rating: Int,
    val comment: String? = null,
    val source: String,
    @SerialName("source_label") val sourceLabel: String,
    @SerialName("transaction_id") val transactionId: Long? = null,
    @SerialName("visit_entry_id") val visitEntryId: Long? = null,
    @SerialName("recorded_by") val recordedBy: String? = null,
    @SerialName("created_at") val createdAt: String,
)

@Serializable
data class FeedbackListResponse(
    val feedbacks: List<FeedbackDto> = emptyList(),
    val count: Int = 0,
    @SerialName("avg_rating") val avgRating: Double? = null,
)

@Serializable
data class FeedbackBody(
    val rating: Int,
    val comment: String? = null,
)

@Serializable
data class FeedbackRequest(
    val feedback: FeedbackBody,
)
