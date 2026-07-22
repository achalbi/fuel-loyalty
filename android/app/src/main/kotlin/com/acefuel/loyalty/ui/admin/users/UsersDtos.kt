package com.acefuel.loyalty.ui.admin.users

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// ---- Responses ----

/** GET /api/v1/admin/users -> { "users": [ ... ] } */
@Serializable
data class AdminUsersResponse(
    val users: List<AdminUserDto> = emptyList(),
)

/**
 * Admin view of a User (Api::V1::Admin::UserSerializer): the shared user fields
 * plus the audit timestamps. `show`, `create` and `update` all return a bare
 * [AdminUserDto].
 */
@Serializable
data class AdminUserDto(
    val id: Long,
    val name: String? = null,
    val username: String? = null,
    val role: String, // "admin" | "staff"
    @SerialName("phone_number") val phoneNumber: String? = null,
    @SerialName("display_name") val displayName: String? = null,
    @SerialName("display_phone_number") val displayPhoneNumber: String? = null,
    val email: String? = null,
    @SerialName("employee_code") val employeeCode: String? = null,
    val subtitle: String? = null,
    @SerialName("avatar_initial") val avatarInitial: String? = null,
    val active: Boolean = true,
    // A7 — operator KYC, masked by default. The full Aadhaar and the raw ID-card
    // URL never appear here; they come only from the audited kyc_reveal endpoint.
    val address: String? = null,
    @SerialName("aadhaar_present") val aadhaarPresent: Boolean = false,
    @SerialName("aadhaar_masked") val aadhaarMasked: String? = null,
    @SerialName("profile_photo_url") val profilePhotoUrl: String? = null,
    @SerialName("id_card_present") val idCardPresent: Boolean = false,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
)

/**
 * GET /api/v1/admin/users/:id/kyc_reveal — admin-only, audited. Returns the full
 * Aadhaar and short-lived signed image URLs. Never cached to disk / persisted.
 */
@Serializable
data class KycRevealDto(
    @SerialName("aadhaar_number") val aadhaarNumber: String? = null,
    @SerialName("id_card_photo_url") val idCardPhotoUrl: String? = null,
    @SerialName("profile_photo_url") val profilePhotoUrl: String? = null,
)

// ---- Requests (canonical nested {"user":{...}} envelope) ----

/**
 * Only the keys we actually send are serialized (Json has encodeDefaults=false and
 * explicitNulls=false), so leaving [password]/[passwordConfirmation] null on an
 * update keeps the existing password server-side (see UsersController#update).
 */
@Serializable
data class AdminUserRequest(
    val name: String? = null,
    val username: String? = null,
    @SerialName("phone_number") val phoneNumber: String? = null,
    val email: String? = null,
    val role: String? = null,
    val active: Boolean? = null,
    val password: String? = null,
    @SerialName("password_confirmation") val passwordConfirmation: String? = null,
    // A7 — a blank/absent aadhaarNumber keeps the stored value (parallel to
    // password); clearing is done via the purge endpoint, not an empty edit.
    val address: String? = null,
    @SerialName("aadhaar_number") val aadhaarNumber: String? = null,
)

@Serializable
data class AdminUserEnvelope(val user: AdminUserRequest)
