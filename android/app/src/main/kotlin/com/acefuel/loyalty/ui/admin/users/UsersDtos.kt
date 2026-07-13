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
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
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
)

@Serializable
data class AdminUserEnvelope(val user: AdminUserRequest)
