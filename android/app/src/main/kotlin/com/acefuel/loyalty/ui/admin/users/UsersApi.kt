package com.acefuel.loyalty.ui.admin.users

import okhttp3.MultipartBody
import okhttp3.RequestBody
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.Multipart
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Part
import retrofit2.http.PartMap
import retrofit2.http.Path

/**
 * Admin Users endpoints. The shared OkHttp client attaches the bearer token and
 * the base URL already ends in "/", so paths stay relative "api/v1/...". JSON
 * request bodies use the canonical nested envelope ({"user":{...}}); the
 * multipart variants send the same scalars as `user[...]` parts alongside the
 * optional image parts (used only when an image was picked — see UsersRepository).
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

    // --- A7 operator KYC ----------------------------------------------------

    @Multipart
    @POST("api/v1/admin/users")
    suspend fun createMultipart(
        @PartMap fields: Map<String, @JvmSuppressWildcards RequestBody>,
        @Part profilePhoto: MultipartBody.Part?,
        @Part idCardPhoto: MultipartBody.Part?,
    ): AdminUserDto

    @Multipart
    @PATCH("api/v1/admin/users/{id}")
    suspend fun updateMultipart(
        @Path("id") id: Long,
        @PartMap fields: Map<String, @JvmSuppressWildcards RequestBody>,
        @Part profilePhoto: MultipartBody.Part?,
        @Part idCardPhoto: MultipartBody.Part?,
    ): AdminUserDto

    /** Audited full-Aadhaar + signed ID-card reveal (admin-only). */
    @GET("api/v1/admin/users/{id}/kyc_reveal")
    suspend fun kycReveal(@Path("id") id: Long): KycRevealDto

    /** Purge KYC (nulls Aadhaar, drops the ID-card image) — keeps the account. */
    @DELETE("api/v1/admin/users/{id}/kyc")
    suspend fun purgeKyc(@Path("id") id: Long): AdminUserDto
}
