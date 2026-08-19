package com.acefuel.loyalty.core.network.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// ---- Requests ----

@Serializable
data class LoginRequest(
    val login: String,
    val password: String,
)

@Serializable
data class RefreshRequest(
    @SerialName("refresh_token") val refreshToken: String,
)

// Requests use the canonical nested `model[...]` envelope (see API param convention).

@Serializable
data class LoyaltyLookupRequest(
    @SerialName("phone_number") val phoneNumber: String,
    @SerialName("full_history") val fullHistory: Boolean = false,
)

@Serializable
data class LoyaltyLookupEnvelope(val loyalty: LoyaltyLookupRequest)

// ---- Responses ----

@Serializable
data class AuthResponse(
    @SerialName("access_token") val accessToken: String,
    @SerialName("refresh_token") val refreshToken: String,
    @SerialName("token_type") val tokenType: String,
    @SerialName("expires_in") val expiresIn: Long,
    val user: UserDto,
)

@Serializable
data class MeResponse(val user: UserDto)

@Serializable
data class UserDto(
    val id: Long,
    val name: String?,
    val username: String?,
    val role: String,
    @SerialName("phone_number") val phoneNumber: String?,
    @SerialName("display_name") val displayName: String?,
    @SerialName("display_phone_number") val displayPhoneNumber: String?,
    val email: String?,
    @SerialName("employee_code") val employeeCode: String?,
    val subtitle: String?,
    @SerialName("avatar_initial") val avatarInitial: String?,
    val active: Boolean,
)

@Serializable
data class ThemeDto(
    @SerialName("primary_color") val primaryColor: String,
    @SerialName("updated_at") val updatedAt: String? = null,
)

@Serializable
data class LoyaltyResponse(
    val customer: LoyaltyCustomerDto,
    @SerialName("total_points") val totalPoints: Int,
    @SerialName("rewards_paused") val rewardsPaused: Boolean,
    @SerialName("minimum_redeemable_points") val minimumRedeemablePoints: Int,
    @SerialName("max_redeemable_points") val maxRedeemablePoints: Int,
    @SerialName("points_until_redeemable") val pointsUntilRedeemable: Int,
    @SerialName("rewards_unlocked") val rewardsUnlocked: Boolean,
    @SerialName("full_history") val fullHistory: Boolean = false,
    @SerialName("show_full_history") val showFullHistory: Boolean = false,
    val activities: List<LoyaltyActivityDto> = emptyList(),
)

@Serializable
data class LoyaltyCustomerDto(
    val name: String?,
    @SerialName("phone_number") val phoneNumber: String?,
)

@Serializable
data class LoyaltyActivityDto(
    val id: Long,
    @SerialName("entry_type") val entryType: String, // "earn" | "redeem"
    val points: Int, // signed
    @SerialName("created_at") val createdAt: String,
    @SerialName("fuel_type") val fuelType: String? = null,
    @SerialName("vehicle_number") val vehicleNumber: String? = null,
    @SerialName("fuel_amount") val fuelAmount: Double? = null,
)

// ---- Staff: customer lookup + redemption ----

@Serializable
data class StaffCustomerDto(
    val id: Long,
    val name: String?,
    @SerialName("phone_number") val phoneNumber: String?,
    val active: Boolean,
    @SerialName("rewards_paused") val rewardsPaused: Boolean,
    @SerialName("status_label") val statusLabel: String,
    @SerialName("rewards_status_label") val rewardsStatusLabel: String,
    @SerialName("total_points") val totalPoints: Int,
    @SerialName("cash_value_per_point") val cashValuePerPoint: Double? = null,
    @SerialName("total_points_cash_reward") val totalPointsCashReward: Double? = null,
    @SerialName("minimum_redeemable_points") val minimumRedeemablePoints: Int,
    @SerialName("redemption_increment") val redemptionIncrement: Int,
    @SerialName("max_redeemable_points") val maxRedeemablePoints: Int,
    @SerialName("max_redeemable_cash_reward") val maxRedeemableCashReward: Double? = null,
    val vehicles: List<StaffVehicleDto> = emptyList(),
)

