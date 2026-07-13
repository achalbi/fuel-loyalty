package com.acefuel.loyalty.ui.admin.users

import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import kotlinx.serialization.json.Json

/** Wraps [UsersApi] calls into [ApiResult] via the shared [apiCall] helper. */
class UsersRepository(
    private val api: UsersApi,
    private val json: Json,
) {
    suspend fun list(): ApiResult<List<AdminUserDto>> =
        apiCall(json) { api.list().users }

    suspend fun show(id: Long): ApiResult<AdminUserDto> =
        apiCall(json) { api.show(id) }

    suspend fun create(request: AdminUserRequest): ApiResult<AdminUserDto> =
        apiCall(json) { api.create(AdminUserEnvelope(request)) }

    suspend fun update(id: Long, request: AdminUserRequest): ApiResult<AdminUserDto> =
        apiCall(json) { api.update(id, AdminUserEnvelope(request)) }
}
