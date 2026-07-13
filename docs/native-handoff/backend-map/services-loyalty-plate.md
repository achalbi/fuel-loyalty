## services:loyalty-plate

Three service objects. No ActiveRecord models/controllers/policies here, but these delegate to model class methods (`Customer.normalize_phone_number`, `Vehicle.normalize_vehicle_number`, `Vehicle.normalize_detected_vehicle_number`, `Vehicle.valid_vehicle_number?`) that the API layer must reuse.

---

### `LoyaltyLookupToken` (`app/services/loyalty_lookup_token.rb`)
Stateless class. Wraps a signed, expiring `Rails.application.message_verifier` token for phone-number lookups.

**Constants**
- `PURPOSE = "loyalty_lookup"` (frozen) — used as both the verifier key and the `purpose:` tag.
- `EXPIRY = 2.minutes` — token TTL.

**Public methods**

`self.generate(phone_number) -> String`
1. `normalized_phone_number = Customer.normalize_phone_number(phone_number)` (normalization delegated to Customer model — API must apply identical normalization).
2. Returns `verifier.generate(payload, purpose: PURPOSE, expires_in: EXPIRY)`.
3. Payload hash = `{ phone_number: normalized_phone_number, nonce: SecureRandom.hex(8) }`. `nonce` is 16 hex chars (8 bytes), makes each token unique.
- Return: signed token string. No error handling; whatever the normalizer / verifier raise propagates.

`self.verified_phone_number(token) -> String | nil`
1. `return nil if token.blank?`
2. `payload = verifier.verified(token, purpose: PURPOSE)` — returns `nil` on invalid signature, wrong purpose, or expired token (non-raising `.verified`).
3. `return nil if payload.blank?`
4. Returns `Customer.normalize_phone_number(payload[:phone_number] || payload["phone_number"])` — reads symbol key first, then string key (handles serializer key-type variance). Re-normalizes on read.
- Return: normalized phone string, or `nil` for blank/invalid/expired/blank-payload.

**Private (class-private)**
- `self.verifier` — `Rails.application.message_verifier(PURPOSE)`. Declared `private_class_method :verifier`.

**API note:** no error strings; failures surface as `nil`. Token round-trip is symmetric: same `PURPOSE` string and `Customer.normalize_phone_number` must be used on both ends. Expiry is 2 minutes from generation.

---

### `VehiclePlateText` (`app/services/vehicle_plate_text.rb`)
Stateless (`class << self`). Normalizes and OCR-corrects Indian vehicle plate strings. Pure string logic, no DB/IO.

**Constants**
- `STANDARD_REGEX = /\A[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{1,4}\z/` — standard Indian plate: 2 state letters, 1–2 district digits, 0–3 series letters, 1–4 number digits.
- `BH_REGEX = /\A[0-9]{2}BH[0-9]{4}[A-Z]{2}\z/` — Bharat (BH) series: 2 year digits, literal `BH`, 4 number digits, 2 series letters.
- `MAX_SAFE_OCR_REPLACEMENTS = 3` — max char substitutions tolerated before a correction is rejected.
- `LETTER_SUBSTITUTIONS` (frozen, digit→letter, applied in alpha segments): `"0"=>"O"`, `"1"=>"I"`, `"2"=>"Z"`, `"5"=>"S"`, `"6"=>"G"`, `"8"=>"B"`.
- `DIGIT_SUBSTITUTIONS` (frozen, letter→digit, applied in digit segments): `"O"=>"0"`, `"Q"=>"0"`, `"D"=>"0"`, `"I"=>"1"`, `"L"=>"1"`, `"T"=>"1"`, `"Z"=>"2"`, `"S"=>"5"`, `"B"=>"8"`, `"G"=>"6"`.

**Public methods**

`normalize(value) -> String`
- `value.to_s.upcase.gsub(/[^A-Z0-9]/, "")` — uppercase, strip everything except A–Z/0–9. (Order: to_s → upcase → strip.)

`valid?(value) -> Boolean`
- `candidate = normalize(value)`; returns `candidate.match?(STANDARD_REGEX) || candidate.match?(BH_REGEX)`.

`normalize_detected(value) -> String`
1. `candidate = normalize(value)`.
2. `return candidate if candidate.blank? || valid?(candidate)` — already-valid or blank passes through unchanged.
3. Else `detected_candidate(candidate) || candidate` — attempt OCR correction; if none succeeds, return the plain normalized string.
- Return: corrected plate, or normalized-but-uncorrected string. Never `nil` (blank input → `""`).

**Private (class-private)**

`detected_candidate(candidate)` → `standard_candidate(candidate) || bh_candidate(candidate)` (standard tried first).