@Serializable
data class StaffVehicleDto(
    val id: Long,
    @SerialName("vehicle_number") val vehicleNumber: String,
    @SerialName("fuel_type_code") val fuelTypeCode: String?,
    @SerialName("fuel_type") val fuelType: String?,
    @SerialName("vehicle_kind") val vehicleKind: String?,
    @SerialName("vehicle_kind_code") val vehicleKindCode: String? = null,
    @SerialName("display_name") val displayName: String?,
    val commercial: Boolean = false,
    @SerialName("commercial_company_name") val commercialCompanyName: String? = null,
    @SerialName("commercial_contact_name") val commercialContactName: String? = null,
    @SerialName("commercial_contact_phone_number") val commercialContactPhoneNumber: String? = null,
    @SerialName("commercial_address") val commercialAddress: String? = null,
    @SerialName("commercial_notes") val commercialNotes: String? = null,
)

// ---- Staff: customers list + profile ----

@Serializable
data class CustomersListResponse(val customers: List<CustomerSummaryDto> = emptyList())

@Serializable
data class CustomerSummaryDto(
    val id: Long,
    val name: String?,
    @SerialName("phone_number") val phoneNumber: String?,
    @SerialName("customer_type") val customerType: String? = null,
    @SerialName("transport_name") val transportName: String? = null,
    val active: Boolean,
    @SerialName("rewards_paused") val rewardsPaused: Boolean,
    @SerialName("total_points") val totalPoints: Int,
    @SerialName("vehicle_numbers") val vehicleNumbers: List<String> = emptyList(),
    @SerialName("vehicles_count") val vehiclesCount: Int,
)

@Serializable
data class CustomerProfileDto(
    val id: Long,
    val name: String?,
    @SerialName("phone_number") val phoneNumber: String?,
    val active: Boolean,
    @SerialName("rewards_paused") val rewardsPaused: Boolean,
    @SerialName("status_label") val statusLabel: String,
    @SerialName("rewards_status_label") val rewardsStatusLabel: String,
    @SerialName("total_points") val totalPoints: Int,
    @SerialName("cash_value_per_point") val cashValuePerPoint: Double? = null,
    @SerialName("total_points_cash_reward") val totalPointsCashReward: Double? = null,
    @SerialName("minimum_redeemable_points") val minimumRedeemablePoints: Int,
    @SerialName("redemption_increment") val redemptionIncrement: Int,
    @SerialName("max_redeemable_points") val maxRedeemablePoints: Int,
    @SerialName("max_redeemable_cash_reward") val maxRedeemableCashReward: Double? = null,
    @SerialName("points_until_redeemable") val pointsUntilRedeemable: Int,
    @SerialName("joined_at") val joinedAt: String,
    @SerialName("visits_count") val visitsCount: Int,
    @SerialName("transactions_count") val transactionsCount: Int,
    // B1/E4 — account taxonomy + fleet master fields.
    @SerialName("customer_type") val customerType: String? = null,
    @SerialName("customer_type_label") val customerTypeLabel: String? = null,
    @SerialName("whatsapp_opt_in") val whatsappOptIn: Boolean = false,
    @SerialName("sms_opt_in") val smsOptIn: Boolean = false,
    @SerialName("transport_name") val transportName: String? = null,
    @SerialName("approx_vehicle_count") val approxVehicleCount: Int? = null,
    @SerialName("info_note") val infoNote: String? = null,
    // Item 13 — the full dated note log, newest first. `infoNote` above is just
    // the most recent entry, kept for older builds.
    val notes: List<CustomerNoteDto> = emptyList(),
    val contacts: List<CustomerContactDto> = emptyList(),
    val vehicles: List<StaffVehicleDto> = emptyList(),
    @SerialName("recent_transactions") val recentTransactions: List<TransactionSummaryDto> = emptyList(),
)

/** One dated entry in a customer's note log. */
@Serializable
data class CustomerNoteDto(
    val id: Long,
    val body: String,
    val author: String? = null,
    @SerialName("created_at") val createdAt: String,
)

@Serializable
data class CustomerCreateRequest(
    val name: String? = null,
    @SerialName("phone_number") val phoneNumber: String,
    @SerialName("info_note") val infoNote: String? = null,
)

@Serializable
data class CustomerCreateEnvelope(val customer: CustomerCreateRequest)

@Serializable
data class CustomerContactUpdateAttributes(
    val id: Long? = null,
    val role: String,
    val name: String? = null,
    @SerialName("phone_number") val phoneNumber: String? = null,
    val contacted: Boolean = false,
    val notes: String? = null,
    @SerialName("_destroy") val destroy: Boolean? = null,
)

