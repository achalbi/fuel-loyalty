package com.acefuel.loyalty.core.data

import com.acefuel.loyalty.core.network.AceFuelApi
import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import com.acefuel.loyalty.core.network.dto.LoyaltyLookupEnvelope
import com.acefuel.loyalty.core.network.dto.LoyaltyLookupRequest
import com.acefuel.loyalty.core.network.dto.LoyaltyResponse
import kotlinx.serialization.json.Json

class LoyaltyRepository(
    private val api: AceFuelApi,
    private val json: Json,
    private val cache: LoyaltyCache,
) {
    suspend fun lookup(phoneNumber: String, fullHistory: Boolean = false): ApiResult<LoyaltyResponse> {
        val result = apiCall(json) {
            api.loyaltyLookup(LoyaltyLookupEnvelope(LoyaltyLookupRequest(phoneNumber, fullHistory)))
        }
        if (result is ApiResult.Success) {
            cache.save(phoneNumber, result.data, System.currentTimeMillis())
        }
        return result
    }

    /** Last cached result for this phone (for the offline fallback). */
    suspend fun cachedFor(phoneNumber: String): CachedLoyalty? = cache.get(phoneNumber)
}
