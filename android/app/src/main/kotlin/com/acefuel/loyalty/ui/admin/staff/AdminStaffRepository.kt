package com.acefuel.loyalty.ui.admin.staff

import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import kotlinx.serialization.json.Json

/** Wraps [AdminStaffApi] calls into [ApiResult] via the shared [apiCall] helper. */
class AdminStaffRepository(
    private val api: AdminStaffApi,
    private val json: Json,
) {
    suspend fun loadStaff(): ApiResult<StaffMembersResponse> =
        apiCall(json) { api.listStaffMembers() }

    suspend fun loadShiftTemplates(): ApiResult<List<ShiftTemplateDto>> =
        apiCall(json) { api.listShiftTemplates().shiftTemplates }

    suspend fun updateProfile(
        id: Long,
        name: String,
        employeeCode: String,
        subtitle: String,
        active: Boolean,
    ): ApiResult<StaffMemberDto> =
        apiCall(json) {
            api.updateStaffMember(
                id,
                StaffUpdateEnvelope(StaffUpdateRequest(name, employeeCode, subtitle, active)),
            )
        }

    suspend fun softDelete(id: Long): ApiResult<StaffMemberDto> =
        apiCall(json) { api.deleteStaffMember(id) }

    suspend fun assignShift(id: Long, shiftTemplateId: Long, notes: String?): ApiResult<ShiftAssignmentDto> =
        apiCall(json) {
            api.assignShift(id, ShiftAssignmentEnvelope(ShiftAssignmentRequest(shiftTemplateId, notes)))
        }
}
