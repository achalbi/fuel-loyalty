package com.acefuel.loyalty.ui.admin.staff

import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Path

/**
 * Admin Staff endpoints. The shared OkHttp client attaches the bearer token and
 * the base URL already ends in "/", so paths are relative "api/v1/...". Request
 * bodies use the canonical nested envelope ({"user":{...}} /
 * {"shift_assignment":{...}}).
 */
interface AdminStaffApi {

    @GET("api/v1/admin/staff_members")
    suspend fun listStaffMembers(): StaffMembersResponse

    @PATCH("api/v1/admin/staff_members/{id}")
    suspend fun updateStaffMember(
        @Path("id") id: Long,
        @Body body: StaffUpdateEnvelope,
    ): StaffMemberDto

    @DELETE("api/v1/admin/staff_members/{id}")
    suspend fun deleteStaffMember(@Path("id") id: Long): StaffMemberDto

    @POST("api/v1/admin/staff_members/{id}/shift_assignments")
    suspend fun assignShift(
        @Path("id") id: Long,
        @Body body: ShiftAssignmentEnvelope,
    ): ShiftAssignmentDto

    @GET("api/v1/admin/shift_templates")
    suspend fun listShiftTemplates(): ShiftTemplatesResponse
}
