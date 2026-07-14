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
 * Indian plate normalization + OCR fixup. A faithful Kotlin port of the server's
 * [VehiclePlateText] (app/services/vehicle_plate_text.rb) so the on-device ML Kit
 * path corrects the different Indian plate formats exactly as the backend would.
 *
 * STANDARD covers `SS DD SSS NNNN` (state letters, 1–2 district digits, 0–3 series
 * letters, 1–4 number digits); BH covers the `NN BH NNNN SS` series. `normalizeDetected`
 * fixes the usual OCR letter/digit swaps segment by segment, preferring the canonical plate
 * shape (2-digit district + 4-digit number) and otherwise the fewest corrections, and refusing
 * anything past [MAX_SAFE_OCR_REPLACEMENTS] so unrelated text isn't force-fit into a plate.
 */
object PlateText {
    private val STANDARD = Regex("^[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{1,4}$")
    private val BH = Regex("^[0-9]{2}BH[0-9]{4}[A-Z]{2}$")
    private const val MAX_SAFE_OCR_REPLACEMENTS = 3

    // Digits an OCR pass commonly reads where a letter belongs, and vice-versa.
    private val LETTER_SUBSTITUTIONS = mapOf(
        '0' to 'O', '1' to 'I', '2' to 'Z', '5' to 'S', '6' to 'G', '8' to 'B',
    )
    private val DIGIT_SUBSTITUTIONS = mapOf(
        'O' to '0', 'Q' to '0', 'D' to '0', 'I' to '1', 'L' to '1', 'T' to '1',
        'Z' to '2', 'S' to '5', 'B' to '8', 'G' to '6',
    )

    /** Upper-case and strip everything but ASCII A–Z / 0–9 (matches the server). */
    fun normalize(raw: String): String =
        raw.uppercase().filter { it in 'A'..'Z' || it in '0'..'9' }

    fun isValid(value: String): Boolean {
        val candidate = normalize(value)
        return STANDARD.matches(candidate) || BH.matches(candidate)
    }

    /**
     * Normalize a single detected token, applying OCR fixup only when the raw read
     * isn't already a valid plate. Returns the corrected plate, or the plain
     * normalized string when no safe correction lands.
     */
    fun normalizeDetected(value: String): String {
        val candidate = normalize(value)
        if (candidate.isEmpty() || isValid(candidate)) return candidate
        return standardCandidate(candidate) ?: bhCandidate(candidate) ?: candidate
    }

    /**
     * Pick the best plate from raw OCR text. Tries the whole capture first (the
     * viewfinder frames just the plate) then individual tokens, preferring one that
     * OCR-corrects to a valid Indian plate; otherwise returns the whole stripped
     * capture so staff can edit it.
     */
    fun bestCandidate(ocrText: String): String? {
        val whole = normalize(ocrText)
        val tokens = ocrText.split(Regex("\\s+")).map { normalize(it) }
        val candidates = (listOf(whole) + tokens).filter { it.length in 6..11 }
        for (candidate in candidates) {
            val corrected = normalizeDetected(candidate)
            if (isValid(corrected)) return corrected
        }
        return whole.takeIf { it.length in 6..11 }
    }

    /** Reconstruct a standard registration, scanning district (1–2) × series (0–3) splits. */
    private fun standardCandidate(candidate: String): String? {
        if (candidate.length !in 4..11) return null
        var best: String? = null
        var bestCost = Int.MAX_VALUE
        var bestPenalty = Int.MAX_VALUE
        for (districtLength in 1..2) {
            for (seriesLength in 0..3) {
                val numberLength = candidate.length - 2 - districtLength - seriesLength
                if (numberLength !in 1..4) continue

                val state = normalizeAlphaSegment(candidate.substring(0, 2))
                val district = normalizeDigitSegment(candidate.substring(2, 2 + districtLength))
                val series = normalizeAlphaSegment(
                    candidate.substring(2 + districtLength, 2 + districtLength + seriesLength),
                )
                val number = normalizeDigitSegment(candidate.substring(candidate.length - numberLength))
                val normalized = "$state$district$series$number"
                if (!STANDARD.matches(normalized)) continue

                val replacements = replacementCount(candidate, normalized)
                if (replacements > MAX_SAFE_OCR_REPLACEMENTS) continue

                // Prefer the canonical `SS DD SSS NNNN` reading — a 2-digit district code plus a
                // full 4-digit number — over a lopsided split (1-digit district, or an extra
                // trailing series letter that shrinks the number) that needs one fewer OCR fix.
                // The canonical shape is what a human reads off the plate, so it's worth up to one
                // extra correction; shapePenalty folds that "+1 tolerance" into the ranking and
                // breaks ties toward it. Mirrors VehiclePlateText#standard_candidate on the server.
                val shapePenalty = if (districtLength == 2 && numberLength == 4) 0 else 1
                val cost = replacements + shapePenalty
                if (cost < bestCost || (cost == bestCost && shapePenalty < bestPenalty)) {
                    bestCost = cost
                    bestPenalty = shapePenalty
                    best = normalized
                }
            }
        }
        return best
    }

    /** Reconstruct a BH-series registration (fixed `NN BH NNNN SS` layout). */
    private fun bhCandidate(candidate: String): String? {
        if (candidate.length != 10) return null
        val normalized = buildString {
            append(normalizeDigitSegment(candidate.substring(0, 2)))
            append(normalizeAlphaSegment(candidate.substring(2, 4)))
            append(normalizeDigitSegment(candidate.substring(4, 8)))
            append(normalizeAlphaSegment(candidate.substring(8, 10)))
        }
        if (!BH.matches(normalized)) return null
        if (normalized.substring(2, 4) != "BH") return null
        if (replacementCount(candidate, normalized) > MAX_SAFE_OCR_REPLACEMENTS) return null
        return normalized
    }

    private fun normalizeAlphaSegment(value: String): String =
        value.map { LETTER_SUBSTITUTIONS[it] ?: it }.joinToString("")

    private fun normalizeDigitSegment(value: String): String =
        value.map { DIGIT_SUBSTITUTIONS[it] ?: it }.joinToString("")

    private fun replacementCount(original: String, candidate: String): Int =
        original.zip(candidate).count { (left, right) -> left != right }
}