`standard_candidate(candidate)`
1. `return nil unless candidate.length.between?(4, 11)`.
2. Brute-force segment split: `district_length ∈ 1..2`, `series_length ∈ 0..3`; `number_length = length - 2 - district_length - series_length`; `next unless number_length.between?(1,4)`.
3. Segments: `state = normalize_alpha_segment(candidate[0,2])`, `district = normalize_digit_segment(candidate[2, district_length])`, `series = normalize_alpha_segment(candidate[2+district_length, series_length])`, `number = normalize_digit_segment(candidate[-number_length, number_length])`.
4. `normalized_candidate = "#{state}#{district}#{series}#{number}"`; `next unless normalized_candidate.match?(STANDARD_REGEX)`.
5. `replacements = replacement_count(candidate, normalized_candidate)`; track `best_candidate = [replacements, normalized_candidate]` keeping the **minimum** replacement count (first-found wins on ties, since strictly `<`).
6. After loops: `return nil unless best_candidate.present?`; `return nil if best_candidate.first > MAX_SAFE_OCR_REPLACEMENTS` (>3 rejected); else return `best_candidate.last`.

`bh_candidate(candidate)`
1. `return nil unless candidate.length == 10`.
2. Build from fixed offsets: `normalize_digit_segment(candidate[0,2])` + `normalize_alpha_segment(candidate[2,2])` + `normalize_digit_segment(candidate[4,4])` + `normalize_alpha_segment(candidate[8,2])`, joined.
3. `return nil unless normalized_candidate.match?(BH_REGEX)`.
4. `return nil unless normalized_candidate[2,2] == "BH"` (positions 2–3 must literally be `BH`).
5. `return nil if replacement_count(candidate, normalized_candidate) > MAX_SAFE_OCR_REPLACEMENTS`.
6. Return `normalized_candidate`.

`normalize_alpha_segment(value)` — each char mapped via `LETTER_SUBSTITUTIONS.fetch(char, char)` (unmapped chars unchanged), joined.

`normalize_digit_segment(value)` — each char mapped via `DIGIT_SUBSTITUTIONS.fetch(char, char)`, joined.

`replacement_count(original, candidate)` — count of differing positions between the two strings (`zip` + count `left != right`; positional Hamming-style diff, length-tolerant via nil-zip).

No user-facing strings/errors in this class.

---

### `VehiclePlateRecognizer` (`app/services/vehicle_plate_recognizer.rb`)
Instance service (class `.call` convenience). Calls the external PlateRecognizer HTTP API, then post-processes candidates through `Vehicle` model methods.

**Constants**
- `DEFAULT_ENDPOINT = "https://api.platerecognizer.com/v1/plate-reader/"`.
- `DEFAULT_REGION = "in"`.
- `OPEN_TIMEOUT_SECONDS = 5`, `READ_TIMEOUT_SECONDS = 20`.

**Result struct** `Result = Struct.new(:found, :plate, :raw, :confidence, :valid, :corrected, :provider, :candidates, keyword_init: true)`
- `as_json(*)` returns exactly these keys (fixed order): `found, plate, raw, confidence, valid, corrected, provider, candidates`. This is the API's response shape.
  - `found` (bool), `plate` (String normalized best plate), `raw` (String, `Vehicle.normalize_vehicle_number(best raw)`), `confidence` (Integer 0–100), `valid` (bool), `corrected` (bool), `provider` (String, always `"plate_recognizer"`), `candidates` (Array, ≤3 hashes each `{plate, raw, confidence, valid}`).

**Error classes**
- `ConfigurationError < StandardError`
- `RecognitionError < StandardError`

**Env / config resolution** (used in both `.call` and `#initialize` signatures):
- `api_token:` ← `ENV["PLATE_RECOGNIZER_API_TOKEN"]`
- `endpoint:` ← `ENV["PLATE_RECOGNIZER_API_URL"].presence || DEFAULT_ENDPOINT`
- `region:` ← `ENV["PLATE_RECOGNIZER_REGION"].presence || DEFAULT_REGION`
- `logger:` ← `Rails.logger`

**Public methods**

`self.available?(api_token: ENV["PLATE_RECOGNIZER_API_TOKEN"]) -> Boolean` — `api_token.present?`.

`self.call(image_data:, api_token:, endpoint:, region:, logger:) -> Result` — instantiates and calls `#call`. Only `image_data:` is required.

`#initialize(image_data:, api_token:, endpoint:, region:, logger:)` — stores all as ivars.

