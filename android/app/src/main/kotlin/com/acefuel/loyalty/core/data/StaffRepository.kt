package com.acefuel.loyalty.core.data

import com.acefuel.loyalty.core.network.AceFuelApi
import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import com.acefuel.loyalty.core.network.dto.CatalogResponse
import com.acefuel.loyalty.core.network.dto.CustomerProfileDto
import com.acefuel.loyalty.core.network.dto.CustomerSummaryDto
import com.acefuel.loyalty.core.network.dto.CustomerUpdateEnvelope
import com.acefuel.loyalty.core.network.dto.CustomerUpdateRequest
import com.acefuel.loyalty.core.network.dto.LedgerPageDto
import com.acefuel.loyalty.core.network.dto.MyPumpDto
import com.acefuel.loyalty.core.network.dto.MyPumpUpdateEnvelope
import com.acefuel.loyalty.core.network.dto.MyPumpUpdateRequest
import com.acefuel.loyalty.core.network.dto.PointsAdjustmentEnvelope
import com.acefuel.loyalty.core.network.dto.PointsAdjustmentRequest
import com.acefuel.loyalty.core.network.dto.PointsAdjustmentResponse
import com.acefuel.loyalty.core.network.dto.RedemptionEnvelope
import com.acefuel.loyalty.core.network.dto.RedemptionRequest
import com.acefuel.loyalty.core.network.dto.RedemptionResponse
import com.acefuel.loyalty.core.network.dto.RegisterCustomerEnvelope
import com.acefuel.loyalty.core.network.dto.RegisterCustomerRequest
import com.acefuel.loyalty.core.network.dto.RegisterCustomerResponse
import com.acefuel.loyalty.core.network.dto.StaffCustomerDto
import com.acefuel.loyalty.core.network.dto.TransactionCreateEnvelope
import com.acefuel.loyalty.core.network.dto.TransactionCreateRequest
import com.acefuel.loyalty.core.network.dto.TransactionCreateResponse
import com.acefuel.loyalty.core.network.dto.VisitEntryCreateResponse
import com.acefuel.loyalty.core.network.dto.VisitEntryEnvelope
import com.acefuel.loyalty.core.network.dto.VisitEntryRequest
import com.acefuel.loyalty.core.network.dto.VehicleMatchDto
import kotlinx.serialization.json.Json

/** Staff/admin operations: customer lookup (reused widely), redemption, adjustment. */
class StaffRepository(
    private val api: AceFuelApi,
    private val json: Json,
) {
    suspend fun lookupCustomer(phoneNumber: String): ApiResult<StaffCustomerDto> =
        apiCall(json) { api.staffCustomerLookup(phoneNumber) }

    suspend fun redeem(phoneNumber: String, points: Int): ApiResult<RedemptionResponse> =
        apiCall(json) { api.redeem(RedemptionEnvelope(RedemptionRequest(phoneNumber, points))) }

    suspend fun adjustPoints(phoneNumber: String, points: Int): ApiResult<PointsAdjustmentResponse> =
        apiCall(json) { api.adjustPoints(PointsAdjustmentEnvelope(PointsAdjustmentRequest(phoneNumber, points))) }

    suspend fun customers(
        query: String?,
        startDate: String? = null,
        endDate: String? = null,
        type: String? = null,
    ): ApiResult<List<CustomerSummaryDto>> =
        apiCall(json) {
            api.staffCustomers(
                query?.ifBlank { null },
                startDate?.ifBlank { null },
                endDate?.ifBlank { null },
                type?.ifBlank { null },
            ).customers
        }

    suspend fun customerProfile(id: Long): ApiResult<CustomerProfileDto> =
        apiCall(json) { api.staffCustomerProfile(id) }

    suspend fun customerLedger(id: Long, page: Int): ApiResult<LedgerPageDto> =
        apiCall(json) { api.staffCustomerLedger(id, page) }

    // F2 — update a customer's channel opt-ins (and account type).
    suspend fun updateCustomer(id: Long, request: CustomerUpdateRequest): ApiResult<CustomerProfileDto> =
        apiCall(json) { api.staffUpdateCustomer(id, CustomerUpdateEnvelope(request)) }

    suspend fun setPaused(id: Long, paused: Boolean): ApiResult<CustomerProfileDto> =
        apiCall(json) { if (paused) api.pauseRewards(id) else api.resumeRewards(id) }

    suspend fun setActive(id: Long, active: Boolean): ApiResult<CustomerProfileDto> =
        apiCall(json) { if (active) api.activateCustomer(id) else api.deactivateCustomer(id) }

    suspend fun vehicleLookup(vehicleNumber: String): ApiResult<List<VehicleMatchDto>> =
        apiCall(json) { api.vehicleLookup(vehicleNumber).matches }

    /** Active fuel-type / vehicle-kind options for the inline registration form. */
    suspend fun catalog(): ApiResult<CatalogResponse> =
        apiCall(json) { api.catalog() }

    /**
     * Register a customer (find-or-build by phone) and attach the vehicle, so an
     * unregistered plate can become a recordable transaction without leaving the
     * screen. Mirrors the web Staff registration modal.
     */
    suspend fun registerCustomer(request: RegisterCustomerRequest): ApiResult<RegisterCustomerResponse> =
        apiCall(json) { api.registerCustomer(RegisterCustomerEnvelope(request)) }

    suspend fun myPump(): ApiResult<MyPumpDto> =
        apiCall(json) { api.myPump() }

    /**
     * Assign the current staff member's pump + active nozzles. The `""` sentinel
     * is prepended so the server sees the ids array as present (see
     * [MyPumpUpdateRequest]); returns the refreshed assignment incl. `ready`.
     */
    suspend fun updateMyPump(fuelPumpId: Long, nozzleIds: List<Long>): ApiResult<MyPumpDto> =
        apiCall(json) {
            api.updateMyPump(
                MyPumpUpdateEnvelope(
                    MyPumpUpdateRequest(
                        fuelPumpId = fuelPumpId,
                        assignedNozzleIds = listOf("") + nozzleIds.map(Long::toString),
                    ),
                ),
            )
        }

    /** Admin: read a staff member's pump assignment + the pump catalog (A10). */
    suspend fun staffMemberPump(staffMemberId: Long): ApiResult<MyPumpDto> =
        apiCall(json) { api.staffMemberPump(staffMemberId) }

    /** Admin: assign a staff member's pump + active nozzles (A10). */
    suspend fun updateStaffMemberPump(staffMemberId: Long, fuelPumpId: Long, nozzleIds: List<Long>): ApiResult<MyPumpDto> =
        apiCall(json) {
            api.updateStaffMemberPump(
                staffMemberId,
                MyPumpUpdateEnvelope(
                    MyPumpUpdateRequest(
                        fuelPumpId = fuelPumpId,
                        assignedNozzleIds = listOf("") + nozzleIds.map(Long::toString),
                    ),
                ),
            )
        }

    suspend fun createTransaction(request: TransactionCreateRequest): ApiResult<TransactionCreateResponse> =
        apiCall(json) { api.createTransaction(TransactionCreateEnvelope(request)) }

    // B2 — record an FSM per-visit capture.
    suspend fun createVisitEntry(request: VisitEntryRequest): ApiResult<VisitEntryCreateResponse> =
        apiCall(json) { api.createVisitEntry(VisitEntryEnvelope(request)) }
}
