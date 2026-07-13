package com.acefuel.loyalty.core.network

import com.acefuel.loyalty.core.network.dto.AuthResponse
import com.acefuel.loyalty.core.network.dto.CustomerProfileDto
import com.acefuel.loyalty.core.network.dto.CustomersListResponse
import com.acefuel.loyalty.core.network.dto.LedgerPageDto
import com.acefuel.loyalty.core.network.dto.LoginRequest
import com.acefuel.loyalty.core.network.dto.LoyaltyLookupEnvelope
import com.acefuel.loyalty.core.network.dto.LoyaltyResponse
import com.acefuel.loyalty.core.network.dto.MeResponse
import com.acefuel.loyalty.core.network.dto.MyPumpDto
import com.acefuel.loyalty.core.network.dto.PointsAdjustmentEnvelope
import com.acefuel.loyalty.core.network.dto.PointsAdjustmentResponse
import com.acefuel.loyalty.core.network.dto.RedemptionEnvelope
import com.acefuel.loyalty.core.network.dto.RedemptionResponse
import com.acefuel.loyalty.core.network.dto.RefreshRequest
import com.acefuel.loyalty.core.network.dto.StaffCustomerDto
import com.acefuel.loyalty.core.network.dto.ThemeDto
import com.acefuel.loyalty.core.network.dto.TransactionCreateEnvelope
import com.acefuel.loyalty.core.network.dto.TransactionCreateResponse
import com.acefuel.loyalty.core.network.dto.VehicleLookupResponse
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.HTTP
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Query

/** Retrofit surface for /api/v1. Grows one endpoint per feature slice. */
interface AceFuelApi {

    @POST("api/v1/auth/login")
    suspend fun login(@Body body: LoginRequest): AuthResponse

    @POST("api/v1/auth/refresh")
    suspend fun refresh(@Body body: RefreshRequest): AuthResponse

    @HTTP(method = "DELETE", path = "api/v1/auth/logout", hasBody = false)
    suspend fun logout()

    @GET("api/v1/auth/me")
    suspend fun me(): MeResponse

    @GET("api/v1/theme")
    suspend fun theme(): ThemeDto

    @POST("api/v1/loyalty/lookup")
    suspend fun loyaltyLookup(@Body body: LoyaltyLookupEnvelope): LoyaltyResponse

    // ---- Staff ----

    @GET("api/v1/staff/customers/lookup")
    suspend fun staffCustomerLookup(@Query("phone_number") phoneNumber: String): StaffCustomerDto

    @GET("api/v1/staff/customers")
    suspend fun staffCustomers(@Query("q") query: String?): CustomersListResponse

    @GET("api/v1/staff/customers/{id}")
    suspend fun staffCustomerProfile(@Path("id") id: Long): CustomerProfileDto

    @GET("api/v1/staff/customers/{id}/ledger")
    suspend fun staffCustomerLedger(@Path("id") id: Long, @Query("page") page: Int): LedgerPageDto

    @PATCH("api/v1/staff/customers/{id}/pause_rewards")
    suspend fun pauseRewards(@Path("id") id: Long): CustomerProfileDto

    @PATCH("api/v1/staff/customers/{id}/resume_rewards")
    suspend fun resumeRewards(@Path("id") id: Long): CustomerProfileDto

    @PATCH("api/v1/staff/customers/{id}/activate")
    suspend fun activateCustomer(@Path("id") id: Long): CustomerProfileDto

    @PATCH("api/v1/staff/customers/{id}/deactivate")
    suspend fun deactivateCustomer(@Path("id") id: Long): CustomerProfileDto

    @POST("api/v1/staff/redemptions")
    suspend fun redeem(@Body body: RedemptionEnvelope): RedemptionResponse

    @GET("api/v1/staff/transactions/lookup")
    suspend fun vehicleLookup(@Query("vehicle_number") vehicleNumber: String): VehicleLookupResponse

    @POST("api/v1/staff/transactions")
    suspend fun createTransaction(@Body body: TransactionCreateEnvelope): TransactionCreateResponse

    @GET("api/v1/my_pump")
    suspend fun myPump(): MyPumpDto

    // ---- Admin ----

    @POST("api/v1/admin/points_adjustments")
    suspend fun adjustPoints(@Body body: PointsAdjustmentEnvelope): PointsAdjustmentResponse
}
