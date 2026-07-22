package com.acefuel.loyalty.ui.admin.crm

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Additive CRM state for the shared customer profile: feedback (all users) plus
 * insight + outreach (admin only). Kept separate from [CustomerProfileViewModel]
 * so the profile screen's existing flow is untouched — this VM only powers the
 * new Feedback / CRM Insight / Outreach sections.
 */
data class CustomerCrmUiState(
    // Feedback — loaded for everyone.
    val feedbackLoading: Boolean = true,
    val feedbacks: List<FeedbackDto> = emptyList(),
    val feedbackCount: Int = 0,
    val avgRating: Double? = null,
    // Insight + contact logs — loaded only for admins.
    val insightLoading: Boolean = false,
    val insight: InsightDto? = null,
    val contactLogs: List<ContactLogDto> = emptyList(),
    // In-flight flags for the two POST actions.
    val submittingFeedback: Boolean = false,
    val loggingContact: Boolean = false,
    // One-shot messages surfaced through the profile screen's snackbar.
    val actionMessage: String? = null,
    val transientError: String? = null,
)

class CustomerCrmViewModel(
    private val repository: CrmRepository,
    private val customerId: Long,
    private val isAdmin: Boolean,
) : ViewModel() {

    private val _state = MutableStateFlow(CustomerCrmUiState(insightLoading = isAdmin))
    val state: StateFlow<CustomerCrmUiState> = _state.asStateFlow()

    init {
        loadFeedback()
        if (isAdmin) loadInsight()
    }

    fun loadFeedback() {
        _state.update { it.copy(feedbackLoading = true) }
        viewModelScope.launch {
            when (val result = repository.feedbacks(customerId)) {
                is ApiResult.Success -> _state.update {
                    it.copy(
                        feedbackLoading = false,
                        feedbacks = result.data.feedbacks,
                        feedbackCount = result.data.count,
                        avgRating = result.data.avgRating,
                    )
                }
                is ApiResult.Error -> _state.update { it.copy(feedbackLoading = false, transientError = result.message) }
                is ApiResult.NetworkError ->
                    _state.update { it.copy(feedbackLoading = false, transientError = "Couldn't reach the server. Try again.") }
            }
        }
    }

    fun loadInsight() {
        if (!isAdmin) return
        _state.update { it.copy(insightLoading = true) }
        viewModelScope.launch {
            // Insight and contact logs are independent reads; fetch both, and let
            // insightLoading clear once the second (contact logs) resolves.
            when (val result = repository.insight(customerId)) {
                is ApiResult.Success -> _state.update { it.copy(insight = result.data) }
                is ApiResult.Error -> _state.update { it.copy(transientError = result.message) }
                is ApiResult.NetworkError ->
                    _state.update { it.copy(transientError = "Couldn't reach the server. Try again.") }
            }
            when (val result = repository.contactLogs(customerId)) {
                is ApiResult.Success ->
                    _state.update { it.copy(insightLoading = false, contactLogs = result.data.contactLogs) }
                is ApiResult.Error -> _state.update { it.copy(insightLoading = false, transientError = result.message) }
                is ApiResult.NetworkError ->
                    _state.update { it.copy(insightLoading = false, transientError = "Couldn't reach the server. Try again.") }
            }
        }
    }

    /** POST a 1–5 rating, then reload feedback (and the insight summary if admin). */
    fun addFeedback(rating: Int, comment: String?) {
        if (_state.value.submittingFeedback) return
        _state.update { it.copy(submittingFeedback = true, transientError = null) }
        viewModelScope.launch {
            val request = FeedbackRequest(
                FeedbackBody(rating = rating, comment = comment?.trim()?.takeUnless { it.isBlank() }),
            )
            when (val result = repository.createFeedback(customerId, request)) {
                is ApiResult.Success -> {
                    _state.update { it.copy(submittingFeedback = false, actionMessage = "Rating saved") }
                    loadFeedback()
                    if (isAdmin) loadInsight() // insight's feedback summary reflects the new rating
                }
                is ApiResult.Error -> _state.update { it.copy(submittingFeedback = false, transientError = result.message) }
                is ApiResult.NetworkError ->
                    _state.update { it.copy(submittingFeedback = false, transientError = "Couldn't reach the server. Try again.") }
            }
        }
    }

    /** POST an outreach log, then reload insight + contact logs (admin only). */
    fun logContact(
        channel: String,
        outcome: String,
        contactedRole: String?,
        customerContactId: Long?,
        notes: String?,
    ) {
        if (_state.value.loggingContact) return
        _state.update { it.copy(loggingContact = true, transientError = null) }
        viewModelScope.launch {
            val request = ContactLogRequest(
                ContactLogBody(
                    channel = channel,
                    outcome = outcome,
                    contactedRole = contactedRole,
                    customerContactId = customerContactId,
                    notes = notes?.trim()?.takeUnless { it.isBlank() },
                ),
            )
            when (val result = repository.createContactLog(customerId, request)) {
                is ApiResult.Success -> {
                    _state.update { it.copy(loggingContact = false, actionMessage = "Contact logged") }
                    loadInsight()
                }
                is ApiResult.Error -> _state.update { it.copy(loggingContact = false, transientError = result.message) }
                is ApiResult.NetworkError ->
                    _state.update { it.copy(loggingContact = false, transientError = "Couldn't reach the server. Try again.") }
            }
        }
    }

    fun consumeActionMessage() = _state.update { it.copy(actionMessage = null) }

    fun consumeTransientError() = _state.update { it.copy(transientError = null) }
}