// Staff/admin customer details, channel opt-ins, notes, and contacts.
@Serializable
data class CustomerUpdateRequest(
    val name: String? = null,
    @SerialName("info_note") val infoNote: String? = null,
    @SerialName("customer_type") val customerType: String? = null,
    @SerialName("whatsapp_opt_in") val whatsappOptIn: Boolean? = null,
    @SerialName("sms_opt_in") val smsOptIn: Boolean? = null,
    @SerialName("customer_contacts_attributes")
    val customerContactsAttributes: List<CustomerContactUpdateAttributes>? = null,
)

@Serializable
data class CustomerUpdateEnvelope(val customer: CustomerUpdateRequest)

@Serializable
data class VehicleUpdateRequest(
    @SerialName("vehicle_number") val vehicleNumber: String,
    @SerialName("fuel_type") val fuelType: String,
    @SerialName("vehicle_kind") val vehicleKind: String,
    @SerialName("commercial_company_name") val commercialCompanyName: String? = null,
    @SerialName("commercial_contact_name") val commercialContactName: String? = null,
    @SerialName("commercial_contact_phone_number") val commercialContactPhoneNumber: String? = null,
    @SerialName("commercial_address") val commercialAddress: String? = null,
    @SerialName("commercial_notes") val commercialNotes: String? = null,
)

@Serializable
data class VehicleUpdateEnvelope(val vehicle: VehicleUpdateRequest)

@Serializable
data class CustomerContactDto(
    val id: Long,
    val role: String,
    @SerialName("role_label") val roleLabel: String,
    val name: String? = null,
    @SerialName("phone_number") val phoneNumber: String? = null,
    val contacted: Boolean = false,
    @SerialName("contacted_at") val contactedAt: String? = null,
    val notes: String? = null,
)

@Serializable
data class TransactionSummaryDto(
    val id: Long,
    @SerialName("vehicle_number") val vehicleNumber: String?,
    @SerialName("handled_by") val handledBy: String?,
    val pump: String? = null,
    val nozzle: String? = null,
    @SerialName("points_earned") val pointsEarned: Int? = null,
    @SerialName("cash_reward") val cashReward: Double? = null,
    @SerialName("fuel_amount") val fuelAmount: Double,
    // Item 5 — the ₹ knocked off THIS fuelling (not the ₹ value of the points it
    // earned, which is `cashReward` above). The API serializes a plain 0 rather
    // than null when none was given; defaulted here so a build talking to an
    // older API that does not send the key at all still parses.
    @SerialName("discount_amount") val discountAmount: Double = 0.0,
    @SerialName("payment_mode") val paymentMode: String,
    @SerialName("created_at") val createdAt: String,
)

@Serializable
data class LedgerPageDto(
    val entries: List<LedgerEntryDto> = emptyList(),
    val page: Int,
    @SerialName("per_page") val perPage: Int,
    val total: Int,
    @SerialName("has_more") val hasMore: Boolean,
)

@Serializable
data class LedgerEntryDto(
    val id: Long,
    @SerialName("entry_type") val entryType: String,
    val label: String,
    val points: Int,
    @SerialName("cash_reward") val cashReward: Double? = null,
    @SerialName("created_at") val createdAt: String,
)

@Serializable
data class RedemptionRequest(
    @SerialName("phone_number") val phoneNumber: String,
    val points: Int,
)

@Serializable
data class RedemptionEnvelope(val redemption: RedemptionRequest)

@Serializable
data class RedemptionResponse(
    @SerialName("points_redeemed") val pointsRedeemed: Int,
    @SerialName("cash_reward_amount") val cashRewardAmount: Double? = null,
    val message: String,
    val customer: StaffCustomerDto,
)

@Serializable
data class PointsAdjustmentRequest(
    @SerialName("phone_number") val phoneNumber: String,
    val points: Int,
)

@Serializable
data class PointsAdjustmentEnvelope(
    @SerialName("points_adjustment") val pointsAdjustment: PointsAdjustmentRequest,
)

@Serializable
data class PointsAdjustmentResponse(
    @SerialName("points_adjusted") val pointsAdjusted: Int,
    val message: String,
    val customer: StaffCustomerDto,
)

// ---- Staff: catalog (form reference data) + inline customer registration ----

/**
 * Active fuel types and vehicle kinds an attendant can choose when registering a
 * customer for an unregistered plate — the same option sources the web form uses
 * (FuelType.active_options / VehicleType.active_options).
 */
@Serializable
data class CatalogResponse(
    @SerialName("fuel_types") val fuelTypes: List<FuelTypeOptionDto> = emptyList(),
    @SerialName("vehicle_kinds") val vehicleKinds: List<VehicleKindOptionDto> = emptyList(),
)

