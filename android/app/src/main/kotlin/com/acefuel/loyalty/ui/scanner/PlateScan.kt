package com.acefuel.loyalty.ui.scanner

import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import retrofit2.Retrofit
import retrofit2.http.Body
import retrofit2.http.POST

// ---- recognize_plate contract (docs/native-handoff/09) ----

@Serializable
data class PlateScanEnvelope(@SerialName("plate_scan") val plateScan: PlateScanBody)

@Serializable
data class PlateScanBody(@SerialName("image_data") val imageData: String)

@Serializable
data class PlateRecognitionDto(
    val found: Boolean = false,
    val plate: String? = null,
    val raw: String? = null,
    val confidence: Double? = null,
    val valid: Boolean = false,
    val corrected: Boolean = false,
    val provider: String? = null,
)

interface PlateApi {
    @POST("api/v1/staff/transactions/recognize_plate")
    suspend fun recognize(@Body body: PlateScanEnvelope): PlateRecognitionDto
}

class PlateScanRepository(private val api: PlateApi, private val json: Json) {
    /** Server recognition (Plate Recognizer). Returns Error on 422/502/503. */
    suspend fun recognize(imageDataUrl: String): ApiResult<PlateRecognitionDto> =
        apiCall(json) { api.recognize(PlateScanEnvelope(PlateScanBody(imageDataUrl))) }

    companion object {
        fun from(retrofit: Retrofit, json: Json) =
            PlateScanRepository(retrofit.create(PlateApi::class.java), json)
    }
}

/**
 * Indian plate normalization + OCR fixup (mirrors VehiclePlateText, docs/native-handoff/04.6).
 * Used by the on-device ML Kit fallback when the server path is unavailable.
 */
object PlateText {
    private val STANDARD = Regex("^[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{1,4}$")
    private val BH = Regex("^[0-9]{2}BH[0-9]{4}[A-Z]{2}$")

    fun normalize(raw: String): String = raw.uppercase().filter { it.isLetterOrDigit() }

    fun isValid(value: String): Boolean = STANDARD.matches(value) || BH.matches(value)

    /** Pick the best plate-shaped token from raw OCR text. */
    fun bestCandidate(ocrText: String): String? =
        ocrText.split(Regex("\\s+"))
            .map { normalize(it) }
            .filter { it.length in 6..11 }
            .firstOrNull { isValid(it) }
            ?: ocrText.replace(Regex("[^A-Za-z0-9]"), "").uppercase().takeIf { it.length in 6..11 }
}