`#call -> Result` (algorithm):
1. `raise ConfigurationError, "Plate recognition service is not configured."` unless `available?(api_token:)`.
2. `raise RecognitionError, "Capture a plate image first."` if `encoded_image.blank?`.
3. `payload = JSON.parse(perform_request.body)`; `build_result(payload)`.
4. Rescue chain:
   - `JSON::ParserError` → `raise RecognitionError, "Plate recognition returned an unreadable response: #{error.message}"`.
   - `RecognitionError, ConfigurationError` → re-raised as-is.
   - other `StandardError` → `logger&.warn("VehiclePlateRecognizer error: #{error.class}: #{error.message}")` then `raise RecognitionError, "Plate recognition could not be completed right now."`.

**Private**

`encoded_image` (memoized) — `image_data.to_s.split(",", 2).last.to_s.strip`. Strips a `data:` URI prefix (keeps part after first comma); if no comma, uses whole string.

`decoded_image` (memoized) — `Base64.strict_decode64(encoded_image)`; on `ArgumentError` → `raise RecognitionError, "The captured plate image could not be read: #{error.message}"`.

`upload_content_type` (memoized) — regex `image_data.to_s[/\Adata:([^;,]+)[;,]/, 1]` (MIME from data URI) `.presence || "image/jpeg"`.

`upload_filename` — `"plate-scan#{upload_extension}"`.

`upload_extension` — `image/png`→`.png`, `image/webp`→`.webp`, else `.jpg`.

`perform_request -> Net::HTTPResponse` (external HTTP call):
- `uri = URI.parse(endpoint)`; `Net::HTTP::Post`.
- Headers: `Authorization: "Token #{api_token}"`, `Accept: "application/json"`.
- Multipart form (`request.set_form([...], "multipart/form-data")`): field `"upload"` = `StringIO.new(decoded_image)` with `filename: upload_filename, content_type: upload_content_type`; field `"regions"` = `region`.
- `Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 20)`.
- Return response if `response.code.to_i` in 200–299; else `raise RecognitionError, error_message_for(response)`.

`build_result(payload) -> Result`:
1. `choices = candidate_choices(payload)`.
2. `best_choice = choices.max_by { |c| [c[:valid] ? 1 : 0, c[:score], c[:normalized].length] }` — rank by valid-first, then score, then longer normalized plate.
3. If `best_choice.blank?` → `Result.new(found: false, provider: "plate_recognizer", candidates: [])` (plate/raw/confidence/valid/corrected all `nil`).
4. Else `Result.new(found: true, plate: best[:normalized], raw: Vehicle.normalize_vehicle_number(best[:raw]), confidence: normalize_confidence(best[:score]), valid: best[:valid], corrected: best[:corrected], provider: "plate_recognizer", candidates: choices.first(3).map { |c| { plate: c[:normalized], raw: Vehicle.normalize_vehicle_number(c[:raw]), confidence: normalize_confidence(c[:score]), valid: c[:valid] } })`.

`candidate_choices(payload) -> Array<Hash>`:
1. Over `Array(payload["results"])`, flat_map: `raw_candidates = [{"plate"=>result["plate"], "score"=>result["score"]}] + Array(result["candidates"])` (primary plate first, then provider candidates).
2. `filter_map` each: `raw_plate = candidate["plate"].to_s`; `next if raw_plate.blank?`.
3. `normalized_plate = Vehicle.normalize_detected_vehicle_number(raw_plate)`.
4. Emit `{ raw: raw_plate, normalized: normalized_plate, score: candidate["score"].to_f, valid: Vehicle.valid_vehicle_number?(normalized_plate), corrected: normalized_plate != Vehicle.normalize_vehicle_number(raw_plate) }`.
5. `.uniq { |c| [c[:normalized], c[:raw]] }` — dedupe on normalized+raw pair.

`normalize_confidence(score) -> Integer`: `value = score.to_f`; `value *= 100 if value <= 1` (accepts 0–1 fraction or 0–100); `value.round`.

`error_message_for(response) -> String`:
- `parsed = JSON.parse(response.body)`; return first present of `parsed["detail"]`, `parsed["message"]`, `parsed.dig("error","message")`, else `"Plate recognition failed with status #{response.code}."`.
- Rescue `JSON::ParserError, TypeError` → `"Plate recognition failed with status #{response.code}."`.

**API notes:** `Vehicle.normalize_detected_vehicle_number` / `normalize_vehicle_number` / `valid_vehicle_number?` almost certainly delegate to `VehiclePlateText.normalize_detected` / `normalize` / `valid?` — the API must reuse the `Vehicle` wrappers, not call `VehiclePlateText` directly, to stay consistent. `corrected` = true when OCR correction changed the plaintext-normalized string. Confidence normalization is lossy (rounds to integer). All external-call failures collapse to `RecognitionError` with the five quoted messages above.