@Serializable
data class FuelTypeOptionDto(val code: String, val label: String)

// B2 — FSM per-visit capture. Litres/discount go as strings to preserve the
// operator's exact decimals; the backend casts them.
@Serializable
data class VisitEntryRequest(
    @SerialName("vehicle_number") val vehicleNumber: String,
    val litres: String,
    @SerialName("fuel_pump_id") val fuelPumpId: Long? = null,
    @SerialName("fuel_type_code") val fuelTypeCode: String? = null,
    @SerialName("discount_amount") val discountAmount: String? = null,
    @SerialName("fleet_otp") val fleetOtp: Boolean = false,
    @SerialName("driver_name") val driverName: String? = null,
    @SerialName("driver_phone_number") val driverPhoneNumber: String? = null,
    @SerialName("transport_name") val transportName: String? = null,
    @SerialName("manager_name") val managerName: String? = null,
    @SerialName("manager_phone_number") val managerPhoneNumber: String? = null,
    @SerialName("owner_name") val ownerName: String? = null,
    @SerialName("owner_phone_number") val ownerPhoneNumber: String? = null,
    @SerialName("approx_vehicle_count") val approxVehicleCount: Int? = null,
)

@Serializable
data class VisitEntryEnvelope(@SerialName("visit_entry") val visitEntry: VisitEntryRequest)

@Serializable
data class VisitEntryDto(
    val id: Long,
    @SerialName("entry_date") val entryDate: String,
    @SerialName("vehicle_number") val vehicleNumber: String,
    @SerialName("customer_id") val customerId: Long? = null,
    @SerialName("customer_name") val customerName: String? = null,
    val litres: Double,
    @SerialName("discount_amount") val discountAmount: Double,
    @SerialName("fleet_otp") val fleetOtp: Boolean = false,
    @SerialName("fuel_pump") val fuelPump: String? = null,
)

@Serializable
data class VisitEntryCreateResponse(
    @SerialName("visit_entry") val visitEntry: VisitEntryDto,
    @SerialName("points_earned") val pointsEarned: Int? = null,
    @SerialName("transaction_id") val transactionId: Long? = null,
)

@Serializable
data class VehicleKindOptionDto(
    val code: String,
    val label: String,
    // lcv/mcv/hcv: the client shows the commercial fields (company/contact/address).
    val commercial: Boolean = false,
)

@Serializable
data class RegisterCustomerRequest(
    val name: String,
    @SerialName("phone_number") val phoneNumber: String,
    @SerialName("vehicle_number") val vehicleNumber: String,
    @SerialName("fuel_type") val fuelType: String,
    @SerialName("vehicle_kind") val vehicleKind: String,
    @SerialName("commercial_company_name") val commercialCompanyName: String? = null,
    @SerialName("commercial_contact_name") val commercialContactName: String? = null,
    @SerialName("commercial_contact_phone_number") val commercialContactPhoneNumber: String? = null,
    @SerialName("commercial_address") val commercialAddress: String? = null,
    @SerialName("commercial_notes") val commercialNotes: String? = null,
)

@Serializable
data class RegisterCustomerEnvelope(val customer: RegisterCustomerRequest)

@Serializable
data class RegisterCustomerResponse(
    val registration: String? = null,
    val customer: StaffCustomerDto,
)

// ---- Staff: new transaction (vehicle lookup, My Pump, create) ----

@Serializable
data class VehicleLookupResponse(val matches: List<VehicleMatchDto> = emptyList())

@Serializable
data class VehicleMatchDto(
    @SerialName("vehicle_id") val vehicleId: Long,
    @SerialName("vehicle_number") val vehicleNumber: String,
    @SerialName("fuel_type_code") val fuelTypeCode: String?,
    @SerialName("fuel_type") val fuelType: String?,
    @SerialName("vehicle_kind_code") val vehicleKindCode: String?,
    @SerialName("vehicle_kind") val vehicleKind: String?,
    val customer: StaffCustomerDto,
)

