package com.acefuel.loyalty.ui.admin.users

import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Path

/**
 * Admin Users endpoints. The shared OkHttp client attaches the bearer token and
 * the base URL already ends in "/", so paths stay relative "api/v1/...". Request
 * bodies use the canonical nested envelope ({"user":{...}}).
 */
interface UsersApi {

    @GET("api/v1/admin/users")
    suspend fun list(): AdminUsersResponse

    @GET("api/v1/admin/users/{id}")
    suspend fun show(@Path("id") id: Long): AdminUserDto

    @POST("api/v1/admin/users")
    suspend fun create(@Body body: AdminUserEnvelope): AdminUserDto

    @PATCH("api/v1/admin/users/{id}")
    suspend fun update(@Path("id") id: Long, @Body body: AdminUserEnvelope): AdminUserDto
}
