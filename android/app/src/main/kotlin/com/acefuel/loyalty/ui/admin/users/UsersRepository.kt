package com.acefuel.loyalty.ui.admin.users

import android.content.ContentResolver
import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody

/** Wraps [UsersApi] calls into [ApiResult] via the shared [apiCall] helper. */
class UsersRepository(
    private val api: UsersApi,
    private val json: Json,
    private val contentResolver: ContentResolver,
) {
    suspend fun list(): ApiResult<List<AdminUserDto>> =
        apiCall(json) { api.list().users }

    suspend fun show(id: Long): ApiResult<AdminUserDto> =
        apiCall(json) { api.show(id) }

    suspend fun create(request: AdminUserRequest): ApiResult<AdminUserDto> =
        apiCall(json) { api.create(AdminUserEnvelope(request)) }

    suspend fun update(id: Long, request: AdminUserRequest): ApiResult<AdminUserDto> =
        apiCall(json) { api.update(id, AdminUserEnvelope(request)) }

    // --- A7 operator KYC ----------------------------------------------------

    suspend fun createMultipart(
        request: AdminUserRequest,
        profilePhoto: PickedImage?,
        idCardPhoto: PickedImage?,
    ): ApiResult<AdminUserDto> = apiCall(json) {
        withContext(Dispatchers.IO) {
            api.createMultipart(
                partMap(request),
                filePart("user[profile_photo]", profilePhoto),
                filePart("user[id_card_photo]", idCardPhoto),
            )
        }
    }

    suspend fun updateMultipart(
        id: Long,
        request: AdminUserRequest,
        profilePhoto: PickedImage?,
        idCardPhoto: PickedImage?,
    ): ApiResult<AdminUserDto> = apiCall(json) {
        withContext(Dispatchers.IO) {
            api.updateMultipart(
                id,
                partMap(request),
                filePart("user[profile_photo]", profilePhoto),
                filePart("user[id_card_photo]", idCardPhoto),
            )
        }
    }

    suspend fun kycReveal(id: Long): ApiResult<KycRevealDto> =
        apiCall(json) { api.kycReveal(id) }

    suspend fun purgeKyc(id: Long): ApiResult<AdminUserDto> =
        apiCall(json) { api.purgeKyc(id) }

    // --- multipart body building -------------------------------------------

    /** Scalars as `user[...]` text parts. Null keys are dropped so an absent
     *  field never clobbers the stored value (parallels the JSON envelope). */
    private fun partMap(r: AdminUserRequest): Map<String, RequestBody> = buildMap {
        fun add(key: String, value: String?) {
            if (value != null) put("user[$key]", value.toRequestBody(TEXT_PLAIN))
        }
        add("name", r.name)
        add("username", r.username)
        add("phone_number", r.phoneNumber)
        add("email", r.email)
        add("role", r.role)
        add("active", r.active?.toString())
        add("password", r.password)
        add("password_confirmation", r.passwordConfirmation)
        add("address", r.address)
        add("aadhaar_number", r.aadhaarNumber)
    }

    private fun filePart(field: String, image: PickedImage?): MultipartBody.Part? {
        if (image == null) return null
        val bytes = contentResolver.openInputStream(image.uri)?.use { it.readBytes() } ?: return null
        val body = bytes.toRequestBody(image.mime.toMediaTypeOrNull())
        return MultipartBody.Part.createFormData(field, image.filename, body)
    }

    private companion object {
        val TEXT_PLAIN = "text/plain".toMediaType()
    }
}