@Serializable
data class MyPumpDto(
    @SerialName("assignment_mode") val assignmentMode: String? = null,
    @SerialName("assignment_date") val assignmentDate: String? = null,
    @SerialName("fuel_pump_id") val fuelPumpId: Long? = null,
    @SerialName("assigned_fuel_pump_nozzle_ids") val assignedNozzleIds: List<Long> = emptyList(),
    val ready: Boolean = false,
    val pumps: List<PumpDto> = emptyList(),
    val message: String? = null,
) {
    /** The active, assigned nozzles on the currently selected pump. */
    fun assignedNozzles(): List<NozzleDto> {
        val pump = pumps.firstOrNull { it.id == fuelPumpId } ?: return emptyList()
        return pump.nozzles.filter { it.active && it.id in assignedNozzleIds }
    }
}

/**
 * PATCH /api/v1/my_pump body — canonical nested `user{}` envelope
 * (base_controller has `wrap_parameters false`, so it must be explicit).
 *
 * [assignedNozzleIds] are strings so the leading `""` sentinel is representable:
 * Rails' `collection_ids=` compacts blanks, but the key must be *present* as an
 * array for the assignment to register — matching the web form's hidden field.
 */
@Serializable
data class MyPumpUpdateEnvelope(val user: MyPumpUpdateRequest)

@Serializable
data class MyPumpUpdateRequest(
    @SerialName("assignment_mode") val assignmentMode: String? = null,
    @SerialName("assignment_date") val assignmentDate: String? = null,
    @SerialName("fuel_pump_id") val fuelPumpId: Long,
    @SerialName("assigned_fuel_pump_nozzle_ids") val assignedNozzleIds: List<String>,
)

@Serializable
data class PumpDto(
    val id: Long,
    @SerialName("display_name") val displayName: String,
    val active: Boolean,
    val nozzles: List<NozzleDto> = emptyList(),
)

@Serializable
data class NozzleDto(
    val id: Long,
    @SerialName("display_name") val displayName: String,
    @SerialName("fuel_type_code") val fuelTypeCode: String?,
    @SerialName("fuel_type") val fuelType: String?,
    val active: Boolean,
)

@Serializable
data class TransactionCreateRequest(
    @SerialName("lookup_mode") val lookupMode: String,
    @SerialName("phone_number") val phoneNumber: String? = null,
    @SerialName("vehicle_number") val vehicleNumber: String? = null,
    @SerialName("vehicle_id") val vehicleId: Long,
    @SerialName("fuel_amount") val fuelAmount: Double,
    @SerialName("discount_amount") val discountAmount: Double? = null,
    @SerialName("fuel_pump_id") val fuelPumpId: Long? = null,
    @SerialName("fuel_pump_nozzle_id") val fuelPumpNozzleId: Long? = null,
    @SerialName("payment_mode") val paymentMode: String,
    // Item 2 — the fleet/driver detail that used to be a separate Capture Visit
    // post. Sent with the sale so one submit records both records.
    @SerialName("fleet_otp") val fleetOtp: Boolean = false,
    @SerialName("transport_name") val transportName: String? = null,
    @SerialName("approx_vehicle_count") val approxVehicleCount: Int? = null,
    @SerialName("driver_name") val driverName: String? = null,
    @SerialName("driver_phone_number") val driverPhoneNumber: String? = null,
    @SerialName("manager_name") val managerName: String? = null,
    @SerialName("manager_phone_number") val managerPhoneNumber: String? = null,
    @SerialName("owner_name") val ownerName: String? = null,
    @SerialName("owner_phone_number") val ownerPhoneNumber: String? = null,
)

@Serializable
data class TransactionCreateEnvelope(val transaction: TransactionCreateRequest)

@Serializable
data class TransactionCreateResponse(
    @SerialName("points_earned") val pointsEarned: Int = 0,
    @SerialName("rewards_paused") val rewardsPaused: Boolean = false,
    @SerialName("new_total") val newTotal: Int = 0,
    val message: String,
    // Set when the sale was recorded but the visit could not be (no catalog
    // price for the fuel); shown to the operator rather than swallowed.
    @SerialName("visit_skipped_reason") val visitSkippedReason: String? = null,
    val customer: StaffCustomerDto,
    val transaction: TransactionResultDto,
)

@Serializable
data class TransactionResultDto(
    val id: Long,
    @SerialName("fuel_amount") val fuelAmount: Double,
    @SerialName("payment_mode") val paymentMode: String,
    val pump: String? = null,
    val nozzle: String? = null,
    @SerialName("created_at") val createdAt: String,
)

// ---- Error envelope: {"error":{"code","message","details?}} ----

@Serializable
data class ErrorEnvelope(val error: ErrorBody)

@Serializable
data class ErrorBody(
    val code: String? = null,
    val message: String? = null,
    val details: Map<String, List<String>>? = null,
)
